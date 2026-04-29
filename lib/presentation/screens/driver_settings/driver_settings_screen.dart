import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';

/// Configuración del conductor.
class DriverSettingsScreen extends StatelessWidget {
  const DriverSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.darkBackground,
      appBar: AppBar(
        title: const Text('Configuración'),
        backgroundColor: AppTheme.darkSurface,
        foregroundColor: AppTheme.darkText,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        children: [
          _sectionTitle(context, 'Preferencias de Viaje'),
          const SizedBox(height: 8),
          Card(
            color: AppTheme.darkSurface,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
              side: BorderSide(color: Colors.white.withValues(alpha: 0.06)),
            ),
            child: const ListTile(
              leading: Icon(Icons.map, color: AppTheme.primaryBlue),
              title: Text(
                'Navegador GPS predeterminado',
                style: TextStyle(
                  color: AppTheme.darkText,
                  fontWeight: FontWeight.w500,
                ),
              ),
              subtitle: Text(
                'Google Maps',
                style: TextStyle(color: AppTheme.darkTextSecondary),
              ),
              trailing: Icon(Icons.map_outlined, color: AppTheme.darkTextSecondary),
            ),
          ),
          const SizedBox(height: 28),
          _sectionTitle(context, 'Notificaciones'),
          const SizedBox(height: 8),
          Card(
            color: AppTheme.darkSurface,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
              side: BorderSide(color: Colors.white.withValues(alpha: 0.06)),
            ),
            child: SwitchListTile(
              value: true,
              onChanged: null,
              activeTrackColor: AppTheme.primaryBlue.withValues(alpha: 0.45),
              activeThumbColor: AppTheme.primaryBlue,
              title: const Text(
                'Sonido de nueva solicitud',
                style: TextStyle(
                  color: AppTheme.darkText,
                  fontWeight: FontWeight.w500,
                ),
              ),
              subtitle: Text(
                'Activado',
                style: TextStyle(
                  color: AppTheme.darkTextSecondary.withValues(alpha: 0.9),
                  fontSize: 13,
                ),
              ),
            ),
          ),
          const SizedBox(height: 28),
          _sectionTitle(context, 'Cuenta'),
          const SizedBox(height: 8),
          Card(
            color: AppTheme.darkSurface,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
              side: BorderSide(color: Colors.white.withValues(alpha: 0.06)),
            ),
            child: ListTile(
              leading: const Icon(Icons.logout, color: AppTheme.errorRed),
              title: const Text(
                'Cerrar sesión',
                style: TextStyle(
                  color: AppTheme.errorRed,
                  fontWeight: FontWeight.w600,
                ),
              ),
              onTap: () => context.go('/login'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionTitle(BuildContext context, String text) {
    return Text(
      text,
      style: Theme.of(context).textTheme.titleSmall?.copyWith(
            color: AppTheme.darkTextSecondary,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.3,
          ),
    );
  }
}
