import '../entities/top_driver_entity.dart';

/// Repositorio de datos agregados del conductor (cartera, métricas).
abstract class DriverRepository {
  /// Suma de `final_price` de viajes `finished` del conductor × comisión (10 %).
  Future<double> getWalletBalance(String driverId);

  /// Valoración en `profiles` (columna opcional `driver_rating`). `null` si no existe.
  Future<double?> getDriverRating(String driverId);

  /// Hasta 5 conductores destacados (vista `top_drivers`). Lista vacía si la
  /// vista no existe o la consulta falla.
  Future<List<TopDriverEntity>> getTopDrivers();

  /// Viajes `finished` del conductor desde siempre. 0 si la consulta falla.
  Future<int> getDriverCompletedTripsCount(String driverId);

  /// Viajes `finished` de hoy (hora local) y lo cobrado en ellos:
  /// `{'trips': int, 'earnings': double}`. Ceros si la consulta falla.
  Future<Map<String, dynamic>> getDriverTodaySummary(String driverId);
}
