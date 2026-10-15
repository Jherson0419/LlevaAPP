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

/// Paso 3 (último) de la creación de cuenta: con el correo se crea la
/// cuenta de pasajero (nombre, avatar y correo) y se entra a la app.
class OnboardingEmailScreen extends StatefulWidget {
  const OnboardingEmailScreen({
    super.key,
    required this.name,
    this.email = '',
    this.phone = '',
    this.gender,
  });

  final String name;

  /// Correo de la cuenta de Google: llega ya escrito en el campo.
  final String email;

  /// Teléfono ya verificado por SMS cuando se llega desde el login por
  /// teléfono; vacío con Google (AuthBloc genera entonces un identificador a
  /// partir del correo).
  final String phone;

  /// Avatar elegido en el paso 2: 'male' | 'female' | 'other'.
  final String? gender;

  @override
  State<OnboardingEmailScreen> createState() => _OnboardingEmailScreenState();
}

class _OnboardingEmailScreenState extends State<OnboardingEmailScreen> {
  late final TextEditingController _emailCtrl =
      TextEditingController(text: widget.email.trim());
  String? _error;

  /// true al crear la cuenta: evita repetir la salida si el AuthBloc vuelve
  /// a emitir AuthAuthenticated.
  bool _finishing = false;

  @override
  void dispose() {
    _emailCtrl.dispose();
    super.dispose();
  }

  Future<void> _handleContinue() async {
    final email = _emailCtrl.text.trim();
    if (email.isEmpty || !email.contains('@') || !email.contains('.')) {
      setState(() => _error = 'Ingresa un correo válido');
      return;
    }
    setState(() => _error = null);
    await playOnboardingFeedback();
    if (!mounted) return;
    context.read<AuthBloc>().add(
          RegisterUser(
            phone: widget.phone.trim(),
            fullName: widget.name,
            email: email,
            dni: '',
            role: 'client',
            gender: widget.gender,
            birthDate: null,
          ),
        );
  }

  Future<void> _onRegistered() async {
    if (_finishing) return;
    setState(() => _finishing = true);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(AppConstants.onboardingCompleteKey, true);
    if (!mounted) return;
    final firstName = widget.name.trim().split(RegExp(r'\s+')).first;
    context.go(
      '/splash/new-user',
      extra: {
        'userName': firstName,
        'phone': '',
        if (widget.gender != null) 'gender': widget.gender,
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<AuthBloc, AuthState>(
      // Solo reacciona mientras es la ruta visible.
      listenWhen: (_, __) => ModalRoute.of(context)?.isCurrent ?? true,
      listener: (context, state) {
        if (state is AuthAuthenticated) {
          _onRegistered();
        } else if (state is AuthError && !_finishing) {
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
          icon: Icons.email_outlined,
          title: '¿Tu correo electrónico?',
          subtitle: 'Lo usaremos para tu cuenta Lleva.',
          buttonText: 'Crear cuenta',
          isLoading: state is AuthLoading || _finishing,
          onButtonPressed: _handleContinue,
          content: TextField(
            controller: _emailCtrl,
            autofocus: widget.email.trim().isEmpty,
            textAlign: TextAlign.center,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.done,
            style: TextStyle(
              color: Theme.of(context).textTheme.bodyLarge?.color,
              fontSize: 22,
            ),
            decoration: InputDecoration(
              border: const UnderlineInputBorder(),
              hintText: 'correo@ejemplo.com',
              hintStyle: const TextStyle(color: Color(0xFF666666)),
              errorText: _error,
            ),
            onSubmitted: (_) => _handleContinue(),
          ),
        );
      },
    );
  }
}
