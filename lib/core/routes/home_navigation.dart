import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../domain/entities/user.dart';
import '../../presentation/cubit/passenger_driver_mode_cubit.dart';

/// Clave de SharedPreferences: true una vez mostrada la pantalla de permisos.
const String kPermissionsShownKey = 'permissions_shown';

/// Estado de la pantalla de permisos en esta ejecución de la app.
abstract final class PermissionsSession {
  /// true si en esta ejecución ya se pasó por /permissions (se aceptó o se
  /// dijo «Ahora no»). El dashboard no vuelve a mostrar el diálogo de
  /// ubicación justo después: si falta el permiso, ofrece «Activar
  /// ubicación».
  static bool handled = false;
}

/// Va al inicio que le corresponde a [user]: panel de conductor o
/// dashboard de pasajero.
void goToHome(BuildContext context, UserEntity user) {
  final mode = context.read<PassengerDriverModeCubit>().state;
  context.go(
    shouldUseDriverHome(user, mode) ? '/dashboard' : '/client-dashboard',
  );
}

/// Tras iniciar sesión (o con la sesión ya abierta al arrancar): la primera
/// vez en este teléfono pasa por /permissions, que explica para qué se piden
/// ubicación y notificaciones; después, directo a [goToHome].
Future<void> goHomeAfterAuth(BuildContext context, UserEntity user) async {
  final prefs = await SharedPreferences.getInstance();
  if (!context.mounted) return;
  if (!(prefs.getBool(kPermissionsShownKey) ?? false)) {
    await prefs.setBool(kPermissionsShownKey, true);
    if (context.mounted) context.go('/permissions');
    return;
  }
  goToHome(context, user);
}
