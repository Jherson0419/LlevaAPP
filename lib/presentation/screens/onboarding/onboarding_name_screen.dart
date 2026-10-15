import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/utils/onboarding_feedback.dart';
import '../../widgets/onboarding/onboarding_scaffold.dart';

/// Paso 1 del onboarding: el nombre. Sigue en la foto de perfil
/// (/onboarding/avatar) y la cuenta se crea en el paso del correo.
class OnboardingNameScreen extends StatefulWidget {
  const OnboardingNameScreen({
    super.key,
    this.email = '',
    this.verifiedPhone,
  });

  /// Correo de la cuenta de Google con la que se inició sesión; vacío si se
  /// llegó por el login por teléfono (se pide en el paso del correo).
  final String email;

  /// Teléfono ya verificado por SMS (llegada desde el login por teléfono).
  final String? verifiedPhone;

  @override
  State<OnboardingNameScreen> createState() => _OnboardingNameScreenState();
}

class _OnboardingNameScreenState extends State<OnboardingNameScreen> {
  static const int _minNameLength = 2;

  final _nameCtrl = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  Future<void> _handleContinue() async {
    final name = _nameCtrl.text.trim();
    if (name.length < _minNameLength) {
      setState(() => _error = 'Ingresa tu nombre');
      return;
    }
    setState(() => _error = null);
    await playOnboardingFeedback();
    if (!mounted) return;
    final verifiedPhone = widget.verifiedPhone?.trim() ?? '';
    context.push(
      '/onboarding/avatar',
      extra: {
        'name': name,
        'email': widget.email.trim(),
        if (verifiedPhone.isNotEmpty) 'phone': verifiedPhone,
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return OnboardingScaffold(
      activeStep: 0,
      icon: Icons.person_outline_rounded,
      title: '¿Cómo te llamas?',
      subtitle: 'Cuéntanos tu nombre para\npersonalizar tu experiencia.',
      buttonText: 'Continuar',
      onButtonPressed: _handleContinue,
      content: TextField(
        controller: _nameCtrl,
        autofocus: true,
        textAlign: TextAlign.center,
        textCapitalization: TextCapitalization.words,
        textInputAction: TextInputAction.done,
        style: TextStyle(
          color: Theme.of(context).textTheme.bodyLarge?.color,
          fontSize: 22,
        ),
        decoration: InputDecoration(
          border: const UnderlineInputBorder(),
          hintText: 'Tu nombre',
          hintStyle: const TextStyle(color: Color(0xFF666666)),
          errorText: _error,
        ),
        onSubmitted: (_) => _handleContinue(),
      ),
    );
  }
}
