import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:google_maps_flutter/google_maps_flutter.dart';

class DirectionsService {
  /// Obtiene las coordenadas de la ruta real usando Google Maps Directions API
  /// Retorna una lista de LatLng que representa la ruta siguiendo las calles
  Future<List<LatLng>> getRouteCoordinates(
    LatLng origin,
    LatLng destination,
    String apiKey,
  ) async {
    try {
      // Construir la URL de la API
      final url = Uri.parse(
        'https://maps.googleapis.com/maps/api/directions/json'
        '?origin=${origin.latitude},${origin.longitude}'
        '&destination=${destination.latitude},${destination.longitude}'
        '&key=$apiKey',
      );

      // Hacer la petición GET
      final response = await http.get(url);

      if (response.statusCode != 200) {
        throw Exception(
          'Error al obtener la ruta: ${response.statusCode}',
        );
      }

      // Parsear el JSON
      final data = json.decode(response.body);

      // Verificar si hay errores en la respuesta
      if (data['status'] != 'OK') {
        throw Exception(
          'Error de la API: ${data['status']} - ${data['error_message'] ?? 'Error desconocido'}',
        );
      }

      // Verificar que haya rutas disponibles
      if (data['routes'] == null || data['routes'].isEmpty) {
        throw Exception('No se encontraron rutas');
      }

      // Obtener el polyline codificado
      final overviewPolyline = data['routes'][0]['overview_polyline'];
      if (overviewPolyline == null || overviewPolyline['points'] == null) {
        throw Exception('No se encontró información de la ruta');
      }

      final encodedPolyline = overviewPolyline['points'] as String;

      // Decodificar el polyline a una lista de LatLng
      return _decodePolyline(encodedPolyline);
    } catch (e) {
      // Re-lanzar el error para que el llamador pueda manejarlo
      throw Exception('Error al obtener la ruta: $e');
    }
  }

  /// Decodifica un polyline codificado (algoritmo de Google Maps)
  /// Implementación nativa en Dart sin dependencias externas
  List<LatLng> _decodePolyline(String encoded) {
    final List<LatLng> points = [];
    int index = 0;
    int lat = 0;
    int lng = 0;

    while (index < encoded.length) {
      int shift = 0;
      int result = 0;
      int byte;

      // Decodificar latitud
      do {
        byte = encoded.codeUnitAt(index++) - 63;
        result |= (byte & 0x1F) << shift;
        shift += 5;
      } while (byte >= 0x20);

      final int deltaLat = ((result & 1) != 0) ? ~(result >> 1) : (result >> 1);
      lat += deltaLat;

      shift = 0;
      result = 0;

      // Decodificar longitud
      do {
        byte = encoded.codeUnitAt(index++) - 63;
        result |= (byte & 0x1F) << shift;
        shift += 5;
      } while (byte >= 0x20);

      final int deltaLng = ((result & 1) != 0) ? ~(result >> 1) : (result >> 1);
      lng += deltaLng;

      // Convertir a coordenadas decimales (dividir por 1e5)
      // IMPORTANTE: LatLng(latitude, longitude) - NO invertir el orden
      final latitude = lat / 1e5;
      final longitude = lng / 1e5;
      
      points.add(
        LatLng(
          latitude,
          longitude,
        ),
      );
    }

    return points;
  }
}
