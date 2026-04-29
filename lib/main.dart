import 'package:flutter/foundation.dart' show TargetPlatform, defaultTargetPlatform, kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:google_maps_flutter_android/google_maps_flutter_android.dart';
import 'package:google_maps_flutter_platform_interface/google_maps_flutter_platform_interface.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'core/di/injection_container.dart' as di;
import 'core/keys/app_overlay_keys.dart';
import 'core/routes/app_router.dart';
import 'core/theme/app_theme.dart';
import 'presentation/bloc/auth/auth_bloc.dart';
import 'presentation/bloc/auth/auth_event.dart';
import 'presentation/cubit/passenger_driver_mode_cubit.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

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
    url: 'https://xplbgugyeqaqsruhbsos.supabase.co',
    anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InhwbGJndWd5ZXFhcXNydWhic29zIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzM1MTc4NDgsImV4cCI6MjA4OTA5Mzg0OH0.bAVkZhj9gpHF73yqjPpMhS7K261_aMT6gqMd-6lsels',
  );

  await di.initDI();

  // Forzar modo oscuro
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: Colors.black,
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );
  
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
      ],
      child: _AuthLifecycleRefresh(
        child: Builder(
          builder: (context) {
            _router ??= AppRouter.createRouter(
              context.read<AuthBloc>(),
              context.read<PassengerDriverModeCubit>(),
            );
            return MaterialApp.router(
              title: 'Lleva Trujillo',
              debugShowCheckedModeBanner: false,
              theme: AppTheme.darkTheme,
              scaffoldMessengerKey: rootScaffoldMessengerKey,
              routerConfig: _router!,
            );
          },
        ),
      ),
    );
  }
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
