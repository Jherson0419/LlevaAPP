import 'package:equatable/equatable.dart';
import '../../../../domain/entities/ride_entity.dart';

abstract class DriverStatusEvent extends Equatable {
  const DriverStatusEvent();

  @override
  List<Object?> get props => [];
}

class ToggleStatus extends DriverStatusEvent {
  const ToggleStatus();
}

class NearbyRidesUpdated extends DriverStatusEvent {
  final List<RideEntity> rides;

  const NearbyRidesUpdated(this.rides);

  @override
  List<Object?> get props => [rides];
}

class ReceiveRequest extends DriverStatusEvent {
  final RideEntity ride;

  const ReceiveRequest(this.ride);

  @override
  List<Object?> get props => [ride];
}

class UpdateOffer extends DriverStatusEvent {
  final double newOffer;

  const UpdateOffer({required this.newOffer});

  @override
  List<Object?> get props => [newOffer];
}

class AcceptRide extends DriverStatusEvent {
  final RideEntity ride;
  final String driverId;
  final double finalPrice;

  const AcceptRide({
    required this.ride,
    required this.driverId,
    required this.finalPrice,
  });

  @override
  List<Object?> get props => [ride, driverId, finalPrice];
}

class RejectRide extends DriverStatusEvent {
  const RejectRide();
}

/// La contraoferta expiró sin respuesta: liberar el viaje en servidor.
class OfferExpired extends DriverStatusEvent {
  final RideEntity ride;

  OfferExpired(this.ride);

  @override
  List<Object?> get props => [ride];
}

class CounterOfferRide extends DriverStatusEvent {
  final RideEntity ride;
  final String driverId;
  final double newPrice;

  const CounterOfferRide({
    required this.ride,
    required this.driverId,
    required this.newPrice,
  });

  @override
  List<Object?> get props => [ride, driverId, newPrice];
}

/// Actualización del viaje activo vía Realtime (aceptación o rechazo del pasajero).
class ActiveRideRemoteUpdated extends DriverStatusEvent {
  final RideEntity ride;

  const ActiveRideRemoteUpdated(this.ride);

  @override
  List<Object?> get props => [ride];
}

class NotifyArrival extends DriverStatusEvent {
  const NotifyArrival();
}

class StartTrip extends DriverStatusEvent {
  const StartTrip();
}

class FinishTrip extends DriverStatusEvent {
  const FinishTrip();
}

