import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:geolocator/geolocator.dart';

import '../../../../core/utils/location_helper.dart';
import '../../../../domain/entities/ride_entity.dart';
import '../../../../domain/entities/ride_offer_entity.dart';
import '../../../../domain/repositories/ride_repository.dart';
import 'driver_status_event.dart';
import 'driver_status_state.dart';

class DriverStatusBloc extends Bloc<DriverStatusEvent, DriverStatusState> {
  final RideRepository rideRepository;
  StreamSubscription<List<RideEntity>>? _ridesSubscription;
  StreamSubscription<RideEntity>? _rideResolutionSubscription;
  StreamSubscription<List<RideOfferEntity>>? _offersSubscription;
  StreamSubscription<Position>? _locationSubscription;
  String? _trackedRideId;
  List<RideEntity> _lastKnownRides = const [];
  Timer? _offerTimer;
  String? _selfDriverIdForOffer;

  DriverStatusBloc({required this.rideRepository}) : super(const DriverOffline()) {
    on<ToggleStatus>(_onToggleStatus);
    on<NearbyRidesUpdated>(_onNearbyRidesUpdated);
    on<ReceiveRequest>(_onReceiveRequest);
    on<AcceptRide>(_onAcceptRide);
    on<RejectRide>(_onRejectRide);
    on<OfferExpired>(_onOfferExpired);
    on<UpdateOffer>(_onUpdateOffer);
    on<CounterOfferRide>(_onCounterOfferRide);
    on<DriverRideOffersUpdated>(_onDriverRideOffersUpdated);
    on<ActiveRideRemoteUpdated>(_onActiveRideRemoteUpdated);
    on<NotifyArrival>(_onNotifyArrival);
    on<StartTrip>(_onStartTrip);
    on<FinishTrip>(_onFinishTrip);
    on<RecoverDriverActiveRide>(_onRecoverDriverActiveRide);
  }

  void _cancelWaitingSubscriptions() {
    _rideResolutionSubscription?.cancel();
    _rideResolutionSubscription = null;
    _offersSubscription?.cancel();
    _offersSubscription = null;
    _selfDriverIdForOffer = null;
  }

  void _onToggleStatus(
    ToggleStatus event,
    Emitter<DriverStatusState> emit,
  ) async {
    if (state is DriverOffline) {
      try {
        final position = await LocationHelper.determinePosition();
        final lat = position.latitude;
        final lng = position.longitude;

        emit(const DriverOnline(availableRides: []));

        _ridesSubscription?.cancel();
        _ridesSubscription = rideRepository
            .getNearbyRideRequests(lat, lng, 5.0)
            .listen(
          (rides) => add(NearbyRidesUpdated(rides)),
          onError: (_) {},
        );
      } catch (_) {
        emit(const DriverOffline());
      }
    } else if (state is DriverOnline ||
        state is DriverNegotiating ||
        state is DriverWaitingForPassengerDecision ||
        state is DriverOnTrip ||
        state is DriverArrivedAtPickup ||
        state is DriverTripInProgress) {
      if (state is DriverWaitingForPassengerDecision) {
        final w = state as DriverWaitingForPassengerDecision;
        try {
          await rideRepository.withdrawRideOffer(w.submittedOfferId);
        } catch (_) {}
        _cancelWaitingSubscriptions();
        _cancelOfferTimer();
      } else {
        _cancelOfferTimer();
        _cancelWaitingSubscriptions();
      }
      _ridesSubscription?.cancel();
      _ridesSubscription = null;
      _stopLocationTracking();
      _lastKnownRides = const [];
      emit(const DriverOffline());
    }
  }

  void _onNearbyRidesUpdated(
    NearbyRidesUpdated event,
    Emitter<DriverStatusState> emit,
  ) {
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
        ),
      );
    }
  }

  Future<void> _onAcceptRide(
    AcceptRide event,
    Emitter<DriverStatusState> emit,
  ) async {
    if (state is! DriverNegotiating) return;

    _rideResolutionSubscription?.cancel();
    _rideResolutionSubscription = null;

    final agreedPrice = event.ride.offeredPrice;
    await _submitNegotiationOffer(
      ride: event.ride,
      driverId: event.driverId,
      finalPrice: agreedPrice,
      emit: emit,
    );
  }

  void _onRejectRide(
    RejectRide event,
    Emitter<DriverStatusState> emit,
  ) {
    if (state is DriverWaitingForPassengerDecision) {
      add(OfferExpired((state as DriverWaitingForPassengerDecision).activeRide));
      return;
    }
    _cancelOfferTimer();
    _cancelWaitingSubscriptions();
    emit(DriverOnline(availableRides: _lastKnownRides));
    _restartSubscription();
  }

  void _onUpdateOffer(
    UpdateOffer event,
    Emitter<DriverStatusState> emit,
  ) {
    if (state is DriverNegotiating) {
      final negotiatingState = state as DriverNegotiating;
      emit(
        DriverNegotiating(
          activeRide: negotiatingState.activeRide,
          currentOffer: event.newOffer,
        ),
      );
    }
  }

  Future<void> _onCounterOfferRide(
    CounterOfferRide event,
    Emitter<DriverStatusState> emit,
  ) async {
    if (state is! DriverNegotiating) return;

    await _submitNegotiationOffer(
      ride: event.ride,
      driverId: event.driverId,
      finalPrice: event.newPrice,
      emit: emit,
    );
  }

  Future<void> _submitNegotiationOffer({
    required RideEntity ride,
    required String driverId,
    required double finalPrice,
    required Emitter<DriverStatusState> emit,
  }) async {
    try {
      _cancelOfferTimer();

      final offer = await rideRepository.submitNegotiationOffer(
        rideId: ride.id,
        driverId: driverId,
        offeredPrice: finalPrice,
      );

      _lastKnownRides =
          _lastKnownRides.where((r) => r.id != ride.id).toList();

      _selfDriverIdForOffer = driverId;

      _offersSubscription?.cancel();
      _offersSubscription =
          rideRepository.listenToRideOffers(ride.id, pendingOnly: false).listen(
        (list) => add(DriverRideOffersUpdated(list)),
      );

      emit(
        DriverWaitingForPassengerDecision(
          activeRide: ride,
          submittedOfferId: offer.id,
          submittedPrice: finalPrice,
        ),
      );

      _rideResolutionSubscription?.cancel();
      _rideResolutionSubscription =
          rideRepository.subscribeToRide(ride.id).listen(
        (r) => add(ActiveRideRemoteUpdated(r)),
      );

      final rideForExpiry = ride;
      _offerTimer = Timer(const Duration(seconds: 10), () {
        _offerTimer = null;
        add(OfferExpired(rideForExpiry));
      });
    } catch (_) {
      emit(DriverOnline(availableRides: _lastKnownRides));
      await _restartSubscription();
    }
  }

  void _onDriverRideOffersUpdated(
    DriverRideOffersUpdated event,
    Emitter<DriverStatusState> emit,
  ) {
    if (state is! DriverWaitingForPassengerDecision) return;
    final w = state as DriverWaitingForPassengerDecision;
    final selfId = _selfDriverIdForOffer;
    if (selfId == null || selfId.isEmpty) return;

    RideOfferEntity? mine;
    for (final o in event.offers) {
      if (o.driverId == selfId && o.rideId == w.activeRide.id) {
        mine = o;
        break;
      }
    }

    if (mine == null) {
      return;
    }

    if (mine.status == 'rejected' || mine.status == 'withdrawn') {
      _cancelOfferTimer();
      _cancelWaitingSubscriptions();
      emit(DriverOnline(availableRides: _lastKnownRides));
      _restartSubscription();
    }
  }

  Future<void> _onOfferExpired(
    OfferExpired event,
    Emitter<DriverStatusState> emit,
  ) async {
    if (state is! DriverWaitingForPassengerDecision) return;
    final w = state as DriverWaitingForPassengerDecision;
    if (w.activeRide.id != event.ride.id) return;

    _cancelOfferTimer();
    try {
      await rideRepository.withdrawRideOffer(w.submittedOfferId);
    } catch (_) {}

    _cancelWaitingSubscriptions();
    emit(DriverOnline(availableRides: _lastKnownRides));
    await _restartSubscription();
  }

  void _onActiveRideRemoteUpdated(
    ActiveRideRemoteUpdated event,
    Emitter<DriverStatusState> emit,
  ) {
    final ride = event.ride;
    final selfId = _selfDriverIdForOffer;

    if (ride.status == 'accepted') {
      _cancelOfferTimer();
      final won = selfId != null && ride.driverId == selfId;
      _cancelWaitingSubscriptions();
      if (won) {
        emit(DriverOnTrip(ride));
        Future.microtask(() => _startLocationTracking(ride.id));
      } else {
        emit(DriverOnline(availableRides: _lastKnownRides));
        _restartSubscription();
      }
      return;
    }

    // Con ofertas en `ride_offers` el viaje sigue en `searching` (o `negotiating`
    // en datos antiguos) hasta que el pasajero elija: no cerrar la UI de oferta.
    if (ride.status == 'searching' || ride.status == 'negotiating') {
      return;
    }

    if (ride.status == 'cancelled' || ride.status == 'canceled') {
      if (state is DriverWaitingForPassengerDecision) {
        _cancelOfferTimer();
        final w = state as DriverWaitingForPassengerDecision;
        unawaited(
          rideRepository.withdrawRideOffer(w.submittedOfferId).catchError((_) {}),
        );
        _cancelWaitingSubscriptions();
        emit(DriverOnline(availableRides: _lastKnownRides));
        _restartSubscription();
        return;
      }
      if (state is DriverNegotiating) {
        _cancelOfferTimer();
        _cancelWaitingSubscriptions();
        emit(DriverOnline(availableRides: _lastKnownRides));
        _restartSubscription();
        return;
      }
      return;
    }

    if (ride.status == 'arrived') {
      emit(DriverArrivedAtPickup(ride));
      return;
    }
    if (ride.status == 'ongoing') {
      emit(DriverTripInProgress(ride));
      return;
    }
  }

  Future<void> _onRecoverDriverActiveRide(
    RecoverDriverActiveRide event,
    Emitter<DriverStatusState> emit,
  ) async {
    final driverId = event.driverId.trim();
    if (driverId.isEmpty) return;

    try {
      final pendingCtx =
          await rideRepository.getPendingOfferContextForDriver(driverId);
      if (pendingCtx != null) {
        _cancelOfferTimer();
        _ridesSubscription?.cancel();
        _ridesSubscription = null;
        _selfDriverIdForOffer = driverId;
        _offersSubscription?.cancel();
        _offersSubscription = rideRepository
            .listenToRideOffers(pendingCtx.ride.id, pendingOnly: false)
            .listen((list) => add(DriverRideOffersUpdated(list)));
        _rideResolutionSubscription?.cancel();
        _rideResolutionSubscription =
            rideRepository.subscribeToRide(pendingCtx.ride.id).listen(
          (r) => add(ActiveRideRemoteUpdated(r)),
        );
        emit(
          DriverWaitingForPassengerDecision(
            activeRide: pendingCtx.ride,
            submittedOfferId: pendingCtx.offer.id,
            submittedPrice: pendingCtx.offer.offeredPrice,
          ),
        );
        return;
      }

      final recovered = await rideRepository.getActiveRideByDriverId(driverId);
      if (recovered == null) return;

      _cancelOfferTimer();
      _ridesSubscription?.cancel();
      _ridesSubscription = null;
      _rideResolutionSubscription?.cancel();
      _rideResolutionSubscription =
          rideRepository.subscribeToRide(recovered.id).listen(
        (r) => add(ActiveRideRemoteUpdated(r)),
      );

      if (recovered.status == 'accepted') {
        emit(DriverOnTrip(_rideWithStatus(recovered, 'accepted')));
        await _startLocationTracking(recovered.id);
      } else if (recovered.status == 'arrived') {
        emit(DriverArrivedAtPickup(_rideWithStatus(recovered, 'arrived')));
        await _startLocationTracking(recovered.id);
      } else if (recovered.status == 'ongoing') {
        emit(DriverTripInProgress(_rideWithStatus(recovered, 'ongoing')));
        await _startLocationTracking(recovered.id);
      }
    } catch (_) {}
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
    } catch (_) {}
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
      clientProfilePicUrl: r.clientProfilePicUrl,
    );
  }

  void _cancelOfferTimer() {
    _offerTimer?.cancel();
    _offerTimer = null;
  }

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
        onError: (_) {},
      );
    } catch (_) {}
  }

  @override
  Future<void> close() async {
    _cancelOfferTimer();
    _locationSubscription?.cancel();
    _ridesSubscription?.cancel();
    _rideResolutionSubscription?.cancel();
    _offersSubscription?.cancel();
    return super.close();
  }
}
