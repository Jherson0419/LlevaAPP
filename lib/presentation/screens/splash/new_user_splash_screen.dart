import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../core/routes/home_navigation.dart';
import '../../../core/theme/app_theme.dart';
import '../../bloc/auth/auth_bloc.dart';
import '../../bloc/auth/auth_state.dart';

/// Splash celebratorio (3 s) para usuarios nuevos. Tiene dos entradas:
/// - Teléfono recién verificado sin perfil: al terminar continúa el
///   onboarding en /onboarding/email (o /onboarding/name si aún no hay
///   nombre), porque el registro todavía no está completo.
/// - Registro ya completado en RegisterProfileScreen (sesión con perfil): al
///   terminar va al dashboard.
class NewUserSplashScreen extends StatefulWidget {
  const NewUserSplashScreen({
    super.key,
    required this.userName,
    required this.phone,
    required this.gender,
  });

  final String userName;
  final String phone;
  final String gender;

  @override
  State<NewUserSplashScreen> createState() => _NewUserSplashScreenState();
}

class _NewUserSplashScreenState extends State<NewUserSplashScreen>
    with TickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _circleExpand;
  late final Animation<double> _confettiFall;
  late final Animation<double> _iconBounce;
  late final Animation<double> _textFade;
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
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3000),
    );

    Animation<double> curved(double begin, double end, Curve curve) =>
        CurvedAnimation(
          parent: _controller,
          curve: Interval(begin, end, curve: curve),
        );

    _circleExpand = curved(0.0, 0.4, Curves.easeOut);
    _confettiFall = curved(0.1, 0.8, Curves.linear);
    _iconBounce = curved(0.2, 0.5, Curves.elasticOut);
    _textFade = curved(0.4, 0.7, Curves.easeOut);
    _nameFade = curved(0.55, 0.8, Curves.easeOut);
    _subtitleFade = curved(0.65, 0.9, Curves.easeOut);

    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed && mounted) {
        // Llegada desde RegisterProfileScreen: el perfil ya está creado, así
        // que no hay onboarding que continuar — directo al dashboard.
        final authState = context.read<AuthBloc>().state;
        if (authState is AuthAuthenticated) {
          goHomeAfterAuth(context, authState.user);
          return;
        }
        // Quien llega desde el login (no desde el onboarding) todavía no
        // dio su nombre ni su género: se piden antes del correo.
        if (widget.userName.trim().isEmpty) {
          context.go('/onboarding/name', extra: {'phone': widget.phone});
        } else {
          context.go(
            '/onboarding/email',
            extra: {
              'name': widget.userName,
              'phone': widget.phone,
              'gender': widget.gender,
            },
          );
        }
      }
    });
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
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
                painter: _CelebrationPainter(
                  circleExpand: _circleExpand,
                  confettiFall: _confettiFall,
                  repaint: _controller,
                ),
              ),
            ),
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ScaleTransition(
                    scale: _iconBounce,
                    child: const Icon(
                      Icons.celebration_rounded,
                      size: 64,
                      color: AppTheme.primaryBlue,
                    ),
                  ),
                  const SizedBox(height: 24),
                  FadeTransition(
                    opacity: _textFade,
                    child: const Column(
                      children: [
                        Text(
                          '¡Bienvenido a',
                          style: TextStyle(
                            color: Color(0xFF666666),
                            fontSize: 22,
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                        Text(
                          'Lleva!',
                          style: TextStyle(
                            color: AppTheme.primaryBlue,
                            fontSize: 48,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 3,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (firstName.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    FadeTransition(
                      opacity: _nameFade,
                      child: Text(
                        firstName,
                        style: const TextStyle(
                          color: Color(0xFF1A1A1A),
                          fontSize: 28,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 8),
                  FadeTransition(
                    opacity: _subtitleFade,
                    child: const Text(
                      'Estamos felices de tenerte aquí',
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
                builder: (context, _) => LinearProgressIndicator(
                  value: _controller.value,
                  minHeight: 3,
                  color: AppTheme.primaryBlue,
                  backgroundColor: const Color(0xFFE0E0E0),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ConfettiPiece {
  const _ConfettiPiece({
    required this.x,
    required this.delay,
    required this.turns,
    required this.phase,
    required this.color,
  });

  /// Posición horizontal como fracción del ancho (0–1).
  final double x;

  /// Retraso de salida como fracción de la caída (0–0.6).
  final double delay;
  final double turns;
  final double phase;

  /// `null` = pieza blanca con borde azul.
  final Color? color;
}

/// Círculo que se expande desde el centro + 20 rectángulos de confeti.
class _CelebrationPainter extends CustomPainter {
  _CelebrationPainter({
    required this.circleExpand,
    required this.confettiFall,
    required Listenable repaint,
  }) : super(repaint: repaint);

  static const List<Color?> _palette = [
    Color(0xFF0066CC),
    Color(0xFF0099FF),
    Color(0xFF00D4FF),
    null,
  ];

  // Semilla fija: el confeti cae igual en cada ejecución.
  static final List<_ConfettiPiece> _pieces = () {
    final random = math.Random(42);
    return List.generate(20, (_) {
      return _ConfettiPiece(
        x: random.nextDouble(),
        delay: random.nextDouble() * 0.6,
        turns: 1 + random.nextDouble() * 3,
        phase: random.nextDouble() * 2 * math.pi,
        color: _palette[random.nextInt(_palette.length)],
      );
    });
  }();

  final Animation<double> circleExpand;
  final Animation<double> confettiFall;

  @override
  void paint(Canvas canvas, Size size) {
    final circlePaint = Paint()
      ..color = AppTheme.primaryBlue.withValues(alpha: 0.08);
    canvas.drawCircle(
      size.center(Offset.zero),
      size.width * circleExpand.value,
      circlePaint,
    );

    final progress = confettiFall.value;
    if (progress <= 0 || progress >= 1) return;

    const rect = Rect.fromLTWH(-2, -4, 4, 8);
    final fill = Paint();
    final border = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = AppTheme.primaryBlue;

    for (final piece in _pieces) {
      // Cada pieza sale con su retraso y todas terminan fuera de pantalla.
      final t = progress * (1 + piece.delay) - piece.delay;
      if (t <= 0) continue;
      final y = -10 + t * (size.height + 20);
      canvas.save();
      canvas.translate(piece.x * size.width, y);
      canvas.rotate(piece.phase + t * piece.turns * 2 * math.pi);
      final color = piece.color;
      if (color != null) {
        canvas.drawRect(rect, fill..color = color);
      } else {
        canvas.drawRect(rect, fill..color = Colors.white);
        canvas.drawRect(rect, border);
      }
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant _CelebrationPainter oldDelegate) => false;
}
