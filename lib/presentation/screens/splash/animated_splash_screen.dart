import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/routes/home_navigation.dart';
import '../../../core/theme/app_theme.dart';
import '../../bloc/auth/auth_bloc.dart';
import '../../bloc/auth/auth_event.dart';
import '../../bloc/auth/auth_state.dart';

/// Splash animado (logo + nombre + subtítulo). En paralelo pide
/// [CheckAuthStatus]; navega recién cuando pasó el tiempo mínimo en pantalla
/// Y la sesión ya se resolvió.
class AnimatedSplashScreen extends StatefulWidget {
  const AnimatedSplashScreen({super.key});

  @override
  State<AnimatedSplashScreen> createState() => _AnimatedSplashScreenState();
}

class _AnimatedSplashScreenState extends State<AnimatedSplashScreen>
    with SingleTickerProviderStateMixin {
  static const Color _blue = AppTheme.primaryBlue;
  static const Color _dotGray = Color(0xFFCCCCCC);

  /// Tiempo mínimo que el splash permanece visible. La animación de entrada
  /// dura 2 s; el resto del tiempo el contenido queda fijo.
  static const Duration _splashDuration = Duration(seconds: 5);

  late final AnimationController _controller;
  Timer? _splashTimer;
  late final Animation<double> _logoScale;
  late final Animation<double> _logoFade;
  late final Animation<double> _textFade;
  late final Animation<double> _textSlide;
  late final Animation<double> _subtitleFade;

  bool _navigated = false;
  bool _splashTimeDone = false;
  bool _authResolved = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    );
    _logoScale = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.0, 0.5, curve: Curves.elasticOut),
    );
    _logoFade = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.0, 0.4, curve: Curves.easeOut),
    );
    _textFade = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.4, 0.7, curve: Curves.easeOut),
    );
    _textSlide = Tween<double>(begin: 20.0, end: 0.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.4, 0.7, curve: Curves.easeOutCubic),
      ),
    );
    _subtitleFade = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.6, 1.0, curve: Curves.easeOut),
    );
    _controller.forward();
    _splashTimer = Timer(_splashDuration, () {
      _splashTimeDone = true;
      _tryNavigate();
    });
    context.read<AuthBloc>().add(const CheckAuthStatus());
  }

  /// Navega solo cuando pasó [_splashDuration] y CheckAuthStatus ya emitió su
  /// resultado; antes de eso el estado es AuthInitial/AuthLoading y decidir
  /// con él mandaría a /login a un usuario con sesión válida.
  void _tryNavigate() {
    if (!mounted || _navigated || !_splashTimeDone || !_authResolved) return;
    final state = context.read<AuthBloc>().state;
    if (state is AuthAuthenticated) {
      _navigated = true;
      goHomeAfterAuth(context, state.user);
    } else {
      // Sin sesión (también en una instalación nueva) siempre al login; la
      // creación de cuenta se abre desde ahí («Crear cuenta»).
      _navigated = true;
      context.go('/login');
    }
  }

  @override
  void dispose() {
    _splashTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<AuthBloc, AuthState>(
      listener: (context, state) {
        if (state is AuthLoading) return;
        _authResolved = true;
        _tryNavigate();
      },
      child: PopScope(
        canPop: false,
        child: Scaffold(
          backgroundColor: Colors.white,
          body: Stack(
            children: [
              // Precarga del SDK de Google Maps: un mapa invisible de 1×1
              // obliga a cargar el motor nativo mientras se ve el splash, y
              // el primer mapa real (dashboard, búsqueda) abre más rápido.
              const Positioned(
                left: 0,
                top: 0,
                width: 1,
                height: 1,
                child: _MapsWarmUp(),
              ),
              SizedBox.expand(
                child: Column(
                  children: [
                    const Spacer(flex: 3),
                    FadeTransition(
                      opacity: _logoFade,
                      child: ScaleTransition(
                        scale: _logoScale,
                        child: Container(
                          width: 120,
                          height: 120,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: _blue.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(32),
                          ),
                          child: Image.asset(
                            'assets/icons/lleva_logo.png',
                            width: 72,
                            height: 72,
                            // Mientras no exista el asset se dibuja el logo en Z.
                            errorBuilder: (_, __, ___) => const CustomPaint(
                              size: Size(72, 72),
                              painter: _ZLogoPainter(),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    FadeTransition(
                      opacity: _textFade,
                      child: AnimatedBuilder(
                        animation: _textSlide,
                        builder: (context, child) => Transform.translate(
                          offset: Offset(0, _textSlide.value),
                          child: child,
                        ),
                        child: const Text(
                          'Lleva',
                          style: TextStyle(
                            color: _blue,
                            fontSize: 42,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 4,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    FadeTransition(
                      opacity: _subtitleFade,
                      child: const Text(
                        'Tu taxi de confianza en Trujillo',
                        style: TextStyle(
                          color: Color(0xFF999999),
                          fontSize: 14,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                    ),
                    const Spacer(flex: 2),
                    const Padding(
                      padding: EdgeInsets.only(bottom: 48),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          _Dot(color: _blue),
                          SizedBox(width: 6),
                          _Dot(color: _dotGray),
                          SizedBox(width: 6),
                          _Dot(color: _dotGray),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Dot extends StatelessWidget {
  const _Dot({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 6,
      height: 6,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }
}

/// Logo de respaldo: trazo en Z con un punto hueco en cada extremo.
class _ZLogoPainter extends CustomPainter {
  const _ZLogoPainter();

  @override
  void paint(Canvas canvas, Size size) {
    const inset = 12.0;
    const start = Offset(inset, inset);
    final end = Offset(size.width - inset, size.height - inset);

    final line = Paint()
      ..color = AppTheme.primaryBlue
      ..style = PaintingStyle.stroke
      ..strokeWidth = 8
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final path = Path()
      ..moveTo(start.dx, start.dy)
      ..lineTo(end.dx, start.dy)
      ..lineTo(start.dx, end.dy)
      ..lineTo(end.dx, end.dy);
    canvas.drawPath(path, line);

    final dotFill = Paint()..color = AppTheme.primaryBlue;
    final dotHole = Paint()..color = Colors.white;
    for (final center in [start, end]) {
      canvas.drawCircle(center, 9, dotFill);
      canvas.drawCircle(center, 4, dotHole);
    }
  }

  @override
  bool shouldRepaint(covariant _ZLogoPainter oldDelegate) => false;
}

/// Mapa invisible que solo sirve para que el SDK nativo de Google Maps se
/// cargue durante el splash. No dibuja nada visible ni recibe gestos.
class _MapsWarmUp extends StatelessWidget {
  const _MapsWarmUp();

  @override
  Widget build(BuildContext context) {
    return const IgnorePointer(
      child: Opacity(
        opacity: 0,
        child: GoogleMap(
          initialCameraPosition: CameraPosition(
            target: LatLng(
              AppConstants.trujilloLatitude,
              AppConstants.trujilloLongitude,
            ),
            zoom: 10,
          ),
          zoomControlsEnabled: false,
          mapToolbarEnabled: false,
          compassEnabled: false,
          myLocationButtonEnabled: false,
        ),
      ),
    );
  }
}
