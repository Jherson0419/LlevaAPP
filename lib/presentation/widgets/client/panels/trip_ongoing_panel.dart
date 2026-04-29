import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../bloc/client_ride/client_ride_bloc.dart';

class TripOngoingPanel extends StatelessWidget {
  const TripOngoingPanel({
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
        Text(
          'En camino a tu destino...',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 12),
        Text(
          'Tarifa acordada: S/ ${price.toStringAsFixed(2)}',
          style: const TextStyle(
            color: AppTheme.darkTextSecondary,
            fontSize: 15,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 12),
        Text(
          'La ruta se muestra en el mapa',
          style: TextStyle(
            color: AppTheme.primaryBlue.withValues(alpha: 0.85),
            fontSize: 13,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}
