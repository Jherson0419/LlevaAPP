import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../bloc/client_ride/client_ride_bloc.dart';
import '../client_payment_method_ui.dart';

class SearchingDriverPanel extends StatelessWidget {
  const SearchingDriverPanel({
    super.key,
    required this.state,
  });

  final ClientRideState state;

  @override
  Widget build(BuildContext context) {
    final rideBloc = context.read<ClientRideBloc>();
    final suggested = state.suggestedPrice;

    double currentPrice() {
      return state.offeredPrice > 0
          ? state.offeredPrice
          : (suggested ?? 5);
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Center(
          child: Container(
            height: 4,
            width: 48,
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              color: Colors.white24,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ),
        const Text(
          'Buscando conductores cercanos..',
          style: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 20),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFF141414),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white24),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Material(
                color: AppTheme.darkSurface,
                borderRadius: BorderRadius.circular(14),
                child: IconButton(
                  constraints: const BoxConstraints(
                    minWidth: 48,
                    minHeight: 48,
                  ),
                  padding: EdgeInsets.zero,
                  onPressed: () {
                    final cur = currentPrice();
                    final next = (cur - 0.5).clamp(1.0, 99999.0);
                    rideBloc.add(PriceChanged(next));
                  },
                  icon: const Icon(
                    Icons.remove,
                    color: AppTheme.primaryBlue,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'S/ ${currentPrice().toStringAsFixed(2)}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Material(
                color: AppTheme.darkSurface,
                borderRadius: BorderRadius.circular(14),
                child: IconButton(
                  constraints: const BoxConstraints(
                    minWidth: 48,
                    minHeight: 48,
                  ),
                  padding: EdgeInsets.zero,
                  onPressed: () {
                    final cur = currentPrice();
                    final next = (cur + 0.5).clamp(1.0, 99999.0);
                    rideBloc.add(PriceChanged(next));
                  },
                  icon: const Icon(Icons.add, color: AppTheme.primaryBlue),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Material(
          color: const Color(0xFF141414),
          borderRadius: BorderRadius.circular(16),
          child: InkWell(
            onTap: () => showClientPaymentMethodPicker(context),
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(
                children: [
                  ClientPaymentMethodImage(
                    method: state.paymentMethod,
                    size: 32,
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Método de pago',
                          style: TextStyle(
                            color: Colors.white54,
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          clientPaymentMethodLabel(state.paymentMethod),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Icon(
                    Icons.chevron_right,
                    color: Colors.white38,
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 20),
        ElevatedButton(
          onPressed: () {
            context.read<ClientRideBloc>().add(const CancelRide());
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.errorRed,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            elevation: 0,
          ),
          child: const Text(
            'Cancelar solicitud',
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
