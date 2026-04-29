import 'package:supabase_flutter/supabase_flutter.dart';

import '../../domain/repositories/driver_repository.dart';

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
}
