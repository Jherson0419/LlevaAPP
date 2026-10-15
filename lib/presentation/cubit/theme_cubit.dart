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

  ThemeCubit._withInitial(super.initial);

  static const _prefsKey = 'theme_mode';

  /// Crea el cubit con la preferencia ya leída como estado inicial — evita
  /// el parpadeo de mostrar el modo por defecto y luego cambiarlo cuando
  /// SharedPreferences resuelve. `main()` espera este future antes de
  /// `runApp()` y reemplaza con esta instancia el registro de DI.
  static Future<ThemeCubit> create() async {
    return ThemeCubit._withInitial(await _readSavedMode());
  }

  static Future<ThemeMode> _readSavedMode() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString(_prefsKey) ?? 'light';
      switch (saved) {
        case 'dark':
          return ThemeMode.dark;
        case 'system':
          return ThemeMode.system;
        default:
          return ThemeMode.light;
      }
    } catch (_) {
      // Sin preferencia legible: se mantiene el modo por defecto (light).
      return ThemeMode.light;
    }
  }

  Future<void> _loadSavedTheme() async {
    final mode = await _readSavedMode();
    if (isClosed) return;
    if (mode != state) emit(mode);
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
