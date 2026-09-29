import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';

/// Pantalla de bienvenida animada mostrada una sola vez tras un login o
/// registro exitoso (no en el flujo de reanudación de sesión, ver
/// SplashScreen). Se autodescarta llamando a [onComplete] al terminar la
/// animación de 2800ms.
class WelcomeSplashScreen extends StatefulWidget {
  final String userName;
  final bool isNewUser;
  final VoidCallback onComplete;

  const WelcomeSplashScreen({
    super.key,
    required this.userName,
    required this.isNewUser,
    required this.onComplete,
  });

  @override
  State<WelcomeSplashScreen> createState() => _WelcomeSplashScreenState();
}

class _WelcomeSplashScreenState extends State<WelcomeSplashScreen>
    with TickerProviderStateMixin {
  static const Duration _totalDuration = Duration(milliseconds: 2800);

  late final AnimationController _controller;
  late final Animation<double> _fadeIn;
  late final Animation<double> _slideUp;
  late final Animation<double> _logoScale;
  late final Animation<double> _nameFade;
  late final Animation<double> _subtitleFade;

  String get _firstName {
    final trimmed = widget.userName.trim();
    if (trimmed.isEmpty) return trimmed;
    return trimmed.split(' ').first;
  }

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: _totalDuration);

    Interval intervalOf(int startMs, int endMs, Curve curve) => Interval(
          startMs / _totalDuration.inMilliseconds,
          endMs / _totalDuration.inMilliseconds,
          curve: curve,
        );

    _fadeIn = CurvedAnimation(
      parent: _controller,
      curve: intervalOf(0, 600, Curves.easeOut),
    );

    _slideUp = Tween<double>(begin: 40, end: 0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: intervalOf(0, 600, Curves.easeOutCubic),
      ),
    );

    _logoScale = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: intervalOf(600, 1000, Curves.elasticOut),
      ),
    );

    _nameFade = CurvedAnimation(
      parent: _controller,
      curve: intervalOf(500, 900, Curves.easeOut),
    );

    _subtitleFade = CurvedAnimation(
      parent: _controller,
      curve: intervalOf(700, 1100, Curves.easeOut),
    );

    startAnimation();
  }

  void startAnimation() {
    _controller.forward();
    _controller.addStatusListener(_handleStatusChange);
  }

  void _handleStatusChange(AnimationStatus status) {
    if (status == AnimationStatus.completed) {
      widget.onComplete();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final subtitle = widget.isNewUser
        ? 'Tu cuenta ha sido creada exitosamente'
        : 'Nos alegra verte de nuevo';

    return Scaffold(
      backgroundColor: AppTheme.darkBackground,
      body: Center(
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
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedBuilder(
                animation: _controller,
                builder: (context, _) => Transform.scale(
                  scale: _logoScale.value,
                  child: Container(
                    width: 60,
                    height: 60,
                    decoration: const BoxDecoration(
                      color: AppTheme.primaryBlue,
                      shape: BoxShape.circle,
                    ),
                    alignment: Alignment.center,
                    child: const Text(
                      'L',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              AnimatedBuilder(
                animation: _controller,
                builder: (context, _) => Opacity(
                  opacity: _nameFade.value,
                  child: Column(
                    children: [
                      const Text(
                        '¡Bienvenido,',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 28,
                          fontWeight: FontWeight.w300,
                        ),
                      ),
                      Text(
                        _firstName,
                        style: const TextStyle(
                          color: AppTheme.primaryBlue,
                          fontSize: 36,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              AnimatedBuilder(
                animation: _controller,
                builder: (context, _) => Opacity(
                  opacity: _subtitleFade.value,
                  child: Text(
                    subtitle,
                    style: const TextStyle(
                      color: Color(0xFFB0B0B0),
                      fontSize: 16,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 40),
              SizedBox(
                width: 200,
                height: 3,
                child: AnimatedBuilder(
                  animation: _controller,
                  builder: (context, _) => ClipRRect(
                    borderRadius: BorderRadius.circular(2),
                    child: LinearProgressIndicator(
                      value: _controller.value,
                      backgroundColor: Colors.white12,
                      color: AppTheme.primaryBlue,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
