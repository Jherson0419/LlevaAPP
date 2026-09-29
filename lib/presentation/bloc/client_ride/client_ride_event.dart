part of 'client_ride_bloc.dart';

abstract class ClientRideEvent extends Equatable {
  const ClientRideEvent();

  @override
  List<Object?> get props => [];
}

class OriginTextChanged extends ClientRideEvent {
  final String text;

  const OriginTextChanged(this.text);

  @override
  List<Object?> get props => [text];
}

class DestTextChanged extends ClientRideEvent {
  final String text;

  const DestTextChanged(this.text);

  @override
  List<Object?> get props => [text];
}

class OriginSelected extends ClientRideEvent {
  final String placeId;
  final String description;

  const OriginSelected(this.placeId, this.description);

  @override
  List<Object?> get props => [placeId, description];
}

class DestSelected extends ClientRideEvent {
  final String placeId;
  final String description;

  const DestSelected(this.placeId, this.description);

  @override
  List<Object?> get props => [placeId, description];
}

/// Inicializa el punto de recojo con la ubicación actual del pasajero.
class InitializePickupFromCurrentLocation extends ClientRideEvent {
  const InitializePickupFromCurrentLocation();
}

/// Mueve el punto de recojo a nuevas coordenadas elegidas en el mapa.
class PickupPinMoved extends ClientRideEvent {
  final LatLng position;

  const PickupPinMoved(this.position);

  @override
  List<Object?> get props => [position];
}

/// Mueve el destino a nuevas coordenadas elegidas en el mapa.
class DestPinMoved extends ClientRideEvent {
  final LatLng position;

  const DestPinMoved(this.position);

  @override
  List<Object?> get props => [position];
}

class PriceChanged extends ClientRideEvent {
  final double price;

  const PriceChanged(this.price);

  @override
  List<Object?> get props => [price];
}

class VehicleCategoryChanged extends ClientRideEvent {
  final ClientVehicleCategory category;

  const VehicleCategoryChanged(this.category);

  @override
  List<Object?> get props => [category];
}

/// Vuelve a elegir origen (mantiene destino). Panel inferior muestra búsqueda.
class StartEditingOrigin extends ClientRideEvent {
  const StartEditingOrigin();
}

/// Vuelve a elegir destino (mantiene origen).
class StartEditingDest extends ClientRideEvent {
  const StartEditingDest();
}

/// Vuelve a la pantalla de búsqueda (origen/destino y menú).
class BackToSearchPanel extends ClientRideEvent {
  const BackToSearchPanel();
}

/// Abre el panel de tarifa / preferencias tras confirmar origen y destino.
class ProceedToReadyToRequest extends ClientRideEvent {
  const ProceedToReadyToRequest();
}

class RidePreferencesChanged extends ClientRideEvent {
  final bool? moreThanFourPassengers;
  final bool? babySeat;
  final bool? pet;
  final String? rideComments;

  const RidePreferencesChanged({
    this.moreThanFourPassengers,
    this.babySeat,
    this.pet,
    this.rideComments,
  });

  @override
  List<Object?> get props =>
      [moreThanFourPassengers, babySeat, pet, rideComments];
}

class PaymentMethodChanged extends ClientRideEvent {
  final String method;

  const PaymentMethodChanged(this.method);

  @override
  List<Object?> get props => [method];
}

class SubmitRideRequest extends ClientRideEvent {
  final String clientId;

  const SubmitRideRequest(this.clientId);

  @override
  List<Object?> get props => [clientId];
}

class RideStatusUpdated extends ClientRideEvent {
  final RideEntity ride;

  const RideStatusUpdated(this.ride);

  @override
  List<Object?> get props => [ride];
}

/// Eventos usados por widgets legacy (no usados en el dashboard principal).
class StartSearch extends ClientRideEvent {
  const StartSearch();
}

class CancelRide extends ClientRideEvent {
  const CancelRide();
}

class CalculateRoute extends ClientRideEvent {
  final String origin;
  final String destination;

  const CalculateRoute({
    required this.origin,
    required this.destination,
  });

  @override
  List<Object?> get props => [origin, destination];
}

class SubmitOffer extends ClientRideEvent {
  final double offerPrice;

  const SubmitOffer({required this.offerPrice});

  @override
  List<Object?> get props => [offerPrice];
}

class AcceptDriverOffer extends ClientRideEvent {
  final String offerId;
  final String driverId;
  final double finalPrice;

  const AcceptDriverOffer({
    required this.offerId,
    required this.driverId,
    required this.finalPrice,
  });

  @override
  List<Object?> get props => [offerId, driverId, finalPrice];
}

class RejectRideOffer extends ClientRideEvent {
  final String offerId;

  const RejectRideOffer(this.offerId);

  @override
  List<Object?> get props => [offerId];
}

class RideOffersUpdated extends ClientRideEvent {
  final List<RideOfferEntity> offers;
  final int viewersCount;

  const RideOffersUpdated(this.offers, {this.viewersCount = 0});

  @override
  List<Object?> get props => [offers, viewersCount];
}

/// Actualiza el precio ofertado del viaje activo para que los conductores
/// lo vean en tiempo real.
class BoostOfferedPrice extends ClientRideEvent {
  final double newPrice;

  const BoostOfferedPrice(this.newPrice);

  @override
  List<Object?> get props => [newPrice];
}

/// Cierra el resumen al terminar el viaje y vuelve al flujo inicial.
class DismissTripCompleted extends ClientRideEvent {
  const DismissTripCompleted();
}

/// Rehidrata un viaje activo del cliente al reabrir la app.
class CheckActiveRide extends ClientRideEvent {
  final String clientId;

  const CheckActiveRide(this.clientId);

  @override
  List<Object?> get props => [clientId];
}
