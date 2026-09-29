import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/utils/onboarding_feedback.dart';
import '../../widgets/onboarding/onboarding_scaffold.dart';

class OnboardingNameScreen extends StatefulWidget {
  const OnboardingNameScreen({super.key});

  @override
  State<OnboardingNameScreen> createState() => _OnboardingNameScreenState();
}

class _OnboardingNameScreenState extends State<OnboardingNameScreen> {
  final _nameCtrl = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  Future<void> _handleContinue() async {
    final name = _nameCtrl.text.trim();
    if (name.length < 2) {
      setState(
        () => _error = 'Ingresa un nombre válido (mínimo 2 caracteres)',
      );
      return;
    }
    setState(() => _error = null);
    await playOnboardingFeedback();
    if (!mounted) return;
    context.push('/onboarding/phone', extra: {'name': name});
  }

  @override
  Widget build(BuildContext context) {
    return OnboardingScaffold(
      activeStep: 1,
      icon: Icons.person_outline_rounded,
      title: '¿Cómo te llamas?',
      subtitle: 'Dinos tu nombre para personalizar\ntu experiencia.',
      buttonText: 'Continuar',
      onButtonPressed: _handleContinue,
      content: TextField(
        controller: _nameCtrl,
        autofocus: true,
        textAlign: TextAlign.center,
        textCapitalization: TextCapitalization.words,
        textInputAction: TextInputAction.done,
        style: const TextStyle(color: Colors.white, fontSize: 22),
        decoration: InputDecoration(
          border: const UnderlineInputBorder(),
          hintText: '¿Tu nombre?',
          hintStyle: const TextStyle(color: Color(0xFF666666)),
          errorText: _error,
        ),
        onSubmitted: (_) => _handleContinue(),
      ),
    );
  }
}
