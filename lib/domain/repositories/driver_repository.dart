/// Repositorio de datos agregados del conductor (cartera, métricas).
abstract class DriverRepository {
  /// Suma de `final_price` de viajes `finished` del conductor × comisión (10 %).
  Future<double> getWalletBalance(String driverId);

  /// Valoración en `profiles` (columna opcional `driver_rating`). `null` si no existe.
  Future<double?> getDriverRating(String driverId);
}
