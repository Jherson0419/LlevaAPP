part of 'client_ride_bloc.dart';

abstract class ClientRideEvent extends Equatable {
  const ClientRideEvent();

  @override
  List<Object?> get props => [];
}

class DestTextChanged extends ClientRideEvent {
  final String text;

  const DestTextChanged(this.text);

  @override
  List<Object?> get props => [text];
}

class DestSelected extends ClientRideEvent {
  final String placeId;
  final String description;

  const DestSelected(this.placeId, this.description);

  @override
  List<Object?> get props => [placeId, description];
}

/// Destino elegido con nombre y coordenadas ya conocidos (p. ej. un lugar
/// sugerido): no pasa por PlacesService.
class DestCoordinatesSelected extends ClientRideEvent {
  final String name;
  final double lat;
  final double lng;

  const DestCoordinatesSelected({
    required this.name,
    required this.lat,
    required this.lng,
  });

  @override
  List<Object?> get props => [name, lat, lng];
}

/// Inicializa el punto de recojo con la ubicación actual del pasajero.
///
/// Con [askPermission] en false no muestra el diálogo de permiso: si falta,
/// se marca [ClientRideState.locationDenied] y la UI ofrece activarlo.
class InitializePickupFromCurrentLocation extends ClientRideEvent {
  const InitializePickupFromCurrentLocation({this.askPermission = true});

  final bool askPermission;

  @override
  List<Object?> get props => [askPermission];
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

/// Intercambia origen y destino (coordenadas y nombres) y recalcula la ruta.
class SwapOriginDestination extends ClientRideEvent {
  const SwapOriginDestination();
}

class PriceChanged extends ClientRideEvent {
  final double price;

  /// true = además de fijar la oferta, cambia a la categoría de vehículo
  /// cuya tarifa sugerida queda más cerca del nuevo precio (paso 3).
  final bool autoSelectCategory;

  const PriceChanged(this.price, {this.autoSelectCategory = false});

  @override
  List<Object?> get props => [price, autoSelectCategory];
}

class VehicleCategoryChanged extends ClientRideEvent {
  final ClientVehicleCategory category;

  const VehicleCategoryChanged(this.category);

  @override
  List<Object?> get props => [category];
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

class CancelRide extends ClientRideEvent {
  const CancelRide();
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
