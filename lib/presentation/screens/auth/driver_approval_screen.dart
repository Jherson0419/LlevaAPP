import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../../bloc/auth/auth_bloc.dart';
import '../../bloc/auth/auth_event.dart';

/// Pantalla de bloqueo para conductores no aprobados o baneados.
class DriverApprovalScreen extends StatelessWidget {
  /// Si es `true`, se muestra el mensaje de cuenta suspendida (baneo).
  final bool isBanned;

  const DriverApprovalScreen({
    super.key,
    this.isBanned = false,
  });

  @override
  Widget build(BuildContext context) {
    final title = isBanned
        ? 'Cuenta suspendida'
        : 'Estamos verificando tus documentos';
    final description = isBanned
        ? 'Tu acceso como conductor ha sido suspendido. Si crees que es un error, contacta a soporte.'
        : 'Tu cuenta ha sido creada exitosamente. Nuestro equipo está revisando tu perfil y los datos de tu vehículo para garantizar la seguridad de la comunidad. Te notificaremos pronto.';

    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: AppTheme.darkBackground,
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    isBanned ? Icons.gpp_bad_outlined : Icons.hourglass_empty,
                    size: 80,
                    color: AppTheme.primaryBlue,
                  ),
                  const SizedBox(height: 24),
                  Text(
                    title,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 22,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    description,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: AppTheme.darkTextSecondary,
                      fontSize: 15,
                      height: 1.45,
                    ),
                  ),
                  const SizedBox(height: 40),
                  OutlinedButton(
                    onPressed: () {
                      context.read<AuthBloc>().add(const LogoutRequested());
                      context.go('/login');
                    },
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppTheme.primaryBlue,
                      side: const BorderSide(color: AppTheme.primaryBlue, width: 1.5),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 32,
                        vertical: 16,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: const Text(
                      'Cerrar sesión',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
