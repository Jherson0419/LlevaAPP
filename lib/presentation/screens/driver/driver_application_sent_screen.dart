import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';

/// Confirmación mostrada tras enviar la solicitud de conductor. Se
/// autodescarta a los 3500ms navegando a `/client-dashboard` — NO a
/// `/dashboard`: la cuenta queda con `isApproved = false`, así que el
/// redirect de [AppRouter] mostrará [DriverApprovalScreen] la próxima vez
/// que el usuario intente entrar al panel de conductor. Ir directo a
/// `/dashboard` aquí saltaría ese gate de aprobación.
class DriverApplicationSentScreen extends StatefulWidget {
  const DriverApplicationSentScreen({super.key});

  @override
  State<DriverApplicationSentScreen> createState() =>
      _DriverApplicationSentScreenState();
}

class _DriverApplicationSentScreenState
    extends State<DriverApplicationSentScreen> with TickerProviderStateMixin {
  static const Duration _totalDuration = Duration(milliseconds: 3500);

  late final AnimationController _controller;
  late final Animation<double> _fadeIn;
  late final Animation<double> _iconScale;
  late final Animation<double> _textFade;
  late final Animation<double> _textSlide;

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
      curve: intervalOf(0, 800, Curves.easeOut),
    );

    _iconScale = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: intervalOf(0, 600, Curves.elasticOut),
      ),
    );

    _textFade = CurvedAnimation(
      parent: _controller,
      curve: intervalOf(800, 1200, Curves.easeOutCubic),
    );

    _textSlide = Tween<double>(begin: 20, end: 0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: intervalOf(800, 1200, Curves.easeOutCubic),
      ),
    );

    _controller.forward();
    _controller.addStatusListener(_handleStatusChange);
  }

  void _handleStatusChange(AnimationStatus status) {
    if (status == AnimationStatus.completed && mounted) {
      context.go('/client-dashboard');
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: AppTheme.darkBackground,
        body: Center(
          child: AnimatedBuilder(
            animation: _controller,
            builder: (context, child) {
              return Opacity(
                opacity: _fadeIn.value,
                child: child,
              );
            },
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                AnimatedBuilder(
                  animation: _controller,
                  builder: (context, _) => Transform.scale(
                    scale: _iconScale.value,
                    child: Container(
                      width: 90,
                      height: 90,
                      decoration: BoxDecoration(
                        color: AppTheme.primaryBlue.withValues(alpha: 0.2),
                        shape: BoxShape.circle,
                      ),
                      alignment: Alignment.center,
                      child: const Icon(
                        Icons.directions_car_rounded,
                        size: 48,
                        color: AppTheme.primaryBlue,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 32),
                AnimatedBuilder(
                  animation: _controller,
                  builder: (context, _) => Opacity(
                    opacity: _textFade.value,
                    child: Transform.translate(
                      offset: Offset(0, _textSlide.value),
                      child: const Column(
                        children: [
                          Text(
                            '¡Solicitud enviada!',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 26,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          SizedBox(height: 12),
                          Text(
                            'Bienvenido a la familia Lleva',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: AppTheme.primaryBlue,
                              fontSize: 18,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          SizedBox(height: 16),
                          Text(
                            'Tu solicitud está en revisión.\n'
                            'En breve recibirás una respuesta.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Color(0xFFB0B0B0),
                              fontSize: 15,
                              fontWeight: FontWeight.w400,
                              height: 1.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 48),
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
      ),
    );
  }
}
