import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../../core/utils/onboarding_feedback.dart';
import '../../widgets/onboarding/onboarding_scaffold.dart';

class OnboardingDniScreen extends StatefulWidget {
  const OnboardingDniScreen({
    super.key,
    required this.name,
    required this.phone,
    required this.email,
    required this.gender,
  });

  final String name;
  final String phone;
  final String email;
  final String gender;

  @override
  State<OnboardingDniScreen> createState() => _OnboardingDniScreenState();
}

class _OnboardingDniScreenState extends State<OnboardingDniScreen> {
  final _dniCtrl = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _dniCtrl.dispose();
    super.dispose();
  }

  Future<void> _handleContinue() async {
    final dni = _dniCtrl.text.trim();
    if (dni.length != 8) {
      setState(() => _error = 'El DNI debe tener 8 dígitos');
      return;
    }
    setState(() => _error = null);
    await playOnboardingFeedback();
    if (!mounted) return;
    context.push(
      '/onboarding/birthdate',
      extra: {
        'name': widget.name,
        'phone': widget.phone,
        'email': widget.email,
        'dni': dni,
        'gender': widget.gender,
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return OnboardingScaffold(
      activeStep: 6,
      icon: Icons.badge_outlined,
      title: '¿Tu número de DNI?',
      subtitle: 'Necesitamos tu DNI para\nverificar tu identidad.',
      buttonText: 'Continuar',
      onButtonPressed: _handleContinue,
      content: TextField(
        controller: _dniCtrl,
        autofocus: true,
        textAlign: TextAlign.center,
        keyboardType: TextInputType.number,
        inputFormatters: [
          FilteringTextInputFormatter.digitsOnly,
          LengthLimitingTextInputFormatter(8),
        ],
        textInputAction: TextInputAction.done,
        style: TextStyle(
          color: Theme.of(context).textTheme.bodyLarge?.color,
          fontSize: 22,
        ),
        decoration: InputDecoration(
          border: const UnderlineInputBorder(),
          hintText: '12345678',
          hintStyle: const TextStyle(color: Color(0xFF666666)),
          errorText: _error,
        ),
        onSubmitted: (_) => _handleContinue(),
      ),
    );
  }
}
