import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_theme.dart';
import '../../bloc/driver_wallet/driver_wallet_cubit.dart';
import '../../bloc/driver_wallet/driver_wallet_state.dart';

/// Cartera del conductor: saldo adeudado y movimientos (UI).
class DriverWalletScreen extends StatelessWidget {
  const DriverWalletScreen({super.key});

  static const Color _cyanBorder = Color(0xFF00D4FF);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.darkBackground,
      appBar: AppBar(
        title: const Text('Cartera'),
        backgroundColor: AppTheme.darkSurface,
        foregroundColor: AppTheme.darkText,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            BlocBuilder<DriverWalletCubit, DriverWalletState>(
              builder: (context, wallet) {
                final amountText = wallet.isLoading
                    ? '…'
                    : '- ${AppConstants.currencySymbol} ${wallet.owedBalance.toStringAsFixed(2)}';

                return Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: AppTheme.darkSurface,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: _cyanBorder, width: 1.5),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'Saldo de la cuenta',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              color: AppTheme.darkTextSecondary,
                              fontWeight: FontWeight.w500,
                            ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        amountText,
                        style: const TextStyle(
                          color: AppTheme.darkText,
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                          letterSpacing: -0.5,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Comisión pendiente con Lleva',
                        style: TextStyle(
                          color: AppTheme.darkTextSecondary.withValues(alpha: 0.9),
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 20),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Recarga con Yape/Plin próximamente'),
                                backgroundColor: AppTheme.darkSurfaceElevated,
                              ),
                            );
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.successGreen,
                            foregroundColor: Colors.black,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                            elevation: 0,
                          ),
                          child: const Text(
                            'Recargar saldo (Yape/Plin)',
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 15,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
            const SizedBox(height: 24),
            Text(
              'Movimientos recientes',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: AppTheme.darkText,
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 12),
            _movementTile(
              icon: Icons.arrow_downward,
              iconColor: Colors.red,
              title: 'Comisión Viaje #1042',
              amount: '- ${AppConstants.currencySymbol} 1.50',
            ),
            const SizedBox(height: 8),
            _movementTile(
              icon: Icons.arrow_upward,
              iconColor: Colors.green,
              title: 'Recarga Yape',
              amount: '+ ${AppConstants.currencySymbol} 20.00',
            ),
          ],
        ),
      ),
    );
  }

  Widget _movementTile({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String amount,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: AppTheme.darkSurface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Row(
        children: [
          Icon(icon, color: iconColor, size: 22),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              title,
              style: const TextStyle(
                color: AppTheme.darkText,
                fontSize: 15,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Text(
            amount,
            style: const TextStyle(
              color: AppTheme.darkText,
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
