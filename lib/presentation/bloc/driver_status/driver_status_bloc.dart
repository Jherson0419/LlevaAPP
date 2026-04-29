import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:geolocator/geolocator.dart';

import '../../../../core/utils/location_helper.dart';
import '../../../../domain/entities/ride_entity.dart';
import '../../../../domain/repositories/ride_repository.dart';
import 'driver_status_event.dart';
import 'driver_status_state.dart';

class DriverStatusBloc extends Bloc<DriverStatusEvent, DriverStatusState> {
  final RideRepository rideRepository;
  StreamSubscription<List<RideEntity>>? _ridesSubscription;
  StreamSubscription<RideEntity>? _rideResolutionSubscription;
  StreamSubscription<Position>? _locationSubscription;
  String? _trackedRideId;
  List<RideEntity> _lastKnownRides = const [];
  Timer? _offerTimer;

  DriverStatusBloc({required this.rideRepository}) : super(const DriverOffline()) {
    on<ToggleStatus>(_onToggleStatus);
    on<NearbyRidesUpdated>(_onNearbyRidesUpdated);
    on<ReceiveRequest>(_onReceiveRequest);
    on<AcceptRide>(_onAcceptRide);
    on<RejectRide>(_onRejectRide);
    on<OfferExpired>(_onOfferExpired);
    on<UpdateOffer>(_onUpdateOffer);
    on<CounterOfferRide>(_onCounterOfferRide);
    on<ActiveRideRemoteUpdated>(_onActiveRideRemoteUpdated);
    on<NotifyArrival>(_onNotifyArrival);
    on<StartTrip>(_onStartTrip);
    on<FinishTrip>(_onFinishTrip);
  }

  void _onToggleStatus(
    ToggleStatus event,
    Emitter<DriverStatusState> emit,
  ) async {
    if (state is DriverOffline) {
      // Cambiar a Online e iniciar suscripción
      try {
        final position = await LocationHelper.determinePosition();
        final lat = position.latitude;
        final lng = position.longitude;

        // Emitir estado Online inicial con lista vacía
        emit(const DriverOnline(availableRides: []));

        // Iniciar suscripción al stream de viajes cercanos
        _ridesSubscription?.cancel();
        _ridesSubscription = rideRepository
            .getNearbyRideRequests(lat, lng, 5.0)
            .listen(
          (rides) => add(NearbyRidesUpdated(rides)),
          onError: (error) {
            // Manejar errores silenciosamente o emitir un estado de error
            // TODO: Implementar logging adecuado
          },
        );
      } catch (e) {
        // Si hay error al obtener ubicación, mantener offline
        emit(const DriverOffline());
      }
    } else if (state is DriverOnline ||
        state is DriverNegotiating ||
        state is DriverOnTrip ||
        state is DriverArrivedAtPickup ||
        state is DriverTripInProgress) {
      _cancelOfferTimer();
      // Cancelar suscripción y cambiar a Offline
      _ridesSubscription?.cancel();
      _ridesSubscription = null;
      _rideResolutionSubscription?.cancel();
      _rideResolutionSubscription = null;
      _stopLocationTracking();
      _lastKnownRides = const [];
      emit(const DriverOffline());
    }
  }

  void _onNearbyRidesUpdated(
    NearbyRidesUpdated event,
    Emitter<DriverStatusState> emit,
  ) {
    // Actualizar la lista de viajes disponibles
    if (state is DriverOnline) {
      _lastKnownRides = event.rides;
      emit(DriverOnline(availableRides: _lastKnownRides));
    }
  }

  void _onReceiveRequest(
    ReceiveRequest event,
    Emitter<DriverStatusState> emit,
  ) async {
    if (state is DriverOnline) {
      emit(
        DriverNegotiating(
          activeRide: event.ride,
          currentOffer: event.ride.offeredPrice,
          awaitingPassengerResponse: false,
        ),
      );
    }
  }

  Future<void> _onAcceptRide(
    AcceptRide event,
    Emitter<DriverStatusState> emit,
  ) async {
    if (state is! DriverNegotiating) return;
    if ((state as DriverNegotiating).awaitingPassengerResponse) return;

    try {
      _rideResolutionSubscription?.cancel();
      _rideResolutionSubscription = null;
      await rideRepository.updateRideStatus(
        event.ride.id,
        'accepted',
        driverId: event.driverId,
        finalPrice: event.finalPrice,
      );

      final updatedRide = RideEntity(
        id: event.ride.id,
        clientId: event.ride.clientId,
        driverId: event.driverId,
        originLat: event.ride.originLat,
        originLng: event.ride.originLng,
        destLat: event.ride.destLat,
        destLng: event.ride.destLng,
        originName: event.ride.originName,
        destName: event.ride.destName,
        status: 'accepted',
        offeredPrice: event.ride.offeredPrice,
        finalPrice: event.finalPrice,
        createdAt: event.ride.createdAt,
        driverLat: event.ride.driverLat,
        driverLng: event.ride.driverLng,
        paymentMethod: event.ride.paymentMethod,
        clientFirstName: event.ride.clientFirstName,
        clientCompletedTrips: event.ride.clientCompletedTrips,
        clientPassengerRating: event.ride.clientPassengerRating,
      );

      emit(DriverOnTrip(updatedRide));
      await _startLocationTracking(updatedRide.id);
    } catch (_) {
      // Si falla, volver a online con la última lista conocida
      emit(DriverOnline(availableRides: _lastKnownRides));
      await _restartSubscription();
    }
  }

  void _onRejectRide(
    RejectRide event,
    Emitter<DriverStatusState> emit,
  ) {
    _cancelOfferTimer();
    _rideResolutionSubscription?.cancel();
    _rideResolutionSubscription = null;
    // Volver a estado Online usando la última lista de viajes, sin tocar Supabase
    emit(DriverOnline(availableRides: _lastKnownRides));
    _restartSubscription();
  }

  void _onUpdateOffer(
    UpdateOffer event,
    Emitter<DriverStatusState> emit,
  ) {
    if (state is DriverNegotiating) {
      final negotiatingState = state as DriverNegotiating;
      if (negotiatingState.awaitingPassengerResponse) return;
      emit(
        DriverNegotiating(
          activeRide: negotiatingState.activeRide,
          currentOffer: event.newOffer,
          awaitingPassengerResponse: false,
        ),
      );
    }
  }

  Future<void> _onCounterOfferRide(
    CounterOfferRide event,
    Emitter<DriverStatusState> emit,
  ) async {
    if (state is! DriverNegotiating) return;
    final negotiatingState = state as DriverNegotiating;
    if (negotiatingState.awaitingPassengerResponse) return;

    try {
      _cancelOfferTimer();

      await rideRepository.updateRideStatus(
        event.ride.id,
        'negotiating',
        driverId: event.driverId,
        finalPrice: event.newPrice,
      );

      final updated = RideEntity(
        id: event.ride.id,
        clientId: event.ride.clientId,
        driverId: event.driverId,
        originLat: event.ride.originLat,
        originLng: event.ride.originLng,
        destLat: event.ride.destLat,
        destLng: event.ride.destLng,
        originName: event.ride.originName,
        destName: event.ride.destName,
        status: 'negotiating',
        offeredPrice: event.ride.offeredPrice,
        finalPrice: event.newPrice,
        createdAt: event.ride.createdAt,
        driverLat: event.ride.driverLat,
        driverLng: event.ride.driverLng,
        paymentMethod: event.ride.paymentMethod,
        clientFirstName: event.ride.clientFirstName,
        clientCompletedTrips: event.ride.clientCompletedTrips,
        clientPassengerRating: event.ride.clientPassengerRating,
      );

      emit(
        DriverNegotiating(
          activeRide: updated,
          currentOffer: event.newPrice,
          awaitingPassengerResponse: true,
        ),
      );

      _rideResolutionSubscription?.cancel();
      _rideResolutionSubscription =
          rideRepository.subscribeToRide(updated.id).listen(
        (ride) => add(ActiveRideRemoteUpdated(ride)),
      );

      final rideForExpiry = updated;
      _offerTimer = Timer(const Duration(seconds: 10), () {
        _offerTimer = null;
        add(OfferExpired(rideForExpiry));
      });
    } catch (_) {
      emit(DriverOnline(availableRides: _lastKnownRides));
      await _restartSubscription();
    }
  }

  Future<void> _onOfferExpired(
    OfferExpired event,
    Emitter<DriverStatusState> emit,
  ) async {
    if (state is! DriverNegotiating) return;
    final n = state as DriverNegotiating;
    if (!n.awaitingPassengerResponse || n.activeRide.id != event.ride.id) {
      return;
    }

    _cancelOfferTimer();
    _rideResolutionSubscription?.cancel();
    _rideResolutionSubscription = null;

    try {
      await rideRepository.updateRideStatus(
        event.ride.id,
        'searching',
        clearDriver: true,
      );
    } catch (_) {
      // Aun así volvemos a online para no bloquear al conductor
    }

    emit(DriverOnline(availableRides: _lastKnownRides));
    await _restartSubscription();
  }

  void _onActiveRideRemoteUpdated(
    ActiveRideRemoteUpdated event,
    Emitter<DriverStatusState> emit,
  ) {
    final ride = event.ride;
    if (ride.status == 'accepted') {
      _cancelOfferTimer();
      _rideResolutionSubscription?.cancel();
      _rideResolutionSubscription = null;
      emit(DriverOnTrip(ride));
      Future.microtask(() => _startLocationTracking(ride.id));
      return;
    }
    if (ride.status == 'searching') {
      _cancelOfferTimer();
      _rideResolutionSubscription?.cancel();
      _rideResolutionSubscription = null;
      emit(DriverOnline(availableRides: _lastKnownRides));
      _restartSubscription();
      return;
    }
    if (ride.status == 'negotiating' && state is DriverNegotiating) {
      final n = state as DriverNegotiating;
      emit(
        DriverNegotiating(
          activeRide: ride,
          currentOffer: ride.finalPrice ?? n.currentOffer,
          awaitingPassengerResponse: true,
        ),
      );
    }
  }

  Future<void> _onNotifyArrival(
    NotifyArrival event,
    Emitter<DriverStatusState> emit,
  ) async {
    if (state is! DriverOnTrip) return;
    final trip = state as DriverOnTrip;
    try {
      await rideRepository.updateRideStatus(trip.activeRide.id, 'arrived');
      emit(DriverArrivedAtPickup(_rideWithStatus(trip.activeRide, 'arrived')));
    } catch (_) {
      // Estado sin cambios; reintento desde UI si se desea
    }
  }

  Future<void> _onStartTrip(
    StartTrip event,
    Emitter<DriverStatusState> emit,
  ) async {
    if (state is! DriverArrivedAtPickup) return;
    final trip = state as DriverArrivedAtPickup;
    try {
      await rideRepository.updateRideStatus(trip.activeRide.id, 'ongoing');
      emit(DriverTripInProgress(_rideWithStatus(trip.activeRide, 'ongoing')));
    } catch (_) {}
  }

  Future<void> _onFinishTrip(
    FinishTrip event,
    Emitter<DriverStatusState> emit,
  ) async {
    if (state is! DriverTripInProgress) return;
    final trip = state as DriverTripInProgress;
    try {
      _stopLocationTracking();
      await rideRepository.updateRideStatus(trip.activeRide.id, 'finished');
      _rideResolutionSubscription?.cancel();
      _rideResolutionSubscription = null;
      emit(DriverOnline(availableRides: _lastKnownRides));
      await _restartSubscription();
    } catch (_) {}
  }

  Future<void> _startLocationTracking(String rideId) async {
    if (_trackedRideId == rideId && _locationSubscription != null) {
      return;
    }

    try {
      final initial = await LocationHelper.determinePosition();
      _locationSubscription?.cancel();
      _trackedRideId = rideId;

      await rideRepository.updateDriverLocation(
        rideId,
        initial.latitude,
        initial.longitude,
      );

      const locationSettings = LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 8,
      );

      _locationSubscription = Geolocator.getPositionStream(
        locationSettings: locationSettings,
      ).listen(
        (position) {
          rideRepository.updateDriverLocation(
            rideId,
            position.latitude,
            position.longitude,
          );
        },
        onError: (_) {},
      );
    } catch (_) {
      _trackedRideId = null;
    }
  }

  void _stopLocationTracking() {
    _locationSubscription?.cancel();
    _locationSubscription = null;
    _trackedRideId = null;
  }

  RideEntity _rideWithStatus(RideEntity r, String status) {
    return RideEntity(
      id: r.id,
      clientId: r.clientId,
      driverId: r.driverId,
      originLat: r.originLat,
      originLng: r.originLng,
      destLat: r.destLat,
      destLng: r.destLng,
      originName: r.originName,
      destName: r.destName,
      status: status,
      offeredPrice: r.offeredPrice,
      finalPrice: r.finalPrice,
      createdAt: r.createdAt,
      driverLat: r.driverLat,
      driverLng: r.driverLng,
      paymentMethod: r.paymentMethod,
      clientFirstName: r.clientFirstName,
      clientCompletedTrips: r.clientCompletedTrips,
      clientPassengerRating: r.clientPassengerRating,
    );
  }

  void _cancelOfferTimer() {
    _offerTimer?.cancel();
    _offerTimer = null;
  }

  /// Reinicia la suscripción de viajes cercanos
  Future<void> _restartSubscription() async {
    try {
      final position = await LocationHelper.determinePosition();
      final lat = position.latitude;
      final lng = position.longitude;

      _ridesSubscription?.cancel();
      _ridesSubscription = rideRepository
          .getNearbyRideRequests(lat, lng, 5.0)
          .listen(
        (rides) => add(NearbyRidesUpdated(rides)),
        onError: (error) {
          // TODO: Implementar logging adecuado
        },
      );
    } catch (e) {
      // TODO: Implementar logging adecuado
    }
  }

  @override
  Future<void> close() async {
    _cancelOfferTimer();
    _locationSubscription?.cancel();
    _ridesSubscription?.cancel();
    _rideResolutionSubscription?.cancel();
    return super.close();
  }
}
