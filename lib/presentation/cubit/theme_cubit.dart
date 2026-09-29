import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Modo de tema elegido por el usuario (claro/oscuro/sistema), persistido en
/// SharedPreferences. Por defecto claro — ver [ThemeMode.light] en el
/// constructor.
class ThemeCubit extends Cubit<ThemeMode> {
  ThemeCubit() : super(ThemeMode.light) {
    // Carga en segundo plano para que registrar el cubit como singleton
    // síncrono en DI (ver injection_container.dart) igual recupere la
    // preferencia guardada poco después de construirse.
    _loadSavedTheme();
  }

  static const _prefsKey = 'theme_mode';

  /// Crea el cubit con la preferencia ya cargada antes de devolverlo — evita
  /// el parpadeo de mostrar el modo por defecto y luego cambiarlo cuando
  /// SharedPreferences resuelve. Útil si en el futuro `main()` pasa a
  /// esperar este future antes de `runApp()`; el registro actual en DI usa
  /// el constructor normal (ver Parte 3), que carga de forma asíncrona.
  static Future<ThemeCubit> create() async {
    final cubit = ThemeCubit();
    await cubit._loadSavedTheme();
    return cubit;
  }

  Future<void> _loadSavedTheme() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString(_prefsKey);
      final mode = switch (saved) {
        'light' => ThemeMode.light,
        'dark' => ThemeMode.dark,
        'system' => ThemeMode.system,
        _ => null,
      };
      if (mode != null && mode != state) {
        emit(mode);
      }
    } catch (_) {
      // Sin preferencia legible: se mantiene el modo por defecto (light).
    }
  }

  Future<void> setLight() => _setMode(ThemeMode.light);
  Future<void> setDark() => _setMode(ThemeMode.dark);
  Future<void> setSystem() => _setMode(ThemeMode.system);

  Future<void> _setMode(ThemeMode mode) async {
    emit(mode);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefsKey, mode.name);
    } catch (_) {
      // Persistencia best-effort: si falla, el modo queda igual aplicado
      // en memoria para esta sesión.
    }
  }
}
