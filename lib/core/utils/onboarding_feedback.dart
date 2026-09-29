import 'package:flutter/services.dart';

/// Feedback táctil + sonoro al pulsar los botones del flujo de onboarding.
/// Usa únicamente APIs nativas de Flutter (sin dependencias nuevas ni
/// llamadas de red): un golpe háptico medio y el sonido de click del
/// sistema — no puede fallar por falta de conexión ni por un asset ausente.
Future<void> playOnboardingFeedback() async {
  await HapticFeedback.mediumImpact();
  await SystemSound.play(SystemSoundType.click);
}
