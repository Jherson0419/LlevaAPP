import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter_polyline_points/flutter_polyline_points.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;

import '../constants/app_constants.dart';

/// Modelo mínimo para una predicción de Google Places.
class Prediction {
  final String placeId;
  final String description;
  final String title;
  final String district;
  final double? distanceKm;

  const Prediction({
    required this.placeId,
    required this.description,
    required this.title,
    required this.district,
    this.distanceKm,
  });

  Prediction copyWith({
    String? placeId,
    String? description,
    String? title,
    String? district,
    double? distanceKm,
    bool clearDistanceKm = false,
  }) {
    return Prediction(
      placeId: placeId ?? this.placeId,
      description: description ?? this.description,
      title: title ?? this.title,
      district: district ?? this.district,
      distanceKm: clearDistanceKm ? null : (distanceKm ?? this.distanceKm),
    );
  }
}

/// Ruta en auto desde Directions API (misma base que Google Maps).
class DrivingRouteResult {
  const DrivingRouteResult({
    required this.points,
    required this.distanceKm,
    required this.durationSeconds,
  });

  final List<LatLng> points;
  final double distanceKm;
  final int durationSeconds;
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
  // Antes este archivo tenía su PROPIA copia hardcodeada de la API key,
  // distinta en el código fuente de la de app_constants.dart aunque con el
  // mismo valor — dos lugares para rotar la misma credencial. Ahora hay una
  // sola fuente de verdad (ver docs/setup_env.md).
  static const String _apiKey = AppConstants.googleMapsApiKey;
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
        _polylinePoints = polylinePoints ?? PolylinePoints(apiKey: _apiKey);

  /// Busca lugares usando la Autocomplete API, restringido a Perú y sesgado
  /// a la zona actual (por defecto Trujillo).
  Future<List<Prediction>> searchPlaces(
    String query, {
    LatLng? near,
    String? cityHint,
  }) async {
    if (query.isEmpty) return [];
    final nearLat = near?.latitude ?? AppConstants.trujilloLatitude;
    final nearLng = near?.longitude ?? AppConstants.trujilloLongitude;
    final effectiveCityHint = (cityHint == null || cityHint.trim().isEmpty)
        ? 'trujillo'
        : cityHint.trim().toLowerCase();

    final uri = Uri.parse(
      '$_placesBaseUrl/autocomplete/json'
      '?input=${Uri.encodeQueryComponent(query)}'
      '&types=geocode'
      '&components=country:pe'
      '&location=$nearLat,$nearLng'
      '&radius=25000'
      '&strictbounds=true'
      '&language=es'
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
    final mapped = predictions
        .map(
          (raw) {
            final p = raw as Map<String, dynamic>;
            final description = (p['description'] as String? ?? '').trim();
            final formatting =
                p['structured_formatting'] as Map<String, dynamic>? ?? const {};
            final title =
                (formatting['main_text'] as String? ?? description).trim();
            final secondary =
                (formatting['secondary_text'] as String? ?? '').trim();
            final district = _extractDistrict(secondary, description);
            final distanceMeters = (p['distance_meters'] as num?)?.toDouble();
            return Prediction(
              placeId: p['place_id'] as String,
              description: description,
              title: title.isEmpty ? description : title,
              district: district,
              distanceKm:
                  distanceMeters == null ? null : (distanceMeters / 1000.0),
            );
          },
        )
        .where((p) {
          if (effectiveCityHint.isEmpty) return true;
          final haystack =
              '${p.description} ${p.district}'.toLowerCase();
          return haystack.contains(effectiveCityHint);
        })
        .toList();

    return mapped;
  }

  /// Completa distancia desde origen para sugerencias de destino.
  Future<List<Prediction>> enrichPredictionsWithDistance({
    required List<Prediction> predictions,
    required LatLng origin,
    int maxItems = 6,
  }) async {
    if (predictions.isEmpty) return const [];
    final limited = predictions.take(maxItems).toList();
    final enriched = <Prediction>[];
    for (final prediction in limited) {
      final details = await getPlaceDetails(prediction.placeId);
      if (details == null) {
        enriched.add(prediction);
        continue;
      }
      final distanceKm = _distanceKm(origin, details.location);
      enriched.add(prediction.copyWith(distanceKm: distanceKm));
    }
    return enriched;
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

  /// Ruta en auto + distancia/duración oficiales de Google Directions.
  Future<DrivingRouteResult?> getDrivingRoute(
    LatLng origin,
    LatLng dest,
  ) async {
    final uri = Uri.parse(
      '$_directionsBaseUrl'
      '?origin=${origin.latitude},${origin.longitude}'
      '&destination=${dest.latitude},${dest.longitude}'
      '&mode=driving'
      '&language=es'
      '&key=$_apiKey',
    );

    try {
      final response = await _httpClient.get(uri);
      if (response.statusCode != 200) return null;

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      if (data['status'] != 'OK') {
        if (kDebugMode) {
          print('Directions error: ${data['status']}');
        }
        return null;
      }

      final routes = data['routes'] as List<dynamic>? ?? const [];
      if (routes.isEmpty) return null;

      final route = routes.first as Map<String, dynamic>;
      final legs = route['legs'] as List<dynamic>? ?? const [];
      if (legs.isEmpty) return null;

      var distanceMeters = 0;
      var durationSeconds = 0;
      for (final legRaw in legs) {
        final leg = legRaw as Map<String, dynamic>;
        final dist = leg['distance'] as Map<String, dynamic>?;
        final dur = leg['duration'] as Map<String, dynamic>?;
        distanceMeters += (dist?['value'] as num?)?.toInt() ?? 0;
        durationSeconds += (dur?['value'] as num?)?.toInt() ?? 0;
      }

      final overview = route['overview_polyline'] as Map<String, dynamic>?;
      final encoded = overview?['points'] as String?;
      if (encoded == null || encoded.isEmpty) return null;

      final decoded = PolylinePoints.decodePolyline(encoded);
      if (decoded.isEmpty) return null;

      final points = decoded
          .map((p) => LatLng(p.latitude, p.longitude))
          .toList(growable: false);

      return DrivingRouteResult(
        points: points,
        distanceKm: distanceMeters / 1000.0,
        durationSeconds: durationSeconds,
      );
    } catch (e) {
      if (kDebugMode) {
        print('getDrivingRoute error: $e');
      }
      return null;
    }
  }

  /// Obtiene la polyline entre origen y destino usando Directions API.
  Future<List<LatLng>> getRoutePolyline(
    LatLng origin,
    LatLng dest,
  ) async {
    final route = await getDrivingRoute(origin, dest);
    if (route != null && route.points.isNotEmpty) {
      return route.points;
    }

    final result = await _polylinePoints.getRouteBetweenCoordinates(
      request: PolylineRequest(
        origin: PointLatLng(origin.latitude, origin.longitude),
        destination: PointLatLng(dest.latitude, dest.longitude),
        mode: TravelMode.driving,
      ),
    );

    if (result.points.isEmpty) return [];

    return result.points.map((p) => LatLng(p.latitude, p.longitude)).toList();
  }

  /// Convierte coordenadas a una dirección legible (Reverse Geocoding).
  Future<String?> reverseGeocode(LatLng position) async {
    final uri = Uri.parse(
      'https://maps.googleapis.com/maps/api/geocode/json'
      '?latlng=${position.latitude},${position.longitude}'
      '&language=es'
      '&key=$_apiKey',
    );

    final response = await _httpClient.get(uri);
    if (response.statusCode != 200) return null;

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    if (data['status'] != 'OK') {
      if (kDebugMode) {
        print('Reverse geocode error: ${data['status']}');
      }
      return null;
    }

    final results = data['results'] as List<dynamic>? ?? const [];
    if (results.isEmpty) return null;
    final first = results.first as Map<String, dynamic>;
    final address = first['formatted_address'] as String?;
    if (address == null || address.trim().isEmpty) return null;
    return address.trim();
  }

  String _extractDistrict(String secondary, String fallbackDescription) {
    final source = secondary.isNotEmpty ? secondary : fallbackDescription;
    final parts = source
        .split(',')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
    if (parts.length >= 2) return parts[1];
    if (parts.isNotEmpty) return parts.first;
    return 'Sin distrito';
  }

  double _distanceKm(LatLng a, LatLng b) {
    const earthRadiusKm = 6371.0;
    final dLat = _degToRad(b.latitude - a.latitude);
    final dLon = _degToRad(b.longitude - a.longitude);
    final lat1 = _degToRad(a.latitude);
    final lat2 = _degToRad(b.latitude);
    final h = (math.sin(dLat / 2) * math.sin(dLat / 2)) +
        (math.cos(lat1) *
            math.cos(lat2) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2));
    final c = 2 * math.atan2(math.sqrt(h), math.sqrt(1 - h));
    return earthRadiusKm * c;
  }

  double _degToRad(double deg) => deg * (3.141592653589793 / 180.0);
}
