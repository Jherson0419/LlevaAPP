class AppConstants {
  // Coordenadas de Trujillo, Perú
  static const double trujilloLatitude = -8.1116;
  static const double trujilloLongitude = -79.0288;

  // Configuración de mapas
  static const double defaultZoom = 13.0;

  // Tiempos de animación
  static const Duration splashDuration = Duration(seconds: 2);
  static const Duration pageTransitionDuration = Duration(milliseconds: 300);

  // Código SMS
  static const int smsCodeLength = 6;
  static const Duration smsResendCooldown = Duration(seconds: 60);

  // Moneda
  static const String currencySymbol = 'S/';

  // Backend ERP (configurar con --dart-define=ERP_API_BASE_URL=https://...)
  static const String erpApiBaseUrl = String.fromEnvironment(
    'ERP_API_BASE_URL',
    defaultValue: '',
  );

  // Google Maps API Key — usada por PlacesService (Directions/Places REST) y
  // por el SDK nativo de Android vía manifestPlaceholder (ver
  // android/app/build.gradle.kts y AndroidManifest.xml). Antes estaba
  // hardcodeada aquí Y repetida en AndroidManifest.xml/places_service.dart;
  // ahora hay una sola fuente de verdad pasada por --dart-define
  // (ver docs/setup_env.md). Ya está expuesta en el historial de git —
  // hay que rotarla en Google Cloud Console, no solo mover el valor.
  static const String googleMapsApiKey = String.fromEnvironment(
    'GOOGLE_MAPS_KEY',
    defaultValue: '',
  );

  // Supabase (antes hardcodeados en main.dart). Ver docs/setup_env.md.
  static const String supabaseUrl = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: '',
  );
  static const String supabaseAnonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue: '',
  );

  // Google Sign-In — Web Client ID (OAuth 2.0), desde Google Cloud Console →
  // Credentials → "Web client" (el mismo que se registra en Supabase →
  // Authentication → Providers → Google). No es un secreto (los client IDs
  // OAuth son públicos por diseño); igual se pasa por --dart-define, como el
  // resto de esta clase, para no fijar en código un valor que cambia por
  // entorno (dev/staging/prod pueden usar proyectos de Google distintos) —
  // ver AuthBloc._onGoogleSignIn.
  static const String googleWebClientId = String.fromEnvironment(
    'GOOGLE_WEB_CLIENT_ID',
    defaultValue: '',
  );

  // Clave de SharedPreferences que marca si el usuario ya pasó por el flujo
  // de onboarding — compartida entre SplashScreen (lectura) y
  // OnboardingCodeScreen (escritura) para evitar un typo entre archivos.
  static const String onboardingCompleteKey = 'onboarding_complete';
}
