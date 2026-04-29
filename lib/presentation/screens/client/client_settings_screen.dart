import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';

class ClientSettingsScreen extends StatelessWidget {
  const ClientSettingsScreen({super.key});

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
        title: const Text('Configuración'),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Términos y Condiciones
            _buildSettingsTile(
              context,
              icon: Icons.description,
              title: 'Términos y Condiciones',
              onTap: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Términos y Condiciones'),
                    backgroundColor: AppTheme.primaryBlue,
                  ),
                );
              },
            ),
            
            const SizedBox(height: 8),
            
            // Política de Privacidad
            _buildSettingsTile(
              context,
              icon: Icons.privacy_tip,
              title: 'Política de Privacidad',
              onTap: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Política de Privacidad'),
                    backgroundColor: AppTheme.primaryBlue,
                  ),
                );
              },
            ),
            
            const SizedBox(height: 8),
            
            // Notificaciones
            _buildSettingsTile(
              context,
              icon: Icons.notifications,
              title: 'Notificaciones',
              trailing: Switch(
                value: true,
                onChanged: (value) {
                  // TODO: Implementar toggle de notificaciones
                },
                activeColor: AppTheme.primaryBlue,
              ),
            ),
            
            const SizedBox(height: 8),
            
            // Idioma
            _buildSettingsTile(
              context,
              icon: Icons.language,
              title: 'Idioma',
              subtitle: 'Español',
              onTap: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Seleccionar idioma'),
                    backgroundColor: AppTheme.primaryBlue,
                  ),
                );
              },
            ),
            
            const SizedBox(height: 32),
            
            // Botón Cerrar Sesión
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  _showLogoutDialog(context);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.errorRed, // #FF3366
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  elevation: 0,
                ),
                child: const Text(
                  'Cerrar Sesión',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSettingsTile(
    BuildContext context, {
    required IconData icon,
    required String title,
    String? subtitle,
    Widget? trailing,
    VoidCallback? onTap,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.darkSurface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListTile(
        leading: Icon(
          icon,
          color: AppTheme.primaryBlue,
          size: 24,
        ),
        title: Text(
          title,
          style: const TextStyle(
            color: AppTheme.darkText,
            fontSize: 16,
            fontWeight: FontWeight.w500,
          ),
        ),
        subtitle: subtitle != null
            ? Text(
                subtitle,
                style: const TextStyle(
                  color: AppTheme.darkTextSecondary,
                  fontSize: 14,
                ),
              )
            : null,
        trailing: trailing ??
            (onTap != null
                ? const Icon(
                    Icons.chevron_right,
                    color: AppTheme.darkTextSecondary,
                  )
                : null),
        onTap: onTap,
      ),
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
