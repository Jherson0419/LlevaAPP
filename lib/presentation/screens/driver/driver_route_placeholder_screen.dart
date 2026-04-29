import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';

/// Pantalla temporal para rutas del conductor en construcción.
class DriverRoutePlaceholderScreen extends StatelessWidget {
  const DriverRoutePlaceholderScreen({
    super.key,
    required this.title,
  });

  final String title;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.darkBackground,
      appBar: AppBar(
        title: Text(title),
        backgroundColor: AppTheme.darkSurface,
        foregroundColor: AppTheme.darkText,
        elevation: 0,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            'Próximamente',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: AppTheme.darkTextSecondary,
                ),
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }
}
