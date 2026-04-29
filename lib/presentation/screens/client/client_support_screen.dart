import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';

/// Soporte para pasajeros.
class ClientSupportScreen extends StatelessWidget {
  const ClientSupportScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.darkBackground,
      appBar: AppBar(
        title: const Text('Soporte'),
        backgroundColor: AppTheme.darkSurface,
        foregroundColor: AppTheme.darkText,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Card(
            color: AppTheme.darkSurface,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
            ),
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 20,
                vertical: 12,
              ),
              leading: const Icon(
                Icons.chat,
                color: Color(0xFF25D366),
                size: 32,
              ),
              title: const Text(
                'Chatea con un asesor',
                style: TextStyle(
                  color: AppTheme.darkText,
                  fontWeight: FontWeight.w600,
                  fontSize: 16,
                ),
              ),
              subtitle: Text(
                'WhatsApp',
                style: TextStyle(
                  color: AppTheme.darkTextSecondary.withValues(alpha: 0.9),
                  fontSize: 13,
                ),
              ),
              trailing: const Icon(
                Icons.chevron_right,
                color: AppTheme.darkTextSecondary,
              ),
              onTap: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Enlace a WhatsApp próximamente'),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 28),
          Text(
            'Problemas comunes',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: AppTheme.darkText,
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 12),
          _issueTile(
            icon: Icons.local_taxi,
            title: 'Tuve un problema con un conductor',
          ),
          const SizedBox(height: 8),
          _issueTile(
            icon: Icons.luggage,
            title: 'Reportar un objeto perdido',
          ),
          const SizedBox(height: 8),
          _issueTile(
            icon: Icons.receipt_long,
            title: 'Revisión de tarifa',
          ),
        ],
      ),
    );
  }

  Widget _issueTile({required IconData icon, required String title}) {
    return Material(
      color: AppTheme.darkSurface,
      borderRadius: BorderRadius.circular(14),
      child: ListTile(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(color: Colors.white.withValues(alpha: 0.06)),
        ),
        leading: Icon(icon, color: AppTheme.primaryBlue, size: 26),
        title: Text(
          title,
          style: const TextStyle(
            color: AppTheme.darkText,
            fontWeight: FontWeight.w500,
            fontSize: 15,
          ),
        ),
        trailing: const Icon(
          Icons.chevron_right,
          color: AppTheme.darkTextSecondary,
        ),
        onTap: () {},
      ),
    );
  }
}
