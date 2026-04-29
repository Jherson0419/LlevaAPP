import 'dart:math' as math;

import 'package:google_maps_flutter/google_maps_flutter.dart';

/// Distancia en km entre dos puntos (Haversine).
double haversineKm(LatLng a, LatLng b) {
  const earthRadiusKm = 6371.0;
  double degToRad(double d) => d * math.pi / 180;

  final dLat = degToRad(b.latitude - a.latitude);
  final dLon = degToRad(b.longitude - a.longitude);
  final lat1 = degToRad(a.latitude);
  final lat2 = degToRad(b.latitude);

  final h = (math.sin(dLat / 2) * math.sin(dLat / 2)) +
      (math.cos(lat1) *
          math.cos(lat2) *
          math.sin(dLon / 2) *
          math.sin(dLon / 2));
  final c = 2 * math.atan2(math.sqrt(h), math.sqrt(1 - h));
  return earthRadiusKm * c;
}

/// Longitud aproximada del recorrido siguiendo la polilínea (km).
double polylineLengthKm(List<LatLng> points) {
  if (points.length < 2) return 0;
  var sum = 0.0;
  for (var i = 0; i < points.length - 1; i++) {
    sum += haversineKm(points[i], points[i + 1]);
  }
  return sum;
}
