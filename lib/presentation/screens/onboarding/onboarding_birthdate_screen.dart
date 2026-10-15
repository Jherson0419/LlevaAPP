import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/age_validation.dart';
import '../../../core/utils/onboarding_feedback.dart';
import '../../bloc/auth/auth_bloc.dart';
import '../../bloc/auth/auth_event.dart';
import '../../bloc/auth/auth_state.dart';
import '../../widgets/onboarding/onboarding_scaffold.dart';

/// Último paso del onboarding: AuthBloc exige fecha de nacimiento (18+) para
/// registrar un cliente, así que se pide aquí y esta pantalla es la que
/// despacha [RegisterUser] con todo lo recolectado en los pasos anteriores.
class OnboardingBirthDateScreen extends StatefulWidget {
  const OnboardingBirthDateScreen({
    super.key,
    required this.name,
    required this.phone,
    required this.email,
    required this.dni,
    required this.gender,
  });

  final String name;
  final String phone;
  final String email;
  final String dni;
  final String gender;

  @override
  State<OnboardingBirthDateScreen> createState() =>
      _OnboardingBirthDateScreenState();
}

class _OnboardingBirthDateScreenState extends State<OnboardingBirthDateScreen> {
  static const int _minAge = 18;

  final _dateCtrl = TextEditingController();
  DateTime? _birthDate;
  String? _error;

  @override
  void dispose() {
    _dateCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final latest = AgeValidation.maxBirthDateForMinimumAge(_minAge);
    final picked = await showDatePicker(
      context: context,
      initialDate: _birthDate ?? latest,
      firstDate: DateTime(1900),
      lastDate: latest,
      helpText: 'Fecha de nacimiento',
    );
    if (picked == null || !mounted) return;
    setState(() {
      _birthDate = picked;
      _error = null;
      _dateCtrl.text = '${picked.day.toString().padLeft(2, '0')}/'
          '${picked.month.toString().padLeft(2, '0')}/${picked.year}';
    });
  }

  Future<void> _handleContinue() async {
    final birthDate = _birthDate;
    if (birthDate == null) {
      setState(() => _error = 'Selecciona tu fecha de nacimiento');
      return;
    }
    if (!AgeValidation.isAtLeastYearsOld(birthDate, _minAge)) {
      setState(
        () => _error = 'Debes tener al menos 18 años para crear una cuenta',
      );
      return;
    }
    setState(() => _error = null);
    await playOnboardingFeedback();
    if (!mounted) return;
    context.read<AuthBloc>().add(
          RegisterUser(
            phone: widget.phone,
            fullName: widget.name,
            email: widget.email,
            dni: widget.dni,
            birthDate: birthDate,
            gender: widget.gender,
            role: 'client',
          ),
        );
  }

  Future<void> _markOnboardingComplete() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(AppConstants.onboardingCompleteKey, true);
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<AuthBloc, AuthState>(
      // Las pantallas anteriores del onboarding siguen montadas debajo y
      // escuchan el mismo AuthBloc; cada una solo reacciona si es la ruta
      // visible.
      listenWhen: (_, __) => ModalRoute.of(context)?.isCurrent ?? true,
      listener: (context, state) async {
        if (state is AuthAuthenticated) {
          // La bienvenida ya se mostró antes del correo (NewUserSplashScreen);
          // el registro por onboarding siempre crea un cliente.
          await _markOnboardingComplete();
          if (!context.mounted) return;
          context.go('/client-dashboard');
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
          activeStep: 7,
          icon: Icons.cake_outlined,
          title: '¿Tu fecha de nacimiento?',
          subtitle: 'Debes ser mayor de 18 años\npara usar Lleva.',
          buttonText: 'Completar registro',
          isLoading: state is AuthLoading,
          onButtonPressed: _handleContinue,
          content: TextField(
            controller: _dateCtrl,
            readOnly: true,
            textAlign: TextAlign.center,
            onTap: _pickDate,
            style: TextStyle(
              color: Theme.of(context).textTheme.bodyLarge?.color,
              fontSize: 22,
            ),
            decoration: InputDecoration(
              border: const UnderlineInputBorder(),
              hintText: 'DD/MM/AAAA',
              hintStyle: const TextStyle(color: Color(0xFF666666)),
              errorText: _error,
            ),
          ),
        );
      },
    );
  }
}
