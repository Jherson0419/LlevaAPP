import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../cubit/theme_cubit.dart';

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
            // Apariencia
            BlocBuilder<ThemeCubit, ThemeMode>(
              builder: (context, mode) {
                return _buildSettingsTile(
                  context,
                  icon: Icons.palette_outlined,
                  title: 'Tema de la aplicación',
                  subtitle: _themeModeLabel(mode),
                  onTap: () => _showThemePicker(context),
                );
              },
            ),

            const SizedBox(height: 8),

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

  String _themeModeLabel(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.light:
        return 'Claro';
      case ThemeMode.dark:
        return 'Oscuro';
      case ThemeMode.system:
        return 'Sistema';
    }
  }

  void _showThemePicker(BuildContext context) {
    final themeCubit = context.read<ThemeCubit>();
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppTheme.darkSurface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) {
        return BlocBuilder<ThemeCubit, ThemeMode>(
          bloc: themeCubit,
          builder: (context, mode) {
            return SafeArea(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      color: Colors.grey[700],
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 20),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Tema de la aplicación',
                        style: TextStyle(
                          color: AppTheme.darkText,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  RadioListTile<ThemeMode>(
                    value: ThemeMode.light,
                    groupValue: mode,
                    activeColor: AppTheme.primaryBlue,
                    title: const Text(
                      'Claro',
                      style: TextStyle(color: AppTheme.darkText),
                    ),
                    onChanged: (_) {
                      themeCubit.setLight();
                      Navigator.pop(sheetContext);
                    },
                  ),
                  RadioListTile<ThemeMode>(
                    value: ThemeMode.dark,
                    groupValue: mode,
                    activeColor: AppTheme.primaryBlue,
                    title: const Text(
                      'Oscuro',
                      style: TextStyle(color: AppTheme.darkText),
                    ),
                    onChanged: (_) {
                      themeCubit.setDark();
                      Navigator.pop(sheetContext);
                    },
                  ),
                  RadioListTile<ThemeMode>(
                    value: ThemeMode.system,
                    groupValue: mode,
                    activeColor: AppTheme.primaryBlue,
                    title: const Text(
                      'Igual que el sistema',
                      style: TextStyle(color: AppTheme.darkText),
                    ),
                    onChanged: (_) {
                      themeCubit.setSystem();
                      Navigator.pop(sheetContext);
                    },
                  ),
                  const SizedBox(height: 12),
                ],
              ),
            );
          },
        );
      },
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
