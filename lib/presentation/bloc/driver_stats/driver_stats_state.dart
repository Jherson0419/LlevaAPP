import 'package:equatable/equatable.dart';

class DriverStatsState extends Equatable {
  final double earnings;
  final int trips;
  /// Desde `profiles.driver_rating` si existe; `null` si no hay dato.
  final double? rating;
  final bool isLoading;

  const DriverStatsState({
    this.earnings = 0,
    this.trips = 0,
    this.rating,
    this.isLoading = false,
  });

  DriverStatsState copyWith({
    double? earnings,
    int? trips,
    double? rating,
    bool? isLoading,
  }) {
    return DriverStatsState(
      earnings: earnings ?? this.earnings,
      trips: trips ?? this.trips,
      rating: rating ?? this.rating,
      isLoading: isLoading ?? this.isLoading,
    );
  }

  @override
  List<Object?> get props => [earnings, trips, rating, isLoading];
}
