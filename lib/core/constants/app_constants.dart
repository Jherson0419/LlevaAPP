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
  
  // Google Maps API Key (también está en AndroidManifest.xml)
  static const String googleMapsApiKey = 'AIzaSyCCYG5f-y30dM9GDSsSvkLyhJraMtfjO5o';
}
