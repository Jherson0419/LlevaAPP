import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../core/routes/home_navigation.dart';
import '../../../core/theme/app_theme.dart';
import '../../bloc/auth/auth_bloc.dart';
import '../../bloc/auth/auth_state.dart';

/// Splash cálido (2,5 s) para un usuario con perfil existente que acaba de
/// iniciar sesión. Al terminar va a su dashboard (misma decisión que
/// AnimatedSplashScreen).
class ReturningUserSplashScreen extends StatefulWidget {
  const ReturningUserSplashScreen({super.key, required this.userName});

  final String userName;

  @override
  State<ReturningUserSplashScreen> createState() =>
      _ReturningUserSplashScreenState();
}

class _ReturningUserSplashScreenState extends State<ReturningUserSplashScreen>
    with TickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _waveRise;
  late final Animation<double> _iconFade;
  late final Animation<double> _iconScale;
  late final Animation<double> _greetingFade;
  late final Animation<double> _nameFade;
  late final Animation<double> _nameScale;
  late final Animation<double> _subtitleFade;

  String get _firstName {
    final trimmed = widget.userName.trim();
    if (trimmed.isEmpty) return trimmed;
    return trimmed.split(' ').first;
  }

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2500),
    );

    Animation<double> curved(double begin, double end, Curve curve) =>
        CurvedAnimation(
          parent: _controller,
          curve: Interval(begin, end, curve: curve),
        );

    _waveRise = curved(0.0, 0.5, Curves.easeOut);
    _iconFade = curved(0.1, 0.4, Curves.easeOut);
    _iconScale = Tween<double>(begin: 0.7, end: 1.0).animate(_iconFade);
    _greetingFade = curved(0.3, 0.6, Curves.easeOut);
    // elasticOut se pasa de 1.0, así que solo se usa para la escala; la
    // opacidad del nombre va con easeOut en el mismo intervalo.
    _nameFade = curved(0.4, 0.7, Curves.easeOut);
    _nameScale = Tween<double>(begin: 0.5, end: 1.0)
        .animate(curved(0.4, 0.7, Curves.elasticOut));
    _subtitleFade = curved(0.55, 0.8, Curves.easeOut);

    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _navigate();
      }
    });
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _navigate() {
    if (!mounted) return;
    final authState = context.read<AuthBloc>().state;
    if (authState is AuthAuthenticated) {
      goHomeAfterAuth(context, authState.user);
    } else {
      context.go('/login');
    }
  }

  @override
  Widget build(BuildContext context) {
    final firstName = _firstName;
    return Scaffold(
      backgroundColor: Colors.white,
      body: PopScope(
        canPop: false,
        child: Stack(
          children: [
            Positioned.fill(
              child: CustomPaint(
                painter: _RisingWavePainter(progress: _waveRise),
              ),
            ),
            Align(
              alignment: const Alignment(0, -0.35),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  FadeTransition(
                    opacity: _iconFade,
                    child: ScaleTransition(
                      scale: _iconScale,
                      child: const Icon(
                        Icons.directions_car_rounded,
                        size: 72,
                        color: AppTheme.primaryBlue,
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  FadeTransition(
                    opacity: _greetingFade,
                    child: const Text(
                      '¡Hola de nuevo,',
                      style: TextStyle(
                        color: Color(0xFF666666),
                        fontSize: 20,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ),
                  if (firstName.isNotEmpty)
                    FadeTransition(
                      opacity: _nameFade,
                      child: ScaleTransition(
                        scale: _nameScale,
                        child: Text(
                          firstName,
                          style: const TextStyle(
                            color: AppTheme.primaryBlue,
                            fontSize: 44,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  const SizedBox(height: 12),
                  FadeTransition(
                    opacity: _subtitleFade,
                    child: const Text(
                      '¿Listo para tu próximo viaje?',
                      style: TextStyle(
                        color: Color(0xFF999999),
                        fontSize: 15,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              height: 3,
              child: AnimatedBuilder(
                animation: _controller,
                // La barra queda sobre la ola azul: en azul no se vería, así
                // que aquí va en blanco.
                builder: (context, _) => LinearProgressIndicator(
                  value: _controller.value,
                  minHeight: 3,
                  color: Colors.white,
                  backgroundColor: Colors.white24,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Ola azul que sube desde debajo de la pantalla hasta cubrir el 40% inferior.
class _RisingWavePainter extends CustomPainter {
  _RisingWavePainter({required this.progress}) : super(repaint: progress);

  final Animation<double> progress;

  @override
  void paint(Canvas canvas, Size size) {
    final p = progress.value;
    if (p <= 0) return;

    // Borde superior de la ola: fuera de pantalla con p=0, al 60% con p=1.
    final crest = size.height * 0.08;
    final top = size.height + crest - (size.height * 0.40 + crest) * p;

    final path = Path()
      ..moveTo(0, top)
      ..cubicTo(
        size.width * 0.25,
        top - crest,
        size.width * 0.55,
        top + crest,
        size.width,
        top - crest * 0.4,
      )
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();

    canvas.drawPath(path, Paint()..color = AppTheme.primaryBlue);
  }

  @override
  bool shouldRepaint(covariant _RisingWavePainter oldDelegate) => false;
}
