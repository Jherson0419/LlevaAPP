import 'dart:async' show unawaited;

import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform, kDebugMode, kIsWeb;
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:google_maps_flutter_android/google_maps_flutter_android.dart';
import 'package:google_maps_flutter_platform_interface/google_maps_flutter_platform_interface.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'core/constants/app_constants.dart';
import 'core/di/injection_container.dart' as di;
import 'core/keys/app_overlay_keys.dart';
import 'core/services/notification_service.dart';
import 'core/routes/app_router.dart';
import 'core/theme/app_theme.dart';
import 'presentation/bloc/auth/auth_bloc.dart';
import 'presentation/bloc/auth/auth_event.dart';
import 'presentation/cubit/passenger_driver_mode_cubit.dart';
import 'presentation/cubit/theme_cubit.dart';

/// Mensajes FCM con la app en segundo plano o cerrada. Las notificaciones
/// (con `notification`) ya las muestra el sistema; esto solo deja registro.
/// Corre en un isolate aparte: tiene que ser una función de nivel superior.
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  debugPrint('Background message: ${message.notification?.title}');
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Firebase (push). Sin google-services.json / GoogleService-Info.plist
  // falla: la app sigue sin notificaciones push en vez de no arrancar.
  // Con timeout: si se cuelga (config nativa rota), se sigue sin push igual
  // que cuando falla.
  try {
    await Firebase.initializeApp().timeout(const Duration(seconds: 10));
  } catch (e) {
    debugPrint('Firebase no configurado: $e');
  }

  if (Firebase.apps.isNotEmpty) {
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
  }

  // Solo en debug: token FCM en consola para probar envíos. Sin await, para
  // no retrasar el arranque (getToken va por red y en iOS espera a APNs).
  if (kDebugMode && Firebase.apps.isNotEmpty) {
    unawaited(
      FirebaseMessaging.instance.getToken().then(
            (token) => debugPrint('FCM Token: $token'),
            onError: (Object e) => debugPrint('FCM Error: $e'),
          ),
    );
  }

  // Qué llegó por --dart-define en este modo (enmascarado).
  debugPrint('ENV SUPABASE_URL: ${_mask(AppConstants.supabaseUrl)}');
  debugPrint('ENV SUPABASE_ANON_KEY: ${_mask(AppConstants.supabaseAnonKey)}');
  debugPrint('ENV GOOGLE_MAPS_KEY: ${_mask(AppConstants.googleMapsApiKey)}');
  debugPrint(
    'ENV GOOGLE_WEB_CLIENT_ID: ${_mask(AppConstants.googleWebClientId)}',
  );

  // Android: useAndroidViewSurface true mejora el orden de capas pero en algunos equipos
  // deja la textura del mapa en negro si hay muchas capas encima. false suele mostrar el mapa;
  // si los paneles quedan detrás del mapa, prueba con true.
  if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
    final maps = GoogleMapsFlutterPlatform.instance;
    if (maps is GoogleMapsFlutterAndroid) {
      maps.useAndroidViewSurface = false;
    }
  }

  // Inicializar Supabase. Sin guard de variables vacías: si faltan, falla
  // aquí (o en el timeout) y se muestra el error en pantalla.
  try {
    await Supabase.initialize(
      url: AppConstants.supabaseUrl,
      anonKey: AppConstants.supabaseAnonKey,
    ).timeout(const Duration(seconds: 10));
  } catch (e) {
    final message = 'No se pudo inicializar Supabase: $e';
    debugPrint('ERROR: $message');
    runApp(_StartupErrorApp(message));
    return;
  }

  await di.initDI();

  // Sin await: pedir permiso y obtener el token FCM no debe retrasar el
  // primer frame.
  unawaited(di.sl<NotificationService>().initialize());

  // Se lee la preferencia de tema antes de runApp() para que el primer frame
  // ya salga con el modo guardado (sin parpadeo claro→oscuro); la instancia
  // ya cargada reemplaza al registro por defecto de initDI().
  final themeCubit = await ThemeCubit.create();
  di.sl.unregister<ThemeCubit>();
  di.sl.registerLazySingleton<ThemeCubit>(() => themeCubit);

  // El estilo de la barra de sistema (iconos claros/oscuros) ahora se aplica
  // de forma dinámica según ThemeCubit — ver _applySystemOverlayStyle,
  // llamado dentro de LlevaApp.build() cada vez que cambia el modo.

  runApp(const LlevaApp());
}

/// Para los logs de arranque: muestra el largo y los extremos, nunca el
/// valor completo.
String _mask(String value) {
  if (value.isEmpty) return '(vacío)';
  if (value.length <= 8) return '*** (${value.length} chars)';
  return '${value.substring(0, 4)}…${value.substring(value.length - 4)} '
      '(${value.length} chars)';
}

/// Pantalla mínima cuando la app no puede arrancar (variables de entorno
/// faltantes o Supabase sin inicializar), en lugar del splash congelado.
class _StartupErrorApp extends StatelessWidget {
  const _StartupErrorApp(this.message);

  final String message;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark(),
      home: Scaffold(
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(message, textAlign: TextAlign.center),
            ),
          ),
        ),
      ),
    );
  }
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
