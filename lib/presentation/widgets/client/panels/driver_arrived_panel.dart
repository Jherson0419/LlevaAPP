import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../bloc/client_ride/client_ride_bloc.dart';

class DriverArrivedPanel extends StatelessWidget {
  const DriverArrivedPanel({
    super.key,
    required this.state,
  });

  final ClientRideState state;

  @override
  Widget build(BuildContext context) {
    final ride = state.activeRide!;
    final price = ride.finalPrice ?? ride.offeredPrice;

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
            color: const Color(0xFF0A1A24),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: AppTheme.primaryBlue.withValues(alpha: 0.65),
              width: 2,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '¡Tu conductor llegó! Búscalo afuera',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 12),
              Text(
                'Tarifa: S/ ${price.toStringAsFixed(2)}',
                style: const TextStyle(
                  color: AppTheme.darkTextSecondary,
                  fontSize: 15,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
