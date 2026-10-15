import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../../core/routes/home_navigation.dart';
import '../../../core/theme/app_theme.dart';
import '../../bloc/auth/auth_bloc.dart';
import '../../bloc/auth/auth_state.dart';

const Color _kBlue = AppTheme.primaryBlue;
const Color _kTextDark = Color(0xFF1A1A1A);
const Color _kTextMuted = Color(0xFF888888);

/// Explica para qué se piden ubicación y notificaciones antes de que el
/// sistema muestre sus diálogos. Se muestra una sola vez por teléfono, antes
/// del primer dashboard (ver goHomeAfterAuth). Con o sin permisos, sigue al
/// dashboard.
class PermissionsScreen extends StatefulWidget {
  const PermissionsScreen({super.key});

  @override
  State<PermissionsScreen> createState() => _PermissionsScreenState();
}

class _PermissionsScreenState extends State<PermissionsScreen> {
  bool _requesting = false;

  Future<void> _requestPermissions() async {
    if (_requesting) return;
    setState(() => _requesting = true);
    try {
      // 1. Ubicación: diálogo del sistema (si aún no se decidió).
      final location = await Geolocator.checkPermission();
      if (location == LocationPermission.denied) {
        await Geolocator.requestPermission();
      }
      // 2. Notificaciones: en Android 13+ muestra el diálogo; en versiones
      // anteriores ya están permitidas y no muestra nada. En iOS se pedirán
      // cuando existan las notificaciones push.
      if (Platform.isAndroid) {
        await Permission.notification.request();
      }
    } catch (_) {
      // Un fallo al pedir permisos no bloquea la entrada a la app.
    }
    if (mounted) _goToDashboard();
  }

  void _goToDashboard() {
    PermissionsSession.handled = true;
    final authState = context.read<AuthBloc>().state;
    if (authState is AuthAuthenticated) {
      goToHome(context, authState.user);
    } else {
      context.go('/login');
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: Colors.white,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                const Spacer(),
                Container(
                  width: 100,
                  height: 100,
                  decoration: const BoxDecoration(
                    color: Color(0xFFEEF5FF),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.location_on_rounded,
                    color: _kBlue,
                    size: 52,
                  ),
                ),
                const SizedBox(height: 28),
                const Text(
                  'Necesitamos tu permiso',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                    color: _kTextDark,
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Para conectarte con conductores cercanos y mostrarte en '
                  'el mapa, Lleva necesita acceder a tu ubicación.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 15,
                    color: Color(0xFF666666),
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 32),
                const _PermissionItem(
                  icon: Icons.my_location_rounded,
                  iconBg: Color(0xFFE3F2FD),
                  iconColor: Color(0xFF1565C0),
                  title: 'Ubicación',
                  subtitle:
                      'Para encontrar conductores cerca de ti y calcular rutas.',
                ),
                const SizedBox(height: 12),
                const _PermissionItem(
                  icon: Icons.notifications_rounded,
                  iconBg: Color(0xFFFFF3E0),
                  iconColor: Color(0xFFE65100),
                  title: 'Notificaciones',
                  subtitle: 'Para avisarte cuando tu conductor llegue o '
                      'acepte tu solicitud.',
                ),
                const Spacer(flex: 2),
                GestureDetector(
                  onTap: _requesting ? null : _requestPermissions,
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF0055BB), Color(0xFF0099FF)],
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                      ),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x440066CC),
                          blurRadius: 12,
                          offset: Offset(0, 4),
                        ),
                      ],
                    ),
                    child: _requesting
                        ? const Center(
                            child: SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            ),
                          )
                        : const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.check_rounded,
                                color: Colors.white,
                                size: 20,
                              ),
                              SizedBox(width: 8),
                              Text(
                                'Permitir acceso',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                  ),
                ),
                const SizedBox(height: 12),
                TextButton(
                  onPressed: _requesting ? null : _goToDashboard,
                  child: const Text(
                    'Ahora no',
                    style: TextStyle(fontSize: 14, color: _kTextMuted),
                  ),
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PermissionItem extends StatelessWidget {
  const _PermissionItem({
    required this.icon,
    required this.iconBg,
    required this.iconColor,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final Color iconBg;
  final Color iconColor;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: iconBg,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: iconColor, size: 22),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: _kTextDark,
                ),
              ),
              Text(
                subtitle,
                style: const TextStyle(
                  fontSize: 12,
                  color: _kTextMuted,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
