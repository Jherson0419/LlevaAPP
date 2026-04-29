import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_polyline_points/flutter_polyline_points.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;

/// Modelo mínimo para una predicción de Google Places.
class Prediction {
  final String placeId;
  final String description;

  const Prediction({
    required this.placeId,
    required this.description,
  });
}

/// Modelo mínimo para los detalles de un lugar.
class PlaceDetails {
  final String placeId;
  final String name;
  final LatLng location;

  const PlaceDetails({
    required this.placeId,
    required this.name,
    required this.location,
  });
}

/// Servicio para consumir Google Places y Directions API.
class PlacesService {
  static const String _apiKey = 'AIzaSyCCYG5f-y30dM9GDSsSvkLyhJraMtfjO5o';
  static const String _placesBaseUrl =
      'https://maps.googleapis.com/maps/api/place';
  static const String _directionsBaseUrl =
      'https://maps.googleapis.com/maps/api/directions/json';

  final http.Client _httpClient;
  final PolylinePoints _polylinePoints;

  PlacesService({
    http.Client? httpClient,
    PolylinePoints? polylinePoints,
  })  : _httpClient = httpClient ?? http.Client(),
        _polylinePoints =
            polylinePoints ?? PolylinePoints(apiKey: _apiKey);

  /// Busca lugares usando la Autocomplete API, restringido a Perú.
  Future<List<Prediction>> searchPlaces(String query) async {
    if (query.isEmpty) return [];

    final uri = Uri.parse(
      '$_placesBaseUrl/autocomplete/json'
      '?input=${Uri.encodeQueryComponent(query)}'
      '&types=geocode'
      '&components=country:pe'
      '&key=$_apiKey',
    );

    final response = await _httpClient.get(uri);
    if (response.statusCode != 200) return [];

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    if (data['status'] != 'OK' && data['status'] != 'ZERO_RESULTS') {
      if (kDebugMode) {
        print('Places autocomplete error: ${data['status']}');
      }
      return [];
    }

    final List predictions = data['predictions'] as List? ?? [];
    return predictions
        .map(
          (p) => Prediction(
            placeId: p['place_id'] as String,
            description: p['description'] as String,
          ),
        )
        .toList();
  }

  /// Obtiene detalles de un lugar, incluyendo coordenadas.
  Future<PlaceDetails?> getPlaceDetails(String placeId) async {
    final uri = Uri.parse(
      '$_placesBaseUrl/details/json'
      '?place_id=$placeId'
      '&fields=place_id,name,geometry'
      '&key=$_apiKey',
    );

    final response = await _httpClient.get(uri);
    if (response.statusCode != 200) return null;

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    if (data['status'] != 'OK') {
      if (kDebugMode) {
        print('Place details error: ${data['status']}');
      }
      return null;
    }

    final result = data['result'] as Map<String, dynamic>;
    final geometry = result['geometry'] as Map<String, dynamic>;
    final location = geometry['location'] as Map<String, dynamic>;

    return PlaceDetails(
      placeId: result['place_id'] as String,
      name: result['name'] as String,
      location: LatLng(
        (location['lat'] as num).toDouble(),
        (location['lng'] as num).toDouble(),
      ),
    );
  }

  /// Obtiene la polyline entre origen y destino usando Directions API.
  Future<List<LatLng>> getRoutePolyline(
    LatLng origin,
    LatLng dest,
  ) async {
    final result = await _polylinePoints.getRouteBetweenCoordinates(
      request: PolylineRequest(
        origin: PointLatLng(origin.latitude, origin.longitude),
        destination: PointLatLng(dest.latitude, dest.longitude),
        mode: TravelMode.driving,
      ),
    );

    if (result.points.isEmpty) return [];

    return result.points
        .map((p) => LatLng(p.latitude, p.longitude))
        .toList();
  }
}

