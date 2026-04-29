import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../domain/repositories/ride_repository.dart';
import 'ride_history_state.dart';

class RideHistoryCubit extends Cubit<RideHistoryState> {
  RideHistoryCubit({required RideRepository rideRepository})
      : _rideRepository = rideRepository,
        super(const RideHistoryInitial());

  final RideRepository _rideRepository;

  Future<void> fetchHistory(String userId, String role) async {
    emit(const RideHistoryLoading());
    try {
      final rides = await _rideRepository.getRideHistory(userId, role);
      emit(RideHistoryLoaded(rides));
    } catch (e) {
      emit(RideHistoryError(e.toString()));
    }
  }
}
