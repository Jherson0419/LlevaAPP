import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../domain/entities/user.dart';

/// Interfaz pasajero (mapa cliente) vs conductor (mapa conductor).
/// Solo aplica a perfiles que pueden alternar (conductor aprobado).
enum PassengerDriverUi { passenger, driver }

/// Persiste la última elección para el próximo arranque.
class PassengerDriverModeCubit extends Cubit<PassengerDriverUi> {
  PassengerDriverModeCubit() : super(PassengerDriverUi.passenger) {
    _restore();
  }

  static const _prefsKey = 'passenger_driver_ui_mode';

  Future<void> _restore() async {
    try {
      final p = await SharedPreferences.getInstance();
      if (p.getString(_prefsKey) == 'driver') {
        emit(PassengerDriverUi.driver);
      }
    } catch (_) {}
  }

  Future<void> setDriverMode() async {
    emit(PassengerDriverUi.driver);
    try {
      final p = await SharedPreferences.getInstance();
      await p.setString(_prefsKey, 'driver');
    } catch (_) {}
  }

  Future<void> setPassengerMode() async {
    emit(PassengerDriverUi.passenger);
    try {
      final p = await SharedPreferences.getInstance();
      await p.setString(_prefsKey, 'passenger');
    } catch (_) {}
  }
}

// --- Reglas compartidas con [AppRouter] y [SplashScreen] ---

/// Puede alternar entre pedir taxi y trabajar (conductor aprobado con datos).
bool userCanTogglePassengerDriver(UserEntity u) {
  if (!u.isApproved || u.isBanned) return false;
  if (u.role == 'driver') return true;
  final hasVehicle = u.carPlate != null && u.carPlate!.trim().isNotEmpty;
  return u.role == 'client' && hasVehicle && u.isDriverApplicant;
}

/// Si true, mostrar el panel de conductor; si false, el de cliente.
bool shouldUseDriverHome(UserEntity u, PassengerDriverUi mode) {
  if (u.role == 'driver') {
    if (u.isBanned) return true;
    if (!u.isApproved) return true;
    if (userCanTogglePassengerDriver(u)) {
      return mode == PassengerDriverUi.driver;
    }
    return true;
  }
  if (userCanTogglePassengerDriver(u)) {
    return mode == PassengerDriverUi.driver;
  }
  return false;
}
