import 'package:supabase_flutter/supabase_flutter.dart';

import '../../domain/entities/top_driver_entity.dart';
import '../../domain/repositories/driver_repository.dart';
import '../models/top_driver_model.dart';

class DriverRepositoryImpl implements DriverRepository {
  DriverRepositoryImpl({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  static const double _commissionRate = 0.10;

  @override
  Future<double> getWalletBalance(String driverId) async {
    if (driverId.isEmpty) return 0;

    final response = await _client
        .from('rides')
        .select('final_price')
        .eq('driver_id', driverId)
        .eq('status', 'finished');

    final list = List<Map<String, dynamic>>.from(response);
    var sum = 0.0;
    for (final row in list) {
      final fp = row['final_price'];
      if (fp == null) continue;
      if (fp is num) {
        sum += fp.toDouble();
      } else {
        final p = double.tryParse(fp.toString());
        if (p != null) sum += p;
      }
    }

    final owed = sum * _commissionRate;
    return double.parse(owed.toStringAsFixed(2));
  }

  @override
  Future<double?> getDriverRating(String driverId) async {
    if (driverId.isEmpty) return null;

    try {
      final row = await _client
          .from('profiles')
          .select('driver_rating')
          .eq('id', driverId)
          .maybeSingle();

      if (row == null) return null;
      final r = row['driver_rating'];
      if (r == null) return null;
      if (r is num) return r.toDouble();
      return double.tryParse(r.toString());
    } catch (_) {
      return null;
    }
  }

  @override
  Future<List<TopDriverEntity>> getTopDrivers() async {
    try {
      final response = await _client.from('top_drivers').select().limit(5);
      return (response as List)
          .map(
            (e) => TopDriverModel.fromJson(Map<String, dynamic>.from(e as Map)),
          )
          .toList();
    } catch (_) {
      return [];
    }
  }

  @override
  Future<int> getDriverCompletedTripsCount(String driverId) async {
    if (driverId.isEmpty) return 0;
    try {
      final response = await _client
          .from('rides')
          .select('id')
          .eq('driver_id', driverId)
          .eq('status', 'finished');
      return (response as List).length;
    } catch (_) {
      return 0;
    }
  }

  @override
  Future<Map<String, dynamic>> getDriverTodaySummary(String driverId) async {
    const empty = {'trips': 0, 'earnings': 0.0};
    if (driverId.isEmpty) return empty;
    try {
      final now = DateTime.now();
      // Inicio del día en hora local, expresado en UTC para compararlo con
      // `created_at` (timestamptz).
      final todayStart =
          DateTime(now.year, now.month, now.day).toUtc().toIso8601String();
      final response = await _client
          .from('rides')
          .select('id, final_price, offered_price')
          .eq('driver_id', driverId)
          .eq('status', 'finished')
          .gte('created_at', todayStart);
      final list = response as List;
      var earnings = 0.0;
      for (final row in list) {
        final map = row as Map;
        final price = map['final_price'] ?? map['offered_price'];
        if (price is num) {
          earnings += price.toDouble();
        } else if (price != null) {
          earnings += double.tryParse(price.toString()) ?? 0;
        }
      }
      return {'trips': list.length, 'earnings': earnings};
    } catch (_) {
      return empty;
    }
  }
}
