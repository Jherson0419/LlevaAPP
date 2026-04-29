import 'dart:async';
import 'dart:math' as math;

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:rxdart/rxdart.dart';

import '../../../core/enums/client_ride_status.dart';
import '../../../core/enums/client_vehicle_category.dart';
import '../../../core/services/places_service.dart';
import '../../../core/utils/client_ride_pricing.dart';
import '../../../data/models/ride_model.dart';
import '../../../domain/entities/ride_entity.dart';
import '../../../domain/repositories/ride_repository.dart';

part 'client_ride_event.dart';
part 'client_ride_state.dart';

class ClientRideBloc extends Bloc<ClientRideEvent, ClientRideState> {
  final PlacesService _placesService;
  final RideRepository _rideRepository;

  StreamSubscription<RideEntity>? _rideSubscription;

  ClientRideBloc({
    required PlacesService placesService,
    required RideRepository rideRepository,
  })  : _placesService = placesService,
        _rideRepository = rideRepository,
        super(const ClientRideState()) {
    on<OriginTextChanged>(_onOriginTextChanged,
        transformer: _debounce<OriginTextChanged>(),);
    on<DestTextChanged>(_onDestTextChanged,
        transformer: _debounce<DestTextChanged>(),);
    on<OriginSelected>(_onOriginSelected);
    on<DestSelected>(_onDestSelected);
    on<PriceChanged>(_onPriceChanged);
    on<VehicleCategoryChanged>(_onVehicleCategoryChanged);
    on<RidePreferencesChanged>(_onRidePreferencesChanged);
    on<StartEditingOrigin>(_onStartEditingOrigin);
    on<StartEditingDest>(_onStartEditingDest);
    on<BackToSearchPanel>(_onBackToSearchPanel);
    on<PaymentMethodChanged>(_onPaymentMethodChanged);
    on<SubmitRideRequest>(_onSubmitRideRequest);
    on<RideStatusUpdated>(_onRideStatusUpdated);
    on<StartSearch>(_onStartSearch);
    on<CancelRide>(_onCancelRide);
    on<CalculateRoute>(_onCalculateRoute);
    on<SubmitOffer>(_onSubmitOffer);
    on<AcceptDriverOffer>(_onAcceptDriverOffer);
    on<RejectDriverOffer>(_onRejectDriverOffer);
    on<DismissTripCompleted>(_onDismissTripCompleted);
  }

  @override
  Future<void> close() async {
    await _rideSubscription?.cancel();
    await super.close();
  }

  EventTransformer<E> _debounce<E>() {
    return (events, mapper) =>
        events.debounceTime(const Duration(milliseconds: 500)).switchMap(mapper);
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

    final predictions = await _placesService.searchPlaces(event.text);
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

    final predictions = await _placesService.searchPlaces(event.text);
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
      final polyline = await _placesService.getRoutePolyline(
        nextState.originLatLng!,
        nextState.destLatLng!,
      );

      final distanceKm =
          _approxDistanceInKm(nextState.originLatLng!, nextState.destLatLng!);
      final suggested = _calculateSuggestedPrice(distanceKm);

      nextState = nextState.copyWith(
        routePolyline: polyline,
        routeBaseSuggested: suggested,
        vehicleCategory: ClientVehicleCategory.standard,
        moreThanFourPassengers: false,
        babySeat: false,
        pet: false,
        rideComments: '',
        status: ClientRideStatus.readyToRequest,
      );
      nextState = _stateWithRecalculatedPrices(nextState);
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
      final polyline = await _placesService.getRoutePolyline(
        nextState.originLatLng!,
        nextState.destLatLng!,
      );

      final distanceKm =
          _approxDistanceInKm(nextState.originLatLng!, nextState.destLatLng!);
      final suggested = _calculateSuggestedPrice(distanceKm);

      nextState = nextState.copyWith(
        routePolyline: polyline,
        routeBaseSuggested: suggested,
        vehicleCategory: ClientVehicleCategory.standard,
        moreThanFourPassengers: false,
        babySeat: false,
        pet: false,
        rideComments: '',
        status: ClientRideStatus.readyToRequest,
      );
      nextState = _stateWithRecalculatedPrices(nextState);
    }

    emit(nextState);
  }

  void _onPriceChanged(
    PriceChanged event,
    Emitter<ClientRideState> emit,
  ) {
    emit(
      state.copyWith(
        offeredPrice: event.price,
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
    final pay = state.paymentMethod;
    emit(ClientRideState(paymentMethod: pay));
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
          moreThanFourPassengers: event.moreThanFourPassengers ??
              state.moreThanFourPassengers,
          babySeat: event.babySeat ?? state.babySeat,
          pet: event.pet ?? state.pet,
          rideComments: event.rideComments ?? state.rideComments,
        ),
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
    final method =
        m == 'yape' ? 'yape' : (m == 'plin' ? 'plin' : 'efectivo');
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

      emit(
        state.copyWith(
          status: ClientRideStatus.searchingDriver,
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

      emit(
        state.copyWith(
          status: ClientRideStatus.searchingDriver,
          activeRide: created,
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
    if (ride.status == 'accepted') {
      emit(
        state.copyWith(
          status: ClientRideStatus.driverAssigned,
          activeRide: ride,
        ),
      );
    } else if (ride.status == 'negotiating') {
      emit(
        state.copyWith(
          status: ClientRideStatus.negotiating,
          activeRide: ride,
        ),
      );
    } else if (ride.status == 'searching') {
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
      emit(
        state.copyWith(
          status: ClientRideStatus.tripFinished,
          activeRide: ride,
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
    emit(const ClientRideState());
  }

  Future<void> _onAcceptDriverOffer(
    AcceptDriverOffer event,
    Emitter<ClientRideState> emit,
  ) async {
    final ride = state.activeRide;
    if (ride == null || state.status != ClientRideStatus.negotiating) return;

    try {
      await _rideRepository.updateRideStatus(ride.id, 'accepted');
    } catch (_) {
      emit(
        state.copyWith(
          status: ClientRideStatus.error,
          errorMessage: 'No se pudo aceptar la oferta del conductor',
        ),
      );
    }
  }

  Future<void> _onRejectDriverOffer(
    RejectDriverOffer event,
    Emitter<ClientRideState> emit,
  ) async {
    final ride = state.activeRide;
    if (ride == null || state.status != ClientRideStatus.negotiating) return;

    try {
      await _rideRepository.updateRideStatus(
        ride.id,
        'searching',
        clearDriver: true,
      );

      final cleared = RideEntity(
        id: ride.id,
        clientId: ride.clientId,
        driverId: null,
        originLat: ride.originLat,
        originLng: ride.originLng,
        destLat: ride.destLat,
        destLng: ride.destLng,
        originName: ride.originName,
        destName: ride.destName,
        status: 'searching',
        offeredPrice: ride.offeredPrice,
        finalPrice: null,
        createdAt: ride.createdAt,
        driverLat: null,
        driverLng: null,
        paymentMethod: ride.paymentMethod,
        clientFirstName: ride.clientFirstName,
        clientCompletedTrips: ride.clientCompletedTrips,
        clientPassengerRating: ride.clientPassengerRating,
      );

      emit(
        state.copyWith(
          status: ClientRideStatus.searchingDriver,
          activeRide: cleared,
        ),
      );
    } catch (_) {
      emit(
        state.copyWith(
          status: ClientRideStatus.error,
          errorMessage: 'No se pudo rechazar la oferta',
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
    await _rideSubscription?.cancel();
    _rideSubscription = null;
    emit(
      state.copyWith(
        status: ClientRideStatus.initial,
        activeRide: null,
      ),
    );
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

  // Fórmula simple: S/ 3.00 base + S/ 1.50 por km
  double _calculateSuggestedPrice(double distanceKm) {
    const base = 3.0;
    const perKm = 1.5;
    final price = base + (distanceKm * perKm);
    // Redondear a 2 decimales
    return double.parse(price.toStringAsFixed(2));
  }
}

