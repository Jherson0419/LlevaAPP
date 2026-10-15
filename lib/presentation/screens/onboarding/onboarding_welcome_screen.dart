import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_theme.dart';
import '../../bloc/auth/auth_bloc.dart';
import '../../bloc/auth/auth_event.dart';
import '../../bloc/auth/auth_state.dart';

class OnboardingWelcomeScreen extends StatefulWidget {
  const OnboardingWelcomeScreen({super.key});

  @override
  State<OnboardingWelcomeScreen> createState() =>
      _OnboardingWelcomeScreenState();
}

class _OnboardingWelcomeScreenState extends State<OnboardingWelcomeScreen>
    with SingleTickerProviderStateMixin {
  // Bienvenida (Google) → nombre.
  static const int _totalSteps = 2;

  late final AnimationController _controller;
  late final Animation<double> _fadeIn;
  late final Animation<double> _slideUp;
  late final Animation<double> _iconScale;
  late final Animation<double> _buttonFade;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
    // Los Interval van como fracción de los 1500 ms del controller:
    // 800 ms = 0.533, 200 ms = 0.133.
    _fadeIn = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.0, 0.533, curve: Curves.easeOut),
    );
    _slideUp = Tween<double>(begin: 30, end: 0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.533, curve: Curves.easeOutCubic),
      ),
    );
    _iconScale = Tween<double>(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.133, 0.533, curve: Curves.elasticOut),
      ),
    );
    _buttonFade = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.533, 1.0, curve: Curves.easeIn),
    );
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleGoogleSignIn() {
    HapticFeedback.mediumImpact();
    SystemSound.play(SystemSoundType.click);
    context.read<AuthBloc>().add(const GoogleSignInRequested());
  }

  Widget _buildGoogleButton() {
    // Mientras Google responde el botón no admite otro toque.
    return BlocBuilder<AuthBloc, AuthState>(
      buildWhen: (p, c) => (p is AuthLoading) != (c is AuthLoading),
      builder: (context, state) {
        final loading = state is AuthLoading;
        return GestureDetector(
          onTap: loading ? null : _handleGoogleSignIn,
          child: Container(
            width: double.infinity,
            height: 56,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE0E0E0), width: 1.5),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.06),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: loading
                ? const Center(
                    child: SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppTheme.primaryBlue,
                      ),
                    ),
                  )
                : const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.g_mobiledata,
                        color: Color(0xFF4285F4),
                        size: 28,
                      ),
                      SizedBox(width: 10),
                      Text(
                        'Continuar con Google',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF1A1A1A),
                        ),
                      ),
                    ],
                  ),
          ),
        );
      },
    );
  }

  void _onAuthState(BuildContext context, AuthState state) {
    if (state is AuthAuthenticated) {
      // Ya tenía cuenta: splash de regreso.
      SharedPreferences.getInstance().then((prefs) {
        prefs.setBool(AppConstants.onboardingCompleteKey, true);
      });
      context.go(
        '/splash/returning-user',
        extra: {'userName': state.user.fullName},
      );
    } else if (state is AuthNeedsRegistration) {
      // Cuenta nueva: solo falta el nombre.
      context.push(
        '/onboarding/name',
        extra: {'name': '', 'email': state.prefilledEmail},
      );
    } else if (state is AuthError) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(state.message),
          backgroundColor: const Color(0xFFFF4444),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<AuthBloc, AuthState>(
      // Sigue montada debajo de /onboarding/name, que escucha el mismo
      // AuthBloc y navega por su cuenta al crear la cuenta.
      listenWhen: (_, __) => ModalRoute.of(context)?.isCurrent ?? true,
      listener: _onAuthState,
      child: _buildScaffold(context),
    );
  }

  Widget _buildScaffold(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFFFFF),
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverFillRemaining(
              hasScrollBody: false,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: AnimatedBuilder(
                  animation: _controller,
                  builder: (context, child) {
                    return Opacity(
                      opacity: _fadeIn.value,
                      child: Transform.translate(
                        offset: Offset(0, _slideUp.value),
                        child: child,
                      ),
                    );
                  },
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      const SizedBox(height: 80),
                      ScaleTransition(
                        scale: _iconScale,
                        child: Container(
                          width: 90,
                          height: 90,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: AppTheme.primaryBlue.withValues(alpha: 0.15),
                          ),
                          child: const Icon(
                            Icons.directions_car_rounded,
                            size: 52,
                            color: AppTheme.primaryBlue,
                          ),
                        ),
                      ),
                      const SizedBox(height: 32),
                      const Text(
                        '¡Hola!',
                        style: TextStyle(
                          color: Color(0xFF1A1A1A),
                          fontSize: 38,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Bienvenido a Lleva',
                        style: TextStyle(
                          color: AppTheme.primaryBlue,
                          fontSize: 22,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'La app de transporte de\nTrujillo, Perú.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Color(0xFF666666),
                          fontSize: 16,
                          fontWeight: FontWeight.w400,
                          height: 1.5,
                        ),
                      ),
                      const SizedBox(height: 48),
                      FadeTransition(
                        opacity: _buttonFade,
                        child: Column(
                          children: [
                            _buildGoogleButton(),
                            const SizedBox(height: 12),
                            TextButton(
                              onPressed: () => context.go('/login'),
                              child: const Text(
                                'Ya tengo cuenta',
                                style: TextStyle(
                                  color: Color(0xFF0066CC),
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Spacer(),
                      const SizedBox(height: 24),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(_totalSteps, (i) {
                          final active = i == 0;
                          return Container(
                            margin: const EdgeInsets.symmetric(horizontal: 4),
                            width: active ? 10 : 6,
                            height: active ? 10 : 6,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: active
                                  ? AppTheme.primaryBlue
                                  : const Color(0xFFE0E0E0),
                            ),
                          );
                        }),
                      ),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
