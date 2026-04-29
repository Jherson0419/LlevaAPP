import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';

class ClientMenuFAB extends StatelessWidget {
  final VoidCallback onPressed;

  const ClientMenuFAB({
    super.key,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    // Mismo criterio que el FAB del mapa conductor (drawer ⋮).
    return FloatingActionButton(
      onPressed: onPressed,
      backgroundColor: AppTheme.darkSurface,
      mini: true,
      elevation: 4,
      child: const Icon(
        Icons.more_vert,
        color: AppTheme.darkText,
        size: 24,
      ),
    );
  }
}
