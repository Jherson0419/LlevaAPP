import 'dart:math' as math;

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../domain/entities/ride_entity.dart';
import '../../domain/repositories/ride_repository.dart';
import '../models/ride_model.dart';

/// Implementación concreta de RideRepository usando Supabase.
///
/// Se comunica con PostgreSQL a través de Supabase para realizar
/// operaciones CRUD y suscripciones en tiempo real.
class RideRepositoryImpl implements RideRepository {
  final SupabaseClient _supabaseClient = Supabase.instance.client;

  @override
  Future<RideEntity> createRideRequest(RideEntity ride) async {
    final rideModel = RideModel(
      id: ride.id,
      clientId: ride.clientId,
      driverId: ride.driverId,
      originLat: ride.originLat,
      originLng: ride.originLng,
      destLat: ride.destLat,
      destLng: ride.destLng,
      originName: ride.originName,
      destName: ride.destName,
      status: ride.status,
      offeredPrice: ride.offeredPrice,
      finalPrice: ride.finalPrice,
      createdAt: ride.createdAt,
      driverLat: ride.driverLat,
      driverLng: ride.driverLng,
      paymentMethod: ride.paymentMethod,
      clientFirstName: ride.clientFirstName,
      clientCompletedTrips: ride.clientCompletedTrips,
      clientPassengerRating: ride.clientPassengerRating,
    );

    final response = await _supabaseClient
        .from('rides')
        .insert(rideModel.toJson())
        .select()
        .maybeSingle();

    if (response == null) {
      throw Exception('No se pudo crear el viaje');
    }
    return RideModel.fromJson(response);
  }

  @override
  Stream<RideEntity> subscribeToRide(String rideId) {
    return _supabaseClient
        .from('rides')
        .stream(primaryKey: ['id'])
        .eq('id', rideId)
        .where((list) => list.isNotEmpty)
        .map(
      (list) => RideModel.fromJson(
        Map<String, dynamic>.from(list.first as Map),
      ),
    );
  }

  @override
  Future<void> updateRideStatus(
    String rideId,
    String status, {
    String? driverId,
    double? finalPrice,
    bool clearDriver = false,
  }) async {
    final updateData = <String, dynamic>{'status': status};

    if (clearDriver) {
      updateData['driver_id'] = null;
      updateData['final_price'] = null;
    } else {
      if (driverId != null) {
        updateData['driver_id'] = driverId;
      }
      if (finalPrice != null) {
        updateData['final_price'] = finalPrice;
      }
    }

    await _supabaseClient
        .from('rides')
        .update(updateData)
        .eq('id', rideId);
  }

  @override
  Future<void> updateDriverLocation(String rideId, double lat, double lng) async {
    await _supabaseClient.from('rides').update({
      'driver_lat': lat,
      'driver_lng': lng,
    }).eq('id', rideId);
  }

  @override
  Stream<List<RideEntity>> getNearbyRideRequests(
    double lat,
    double lng,
    double radiusInKm,
  ) {
    return _supabaseClient
        .from('rides')
        .stream(primaryKey: ['id'])
        .eq('status', 'searching')
        .asyncMap((data) async {
      final list = List<Map<String, dynamic>>.from(data as List<dynamic>);
      final rides = list
          .map((json) => RideModel.fromJson(json))
          .where(
            (ride) =>
                _approxDistanceInKm(
                  lat,
                  lng,
                  ride.originLat,
                  ride.originLng,
                ) <=
                radiusInKm,
          )
          .toList();
      return _enrichNearbyRidesForDriver(rides);
    });
  }

  /// Nombre (primer token de `full_name`) y conteo de viajes terminados del pasajero.
  Future<List<RideEntity>> _enrichNearbyRidesForDriver(
    List<RideModel> rides,
  ) async {
    if (rides.isEmpty) return const [];

    final ids = rides.map((r) => r.clientId).toSet().toList();
    if (ids.isEmpty) return rides;

    final idToFullName = <String, String>{};
    try {
      final profiles = await _supabaseClient
          .from('profiles')
          .select('id, full_name')
          .inFilter('id', ids);
      for (final row in profiles as List<dynamic>) {
        final m = Map<String, dynamic>.from(row as Map<dynamic, dynamic>);
        idToFullName[m['id'].toString()] = m['full_name']?.toString() ?? '';
      }
    } catch (_) {}

    final tripCounts = {for (final id in ids) id: 0};
    try {
      final rows = await _supabaseClient
          .from('rides')
          .select('client_id')
          .eq('status', 'finished')
          .inFilter('client_id', ids);
      for (final row in rows as List<dynamic>) {
        final m = Map<String, dynamic>.from(row as Map<dynamic, dynamic>);
        final cid = m['client_id']?.toString();
        if (cid != null) {
          tripCounts[cid] = (tripCounts[cid] ?? 0) + 1;
        }
      }
    } catch (_) {}

    final idToPassengerRating = <String, double>{};
    try {
      final ratingRows = await _supabaseClient
          .from('profiles')
          .select('id, passenger_rating')
          .inFilter('id', ids);
      for (final row in ratingRows as List<dynamic>) {
        final m = Map<String, dynamic>.from(row as Map<dynamic, dynamic>);
        final id = m['id']?.toString();
        final raw = m['passenger_rating'];
        if (id == null || raw == null) continue;
        final d = raw is num ? raw.toDouble() : double.tryParse(raw.toString());
        if (d != null) idToPassengerRating[id] = d;
      }
    } catch (_) {}

    return rides
        .map(
          (r) => RideModel(
            id: r.id,
            clientId: r.clientId,
            driverId: r.driverId,
            originLat: r.originLat,
            originLng: r.originLng,
            destLat: r.destLat,
            destLng: r.destLng,
            originName: r.originName,
            destName: r.destName,
            status: r.status,
            offeredPrice: r.offeredPrice,
            finalPrice: r.finalPrice,
            createdAt: r.createdAt,
            driverLat: r.driverLat,
            driverLng: r.driverLng,
            paymentMethod: r.paymentMethod,
            clientFirstName: _passengerFirstNameFromFullName(idToFullName[r.clientId]),
            clientCompletedTrips: tripCounts[r.clientId] ?? 0,
            clientPassengerRating: idToPassengerRating[r.clientId],
          ),
        )
        .toList();
  }

  String _passengerFirstNameFromFullName(String? fullName) {
    final t = (fullName ?? '').trim();
    if (t.isEmpty) return 'Pasajero';
    return t.split(RegExp(r'\s+')).first;
  }

  /// Distancia aproximada en km (Haversine), misma lógica que en el flujo del cliente.
  double _approxDistanceInKm(
    double lat1,
    double lng1,
    double lat2,
    double lng2,
  ) {
    const earthRadiusKm = 6371.0;

    final dLat = _degToRad(lat2 - lat1);
    final dLon = _degToRad(lng2 - lng1);

    final radLat1 = _degToRad(lat1);
    final radLat2 = _degToRad(lat2);

    final h = (math.sin(dLat / 2) * math.sin(dLat / 2)) +
        (math.cos(radLat1) *
            math.cos(radLat2) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2));
    final c = 2 * math.atan2(math.sqrt(h), math.sqrt(1 - h));

    return earthRadiusKm * c;
  }

  double _degToRad(double deg) => deg * (math.pi / 180.0);

  @override
  Future<Map<String, dynamic>> getTodayDriverStats(String driverId) async {
    final now = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day);

    final response = await _supabaseClient
        .from('rides')
        .select('final_price')
        .eq('driver_id', driverId)
        .eq('status', 'finished')
        .gte('created_at', startOfDay.toIso8601String());

    final list = List<Map<String, dynamic>>.from(response as List<dynamic>);
    var sum = 0.0;
    for (final row in list) {
      final fp = row['final_price'];
      if (fp != null) {
        if (fp is num) {
          sum += fp.toDouble();
        } else {
          sum += double.parse(fp.toString());
        }
      }
    }

    return {
      'earnings': sum,
      'trips': list.length,
    };
  }

  @override
  Future<List<RideEntity>> getRideHistory(String userId, String role) async {
    if (userId.isEmpty) {
      return [];
    }

    final List<dynamic> response;
    if (role == 'client') {
      response = await _supabaseClient
          .from('rides')
          .select()
          .eq('client_id', userId)
          .order('created_at', ascending: false);
    } else if (role == 'driver') {
      response = await _supabaseClient
          .from('rides')
          .select()
          .eq('driver_id', userId)
          .order('created_at', ascending: false);
    } else {
      throw ArgumentError('role debe ser client o driver');
    }

    final raw = List<Map<String, dynamic>>.from(response);
    final rides = <RideEntity>[];

    for (final row in raw) {
      try {
        rides.add(
          RideModel.fromJsonForHistory(
            Map<String, dynamic>.from(row),
          ),
        );
      } catch (_) {
        continue;
      }
    }

    return rides;
  }
}
