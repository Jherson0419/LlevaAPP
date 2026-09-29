/// Estado del flujo de viaje del pasajero (cliente) en pantalla.
enum ClientRideStatus {
  initial,
  readyToRequest,
  requesting,
  searchingDriver,
  negotiating,
  driverAssigned,
  driverArrived,
  tripOngoing,
  tripFinished,
  error,
}
