import '../entities/ride_entity.dart';
import '../entities/ride_offer_entity.dart';

/// Contrato abstracto para el repositorio de Viajes (Rides).
/// 
/// Define las operaciones que cualquier implementación
/// de repositorio debe cumplir para interactuar con la base de datos.
abstract class RideRepository {
  /// Crea una nueva solicitud de viaje en la base de datos.
  /// 
  /// [ride] - La entidad RideEntity con los datos del viaje a crear.
  /// 
  /// Lanza una excepción si la operación falla.
  /// Retorna el viaje persistido (incluye el `id` generado por la base).
  Future<RideEntity> createRideRequest(RideEntity ride);

  /// Escucha en tiempo real los cambios de un viaje concreto.
  Stream<RideEntity> subscribeToRide(String rideId);

  /// Obtiene un viaje puntual por id para validar estado actual.
  Future<RideEntity?> getRideById(String rideId);

  /// Obtiene el viaje activo del cliente si sigue en curso de asignación.
  /// Considera estados recuperables para rehidratar UI (p. ej. searching/accepted).
  Future<RideEntity?> getActiveRideByClientId(String clientId);

  /// Obtiene el viaje activo del conductor si ya tiene uno asignado/en curso.
  Future<RideEntity?> getActiveRideByDriverId(String driverId);

  /// Acepta un viaje en backend ERP con validación estricta de estado.
  ///
  /// Debe lanzar [RideRequestExpiredException] cuando el backend responde 409
  /// por solicitud expirada/cancelada.
  Future<RideEntity> acceptRide({
    required String rideId,
    required String driverId,
  });

  /// Obtiene un stream de solicitudes de viaje cercanas en tiempo real.
  /// 
  /// [lat] - Latitud del punto de referencia.
  /// [lng] - Longitud del punto de referencia.
  /// [radiusInKm] - Radio de búsqueda en kilómetros.
  /// 
  /// Retorna un Stream que emite listas de RideEntity cuando hay cambios
  /// en las solicitudes de viaje dentro del radio especificado.
  /// 
  /// El stream se mantiene activo y emite actualizaciones en tiempo real
  /// cuando se crean, modifican o eliminan solicitudes de viaje.
  Stream<List<RideEntity>> getNearbyRideRequests(
    double lat,
    double lng,
    double radiusInKm,
  );

  /// Marca el viaje como cancelado en la tabla `rides` (no elimina el registro).
  ///
  /// Actualiza la columna `status` a `'cancelled'` para que el servidor pueda
  /// archivar el viaje al historial según las reglas configuradas.
  Future<void> cancelRide(String rideId);

  /// Actualiza el estado de un viaje existente.
  ///
  /// [rideId] - ID del viaje en la tabla `rides`.
  /// [status] - Nuevo estado (p. ej. 'searching', 'negotiating', 'accepted',
  /// 'arrived', 'ongoing', 'finished', etc.).
  /// [driverId] - Opcional, ID del conductor que acepta el viaje.
  /// [finalPrice] - Opcional, tarifa final acordada.
  /// [clearDriver] - Si es true, fuerza `driver_id` y `final_price` a null en Supabase.
  Future<void> updateRideStatus(
    String rideId,
    String status, {
    String? driverId,
    double? finalPrice,
    bool clearDriver = false,
  });

  /// Actualiza la posición en vivo del conductor en el viaje.
  Future<void> updateDriverLocation(String rideId, double lat, double lng);

  /// Viajes finalizados hoy para el conductor: suma de [final_price] y cantidad.
  ///
  /// Retorna `{'earnings': double, 'trips': int}`.
  Future<Map<String, dynamic>> getTodayDriverStats(String driverId);

  /// Historial de viajes del usuario según rol (`client` | `driver`).
  Future<List<RideEntity>> getRideHistory(String userId, String role);

  /// Ofertas de conductores para un viaje en `searching` (tiempo real).
  ///
  /// Si [pendingOnly] es true, solo emite filas con `status = pending` (vista pasajero).
  /// El conductor puede usar `pendingOnly: false` para observar cambios de estado de su fila.
  Stream<List<RideOfferEntity>> listenToRideOffers(
    String rideId, {
    bool pendingOnly = true,
  });

  /// Lectura puntual de ofertas `pending` (útil si Realtime no está habilitado en `ride_offers`).
  Future<List<RideOfferEntity>> fetchPendingRideOffers(String rideId);

  /// Inserta o actualiza una oferta `pending` sin cambiar el estado del viaje (`searching`).
  Future<RideOfferEntity> submitNegotiationOffer({
    required String rideId,
    required String driverId,
    required double offeredPrice,
  });

  /// Retira la oferta del conductor (`withdrawn`).
  Future<void> withdrawRideOffer(String offerId);

  /// El pasajero descarta una oferta concreta (`rejected`).
  Future<void> rejectRideOffer(String offerId);

  /// Acepta una oferta: RPC atómica preferida; ver `supabase/migrations/ride_offers.sql`.
  Future<void> acceptRideOffer({
    required String offerId,
    required String rideId,
    required String driverId,
    required double finalPrice,
  });

  /// Conductor con oferta `pending` y viaje aún en `searching` (recuperación de sesión).
  Future<({RideEntity ride, RideOfferEntity offer})?>
      getPendingOfferContextForDriver(String driverId);

  /// Número de conductores distintos que han respondido a esta solicitud
  /// (cualquier estado en ride_offers). Proxy de "conductores que han visto la oferta".
  Future<int> getRideViewersCount(String rideId);

  /// Actualiza el precio ofertado del viaje en la tabla `rides` para que los
  /// conductores lo vean en tiempo real.
  Future<void> updateOfferedPrice(String rideId, double newPrice);
}

/// Error controlado cuando la solicitud ya no se puede aceptar.
class RideRequestExpiredException implements Exception {
  final String message;

  const RideRequestExpiredException(this.message);

  @override
  String toString() => message;
}

/// Error de negocio genérico para aceptación de viaje.
class RideAcceptanceException implements Exception {
  final String message;

  const RideAcceptanceException(this.message);

  @override
  String toString() => message;
}
