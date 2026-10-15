import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../domain/entities/top_driver_entity.dart';
import '../../../domain/repositories/driver_repository.dart';

part 'top_drivers_state.dart';

class TopDriversCubit extends Cubit<TopDriversState> {
  final DriverRepository _driverRepository;

  TopDriversCubit(this._driverRepository) : super(TopDriversInitial()) {
    loadTopDrivers();
  }

  Future<void> loadTopDrivers() async {
    emit(TopDriversLoading());
    try {
      final drivers = await _driverRepository.getTopDrivers();
      // La pantalla pudo cerrarse mientras llegaba la respuesta.
      if (isClosed) return;
      emit(TopDriversLoaded(drivers));
    } catch (e) {
      if (isClosed) return;
      emit(TopDriversLoaded([]));
    }
  }
}
