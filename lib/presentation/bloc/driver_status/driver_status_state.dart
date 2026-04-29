import 'package:equatable/equatable.dart';
import '../../../../domain/entities/ride_entity.dart';

abstract class DriverStatusState extends Equatable {
  const DriverStatusState();

  @override
  List<Object?> get props => [];
}

class DriverOffline extends DriverStatusState {
  const DriverOffline();
}

class DriverOnline extends DriverStatusState {
  final List<RideEntity> availableRides;

  const DriverOnline({this.availableRides = const []});

  @override
  List<Object?> get props => [availableRides];
}

class DriverNegotiating extends DriverStatusState {
  final RideEntity activeRide;
  final double currentOffer;
  /// Tras enviar una contraoferta: esperando decisión del pasajero.
  final bool awaitingPassengerResponse;

  const DriverNegotiating({
    required this.activeRide,
    required this.currentOffer,
    this.awaitingPassengerResponse = false,
  });

  @override
  List<Object?> get props => [activeRide, currentOffer, awaitingPassengerResponse];
}

class DriverOnTrip extends DriverStatusState {
  final RideEntity activeRide;

  const DriverOnTrip(this.activeRide);

  @override
  List<Object?> get props => [activeRide];
}

/// Conductor en punto de recojo (pasajero aún no sube).
class DriverArrivedAtPickup extends DriverStatusState {
  final RideEntity activeRide;

  const DriverArrivedAtPickup(this.activeRide);

  @override
  List<Object?> get props => [activeRide];
}

/// Viaje en curso (hacia el destino).
class DriverTripInProgress extends DriverStatusState {
  final RideEntity activeRide;

  const DriverTripInProgress(this.activeRide);

  @override
  List<Object?> get props => [activeRide];
}
