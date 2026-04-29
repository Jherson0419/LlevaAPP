import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../domain/repositories/driver_repository.dart';
import '../../../domain/repositories/ride_repository.dart';
import 'driver_stats_state.dart';

class DriverStatsCubit extends Cubit<DriverStatsState> {
  DriverStatsCubit({
    required RideRepository rideRepository,
    required DriverRepository driverRepository,
  })  : _rideRepository = rideRepository,
        _driverRepository = driverRepository,
        super(const DriverStatsState());

  final RideRepository _rideRepository;
  final DriverRepository _driverRepository;
  String? _cachedDriverId;

  Future<void> loadTodayStats(String driverId) async {
    if (driverId.isEmpty) return;
    _cachedDriverId = driverId;
    emit(
      DriverStatsState(
        earnings: state.earnings,
        trips: state.trips,
        rating: state.rating,
        isLoading: true,
      ),
    );
    try {
      final results = await Future.wait([
        _rideRepository.getTodayDriverStats(driverId),
        _driverRepository.getDriverRating(driverId),
      ]);
      final map = results[0] as Map<String, dynamic>;
      final rating = results[1] as double?;
      final earnings = (map['earnings'] as num).toDouble();
      final trips = map['trips'] as int;
      emit(
        DriverStatsState(
          earnings: earnings,
          trips: trips,
          rating: rating,
          isLoading: false,
        ),
      );
    } catch (_) {
      emit(
        DriverStatsState(
          earnings: state.earnings,
          trips: state.trips,
          rating: state.rating,
          isLoading: false,
        ),
      );
    }
  }

  Future<void> refresh() async {
    final id = _cachedDriverId;
    if (id == null || id.isEmpty) return;
    await loadTodayStats(id);
  }
}
