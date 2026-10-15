import 'package:flutter/material.dart';

import '../enums/client_vehicle_category.dart';

/// Categoría del vehículo del conductor y nivel según sus viajes.
///
/// Usa la misma [ClientVehicleCategory] que el pasajero elige al pedir.
abstract final class VehicleCategoryHelper {
  /// Categoría por antigüedad: 2 años o menos es Confort; el resto, Estándar.
  /// Solo para mostrarla: no cambia qué solicitudes recibe el conductor.
  static ClientVehicleCategory getCategoryByYear(int? carYear) {
    if (carYear == null) return ClientVehicleCategory.standard;
    final age = DateTime.now().year - carYear;
    if (age <= 2) return ClientVehicleCategory.comfort;
    return ClientVehicleCategory.standard;
  }

  static String getCategoryName(ClientVehicleCategory category) {
    switch (category) {
      case ClientVehicleCategory.comfort:
        return 'Confort';
      case ClientVehicleCategory.xl:
        return 'XL';
      case ClientVehicleCategory.moto:
        return 'Moto';
      case ClientVehicleCategory.standard:
        return 'Estándar';
    }
  }

  static Color getCategoryColor(ClientVehicleCategory category) {
    switch (category) {
      case ClientVehicleCategory.comfort:
        return const Color(0xFF6A0DAD);
      case ClientVehicleCategory.xl:
        return const Color(0xFF0A7A4B);
      case ClientVehicleCategory.moto:
        return const Color(0xFFCC4400);
      case ClientVehicleCategory.standard:
        return const Color(0xFF0066CC);
    }
  }

  static List<Color> getCategoryGradient(ClientVehicleCategory category) {
    switch (category) {
      case ClientVehicleCategory.comfort:
        return const [Color(0xFF6A0DAD), Color(0xFFAA44FF)];
      case ClientVehicleCategory.xl:
        return const [Color(0xFF0A7A4B), Color(0xFF00C878)];
      case ClientVehicleCategory.moto:
        return const [Color(0xFFCC4400), Color(0xFFFF7733)];
      case ClientVehicleCategory.standard:
        return const [Color(0xFF0055BB), Color(0xFF0088FF)];
    }
  }

  static DriverLevel getLevel(int totalTrips) {
    if (totalTrips >= 500) return DriverLevel.diamond;
    if (totalTrips >= 100) return DriverLevel.gold;
    if (totalTrips >= 20) return DriverLevel.platinum;
    return DriverLevel.basic;
  }
}

/// Nivel del conductor según sus viajes completados.
enum DriverLevel { basic, platinum, gold, diamond }

extension DriverLevelExt on DriverLevel {
  /// Nombre para mostrar (no es `Enum.name`).
  String get label {
    switch (this) {
      case DriverLevel.basic:
        return 'Básico';
      case DriverLevel.platinum:
        return 'Platino';
      case DriverLevel.gold:
        return 'Oro';
      case DriverLevel.diamond:
        return 'Diamante';
    }
  }

  Color get color {
    switch (this) {
      case DriverLevel.basic:
        return const Color(0xFF888888);
      case DriverLevel.platinum:
        return const Color(0xFF0066CC);
      case DriverLevel.gold:
        return const Color(0xFFFFB800);
      case DriverLevel.diamond:
        return const Color(0xFF00D4FF);
    }
  }

  List<Color> get gradient {
    switch (this) {
      case DriverLevel.basic:
        return const [Color(0xFF888888), Color(0xFFAAAAAA)];
      case DriverLevel.platinum:
        return const [Color(0xFF0055BB), Color(0xFF0099FF)];
      case DriverLevel.gold:
        return const [Color(0xFFFF8C00), Color(0xFFFFD700)];
      case DriverLevel.diamond:
        return const [Color(0xFF00B4CC), Color(0xFF00D4FF)];
    }
  }

  IconData get icon {
    switch (this) {
      case DriverLevel.basic:
        return Icons.person_rounded;
      case DriverLevel.platinum:
        return Icons.star_rounded;
      case DriverLevel.gold:
        return Icons.workspace_premium_rounded;
      case DriverLevel.diamond:
        return Icons.diamond_rounded;
    }
  }

  /// Viajes necesarios para el siguiente nivel.
  int get nextLevelTrips {
    switch (this) {
      case DriverLevel.basic:
        return 20;
      case DriverLevel.platinum:
        return 100;
      case DriverLevel.gold:
      case DriverLevel.diamond:
        return 500;
    }
  }

  String get nextLevelName {
    switch (this) {
      case DriverLevel.basic:
        return 'Platino';
      case DriverLevel.platinum:
        return 'Oro';
      case DriverLevel.gold:
      case DriverLevel.diamond:
        return 'Diamante';
    }
  }

  /// Viajes con los que se entra a este nivel.
  int get minTrips {
    switch (this) {
      case DriverLevel.basic:
        return 0;
      case DriverLevel.platinum:
        return 20;
      case DriverLevel.gold:
        return 100;
      case DriverLevel.diamond:
        return 500;
    }
  }

  bool get isMax => this == DriverLevel.diamond;

  /// Avance hacia el siguiente nivel (0–1); 1 en el nivel máximo.
  double progressFor(int totalTrips) {
    if (isMax) return 1;
    final span = nextLevelTrips - minTrips;
    return ((totalTrips - minTrips) / span).clamp(0.0, 1.0);
  }

  /// Viajes que faltan para el siguiente nivel; 0 en el máximo.
  int remainingFor(int totalTrips) {
    if (isMax) return 0;
    final left = nextLevelTrips - totalTrips;
    return left < 0 ? 0 : left;
  }
}
