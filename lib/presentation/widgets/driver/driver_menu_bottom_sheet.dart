import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../../bloc/auth/auth_bloc.dart';
import '../../bloc/auth/auth_state.dart';

class DriverMenuBottomSheet extends StatelessWidget {
  const DriverMenuBottomSheet({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppTheme.darkSurface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Asa de arrastre
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.only(top: 12, bottom: 24),
            decoration: BoxDecoration(
              color: Colors.grey[700],
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Header con Avatar y datos del conductor
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: AppTheme.primaryBlue.withOpacity(0.2),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: AppTheme.primaryBlue,
                      width: 2,
                    ),
                  ),
                  child: const Icon(
                    Icons.person,
                    color: AppTheme.primaryBlue,
                    size: 32,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Carlos Conductor',
                        style: TextStyle(
                          color: AppTheme.darkText,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Chevrolet Onix RS - Placa ABC-123',
                        style: TextStyle(
                          color: AppTheme.primaryBlue,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),
          const Divider(
            color: AppTheme.darkSurfaceElevated,
            height: 1,
            thickness: 1,
          ),

          // Mis Ganancias / historial de viajes
          _buildMenuTile(
            context,
            icon: Icons.account_balance_wallet,
            title: 'Mis Ganancias',
            onTap: () {
              Navigator.pop(context);
              final auth = context.read<AuthBloc>().state;
              if (auth is! AuthAuthenticated) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Inicia sesión para ver tu historial'),
                    backgroundColor: AppTheme.errorRed,
                  ),
                );
                return;
              }
              context.push(
                '/history',
                extra: <String, String>{
                  'userId': auth.user.id,
                  'role': 'driver',
                },
              );
            },
          ),

          // Documentos
          _buildMenuTile(
            context,
            icon: Icons.description,
            title: 'Documentos (SOAT/Brevete)',
            onTap: () {
              Navigator.pop(context);
              // TODO: Navegar a documentos
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Pantalla de documentos próximamente'),
                  backgroundColor: AppTheme.primaryBlue,
                ),
              );
            },
          ),

          // Configuración
          _buildMenuTile(
            context,
            icon: Icons.settings,
            title: 'Configuración',
            onTap: () {
              Navigator.pop(context);
              // TODO: Navegar a configuración
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Pantalla de configuración próximamente'),
                  backgroundColor: AppTheme.primaryBlue,
                ),
              );
            },
          ),

          const SizedBox(height: 8),

          // Cerrar Sesión
          _buildMenuTile(
            context,
            icon: Icons.logout,
            title: 'Cerrar Sesión',
            textColor: AppTheme.errorRed,
            iconColor: AppTheme.errorRed,
            onTap: () {
              Navigator.pop(context);
              _showLogoutDialog(context);
            },
          ),

          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildMenuTile(
    BuildContext context, {
    required IconData icon,
    required String title,
    required VoidCallback onTap,
    Color? textColor,
    Color? iconColor,
  }) {
    return ListTile(
      leading: Icon(
        icon,
        color: iconColor ?? AppTheme.darkText,
        size: 24,
      ),
      title: Text(
        title,
        style: TextStyle(
          color: textColor ?? AppTheme.darkText,
          fontSize: 16,
          fontWeight: FontWeight.w500,
        ),
      ),
      trailing: const Icon(
        Icons.chevron_right,
        color: AppTheme.darkTextSecondary,
        size: 24,
      ),
      onTap: onTap,
    );
  }

  void _showLogoutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.darkSurface,
        title: const Text(
          'Cerrar Sesión',
          style: TextStyle(color: AppTheme.darkText),
        ),
        content: const Text(
          '¿Estás seguro de que deseas cerrar sesión?',
          style: TextStyle(color: AppTheme.darkTextSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              context.go('/login');
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.errorRed,
              foregroundColor: Colors.white,
            ),
            child: const Text('Cerrar Sesión'),
          ),
        ],
      ),
    );
  }
}
