part of 'client_ride_bloc.dart';

/// Estado único para manejar todo el flujo del pasajero.
class ClientRideState extends Equatable {
  static const Object _unset = Object();

  final ClientRideStatus status;
  final String? originName;
  final String? destName;
  final LatLng? originLatLng;
  final LatLng? destLatLng;
  final List<Prediction> originPredictions;
  final List<Prediction> destPredictions;
  final List<LatLng> routePolyline;
  /// Distancia en km por ruta en auto (Google Directions), no línea recta.
  final double? routeDistanceKm;
  /// Duración estimada del trayecto en segundos (Google Directions).
  final int? routeDurationSeconds;
  /// Tarifa calculada solo por distancia (antes de categoría y extras).
  final double? routeBaseSuggested;
  final ClientVehicleCategory vehicleCategory;
  final bool moreThanFourPassengers;
  final bool babySeat;
  final bool pet;
  final String rideComments;
  final double offeredPrice;
  final double? suggestedPrice;
  final String? errorMessage;
  final RideEntity? activeRide;
  final List<RideOfferEntity> pendingRideOffers;
  final String paymentMethod;
  /// Conductores distintos que han respondido a esta solicitud (proxy de visualizaciones).
  final int viewersCount;

  const ClientRideState({
    this.status = ClientRideStatus.initial,
    this.originName,
    this.destName,
    this.originLatLng,
    this.destLatLng,
    this.originPredictions = const [],
    this.destPredictions = const [],
    this.routePolyline = const [],
    this.routeDistanceKm,
    this.routeDurationSeconds,
    this.routeBaseSuggested,
    this.vehicleCategory = ClientVehicleCategory.standard,
    this.moreThanFourPassengers = false,
    this.babySeat = false,
    this.pet = false,
    this.rideComments = '',
    this.offeredPrice = 0,
    this.suggestedPrice,
    this.errorMessage,
    this.activeRide,
    this.pendingRideOffers = const [],
    this.paymentMethod = 'efectivo',
    this.viewersCount = 0,
  });

  ClientRideState copyWith({
    ClientRideStatus? status,
    String? originName,
    String? destName,
    LatLng? originLatLng,
    LatLng? destLatLng,
    List<Prediction>? originPredictions,
    List<Prediction>? destPredictions,
    List<LatLng>? routePolyline,
    Object? routeDistanceKm = _unset,
    Object? routeDurationSeconds = _unset,
    double? routeBaseSuggested,
    ClientVehicleCategory? vehicleCategory,
    bool? moreThanFourPassengers,
    bool? babySeat,
    bool? pet,
    String? rideComments,
    double? offeredPrice,
    double? suggestedPrice,
    String? errorMessage,
    Object? activeRide = _unset,
    List<RideOfferEntity>? pendingRideOffers,
    String? paymentMethod,
    int? viewersCount,
  }) {
    return ClientRideState(
      status: status ?? this.status,
      originName: originName ?? this.originName,
      destName: destName ?? this.destName,
      originLatLng: originLatLng ?? this.originLatLng,
      destLatLng: destLatLng ?? this.destLatLng,
      originPredictions: originPredictions ?? this.originPredictions,
      destPredictions: destPredictions ?? this.destPredictions,
      routePolyline: routePolyline ?? this.routePolyline,
      routeDistanceKm: routeDistanceKm == _unset
          ? this.routeDistanceKm
          : routeDistanceKm as double?,
      routeDurationSeconds: routeDurationSeconds == _unset
          ? this.routeDurationSeconds
          : routeDurationSeconds as int?,
      routeBaseSuggested: routeBaseSuggested ?? this.routeBaseSuggested,
      vehicleCategory: vehicleCategory ?? this.vehicleCategory,
      moreThanFourPassengers:
          moreThanFourPassengers ?? this.moreThanFourPassengers,
      babySeat: babySeat ?? this.babySeat,
      pet: pet ?? this.pet,
      rideComments: rideComments ?? this.rideComments,
      offeredPrice: offeredPrice ?? this.offeredPrice,
      suggestedPrice: suggestedPrice ?? this.suggestedPrice,
      errorMessage: errorMessage,
      activeRide: activeRide == _unset
          ? this.activeRide
          : activeRide as RideEntity?,
      pendingRideOffers: pendingRideOffers ?? this.pendingRideOffers,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      viewersCount: viewersCount ?? this.viewersCount,
    );
  }

  @override
  List<Object?> get props => [
        status,
        originName,
        destName,
        originLatLng,
        destLatLng,
        originPredictions,
        destPredictions,
        routePolyline,
        routeDistanceKm,
        routeDurationSeconds,
        routeBaseSuggested,
        vehicleCategory,
        moreThanFourPassengers,
        babySeat,
        pet,
        rideComments,
        offeredPrice,
        suggestedPrice,
        errorMessage,
        activeRide,
        pendingRideOffers,
        paymentMethod,
        viewersCount,
      ];
}

