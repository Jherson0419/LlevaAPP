import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../presentation/bloc/auth/auth_bloc.dart';
import '../../presentation/cubit/passenger_driver_mode_cubit.dart';

/// Notifica a [GoRouter] ante cambios de sesión o modo pasajero/conductor.
class GoRouterRefreshCombined extends ChangeNotifier {
  GoRouterRefreshCombined(this._authBloc, this._modeCubit) {
    notifyListeners();
    _subAuth = _authBloc.stream.listen((_) => notifyListeners());
    _subMode = _modeCubit.stream.listen((_) => notifyListeners());
  }

  final AuthBloc _authBloc;
  final PassengerDriverModeCubit _modeCubit;

  late final StreamSubscription<dynamic> _subAuth;
  late final StreamSubscription<PassengerDriverUi> _subMode;

  @override
  void dispose() {
    _subAuth.cancel();
    _subMode.cancel();
    super.dispose();
  }
}
