import 'dart:math' as math;

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../domain/entities/ride_entity.dart';
import '../../../domain/repositories/driver_repository.dart';
import '../../../domain/repositories/ride_repository.dart';

/// Datos del inicio del conductor: nivel (viajes totales), resumen de hoy,
/// comisión por pagar y últimos viajes.
class DriverProfileState extends Equatable {
  const DriverProfileState({
    this.totalTrips = 0,
    this.todayTrips = 0,
    this.todayEarnings = 0.0,
    this.todayKm = 0.0,
    this.walletBalance = 0.0,
    this.rating,
    this.recentTrips = const [],
    this.isLoading = false,
  });

  /// Viajes `finished` desde siempre (define el nivel).
  final int totalTrips;
  final int todayTrips;
  final double todayEarnings;

  /// Kilómetros aproximados de los viajes de hoy (línea recta origen →
  /// destino de cada uno).
  final double todayKm;

  /// Comisión que el conductor debe a la plataforma (10 % de lo cobrado),
  /// tal como la calcula [DriverRepository.getWalletBalance].
  final double walletBalance;

  /// `profiles.driver_rating`; `null` si no hay dato.
  final double? rating;

  /// Últimos 10 viajes terminados, del más reciente al más antiguo.
  final List<RideEntity> recentTrips;
  final bool isLoading;

  DriverProfileState copyWith({
    int? totalTrips,
    int? todayTrips,
    double? todayEarnings,
    double? todayKm,
    double? walletBalance,
    double? rating,
    List<RideEntity>? recentTrips,
    bool? isLoading,
  }) {
    return DriverProfileState(
      totalTrips: totalTrips ?? this.totalTrips,
      todayTrips: todayTrips ?? this.todayTrips,
      todayEarnings: todayEarnings ?? this.todayEarnings,
      todayKm: todayKm ?? this.todayKm,
      walletBalance: walletBalance ?? this.walletBalance,
      rating: rating ?? this.rating,
      recentTrips: recentTrips ?? this.recentTrips,
      isLoading: isLoading ?? this.isLoading,
    );
  }

  @override
  List<Object?> get props => [
        totalTrips,
        todayTrips,
        todayEarnings,
        todayKm,
        walletBalance,
        rating,
        recentTrips,
        isLoading,
      ];
}

class DriverProfileCubit extends Cubit<DriverProfileState> {
  DriverProfileCubit(this._driverRepo, this._rideRepo)
      : super(const DriverProfileState());

  final DriverRepository _driverRepo;
  final RideRepository _rideRepo;

  String? _driverId;

  /// Carga (o recarga) todo en paralelo. Si una consulta falla, las demás
  /// igual se muestran.
  Future<void> load(String driverId) async {
    if (driverId.isEmpty) return;
    _driverId = driverId;
    emit(state.copyWith(isLoading: true));

    Future<T> safe<T>(Future<T> future, T fallback) =>
        future.catchError((_) => fallback);

    final results = await Future.wait<Object?>([
      safe<int>(_driverRepo.getDriverCompletedTripsCount(driverId), 0),
      safe<Map<String, dynamic>>(
        _driverRepo.getDriverTodaySummary(driverId),
        const {'trips': 0, 'earnings': 0.0},
      ),
      safe<double>(_driverRepo.getWalletBalance(driverId), 0.0),
      safe<double?>(_driverRepo.getDriverRating(driverId), null),
      safe<List<RideEntity>>(
        _rideRepo.getRideHistory(driverId, 'driver'),
        const [],
      ),
    ]);
    if (isClosed) return;

    final today = results[1] as Map<String, dynamic>;
    final history = results[4] as List<RideEntity>;
    final finished =
        history.where((r) => r.status == 'finished').toList(growable: false);

    final now = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day);
    var todayKm = 0.0;
    for (final ride in finished) {
      if (ride.createdAt.toLocal().isBefore(startOfDay)) continue;
      todayKm += _straightLineKm(ride);
    }

    emit(
      DriverProfileState(
        totalTrips: results[0] as int,
        todayTrips: (today['trips'] as num?)?.toInt() ?? 0,
        todayEarnings: (today['earnings'] as num?)?.toDouble() ?? 0.0,
        todayKm: todayKm,
        walletBalance: results[2] as double,
        rating: results[3] as double?,
        recentTrips: finished.take(10).toList(growable: false),
      ),
    );
  }

  /// Recarga con el último conductor cargado (p. ej. al terminar un viaje).
  Future<void> refresh() async {
    final id = _driverId;
    if (id != null) await load(id);
  }

  static double _straightLineKm(RideEntity ride) {
    const earthRadiusKm = 6371.0;
    double rad(double deg) => deg * math.pi / 180;
    final dLat = rad(ride.destLat - ride.originLat);
    final dLng = rad(ride.destLng - ride.originLng);
    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(rad(ride.originLat)) *
            math.cos(rad(ride.destLat)) *
            math.sin(dLng / 2) *
            math.sin(dLng / 2);
    return earthRadiusKm * 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
  }
}
