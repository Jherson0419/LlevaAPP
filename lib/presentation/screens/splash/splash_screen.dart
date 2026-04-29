import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../bloc/auth/auth_bloc.dart';
import '../../bloc/auth/auth_state.dart';
import '../../bloc/auth/auth_event.dart';
import '../../cubit/passenger_driver_mode_cubit.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  bool _requested = false;

  @override
  Widget build(BuildContext context) {
    if (!_requested) {
      _requested = true;
      context.read<AuthBloc>().add(const CheckAuthStatus());
    }

    return BlocListener<AuthBloc, AuthState>(
      listener: (context, state) {
        if (state is AuthAuthenticated) {
          final mode = context.read<PassengerDriverModeCubit>().state;
          if (shouldUseDriverHome(state.user, mode)) {
            context.go('/dashboard');
          } else {
            context.go('/client-dashboard');
          }
        } else if (state is AuthInitial || state is AuthError) {
          context.go('/login');
        }
      },
      child: Scaffold(
        backgroundColor: AppTheme.darkBackground,
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CustomPaint(
                size: const Size(120, 120),
                painter: LlevaLogoPainter(),
              ),
              const SizedBox(height: 32),
              Text(
                'Lleva Trujillo',
                style: Theme.of(context).textTheme.displaySmall?.copyWith(
                      color: AppTheme.primaryBlue,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 2,
                    ),
              ),
              const SizedBox(height: 24),
              const SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor:
                      AlwaysStoppedAnimation<Color>(AppTheme.primaryBlue),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Custom Painter para el logo de Lleva (L con flecha)
class LlevaLogoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppTheme.primaryBlue
      ..style = PaintingStyle.stroke
      ..strokeWidth = 8
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final path = Path();
    
    // Dibujar la L
    path.moveTo(size.width * 0.2, size.height * 0.2);
    path.lineTo(size.width * 0.2, size.height * 0.8);
    path.lineTo(size.width * 0.6, size.height * 0.8);
    
    // Flecha que fluye desde la L
    path.moveTo(size.width * 0.6, size.height * 0.8);
    path.lineTo(size.width * 0.8, size.height * 0.6);
    path.moveTo(size.width * 0.8, size.height * 0.6);
    path.lineTo(size.width * 0.75, size.height * 0.55);
    path.moveTo(size.width * 0.8, size.height * 0.6);
    path.lineTo(size.width * 0.75, size.height * 0.65);
    
    canvas.drawPath(path, paint);
    
    // Efecto de brillo
    final glowPaint = Paint()
      ..color = AppTheme.primaryBlue.withOpacity(0.3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 12
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
    
    canvas.drawPath(path, glowPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
