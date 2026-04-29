import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/di/injection_container.dart' as di;
import '../../../core/theme/app_theme.dart';
import '../../../domain/entities/ride_entity.dart';
import '../../bloc/ride_history/ride_history_cubit.dart';
import '../../bloc/ride_history/ride_history_state.dart';

class RideHistoryScreen extends StatelessWidget {
  const RideHistoryScreen({
    super.key,
    required this.userId,
    required this.role,
  });

  final String userId;
  final String role;

  static const Color _priceColor = Color(0xFF00D4FF);

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => di.sl<RideHistoryCubit>()..fetchHistory(userId, role),
      child: Scaffold(
        backgroundColor: AppTheme.darkBackground,
        appBar: AppBar(
          title: const Text('Mis Viajes'),
          backgroundColor: AppTheme.darkSurface,
          foregroundColor: AppTheme.darkText,
          elevation: 0,
        ),
        body: BlocBuilder<RideHistoryCubit, RideHistoryState>(
          builder: (context, state) {
            if (state is RideHistoryLoading || state is RideHistoryInitial) {
              return const Center(
                child: CircularProgressIndicator(
                  color: AppTheme.primaryBlue,
                ),
              );
            }

            if (state is RideHistoryError) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.error_outline,
                        color: AppTheme.errorRed,
                        size: 48,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        state.message,
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: AppTheme.darkText),
                      ),
                      const SizedBox(height: 24),
                      TextButton(
                        onPressed: () => context
                            .read<RideHistoryCubit>()
                            .fetchHistory(userId, role),
                        child: const Text('Reintentar'),
                      ),
                    ],
                  ),
                ),
              );
            }

            if (state is! RideHistoryLoaded) {
              return const SizedBox.shrink();
            }

            final rides = state.rides;
            if (rides.isEmpty) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.directions_car_outlined,
                        size: 80,
                        color: AppTheme.darkTextSecondary.withValues(alpha: 0.6),
                      ),
                      const SizedBox(height: 24),
                      Text(
                        'Aún no tienes viajes',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              color: AppTheme.darkText,
                              fontWeight: FontWeight.w600,
                            ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Cuando completes un viaje, aparecerá aquí.',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: AppTheme.darkTextSecondary,
                            ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              );
            }

            final dateFmt = DateFormat.yMMMd('es').add_Hm();

            return ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: rides.length,
              itemBuilder: (context, index) {
                return _RideHistoryCard(
                  ride: rides[index],
                  dateFormat: dateFmt,
                  priceColor: _priceColor,
                );
              },
            );
          },
        ),
      ),
    );
  }
}

class _RideHistoryCard extends StatelessWidget {
  const _RideHistoryCard({
    required this.ride,
    required this.dateFormat,
    required this.priceColor,
  });

  final RideEntity ride;
  final DateFormat dateFormat;
  final Color priceColor;

  String _statusLabel(String status) {
    switch (status) {
      case 'finished':
        return 'Completado';
      case 'cancelled':
        return 'Cancelado';
      case 'ongoing':
        return 'En curso';
      case 'accepted':
      case 'arrived':
        return 'En progreso';
      case 'searching':
        return 'Buscando';
      case 'negotiating':
        return 'Negociando';
      default:
        return status.isEmpty ? '—' : status;
    }
  }

  IconData _statusIcon(String status) {
    switch (status) {
      case 'finished':
        return Icons.check_circle_outline;
      case 'cancelled':
        return Icons.cancel_outlined;
      default:
        return Icons.local_taxi_outlined;
    }
  }

  @override
  Widget build(BuildContext context) {
    final price = ride.finalPrice ?? ride.offeredPrice;
    final priceText = price > 0
        ? '${AppConstants.currencySymbol} ${price.toStringAsFixed(2)}'
        : '—';

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      color: AppTheme.darkSurface,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    dateFormat.format(ride.createdAt.toLocal()),
                    style: const TextStyle(
                      color: AppTheme.darkTextSecondary,
                      fontSize: 13,
                    ),
                  ),
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      _statusIcon(ride.status),
                      size: 16,
                      color: AppTheme.darkTextSecondary,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      _statusLabel(ride.status),
                      style: const TextStyle(
                        color: AppTheme.darkTextSecondary,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.trip_origin,
                  size: 18,
                  color: AppTheme.primaryBlue,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    ride.originName,
                    style: const TextStyle(
                      color: AppTheme.darkText,
                      fontSize: 15,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.place_outlined,
                  size: 18,
                  color: AppTheme.successGreen,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    ride.destName,
                    style: const TextStyle(
                      color: AppTheme.darkText,
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              priceText,
              style: TextStyle(
                color: priceColor,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
