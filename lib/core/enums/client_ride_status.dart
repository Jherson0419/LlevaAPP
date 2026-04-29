/// Estado del flujo de viaje del pasajero (cliente) en pantalla.
enum ClientRideStatus {
  initial,
  readyToRequest,
  searchingDriver,
  negotiating,
  driverAssigned,
  driverArrived,
  tripOngoing,
  tripFinished,
  error,
}
