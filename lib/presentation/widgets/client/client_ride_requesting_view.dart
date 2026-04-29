import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';

class ClientRideRequestingView extends StatelessWidget {
  const ClientRideRequestingView({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24.0),
      decoration: const BoxDecoration(
        color: AppTheme.darkSurface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle del draggable sheet
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.only(bottom: 24),
            decoration: BoxDecoration(
              color: AppTheme.darkTextSecondary.withOpacity(0.3),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          
          // Indicador de carga
          const CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primaryBlue),
            strokeWidth: 3,
          ),
          const SizedBox(height: 24),
          
          // Texto
          Text(
            'Buscando conductores cercanos...',
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  color: AppTheme.darkText,
                  fontWeight: FontWeight.w600,
                ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            'Por favor espera',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppTheme.darkTextSecondary,
                ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
