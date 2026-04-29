import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';

/// Ayuda y guías para conductores.
class DriverHelpScreen extends StatelessWidget {
  const DriverHelpScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.darkBackground,
      appBar: AppBar(
        title: const Text('Ayuda'),
        backgroundColor: AppTheme.darkSurface,
        foregroundColor: AppTheme.darkText,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        children: [
          _helpTile(
            icon: Icons.trending_up,
            title: 'Guía para maximizar tus ganancias',
          ),
          _helpTile(
            icon: Icons.star,
            title: 'Cómo funciona el sistema de calificaciones',
          ),
          _helpTile(
            icon: Icons.rule,
            title: 'Reglas de la comunidad Lleva',
          ),
          _helpTile(
            icon: Icons.description,
            title: 'Términos y condiciones',
          ),
        ],
      ),
    );
  }

  Widget _helpTile({required IconData icon, required String title}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Material(
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
      ),
    );
  }
}
