import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../../bloc/auth/auth_bloc.dart';
import '../../bloc/auth/auth_state.dart';
import 'client_menu_actions.dart';

/// Panel lateral del pasajero: mismo esquema visual que [DriverDrawer] (~78% ancho, tema oscuro).
class ClientDrawer extends StatelessWidget {
  const ClientDrawer({
    super.key,
    required this.hostContext,
    required this.onCityTap,
  });

  /// Contexto del [Scaffold] principal (válido tras cerrar el drawer).
  final BuildContext hostContext;

  /// Cierra el drawer y devuelve al mapa (vista principal).
  final VoidCallback onCityTap;

  static const Color _bg = Color(0xFF0A0A0A);
  static const Color _headerBg = Color(0xFF1A1A1A);
  static const Color _accent = Color(0xFF00D4FF);

  void _closeDrawerThen(BuildContext drawerContext, VoidCallback action) {
    Navigator.of(drawerContext).pop();
    WidgetsBinding.instance.addPostFrameCallback((_) => action());
  }

  void _showLogoutDialog(BuildContext drawerContext) {
    Navigator.of(drawerContext).pop();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!hostContext.mounted) return;
      showDialog<void>(
        context: hostContext,
        builder: (dialogContext) => AlertDialog(
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
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(dialogContext);
                hostContext.go('/login');
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
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: double.infinity,
      color: _bg,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Material(
              color: _headerBg,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  InkWell(
                    onTap: () => _closeDrawerThen(
                      context,
                      () {
                        if (hostContext.mounted) {
                          GoRouter.of(hostContext).push('/client-profile');
                        }
                      },
                    ),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 20, 16, 12),
                      child: BlocBuilder<AuthBloc, AuthState>(
                        buildWhen: (prev, curr) =>
                            prev.runtimeType != curr.runtimeType ||
                            (prev is AuthAuthenticated &&
                                curr is AuthAuthenticated &&
                                (prev.user.id != curr.user.id ||
                                    prev.user.fullName != curr.user.fullName)),
                        builder: (context, authState) {
                          final name = authState is AuthAuthenticated
                              ? authState.user.fullName
                              : 'Pasajero';

                          return Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(3),
                                decoration: const BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: _accent,
                                ),
                                child: const CircleAvatar(
                                  radius: 36,
                                  backgroundColor: AppTheme.darkSurface,
                                  child: Icon(
                                    Icons.person,
                                    size: 44,
                                    color: AppTheme.darkTextSecondary,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      name,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                        height: 1.2,
                                      ),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 8),
                                    Row(
                                      children: [
                                        Icon(
                                          Icons.star_rounded,
                                          color: Colors.amber.shade400,
                                          size: 20,
                                        ),
                                        const SizedBox(width: 6),
                                        const Text(
                                          '—',
                                          style: TextStyle(
                                            color: _accent,
                                            fontSize: 16,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          '(— viajes)',
                                          style: TextStyle(
                                            color: AppTheme.darkTextSecondary,
                                            fontSize: 13,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(8, 0, 8, 12),
                    child: Material(
                      color: const Color(0xFF141414),
                      borderRadius: BorderRadius.circular(12),
                      child: ListTile(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        leading: const Icon(
                          Icons.map_outlined,
                          color: _accent,
                          size: 26,
                        ),
                        title: const Text(
                          'Ciudad',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                            fontSize: 15,
                          ),
                        ),
                        subtitle: const Text(
                          'Ver mapa y tu zona',
                          style: TextStyle(
                            color: AppTheme.darkTextSecondary,
                            fontSize: 12,
                          ),
                        ),
                        trailing: const Icon(
                          Icons.chevron_right,
                          color: AppTheme.darkTextSecondary,
                        ),
                        onTap: () =>
                            _closeDrawerThen(context, onCityTap),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: EdgeInsets.zero,
                children: [
                  _navTile(
                    context,
                    icon: Icons.local_shipping_outlined,
                    title: 'Entregas',
                    onTap: () => _closeDrawerThen(
                      context,
                      () {
                        if (hostContext.mounted) {
                          GoRouter.of(hostContext).push('/client-trips');
                        }
                      },
                    ),
                  ),
                  _navTile(
                    context,
                    icon: Icons.history,
                    title: 'Historial de solicitudes',
                    onTap: () {
                      final auth = hostContext.read<AuthBloc>().state;
                      if (auth is! AuthAuthenticated) {
                        _closeDrawerThen(context, () {
                          ScaffoldMessenger.of(hostContext).showSnackBar(
                            const SnackBar(
                              content: Text(
                                'Inicia sesión para ver tu historial',
                              ),
                              backgroundColor: AppTheme.errorRed,
                            ),
                          );
                        });
                        return;
                      }
                      _closeDrawerThen(context, () {
                        if (hostContext.mounted) {
                          GoRouter.of(hostContext).push(
                            '/history',
                            extra: <String, String>{
                              'userId': auth.user.id,
                              'role': 'client',
                            },
                          );
                        }
                      });
                    },
                  ),
                  _navTile(
                    context,
                    icon: Icons.account_balance_wallet,
                    title: 'Cartera',
                    onTap: () => _closeDrawerThen(
                      context,
                      () {
                        if (hostContext.mounted) {
                          GoRouter.of(hostContext).push('/client-wallet');
                        }
                      },
                    ),
                  ),
                  _navTile(
                    context,
                    icon: Icons.route_outlined,
                    title: 'Viajes',
                    onTap: () {
                      final auth = hostContext.read<AuthBloc>().state;
                      if (auth is! AuthAuthenticated) {
                        _closeDrawerThen(context, () {
                          ScaffoldMessenger.of(hostContext).showSnackBar(
                            const SnackBar(
                              content: Text(
                                'Inicia sesión para ver tus viajes',
                              ),
                              backgroundColor: AppTheme.errorRed,
                            ),
                          );
                        });
                        return;
                      }
                      _closeDrawerThen(context, () {
                        if (hostContext.mounted) {
                          GoRouter.of(hostContext).push('/client-trips');
                        }
                      });
                    },
                  ),
                  _navTile(
                    context,
                    icon: Icons.shield_outlined,
                    title: 'Seguridad',
                    onTap: () => _closeDrawerThen(
                      context,
                      () {
                        if (hostContext.mounted) {
                          ClientMenuActions.showSecurityDialog(hostContext);
                        }
                      },
                    ),
                  ),
                  _navTile(
                    context,
                    icon: Icons.support_agent,
                    title: 'Soporte',
                    onTap: () => _closeDrawerThen(
                      context,
                      () {
                        if (hostContext.mounted) {
                          GoRouter.of(hostContext).push('/client-support');
                        }
                      },
                    ),
                  ),
                  _navTile(
                    context,
                    icon: Icons.help_outline,
                    title: 'Ayuda',
                    onTap: () => _closeDrawerThen(
                      context,
                      () {
                        if (hostContext.mounted) {
                          GoRouter.of(hostContext).push('/client-help');
                        }
                      },
                    ),
                  ),
                  _navTile(
                    context,
                    icon: Icons.settings,
                    title: 'Configuración',
                    onTap: () => _closeDrawerThen(
                      context,
                      () {
                        if (hostContext.mounted) {
                          GoRouter.of(hostContext).push('/client-settings');
                        }
                      },
                    ),
                  ),
                  _navTile(
                    context,
                    icon: Icons.gavel_outlined,
                    title: 'Legal',
                    onTap: () => _closeDrawerThen(
                      context,
                      () {
                        if (hostContext.mounted) {
                          ClientMenuActions.showLegalDialog(hostContext);
                        }
                      },
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 8, 12, 16),
                    child: Material(
                      color: _accent.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(14),
                      child: ListTile(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                          side: BorderSide(
                            color: _accent.withValues(alpha: 0.4),
                          ),
                        ),
                        leading: const Icon(
                          Icons.drive_eta,
                          color: _accent,
                          size: 28,
                        ),
                        title: const Text(
                          'Gana dinero conduciendo',
                          style: TextStyle(
                            color: _accent,
                            fontWeight: FontWeight.w800,
                            fontSize: 15,
                          ),
                        ),
                        subtitle: const Text(
                          'Envía tu solicitud como conductor',
                          style: TextStyle(
                            color: AppTheme.darkTextSecondary,
                            fontSize: 12,
                          ),
                        ),
                        trailing: const Icon(
                          Icons.chevron_right,
                          color: AppTheme.darkTextSecondary,
                        ),
                        onTap: () {
                          Navigator.of(context).pop();
                          WidgetsBinding.instance.addPostFrameCallback((_) {
                            if (hostContext.mounted) {
                              ClientMenuActions.onEarnMoneyDriving(hostContext);
                            }
                          });
                        },
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: OutlinedButton.icon(
                onPressed: () => _showLogoutDialog(context),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppTheme.errorRed,
                  side: const BorderSide(color: AppTheme.errorRed, width: 1.5),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                icon: const Icon(Icons.logout, size: 20),
                label: const Text(
                  'Cerrar Sesión',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _navTile(
    BuildContext drawerContext, {
    required IconData icon,
    required String title,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Icon(icon, color: _accent, size: 26),
      title: Text(
        title,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w500,
          fontSize: 15,
        ),
      ),
      trailing: const Icon(
        Icons.chevron_right,
        color: AppTheme.darkTextSecondary,
      ),
      onTap: onTap,
    );
  }
}
