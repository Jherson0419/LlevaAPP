import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/constants/app_constants.dart';

class ClientWalletScreen extends StatelessWidget {
  const ClientWalletScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.darkBackground,
      appBar: AppBar(
        backgroundColor: AppTheme.darkBackground,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Billetera'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 24),
              
              // Saldo actual
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: AppTheme.darkSurface,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: AppTheme.primaryBlue.withOpacity(0.3),
                    width: 1,
                  ),
                ),
                child: Column(
                  children: [
                    Text(
                      'Saldo Disponible',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: AppTheme.darkTextSecondary,
                          ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${AppConstants.currencySymbol} 150.00',
                      style: Theme.of(context).textTheme.displayMedium?.copyWith(
                            color: AppTheme.primaryBlue,
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                  ],
                ),
              ),
              
              const SizedBox(height: 32),
              
              Text(
                'Métodos de Pago',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      color: AppTheme.darkText,
                      fontWeight: FontWeight.bold,
                    ),
              ),
              
              const SizedBox(height: 16),
              
              // Tarjeta Efectivo
              _buildPaymentCard(
                context,
                title: 'Efectivo',
                icon: Icons.money,
                color: AppTheme.successGreen,
                isDefault: true,
              ),
              
              const SizedBox(height: 12),
              
              // Tarjeta Yape
              _buildPaymentCard(
                context,
                title: 'Yape',
                icon: Icons.account_balance_wallet,
                color: const Color(0xFF00D4FF),
                subtitle: 'Conectado',
              ),
              
              const SizedBox(height: 12),
              
              // Tarjeta Plin
              _buildPaymentCard(
                context,
                title: 'Plin',
                icon: Icons.account_balance_wallet,
                color: const Color(0xFF00D4FF),
                subtitle: 'Conectado',
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPaymentCard(
    BuildContext context, {
    required String title,
    required IconData icon,
    required Color color,
    String? subtitle,
    bool isDefault = false,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.darkSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDefault ? color : AppTheme.darkSurfaceElevated,
          width: isDefault ? 2 : 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: color.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              icon,
              color: color,
              size: 28,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      title,
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                            color: AppTheme.darkText,
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                    if (isDefault) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: color,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text(
                          'Por defecto',
                          style: TextStyle(
                            color: Colors.black,
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: AppTheme.darkTextSecondary,
                        ),
                  ),
                ],
              ],
            ),
          ),
          Icon(
            Icons.chevron_right,
            color: AppTheme.darkTextSecondary,
          ),
        ],
      ),
    );
  }
}
