part of 'top_drivers_cubit.dart';

abstract class TopDriversState {}

class TopDriversInitial extends TopDriversState {}

class TopDriversLoading extends TopDriversState {}

class TopDriversLoaded extends TopDriversState {
  final List<TopDriverEntity> drivers;

  TopDriversLoaded(this.drivers);
}
