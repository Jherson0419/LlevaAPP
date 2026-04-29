import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class LocationHelper {
  /// Determina la posición actual del dispositivo
  /// Verifica permisos y servicios de ubicación antes de obtener la posición
  static Future<Position> determinePosition() async {
    bool serviceEnabled;
    LocationPermission permission;

    // Verificar si el servicio de ubicación está habilitado
    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      throw Exception(
        'Los servicios de ubicación están deshabilitados. Por favor, habilítalos en la configuración.',
      );
    }

    // Verificar permisos
    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        throw Exception(
          'Los permisos de ubicación fueron denegados. Por favor, habilítalos en la configuración.',
        );
      }
    }

    if (permission == LocationPermission.deniedForever) {
      throw Exception(
        'Los permisos de ubicación están denegados permanentemente. Por favor, habilítalos en la configuración de la aplicación.',
      );
    }

    // Obtener la posición actual
    return await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
    );
  }

  /// Calcula la distancia entre dos puntos geográficos
  /// Retorna la distancia en kilómetros redondeada a 1 decimal
  static double calculateDistance(LatLng start, LatLng end) {
    final distanceInMeters = Geolocator.distanceBetween(
      start.latitude,
      start.longitude,
      end.latitude,
      end.longitude,
    );

    // Convertir metros a kilómetros y redondear a 1 decimal
    final distanceInKm = distanceInMeters / 1000.0;
    return double.parse(distanceInKm.toStringAsFixed(1));
  }

  /// Calcula la distancia desde la ubicación actual hasta un punto destino
  /// Retorna la distancia en kilómetros redondeada a 1 decimal
  static Future<double> calculateDistanceFromCurrent(Position currentPosition, LatLng destination) async {
    return calculateDistance(
      LatLng(currentPosition.latitude, currentPosition.longitude),
      destination,
    );
  }
}
