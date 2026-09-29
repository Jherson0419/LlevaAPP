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

/// Estado online con aviso de solicitud expirada al aceptar.
class DriverRequestExpired extends DriverOnline {
  final String message;

  const DriverRequestExpired({
    required super.availableRides,
    this.message = 'Esta solicitud ha expirado y ya no está disponible',
  });

  @override
  List<Object?> get props => [availableRides, message];
}

/// Conductor revisa la solicitud (precio, ruta) antes de enviar oferta.
class DriverNegotiating extends DriverStatusState {
  final RideEntity activeRide;
  final double currentOffer;

  const DriverNegotiating({
    required this.activeRide,
    required this.currentOffer,
  });

  @override
  List<Object?> get props => [activeRide, currentOffer];
}

/// Oferta enviada a `ride_offers`; el viaje sigue en `searching` hasta que el pasajero elija.
class DriverWaitingForPassengerDecision extends DriverStatusState {
  final RideEntity activeRide;
  final String submittedOfferId;
  final double submittedPrice;

  const DriverWaitingForPassengerDecision({
    required this.activeRide,
    required this.submittedOfferId,
    required this.submittedPrice,
  });

  @override
  List<Object?> get props => [activeRide, submittedOfferId, submittedPrice];
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
