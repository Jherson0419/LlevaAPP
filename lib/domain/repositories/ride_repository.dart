import '../entities/ride_entity.dart';

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
}
