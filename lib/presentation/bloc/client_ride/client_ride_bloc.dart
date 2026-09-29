import 'dart:async';
import 'dart:developer' as developer;
import 'dart:math' as math;

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:rxdart/rxdart.dart';

import '../../../core/enums/client_ride_status.dart';
import '../../../core/enums/client_vehicle_category.dart';
import '../../../core/services/places_service.dart';
import '../../../core/utils/client_ride_pricing.dart';
import '../../../core/utils/location_helper.dart';
import '../../../data/models/ride_model.dart';
import '../../../domain/entities/ride_entity.dart';
import '../../../domain/entities/ride_offer_entity.dart';
import '../../../domain/repositories/ride_repository.dart';

part 'client_ride_event.dart';
part 'client_ride_state.dart';

class ClientRideBloc extends Bloc<ClientRideEvent, ClientRideState> {
  final PlacesService _placesService;
  final RideRepository _rideRepository;
  static const Duration _requestRecoveryWindow = Duration(minutes: 15);

  StreamSubscription<RideEntity>? _rideSubscription;
  StreamSubscription<List<RideOfferEntity>>? _rideOffersSubscription;
  Timer? _rideOffersPollTimer;
  String? _rideOffersPollRideId;

  ClientRideBloc({
    required PlacesService placesService,
    required RideRepository rideRepository,
  })  : _placesService = placesService,
        _rideRepository = rideRepository,
        super(const ClientRideState()) {
    on<OriginTextChanged>(
      _onOriginTextChanged,
      transformer: _debounce<OriginTextChanged>(),
    );
    on<DestTextChanged>(
      _onDestTextChanged,
      transformer: _debounce<DestTextChanged>(),
    );
    on<OriginSelected>(_onOriginSelected);
    on<DestSelected>(_onDestSelected);
    on<InitializePickupFromCurrentLocation>(
      _onInitializePickupFromCurrentLocation,
    );
    on<PickupPinMoved>(_onPickupPinMoved);
    on<DestPinMoved>(_onDestPinMoved);
    on<PriceChanged>(_onPriceChanged);
    on<VehicleCategoryChanged>(_onVehicleCategoryChanged);
    on<RidePreferencesChanged>(_onRidePreferencesChanged);
    on<StartEditingOrigin>(_onStartEditingOrigin);
    on<StartEditingDest>(_onStartEditingDest);
    on<BackToSearchPanel>(_onBackToSearchPanel);
    on<ProceedToReadyToRequest>(_onProceedToReadyToRequest);
    on<PaymentMethodChanged>(_onPaymentMethodChanged);
    on<SubmitRideRequest>(_onSubmitRideRequest);
    on<RideStatusUpdated>(_onRideStatusUpdated);
    on<StartSearch>(_onStartSearch);
    on<CancelRide>(_onCancelRide);
    on<CalculateRoute>(_onCalculateRoute);
    on<SubmitOffer>(_onSubmitOffer);
    on<AcceptDriverOffer>(_onAcceptDriverOffer);
    on<RejectRideOffer>(_onRejectRideOffer);
    on<RideOffersUpdated>(_onRideOffersUpdated);
    on<DismissTripCompleted>(_onDismissTripCompleted);
    on<CheckActiveRide>(_onCheckActiveRide);
    on<BoostOfferedPrice>(_onBoostOfferedPrice);
  }

  @override
  Future<void> close() async {
    _rideOffersPollTimer?.cancel();
    _rideOffersPollTimer = null;
    _rideOffersPollRideId = null;
    await _rideSubscription?.cancel();
    await _rideOffersSubscription?.cancel();
    await super.close();
  }

  EventTransformer<E> _debounce<E>() {
    return (events, mapper) => events
        .debounceTime(const Duration(milliseconds: 500))
        .switchMap(mapper);
  }

  Future<void> _onOriginTextChanged(
    OriginTextChanged event,
    Emitter<ClientRideState> emit,
  ) async {
    emit(
      state.copyWith(
        originName: event.text,
        status: ClientRideStatus.initial,
        errorMessage: null,
      ),
    );

    final predictions = await _placesService.searchPlaces(
      event.text,
      near: state.originLatLng,
      cityHint: _cityHintFromState(state),
    );
    emit(
      state.copyWith(
        originPredictions: predictions,
      ),
    );
  }

  Future<void> _onDestTextChanged(
    DestTextChanged event,
    Emitter<ClientRideState> emit,
  ) async {
    emit(
      state.copyWith(
        destName: event.text,
        status: ClientRideStatus.initial,
        errorMessage: null,
      ),
    );

    final basePredictions = await _placesService.searchPlaces(
      event.text,
      near: state.originLatLng,
      cityHint: _cityHintFromState(state),
    );
    final predictions = state.originLatLng == null
        ? basePredictions
        : await _placesService.enrichPredictionsWithDistance(
            predictions: basePredictions,
            origin: state.originLatLng!,
          );
    emit(
      state.copyWith(
        destPredictions: predictions,
      ),
    );
  }

  Future<void> _onOriginSelected(
    OriginSelected event,
    Emitter<ClientRideState> emit,
  ) async {
    emit(
      state.copyWith(
        originName: event.description,
        originPredictions: const [],
        errorMessage: null,
        status: ClientRideStatus.initial,
      ),
    );

    final details = await _placesService.getPlaceDetails(event.placeId);
    if (details == null) {
      emit(
        state.copyWith(
          status: ClientRideStatus.error,
          errorMessage: 'No se pudo obtener el punto de recojo',
        ),
      );
      return;
    }

    var nextState = state.copyWith(
      originLatLng: details.location,
      status: ClientRideStatus.initial,
    );

    if (nextState.originLatLng != null && nextState.destLatLng != null) {
      nextState = await _applyDrivingRoute(
        base: nextState,
        origin: nextState.originLatLng!,
        dest: nextState.destLatLng!,
      );
    }

    emit(nextState);
  }

  Future<void> _onInitializePickupFromCurrentLocation(
    InitializePickupFromCurrentLocation event,
    Emitter<ClientRideState> emit,
  ) async {
    if (state.originLatLng != null) return;
    try {
      final position = await LocationHelper.determinePosition();
      final latLng = LatLng(position.latitude, position.longitude);
      final address = await _placesService.reverseGeocode(latLng);
      emit(
        state.copyWith(
          originLatLng: latLng,
          originName: address ?? 'Mi ubicación actual',
          originPredictions: const [],
          errorMessage: null,
        ),
      );
    } catch (_) {
      // No bloquea el flujo si el usuario aún no otorgó permisos.
    }
  }

  Future<void> _onPickupPinMoved(
    PickupPinMoved event,
    Emitter<ClientRideState> emit,
  ) async {
    final movedLatLng = event.position;
    final address = await _placesService.reverseGeocode(movedLatLng);
    var nextState = state.copyWith(
      originLatLng: movedLatLng,
      originName: address ?? 'Punto de recojo seleccionado',
      originPredictions: const [],
      routePolyline: const [],
      routeDistanceKm: null,
      routeDurationSeconds: null,
      routeBaseSuggested: null,
      suggestedPrice: null,
      offeredPrice: 0,
      status: ClientRideStatus.initial,
      errorMessage: null,
    );

    if (nextState.destLatLng != null) {
      nextState = await _applyDrivingRoute(
        base: nextState,
        origin: movedLatLng,
        dest: nextState.destLatLng!,
      );
    }

    emit(nextState);
  }

  Future<void> _onDestPinMoved(
    DestPinMoved event,
    Emitter<ClientRideState> emit,
  ) async {
    final movedLatLng = event.position;
    final address = await _placesService.reverseGeocode(movedLatLng);
    var nextState = state.copyWith(
      destLatLng: movedLatLng,
      destName: address ?? 'Destino seleccionado',
      destPredictions: const [],
      routePolyline: const [],
      routeDistanceKm: null,
      routeDurationSeconds: null,
      routeBaseSuggested: null,
      suggestedPrice: null,
      offeredPrice: 0,
      status: ClientRideStatus.initial,
      errorMessage: null,
    );

    if (nextState.originLatLng != null) {
      nextState = await _applyDrivingRoute(
        base: nextState,
        origin: nextState.originLatLng!,
        dest: movedLatLng,
      );
    }

    emit(nextState);
  }

  Future<void> _onDestSelected(
    DestSelected event,
    Emitter<ClientRideState> emit,
  ) async {
    emit(
      state.copyWith(
        destName: event.description,
        destPredictions: const [],
        errorMessage: null,
        status: ClientRideStatus.initial,
      ),
    );

    final details = await _placesService.getPlaceDetails(event.placeId);
    if (details == null) {
      emit(
        state.copyWith(
          status: ClientRideStatus.error,
          errorMessage: 'No se pudo obtener el destino',
        ),
      );
      return;
    }

    var nextState = state.copyWith(
      destLatLng: details.location,
      status: ClientRideStatus.initial,
    );

    if (nextState.originLatLng != null && nextState.destLatLng != null) {
      nextState = await _applyDrivingRoute(
        base: nextState,
        origin: nextState.originLatLng!,
        dest: nextState.destLatLng!,
      );
    }

    emit(nextState);
  }

  void _onPriceChanged(
    PriceChanged event,
    Emitter<ClientRideState> emit,
  ) {
    emit(
      state.copyWith(
        offeredPrice: ClientRidePricing.clampOfferedPrice(
          price: event.price,
          suggestedPrice: state.suggestedPrice,
        ),
        errorMessage: null,
      ),
    );
  }

  void _onStartEditingOrigin(
    StartEditingOrigin event,
    Emitter<ClientRideState> emit,
  ) {
    emit(
      state.copyWith(
        status: ClientRideStatus.initial,
        originLatLng: null,
        originPredictions: const [],
        routePolyline: const [],
        suggestedPrice: null,
        routeBaseSuggested: null,
        offeredPrice: 0,
        errorMessage: null,
        vehicleCategory: ClientVehicleCategory.standard,
        moreThanFourPassengers: false,
        babySeat: false,
        pet: false,
        rideComments: '',
      ),
    );
  }

  void _onStartEditingDest(
    StartEditingDest event,
    Emitter<ClientRideState> emit,
  ) {
    emit(
      state.copyWith(
        status: ClientRideStatus.initial,
        destLatLng: null,
        destPredictions: const [],
        routePolyline: const [],
        suggestedPrice: null,
        routeBaseSuggested: null,
        offeredPrice: 0,
        errorMessage: null,
        vehicleCategory: ClientVehicleCategory.standard,
        moreThanFourPassengers: false,
        babySeat: false,
        pet: false,
        rideComments: '',
      ),
    );
  }

  Future<void> _onBackToSearchPanel(
    BackToSearchPanel event,
    Emitter<ClientRideState> emit,
  ) async {
    await _rideSubscription?.cancel();
    _rideSubscription = null;
    _stopListeningToRideOffers();
    final pay = state.paymentMethod;
    emit(ClientRideState(paymentMethod: pay));
  }

  void _startListeningToRideOffers(String rideId) {
    if (rideId.isEmpty || rideId == 'temporal') return;
    _rideOffersPollTimer?.cancel();
    _rideOffersSubscription?.cancel();
    _rideOffersPollRideId = rideId;

    _rideOffersSubscription = _rideRepository
        .listenToRideOffers(rideId, pendingOnly: true)
        .listen(
          (offers) => add(RideOffersUpdated(offers)),
          onError: (Object e, StackTrace st) {
            developer.log(
              'listenToRideOffers subscription: $e',
              name: 'ClientRideBloc',
              error: e,
              stackTrace: st,
            );
          },
        );

    // Primera carga y sondeo: sin Realtime en `ride_offers` el stream no notifica entre dispositivos.
    Future<void> pull() async {
      try {
        final results = await Future.wait([
          _rideRepository.fetchPendingRideOffers(rideId),
          _rideRepository.getRideViewersCount(rideId),
        ]);
        final list = results[0] as List<RideOfferEntity>;
        final viewers = results[1] as int;
        if (!isClosed) add(RideOffersUpdated(list, viewersCount: viewers));
      } catch (e, st) {
        developer.log(
          'poll ride_offers: $e',
          name: 'ClientRideBloc',
          error: e,
          stackTrace: st,
        );
      }
    }

    Future<void>.microtask(pull);

    _rideOffersPollTimer = Timer.periodic(const Duration(seconds: 2), (_) {
      final id = _rideOffersPollRideId;
      if (id == null || id.isEmpty || isClosed) return;
      pull();
    });
  }

  void _stopListeningToRideOffers() {
    _rideOffersPollTimer?.cancel();
    _rideOffersPollTimer = null;
    _rideOffersPollRideId = null;
    _rideOffersSubscription?.cancel();
    _rideOffersSubscription = null;
  }

  void _onVehicleCategoryChanged(
    VehicleCategoryChanged event,
    Emitter<ClientRideState> emit,
  ) {
    emit(
      _stateWithRecalculatedPrices(
        state.copyWith(vehicleCategory: event.category),
      ),
    );
  }

  void _onRidePreferencesChanged(
    RidePreferencesChanged event,
    Emitter<ClientRideState> emit,
  ) {
    emit(
      _stateWithRecalculatedPrices(
        state.copyWith(
          moreThanFourPassengers:
              event.moreThanFourPassengers ?? state.moreThanFourPassengers,
          babySeat: event.babySeat ?? state.babySeat,
          pet: event.pet ?? state.pet,
          rideComments: event.rideComments ?? state.rideComments,
        ),
      ),
    );
  }

  Future<ClientRideState> _applyDrivingRoute({
    required ClientRideState base,
    required LatLng origin,
    required LatLng dest,
  }) async {
    final driving = await _placesService.getDrivingRoute(origin, dest);
    final distanceKm =
        driving?.distanceKm ?? _approxDistanceInKm(origin, dest);
    final points = driving?.points.isNotEmpty == true
        ? driving!.points
        : await _placesService.getRoutePolyline(origin, dest);
    final baseFare = _calculateSuggestedPrice(distanceKm);

    var next = base.copyWith(
      routePolyline: points,
      routeDistanceKm: distanceKm,
      routeDurationSeconds: driving?.durationSeconds,
      routeBaseSuggested: baseFare,
      vehicleCategory: ClientVehicleCategory.standard,
      moreThanFourPassengers: false,
      babySeat: false,
      pet: false,
      rideComments: '',
      status: base.status,
      errorMessage: null,
    );
    return _stateWithRecalculatedPrices(next);
  }

  Future<void> _onProceedToReadyToRequest(
    ProceedToReadyToRequest event,
    Emitter<ClientRideState> emit,
  ) async {
    final origin = state.originLatLng;
    final dest = state.destLatLng;
    if (origin == null || dest == null) return;

    ClientRideState next = state;
    if (state.routePolyline.isEmpty || state.routeBaseSuggested == null) {
      next = await _applyDrivingRoute(
        base: state,
        origin: origin,
        dest: dest,
      );
    }
    emit(
      _stateWithRecalculatedPrices(
        next.copyWith(status: ClientRideStatus.readyToRequest),
      ),
    );
  }

  ClientRideState _stateWithRecalculatedPrices(ClientRideState s) {
    final base = s.routeBaseSuggested;
    if (base == null || base <= 0) return s;
    final total = ClientRidePricing.totalSuggested(
      routeBase: base,
      category: s.vehicleCategory,
      moreThanFourPassengers: s.moreThanFourPassengers,
      babySeat: s.babySeat,
      pet: s.pet,
    );
    return s.copyWith(suggestedPrice: total, offeredPrice: total);
  }

  String _composeDestNameForPayload(ClientRideState s) {
    final name = s.destName ?? '';
    final tags = <String>[];
    switch (s.vehicleCategory) {
      case ClientVehicleCategory.comfort:
        tags.add('Confort');
        break;
      case ClientVehicleCategory.xl:
        tags.add('XL (hasta 6 pax)');
        break;
      case ClientVehicleCategory.standard:
        break;
    }
    if (s.moreThanFourPassengers) tags.add('Más de 4 pasajeros');
    if (s.babySeat) tags.add('Silla de bebé');
    if (s.pet) tags.add('Mascota');
    final buf = StringBuffer(name);
    if (tags.isNotEmpty) {
      buf.write('\n[Servicio: ${tags.join(', ')}]');
    }
    final notes = s.rideComments.trim();
    if (notes.isNotEmpty) {
      buf.write('\nNotas: $notes');
    }
    return buf.toString();
  }

  void _onPaymentMethodChanged(
    PaymentMethodChanged event,
    Emitter<ClientRideState> emit,
  ) {
    final m = event.method.trim().toLowerCase();
    final method = m == 'yape' ? 'yape' : (m == 'plin' ? 'plin' : 'efectivo');
    emit(
      state.copyWith(
        paymentMethod: method,
        errorMessage: null,
      ),
    );
  }

  Future<void> _onSubmitRideRequest(
    SubmitRideRequest event,
    Emitter<ClientRideState> emit,
  ) async {
    if (state.status == ClientRideStatus.requesting ||
        state.status == ClientRideStatus.searchingDriver) {
      return;
    }

    if (state.originLatLng == null ||
        state.destLatLng == null ||
        state.originName == null ||
        state.destName == null ||
        state.offeredPrice <= 0) {
      emit(
        state.copyWith(
          status: ClientRideStatus.error,
          errorMessage: 'Completa origen, destino y tarifa antes de continuar',
        ),
      );
      return;
    }

    // Validar que el clientId no esté vacío
    if (event.clientId.isEmpty) {
      emit(
        state.copyWith(
          status: ClientRideStatus.error,
          errorMessage:
              'No se pudo identificar tu usuario. Vuelve a iniciar sesión antes de pedir un viaje.',
        ),
      );
      return;
    }

    try {
      await _rideSubscription?.cancel();
      _rideSubscription = null;
      _stopListeningToRideOffers();

      emit(
        state.copyWith(
          status: ClientRideStatus.requesting,
          errorMessage: null,
        ),
      );

      final ride = RideModel(
        id: 'temporal',
        clientId: event.clientId,
        driverId: null,
        originLat: state.originLatLng!.latitude,
        originLng: state.originLatLng!.longitude,
        destLat: state.destLatLng!.latitude,
        destLng: state.destLatLng!.longitude,
        originName: state.originName!,
        destName: _composeDestNameForPayload(state),
        status: 'searching',
        offeredPrice: state.offeredPrice,
        finalPrice: null,
        createdAt: DateTime.now(),
        paymentMethod: state.paymentMethod,
      );

      final created = await _rideRepository.createRideRequest(ride);

      _rideSubscription = _rideRepository.subscribeToRide(created.id).listen(
            (updated) => add(RideStatusUpdated(updated)),
          );

      _startListeningToRideOffers(created.id);

      emit(
        state.copyWith(
          status: ClientRideStatus.searchingDriver,
          activeRide: created,
          pendingRideOffers: const [],
        ),
      );
    } catch (e, stack) {
      // Log detallado para depurar fallos al crear el viaje
      // ignore: avoid_print
      print('❌ Error al crear solicitud de viaje: $e');
      // ignore: avoid_print
      print('Stacktrace: $stack');

      emit(
        state.copyWith(
          status: ClientRideStatus.error,
          errorMessage: 'No se pudo crear la solicitud de viaje',
        ),
      );
    }
  }

  void _onRideStatusUpdated(
    RideStatusUpdated event,
    Emitter<ClientRideState> emit,
  ) {
    final ride = event.ride;
    developer.log(
      '[NEGOTIATION_DEBUG] RideStatusUpdated '
      'rideId=${ride.id} status=${ride.status} '
      'driverId=${ride.driverId} '
      'driverName=${ride.driverFullName} '
      'car=${ride.driverCarBrand} ${ride.driverCarModel} '
      'plate=${ride.driverCarPlate} '
      'offered=${ride.offeredPrice} final=${ride.finalPrice}',
      name: 'ClientRideBloc',
    );

    if (ride.status == 'accepted') {
      _stopListeningToRideOffers();
      emit(
        state.copyWith(
          status: ClientRideStatus.driverAssigned,
          activeRide: ride,
          pendingRideOffers: const [],
        ),
      );
    } else if (ride.status == 'negotiating' || ride.status == 'searching') {
      emit(
        state.copyWith(
          status: ClientRideStatus.searchingDriver,
          activeRide: ride,
        ),
      );
    } else if (ride.status == 'arrived') {
      emit(
        state.copyWith(
          status: ClientRideStatus.driverArrived,
          activeRide: ride,
        ),
      );
    } else if (ride.status == 'ongoing') {
      emit(
        state.copyWith(
          status: ClientRideStatus.tripOngoing,
          activeRide: ride,
        ),
      );
    } else if (ride.status == 'finished') {
      _rideSubscription?.cancel();
      _rideSubscription = null;
      _stopListeningToRideOffers();
      emit(
        state.copyWith(
          status: ClientRideStatus.tripFinished,
          activeRide: ride,
          pendingRideOffers: const [],
        ),
      );
    } else if (ride.status == 'cancelled') {
      _rideSubscription?.cancel();
      _rideSubscription = null;
      _stopListeningToRideOffers();
      emit(
        state.copyWith(
          status: ClientRideStatus.initial,
          activeRide: null,
          errorMessage: null,
          pendingRideOffers: const [],
        ),
      );
    } else {
      emit(state.copyWith(activeRide: ride));
    }
  }

  Future<void> _onDismissTripCompleted(
    DismissTripCompleted event,
    Emitter<ClientRideState> emit,
  ) async {
    await _rideSubscription?.cancel();
    _rideSubscription = null;
    _stopListeningToRideOffers();
    emit(const ClientRideState());
  }

  Future<void> _onCheckActiveRide(
    CheckActiveRide event,
    Emitter<ClientRideState> emit,
  ) async {
    final clientId = event.clientId.trim();
    if (clientId.isEmpty) return;

    try {
      final recovered = await _rideRepository.getActiveRideByClientId(clientId);
      if (recovered == null) return;

      // No rehidratar solicitudes antiguas; el backend las archivará pronto.
      final age = DateTime.now().toUtc().difference(recovered.createdAt.toUtc());
      if (age >= _requestRecoveryWindow) {
        return;
      }

      await _rideSubscription?.cancel();
      _rideSubscription = _rideRepository.subscribeToRide(recovered.id).listen(
            (updated) => add(RideStatusUpdated(updated)),
          );

      switch (recovered.status) {
        case 'searching':
        case 'negotiating':
          _startListeningToRideOffers(recovered.id);
          emit(
            state.copyWith(
              status: ClientRideStatus.searchingDriver,
              activeRide: recovered,
              errorMessage: null,
            ),
          );
          break;
        case 'accepted':
          _stopListeningToRideOffers();
          emit(
            state.copyWith(
              status: ClientRideStatus.driverAssigned,
              activeRide: recovered,
              errorMessage: null,
              pendingRideOffers: const [],
            ),
          );
          break;
        case 'arrived':
          _stopListeningToRideOffers();
          emit(
            state.copyWith(
              status: ClientRideStatus.driverArrived,
              activeRide: recovered,
              errorMessage: null,
            ),
          );
          break;
        case 'ongoing':
          // En este estado la UI muestra directamente mapa + ruta activa (TripOngoingPanel).
          _stopListeningToRideOffers();
          emit(
            state.copyWith(
              status: ClientRideStatus.tripOngoing,
              activeRide: recovered,
              errorMessage: null,
            ),
          );
          break;
        default:
          break;
      }
    } catch (e, stack) {
      developer.log(
        'CheckActiveRide: no se pudo recuperar viaje activo: $e',
        name: 'ClientRideBloc',
        error: e,
        stackTrace: stack,
      );
    }
  }

  void _onRideOffersUpdated(
    RideOffersUpdated event,
    Emitter<ClientRideState> emit,
  ) {
    final prev = state.pendingRideOffers;
    final merged = event.offers
        .map((fresh) {
          RideOfferEntity? old;
          for (final p in prev) {
            if (p.id == fresh.id) {
              old = p;
              break;
            }
          }
          if (old == null) {
            for (final p in prev) {
              if (p.driverId == fresh.driverId) {
                old = p;
                break;
              }
            }
          }
          return RideOfferEntity.mergeNullableProfile(fresh, old);
        })
        .toList();
    emit(
      state.copyWith(
        pendingRideOffers: merged,
        viewersCount:
            event.viewersCount > 0 ? event.viewersCount : state.viewersCount,
      ),
    );
  }

  Future<void> _onBoostOfferedPrice(
    BoostOfferedPrice event,
    Emitter<ClientRideState> emit,
  ) async {
    final ride = state.activeRide;
    if (ride == null || state.status != ClientRideStatus.searchingDriver) return;

    final clamped = ClientRidePricing.clampOfferedPrice(
      price: event.newPrice,
      suggestedPrice: state.suggestedPrice,
    );

    try {
      await _rideRepository.updateOfferedPrice(ride.id, clamped);
      emit(state.copyWith(offeredPrice: clamped, errorMessage: null));
    } catch (e, stack) {
      developer.log(
        'BoostOfferedPrice: $e',
        name: 'ClientRideBloc',
        error: e,
        stackTrace: stack,
      );
      emit(
        state.copyWith(
          status: ClientRideStatus.error,
          errorMessage: 'No se pudo actualizar el precio. Intenta de nuevo.',
        ),
      );
    }
  }

  Future<void> _onAcceptDriverOffer(
    AcceptDriverOffer event,
    Emitter<ClientRideState> emit,
  ) async {
    final ride = state.activeRide;
    if (ride == null || state.status != ClientRideStatus.searchingDriver) {
      return;
    }

    try {
      await _rideRepository.acceptRideOffer(
        offerId: event.offerId,
        rideId: ride.id,
        driverId: event.driverId,
        finalPrice: event.finalPrice,
      );
    } catch (_) {
      emit(
        state.copyWith(
          status: ClientRideStatus.error,
          errorMessage: 'No se pudo aceptar la oferta del conductor',
        ),
      );
    }
  }

  Future<void> _onRejectRideOffer(
    RejectRideOffer event,
    Emitter<ClientRideState> emit,
  ) async {
    try {
      await _rideRepository.rejectRideOffer(event.offerId);
    } catch (_) {
      emit(
        state.copyWith(
          status: ClientRideStatus.error,
          errorMessage: 'No se pudo descartar la oferta',
        ),
      );
    }
  }

  void _onStartSearch(StartSearch event, Emitter<ClientRideState> emit) {
    emit(
      state.copyWith(
        status: ClientRideStatus.initial,
        errorMessage: null,
      ),
    );
  }

  Future<void> _onCancelRide(
    CancelRide event,
    Emitter<ClientRideState> emit,
  ) async {
    developer.log(
      'CancelRide: recibido — activeRide?.id=${state.activeRide?.id}, '
      'status=${state.status}, '
      'activeRide?.status=${state.activeRide?.status}',
      name: 'ClientRideBloc',
    );

    await _rideSubscription?.cancel();
    _rideSubscription = null;
    _stopListeningToRideOffers();

    final rideId = state.activeRide?.id;
    final canPersist =
        rideId != null && rideId.isNotEmpty && rideId != 'temporal';

    if (!canPersist) {
      developer.log(
        'CancelRide: sin persistencia en Supabase — '
        'rideId=$rideId (vacío, null o temporal). Solo se limpia UI.',
        name: 'ClientRideBloc',
      );
      emit(
        state.copyWith(
          status: ClientRideStatus.initial,
          activeRide: null,
          errorMessage: null,
          pendingRideOffers: const [],
        ),
      );
      return;
    }

    developer.log(
      'CancelRide: llamando cancelRide(rideId=$rideId)',
      name: 'ClientRideBloc',
    );

    try {
      await _rideRepository.cancelRide(rideId);
      developer.log(
        'CancelRide: éxito — estado UI → initial, viaje cancelado en BD',
        name: 'ClientRideBloc',
      );
      emit(
        state.copyWith(
          status: ClientRideStatus.initial,
          activeRide: null,
          errorMessage: null,
          pendingRideOffers: const [],
        ),
      );
    } catch (e, stack) {
      developer.log(
        'CancelRide: falló la petición a Supabase — $e',
        name: 'ClientRideBloc',
        error: e,
        stackTrace: stack,
      );
      emit(
        state.copyWith(
          status: ClientRideStatus.error,
          errorMessage:
              'No se pudo cancelar el viaje en el servidor. Intenta de nuevo.',
        ),
      );
    }
  }

  void _onCalculateRoute(
    CalculateRoute event,
    Emitter<ClientRideState> emit,
  ) {
    // Flujo principal: usar el panel del dashboard con Places.
  }

  void _onSubmitOffer(SubmitOffer event, Emitter<ClientRideState> emit) {
    emit(state.copyWith(offeredPrice: event.offerPrice));
  }

  // Distancia aproximada en km usando fórmula de Haversine simplificada
  double _approxDistanceInKm(LatLng a, LatLng b) {
    const earthRadiusKm = 6371.0;

    final dLat = _degToRad(b.latitude - a.latitude);
    final dLon = _degToRad(b.longitude - a.longitude);

    final lat1 = _degToRad(a.latitude);
    final lat2 = _degToRad(b.latitude);

    final h = (math.sin(dLat / 2) * math.sin(dLat / 2)) +
        (math.cos(lat1) *
            math.cos(lat2) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2));
    final c = 2 * math.atan2(math.sqrt(h), math.sqrt(1 - h));

    return earthRadiusKm * c;
  }

  double _degToRad(double deg) => deg * (math.pi / 180.0);

  String _cityHintFromState(ClientRideState s) {
    final text = '${s.originName ?? ''} ${s.destName ?? ''}'.toLowerCase();
    if (text.contains('trujillo')) return 'trujillo';
    return 'trujillo';
  }

  double _calculateSuggestedPrice(double distanceKm) {
    return ClientRidePricing.routeBaseFromDistanceKm(distanceKm);
  }
}
