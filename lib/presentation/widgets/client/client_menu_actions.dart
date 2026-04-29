import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../../bloc/auth/auth_bloc.dart';
import '../../bloc/auth/auth_state.dart';
import '../../cubit/passenger_driver_mode_cubit.dart';

/// Diálogos y acciones compartidas del menú pasajero (drawer / futuras variantes).
class ClientMenuActions {
  ClientMenuActions._();

  static void showLegalDialog(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppTheme.darkSurface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: const Text(
          'Legal',
          style: TextStyle(
            color: AppTheme.darkText,
            fontSize: 22,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: const Text(
          'Términos de uso y política de privacidad estarán disponibles aquí. '
          'Puedes revisar también la configuración de la app.',
          style: TextStyle(
            color: AppTheme.darkTextSecondary,
            fontSize: 15,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text(
              'Cerrar',
              style: TextStyle(color: AppTheme.darkTextSecondary),
            ),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(dialogContext);
              context.push('/client-settings');
            },
            child: const Text(
              'Configuración',
              style: TextStyle(color: AppTheme.primaryBlue),
            ),
          ),
        ],
      ),
    );
  }

  static void onEarnMoneyDriving(BuildContext context) {
    final auth = context.read<AuthBloc>().state;
    if (auth is! AuthAuthenticated) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Inicia sesión para continuar'),
          backgroundColor: AppTheme.errorRed,
        ),
      );
      return;
    }
    final u = auth.user;

    if (userCanTogglePassengerDriver(u)) {
      context.read<PassengerDriverModeCubit>().setDriverMode();
      context.go('/dashboard');
      return;
    }

    if (u.role == 'driver') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Ya tienes cuenta de conductor'),
          backgroundColor: AppTheme.primaryBlue,
        ),
      );
      return;
    }
    if (u.isDriverApplicant && !u.isApproved) {
      showDialog<void>(
        context: context,
        builder: (dialogCtx) => AlertDialog(
          backgroundColor: AppTheme.darkSurface,
          title: const Text(
            'Solicitud en revisión',
            style: TextStyle(color: AppTheme.darkText),
          ),
          content: const Text(
            'Tus documentos están en revisión. Te avisaremos cuando haya novedades.',
            style: TextStyle(color: AppTheme.darkTextSecondary),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogCtx),
              child: const Text(
                'Entendido',
                style: TextStyle(color: AppTheme.primaryBlue),
              ),
            ),
          ],
        ),
      );
      return;
    }
    if (!u.isDriverApplicant) {
      context.push('/become-driver');
      return;
    }
    if (u.isApproved) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Completa tus datos de conductor o espera la aprobación para '
            'usar el modo conductor.',
          ),
          backgroundColor: AppTheme.primaryBlue,
        ),
      );
    }
  }

  static void showSecurityDialog(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppTheme.darkSurface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: const Text(
          'Centro de Seguridad',
          style: TextStyle(
            color: AppTheme.errorRed,
            fontSize: 22,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.pop(dialogContext);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Llamando a Emergencias (105)...'),
                      backgroundColor: AppTheme.errorRed,
                      duration: Duration(seconds: 2),
                    ),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.errorRed,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  elevation: 0,
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.phone, size: 26),
                    SizedBox(width: 10),
                    Text(
                      'Emergencias (105)',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () {
                  Navigator.pop(dialogContext);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Compartiendo ubicación del viaje...'),
                      backgroundColor: AppTheme.primaryBlue,
                    ),
                  );
                },
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppTheme.primaryBlue,
                  side: const BorderSide(color: AppTheme.primaryBlue, width: 2),
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.share, size: 22),
                    SizedBox(width: 10),
                    Text(
                      'Compartir mi viaje',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text(
              'Cerrar',
              style: TextStyle(color: AppTheme.darkTextSecondary),
            ),
          ),
        ],
      ),
    );
  }
}
