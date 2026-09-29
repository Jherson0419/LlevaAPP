import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../../cubit/theme_cubit.dart';

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
          _sectionTitle(context, 'Apariencia'),
          const SizedBox(height: 8),
          BlocBuilder<ThemeCubit, ThemeMode>(
            builder: (context, mode) {
              return Card(
                color: AppTheme.darkSurface,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                  side: BorderSide(color: Colors.white.withValues(alpha: 0.06)),
                ),
                child: ListTile(
                  leading: const Icon(
                    Icons.palette_outlined,
                    color: AppTheme.primaryBlue,
                  ),
                  title: const Text(
                    'Tema de la aplicación',
                    style: TextStyle(
                      color: AppTheme.darkText,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  subtitle: Text(
                    _themeModeLabel(mode),
                    style: const TextStyle(color: AppTheme.darkTextSecondary),
                  ),
                  trailing: const Icon(
                    Icons.chevron_right,
                    color: AppTheme.darkTextSecondary,
                  ),
                  onTap: () => _showThemePicker(context),
                ),
              );
            },
          ),
          const SizedBox(height: 28),
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
