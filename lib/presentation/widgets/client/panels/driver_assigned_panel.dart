import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../bloc/client_ride/client_ride_bloc.dart';

class DriverAssignedPanel extends StatelessWidget {
  const DriverAssignedPanel({
    super.key,
    required this.state,
  });

  final ClientRideState state;

  @override
  Widget build(BuildContext context) {
    final ride = state.activeRide!;
    final agreedPrice = ride.finalPrice ?? ride.offeredPrice;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          height: 4,
          width: 48,
          margin: const EdgeInsets.only(bottom: 16),
          decoration: BoxDecoration(
            color: Colors.white24,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: const Color(0xFF0D3D2E),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: AppTheme.successGreen.withValues(alpha: 0.45),
              width: 1.5,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.check_circle_rounded,
                    color: AppTheme.successGreen,
                    size: 28,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      '¡Tu conductor va en camino!',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                'Tarifa acordada: S/ ${agreedPrice.toStringAsFixed(2)}',
                style: const TextStyle(
                  color: AppTheme.darkTextSecondary,
                  fontSize: 16,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        OutlinedButton(
          onPressed: () {
            // Navegación / detalle: pendiente de producto
          },
          style: OutlinedButton.styleFrom(
            foregroundColor: AppTheme.primaryBlue,
            side: const BorderSide(color: AppTheme.primaryBlue, width: 1.5),
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
          child: const Text(
            'Ver detalles',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}
