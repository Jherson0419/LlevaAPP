import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';

/// Layout compartido por las 4 pantallas de onboarding (bienvenida, nombre,
/// teléfono, código): puntos de progreso, ícono, título/subtítulo, un slot
/// opcional de contenido (campo de texto, fila de teléfono, casillas OTP) y
/// el botón principal.
class OnboardingScaffold extends StatelessWidget {
  const OnboardingScaffold({
    super.key,
    required this.activeStep,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.buttonText,
    required this.onButtonPressed,
    this.content,
    this.isLoading = false,
  });

  static const int totalSteps = 4;

  final int activeStep;
  final IconData icon;
  final String title;
  final String subtitle;
  final Widget? content;
  final String buttonText;
  final VoidCallback? onButtonPressed;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.darkBackground,
      appBar: AppBar(
        backgroundColor: AppTheme.darkBackground,
        elevation: 0,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(totalSteps, (i) {
                  final active = i == activeStep;
                  return Container(
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    width: active ? 10 : 6,
                    height: active ? 10 : 6,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: active ? AppTheme.primaryBlue : Colors.grey[700],
                    ),
                  );
                }),
              ),
              const SizedBox(height: 40),
              Icon(icon, size: 72, color: AppTheme.primaryBlue),
              const SizedBox(height: 24),
              Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                subtitle,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Color(0xFFB0B0B0),
                  fontSize: 16,
                ),
              ),
              if (content != null) ...[
                const SizedBox(height: 32),
                content!,
              ],
              const SizedBox(height: 40),
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: isLoading ? null : onButtonPressed,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryBlue,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor:
                        AppTheme.primaryBlue.withValues(alpha: 0.5),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 0,
                  ),
                  child: isLoading
                      ? const SizedBox(
                          height: 22,
                          width: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor:
                                AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : Text(
                          buttonText,
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}
