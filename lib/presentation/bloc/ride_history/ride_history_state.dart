import 'package:equatable/equatable.dart';

import '../../../domain/entities/ride_entity.dart';

abstract class RideHistoryState extends Equatable {
  const RideHistoryState();

  @override
  List<Object?> get props => [];
}

class RideHistoryInitial extends RideHistoryState {
  const RideHistoryInitial();
}

class RideHistoryLoading extends RideHistoryState {
  const RideHistoryLoading();
}

class RideHistoryLoaded extends RideHistoryState {
  const RideHistoryLoaded(this.rides);

  final List<RideEntity> rides;

  @override
  List<Object?> get props => [rides];
}

class RideHistoryError extends RideHistoryState {
  const RideHistoryError(this.message);

  final String message;

  @override
  List<Object?> get props => [message];
}
