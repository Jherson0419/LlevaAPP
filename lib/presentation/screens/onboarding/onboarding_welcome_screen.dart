import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/utils/onboarding_feedback.dart';
import '../../widgets/onboarding/onboarding_scaffold.dart';

class OnboardingWelcomeScreen extends StatelessWidget {
  const OnboardingWelcomeScreen({super.key});

  Future<void> _handleContinue(BuildContext context) async {
    await playOnboardingFeedback();
    if (!context.mounted) return;
    context.push('/onboarding/name');
  }

  @override
  Widget build(BuildContext context) {
    return OnboardingScaffold(
      activeStep: 0,
      icon: Icons.directions_car_rounded,
      title: '¡Hola! 👋',
      subtitle: 'Bienvenido a Lleva,\nla app de transporte de Trujillo.',
      buttonText: 'Empezar',
      onButtonPressed: () => _handleContinue(context),
    );
  }
}
