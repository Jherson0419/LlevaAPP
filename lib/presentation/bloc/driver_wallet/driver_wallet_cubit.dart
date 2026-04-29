import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../domain/repositories/driver_repository.dart';
import 'driver_wallet_state.dart';

class DriverWalletCubit extends Cubit<DriverWalletState> {
  DriverWalletCubit({required DriverRepository driverRepository})
      : _driverRepository = driverRepository,
        super(const DriverWalletState());

  final DriverRepository _driverRepository;
  String? _cachedDriverId;

  Future<void> loadWallet(String driverId) async {
    if (driverId.isEmpty) {
      _cachedDriverId = null;
      emit(const DriverWalletState(owedBalance: 0, isLoading: false));
      return;
    }

    _cachedDriverId = driverId;
    emit(state.copyWith(isLoading: true));
    try {
      final balance = await _driverRepository.getWalletBalance(driverId);
      emit(DriverWalletState(owedBalance: balance, isLoading: false));
    } catch (_) {
      emit(state.copyWith(isLoading: false));
    }
  }

  Future<void> refresh() async {
    final id = _cachedDriverId;
    if (id == null || id.isEmpty) return;
    await loadWallet(id);
  }
}
