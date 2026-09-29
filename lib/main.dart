import 'package:flutter/foundation.dart' show TargetPlatform, defaultTargetPlatform, kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:google_maps_flutter_android/google_maps_flutter_android.dart';
import 'package:google_maps_flutter_platform_interface/google_maps_flutter_platform_interface.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'core/constants/app_constants.dart';
import 'core/di/injection_container.dart' as di;
import 'core/keys/app_overlay_keys.dart';
import 'core/routes/app_router.dart';
import 'core/theme/app_theme.dart';
import 'presentation/bloc/auth/auth_bloc.dart';
import 'presentation/bloc/auth/auth_event.dart';
import 'presentation/cubit/passenger_driver_mode_cubit.dart';
import 'presentation/cubit/theme_cubit.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Antes la URL y la anon key de Supabase estaban hardcodeadas aquí (y por
  // lo tanto en el historial de git). Fallar rápido y explícito si faltan es
  // mejor que intentar inicializar Supabase con una URL vacía — ver
  // docs/setup_env.md para correr la app con --dart-define-from-file=.env.
  if (AppConstants.supabaseUrl.isEmpty || AppConstants.supabaseAnonKey.isEmpty) {
    throw StateError(
      'Faltan SUPABASE_URL/SUPABASE_ANON_KEY. Corre la app con '
      '--dart-define-from-file=.env (ver docs/setup_env.md).',
    );
  }

  // Android: useAndroidViewSurface true mejora el orden de capas pero en algunos equipos
  // deja la textura del mapa en negro si hay muchas capas encima. false suele mostrar el mapa;
  // si los paneles quedan detrás del mapa, prueba con true.
  if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
    final maps = GoogleMapsFlutterPlatform.instance;
    if (maps is GoogleMapsFlutterAndroid) {
      maps.useAndroidViewSurface = false;
    }
  }

  // Inicializar Supabase
  await Supabase.initialize(
    url: AppConstants.supabaseUrl,
    anonKey: AppConstants.supabaseAnonKey,
  );

  await di.initDI();

  // El estilo de la barra de sistema (iconos claros/oscuros) ahora se aplica
  // de forma dinámica según ThemeCubit — ver _applySystemOverlayStyle,
  // llamado dentro de LlevaApp.build() cada vez que cambia el modo.

  runApp(const LlevaApp());
}

class LlevaApp extends StatefulWidget {
  const LlevaApp({super.key});

  @override
  State<LlevaApp> createState() => _LlevaAppState();
}

class _LlevaAppState extends State<LlevaApp> {
  GoRouter? _router;

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider(create: (_) => di.sl<AuthBloc>()),
        BlocProvider(create: (_) => di.sl<PassengerDriverModeCubit>()),
        BlocProvider(create: (_) => di.sl<ThemeCubit>()),
      ],
      child: _AuthLifecycleRefresh(
        child: Builder(
          builder: (context) {
            _router ??= AppRouter.createRouter(
              context.read<AuthBloc>(),
              context.read<PassengerDriverModeCubit>(),
            );
            return BlocBuilder<ThemeCubit, ThemeMode>(
              builder: (context, themeMode) {
                _applySystemOverlayStyle(context, themeMode);
                return MaterialApp.router(
                  title: 'Lleva Trujillo',
                  debugShowCheckedModeBanner: false,
                  theme: AppTheme.lightTheme,
                  darkTheme: AppTheme.darkTheme,
                  themeMode: themeMode,
                  scaffoldMessengerKey: rootScaffoldMessengerKey,
                  routerConfig: _router!,
                );
              },
            );
          },
        ),
      ),
    );
  }
}

/// Resuelve el brillo real para [ThemeMode.system] contra el brillo de la
/// plataforma; para light/dark ya es explícito.
Brightness _resolveBrightness(BuildContext context, ThemeMode mode) {
  switch (mode) {
    case ThemeMode.light:
      return Brightness.light;
    case ThemeMode.dark:
      return Brightness.dark;
    case ThemeMode.system:
      return MediaQuery.platformBrightnessOf(context);
  }
}

/// Reemplaza el antiguo `SystemChrome.setSystemUIOverlayStyle` fijo (siempre
/// oscuro) llamado una sola vez en `main()`. Se invoca en cada rebuild
/// disparado por [ThemeCubit] para que la barra de estado/navegación siga
/// al modo elegido (o al sistema, si corresponde).
void _applySystemOverlayStyle(BuildContext context, ThemeMode mode) {
  final isDark = _resolveBrightness(context, mode) == Brightness.dark;
  SystemChrome.setSystemUIOverlayStyle(
    SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
      systemNavigationBarColor: isDark ? Colors.black : Colors.white,
      systemNavigationBarIconBrightness:
          isDark ? Brightness.light : Brightness.dark,
    ),
  );
}

/// Al volver al primer plano, sincroniza el perfil con Supabase (aprobación ERP, cambio de rol).
class _AuthLifecycleRefresh extends StatefulWidget {
  const _AuthLifecycleRefresh({required this.child});

  final Widget child;

  @override
  State<_AuthLifecycleRefresh> createState() => _AuthLifecycleRefreshState();
}

class _AuthLifecycleRefreshState extends State<_AuthLifecycleRefresh>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      context.read<AuthBloc>().add(const RefreshProfileEvent());
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
