import '../enums/client_vehicle_category.dart';

/// Cálculo de tarifas del pasajero: base por distancia, recargos y límites de oferta.
class ClientRidePricing {
  ClientRidePricing._();

  /// Tarifa base fija (S/) al calcular por kilómetros.
  static const double routeBaseFare = 3.0;

  /// S/ por kilómetro (sobre la tarifa base fija).
  static const double routePerKm = 1.80;

  /// El pasajero no puede ofertar más de [maxDiscountBelowSuggested] por debajo
  /// de la tarifa sugerida (categoría + extras).
  static const double maxDiscountBelowSuggested = 2.0;

  /// Paso al bajar/subir precio con los botones − y +.
  static const double priceDecreaseStep = 0.5;

  /// Paso al subir precio con los botones +.
  static const double priceIncreaseStep = 0.5;

  static const double minOfferedPrice = 1.0;
  static const double maxOfferedPrice = 999999.0;

  static double _roundHalf(double x) => (x * 2).round() / 2;

  /// Tarifa por distancia antes de categoría y extras.
  static double routeBaseFromDistanceKm(double distanceKm) {
    final price = routeBaseFare + (distanceKm * routePerKm);
    return double.parse(price.toStringAsFixed(2));
  }

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
    return _roundHalf(routeBase + extra).clamp(minOfferedPrice, maxOfferedPrice);
  }

  /// Precio mínimo que el pasajero puede ofertar respecto a la tarifa sugerida.
  static double minimumOfferedPrice(double? suggestedPrice) {
    if (suggestedPrice == null || suggestedPrice <= 0) {
      return minOfferedPrice;
    }
    return (suggestedPrice - maxDiscountBelowSuggested)
        .clamp(minOfferedPrice, maxOfferedPrice);
  }

  /// Ajusta una oferta manual o por botones al rango permitido.
  static double clampOfferedPrice({
    required double price,
    required double? suggestedPrice,
  }) {
    final min = minimumOfferedPrice(suggestedPrice);
    return price.clamp(min, maxOfferedPrice);
  }

  static double decreaseOffered({
    required double current,
    required double? suggestedPrice,
  }) {
    final min = minimumOfferedPrice(suggestedPrice);
    final next = current - priceDecreaseStep;
    return next < min ? min : next;
  }

  static double increaseOffered(double current) {
    return (current + priceIncreaseStep).clamp(minOfferedPrice, maxOfferedPrice);
  }
}
