import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/onboarding_feedback.dart';
import '../../bloc/auth/auth_bloc.dart';
import '../../bloc/auth/auth_event.dart';
import '../../bloc/auth/auth_state.dart';
import '../../widgets/onboarding/onboarding_scaffold.dart';
import '../../widgets/otp_code_box.dart';

class OnboardingCodeScreen extends StatefulWidget {
  const OnboardingCodeScreen({
    super.key,
    required this.name,
    required this.phone,
    required this.gender,
  });

  final String name;
  final String phone;
  final String gender;

  @override
  State<OnboardingCodeScreen> createState() => _OnboardingCodeScreenState();
}

class _OnboardingCodeScreenState extends State<OnboardingCodeScreen> {
  static const _codeLength = AppConstants.smsCodeLength;

  final List<TextEditingController> _controllers = List.generate(
    _codeLength,
    (_) => TextEditingController(),
  );
  final List<FocusNode> _focusNodes = List.generate(
    _codeLength,
    (_) => FocusNode(),
  );

  String get _code => _controllers.map((c) => c.text).join();

  @override
  void dispose() {
    for (final c in _controllers) {
      c.dispose();
    }
    for (final f in _focusNodes) {
      f.dispose();
    }
    super.dispose();
  }

  void _clearCode() {
    for (final c in _controllers) {
      c.clear();
    }
    _focusNodes.first.requestFocus();
  }

  void _onChanged(int index, String value) {
    if (value.isNotEmpty) {
      if (index < _codeLength - 1) {
        _focusNodes[index + 1].requestFocus();
      } else {
        _focusNodes[index].unfocus();
        if (_code.length == _codeLength) {
          _handleVerify();
        }
      }
    }
  }

  Future<void> _handleVerify() async {
    if (_code.length != _codeLength) return;
    await playOnboardingFeedback();
    if (!mounted) return;
    // widget.phone ya es el local de 9 dígitos que se usó para pedir el
    // código (ver OnboardingPhoneScreen) — igual que en el resto de la app,
    // AuthBloc antepone +51 internamente solo para Supabase Auth.
    context.read<AuthBloc>().add(
          OtpVerified(phone: widget.phone, code: _code),
        );
  }

  Future<void> _markOnboardingComplete() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(AppConstants.onboardingCompleteKey, true);
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<AuthBloc, AuthState>(
      // Esta pantalla sigue montada debajo de correo/DNI; sin este filtro
      // reaccionaría también al AuthAuthenticated/AuthError del registro
      // final (ver OnboardingDniScreen).
      listenWhen: (_, __) => ModalRoute.of(context)?.isCurrent ?? true,
      listener: (context, state) async {
        if (state is AuthAuthenticated) {
          // Teléfono con perfil existente: es un login, no un registro.
          await _markOnboardingComplete();
          if (!context.mounted) return;
          context.go(
            '/splash/returning-user',
            extra: {'userName': state.user.fullName},
          );
        } else if (state is AuthNeedsRegistration) {
          // El splash de bienvenida continúa luego a /onboarding/email.
          context.go(
            '/splash/new-user',
            extra: {
              'userName': widget.name,
              'phone': widget.phone,
              'gender': widget.gender,
            },
          );
        } else if (state is AuthError) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(state.message),
              backgroundColor: AppTheme.errorRed,
            ),
          );
          _clearCode();
        }
      },
      builder: (context, state) {
        return OnboardingScaffold(
          activeStep: 4,
          icon: Icons.mark_chat_read_outlined,
          title: 'Código de verificación',
          subtitle: 'Ingresa el código que enviamos\nal +51 ${widget.phone}',
          buttonText: 'Verificar',
          isLoading: state is AuthLoading,
          onButtonPressed: _handleVerify,
          content: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: List.generate(_codeLength, (index) {
                  return OtpCodeBox(
                    controller: _controllers[index],
                    focusNode: _focusNodes[index],
                    width: 45,
                    height: 56,
                    fontSize: 22,
                    onChanged: (value) => _onChanged(index, value),
                  );
                }),
              ),
              const SizedBox(height: 12),
              const Text(
                'Ingresa 000000 para continuar',
                style: TextStyle(
                  color: AppTheme.primaryBlue,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
