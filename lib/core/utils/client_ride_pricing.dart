import '../enums/client_vehicle_category.dart';

/// Cálculo de recargos por categoría de vehículo y preferencias del viaje.
class ClientRidePricing {
  ClientRidePricing._();

  static double _roundHalf(double x) => (x * 2).round() / 2;

  /// Recargo por categoría (sobre la tarifa base por distancia).
  static double categoryExtra(ClientVehicleCategory category, double base) {
    switch (category) {
      case ClientVehicleCategory.standard:
        return 0;
      case ClientVehicleCategory.comfort:
        return _roundHalf(base * 0.10);
      case ClientVehicleCategory.xl:
        return _roundHalf(base * 0.22);
    }
  }

  static double optionsExtra({
    required bool moreThanFourPassengers,
    required bool babySeat,
    required bool pet,
  }) {
    double e = 0;
    if (moreThanFourPassengers) e += 2;
    if (babySeat) e += 1.5;
    if (pet) e += 1.5;
    return e;
  }

  static double totalSuggested({
    required double routeBase,
    required ClientVehicleCategory category,
    required bool moreThanFourPassengers,
    required bool babySeat,
    required bool pet,
  }) {
    final extra = categoryExtra(category, routeBase) +
        optionsExtra(
          moreThanFourPassengers: moreThanFourPassengers,
          babySeat: babySeat,
          pet: pet,
        );
    return _roundHalf(routeBase + extra).clamp(1.0, 999999.0);
  }
}
