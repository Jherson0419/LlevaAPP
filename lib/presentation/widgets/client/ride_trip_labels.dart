import '../../bloc/client_ride/client_ride_bloc.dart';

/// Textos de distancia y duración del viaje para los resúmenes del flujo de
/// pedido. Devuelven guiones mientras la ruta no está calculada.
abstract final class RideTripLabels {
  static bool hasRoute(ClientRideState state) {
    final km = state.routeDistanceKm;
    return km != null && km > 0;
  }

  /// Distancia de la ruta, p. ej. «3.4 km».
  static String distance(ClientRideState state) {
    final km = state.routeDistanceKm;
    if (km == null || km <= 0) return '-- km';
    return '${km.toStringAsFixed(1)} km';
  }

  /// Duración de la ruta, p. ej. «12 min». Usa la de Google Directions y,
  /// si no vino, una estimación a 30 km/h.
  static String duration(ClientRideState state) {
    final km = state.routeDistanceKm;
    if (km == null || km <= 0) return '-- min';
    final seconds = state.routeDurationSeconds;
    final minutes = seconds != null && seconds > 0
        ? (seconds / 60).ceil()
        : (km / 30.0 * 60.0).ceil();
    return '${minutes.clamp(1, 999)} min';
  }
}
