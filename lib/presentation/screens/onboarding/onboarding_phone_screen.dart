import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/onboarding_feedback.dart';
import '../../bloc/auth/auth_bloc.dart';
import '../../bloc/auth/auth_event.dart';
import '../../bloc/auth/auth_state.dart';
import '../../widgets/onboarding/onboarding_scaffold.dart';

class OnboardingPhoneScreen extends StatefulWidget {
  const OnboardingPhoneScreen({super.key, required this.name});

  final String name;

  @override
  State<OnboardingPhoneScreen> createState() => _OnboardingPhoneScreenState();
}

class _OnboardingPhoneScreenState extends State<OnboardingPhoneScreen> {
  final _phoneCtrl = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _phoneCtrl.dispose();
    super.dispose();
  }

  Future<void> _handleContinue() async {
    final digits = _phoneCtrl.text.trim();
    if (digits.length != 9) {
      setState(
        () => _error = 'Ingresa un número de celular válido (9 dígitos)',
      );
      return;
    }
    setState(() => _error = null);
    await playOnboardingFeedback();
    if (!mounted) return;
    // Teléfono local de 9 dígitos, sin prefijo — igual que en login_screen.dart
    // y sms_verification_screen.dart. AuthBloc antepone +51 internamente
    // (_toE164) solo para la llamada a Supabase Auth; el resto del flujo
    // (profiles.phone, RegisterUser, etc.) espera el número sin prefijo.
    context.read<AuthBloc>().add(SendOtpRequested(digits));
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<AuthBloc, AuthState>(
      listener: (context, state) {
        if (state is AuthOtpSent) {
          context.push(
            '/onboarding/code',
            extra: {'name': widget.name, 'phone': _phoneCtrl.text.trim()},
          );
        } else if (state is AuthError) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(state.message),
              backgroundColor: AppTheme.errorRed,
            ),
          );
        }
      },
      builder: (context, state) {
        return OnboardingScaffold(
          activeStep: 2,
          icon: Icons.phone_android_rounded,
          title: 'Tu número de WhatsApp',
          subtitle: 'Te enviaremos un código de verificación\npor WhatsApp.',
          buttonText: 'Enviar código',
          isLoading: state is AuthLoading,
          onButtonPressed: _handleContinue,
          content: Row(
            children: [
              const Text(
                '+51',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: _phoneCtrl,
                  autofocus: true,
                  keyboardType: TextInputType.number,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(9),
                  ],
                  style: const TextStyle(color: Colors.white, fontSize: 22),
                  textInputAction: TextInputAction.done,
                  decoration: InputDecoration(
                    border: const UnderlineInputBorder(),
                    hintText: '999 999 999',
                    hintStyle: const TextStyle(color: Color(0xFF666666)),
                    errorText: _error,
                  ),
                  onSubmitted: (_) => _handleContinue(),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
