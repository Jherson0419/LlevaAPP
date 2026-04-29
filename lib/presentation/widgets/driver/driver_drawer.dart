import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/routes/app_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../bloc/auth/auth_bloc.dart';
import '../../bloc/auth/auth_state.dart';
import '../../bloc/driver_stats/driver_stats_cubit.dart';
import '../../bloc/driver_stats/driver_stats_state.dart';
import '../../bloc/driver_wallet/driver_wallet_cubit.dart';
import '../../bloc/driver_wallet/driver_wallet_state.dart';
import '../../cubit/passenger_driver_mode_cubit.dart';

/// Panel lateral del conductor: ~78% ancho, tema oscuro.
class DriverDrawer extends StatelessWidget {
  const DriverDrawer({
    super.key,
    required this.hostContext,
  });

  /// Contexto del [Scaffold] principal (válido tras cerrar el drawer).
  final BuildContext hostContext;

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
              child: InkWell(
                onTap: () => _closeDrawerThen(
                  context,
                  () {
                    if (hostContext.mounted) {
                      GoRouter.of(hostContext).push(AppRouter.driverProfilePath);
                    }
                  },
                ),
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
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
                          : 'Conductor';

                      return BlocBuilder<DriverStatsCubit, DriverStatsState>(
                        builder: (context, stats) {
                          final ratingText = stats.isLoading
                              ? '…'
                              : (stats.rating != null
                                  ? stats.rating!.toStringAsFixed(1)
                                  : '—');
                          final tripsCount =
                              stats.isLoading ? 0 : stats.trips;
                          final tripsLabel = stats.isLoading
                              ? '(… viajes)'
                              : '($tripsCount viajes)';

                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(3),
                                decoration: const BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: _accent,
                                ),
                                child: CircleAvatar(
                                  radius: 40,
                                  backgroundColor: AppTheme.darkSurface,
                                  child: const Icon(
                                    Icons.person,
                                    size: 48,
                                    color: AppTheme.darkTextSecondary,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 16),
                              Text(
                                name,
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 10),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.star_rounded,
                                    color: Colors.amber.shade400,
                                    size: 22,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    ratingText,
                                    style: const TextStyle(
                                      color: _accent,
                                      fontSize: 17,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    tripsLabel,
                                    style: const TextStyle(
                                      color: AppTheme.darkTextSecondary,
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          );
                        },
                      );
                    },
                  ),
                ),
              ),
            ),
            Expanded(
              child: ListView(
                padding: EdgeInsets.zero,
                children: [
                  _cityRequestsTile(context),
                  _walletTile(context),
                  _navTile(
                    context,
                    icon: Icons.support_agent,
                    title: 'Soporte',
                    route: AppRouter.driverSupportPath,
                  ),
                  _navTile(
                    context,
                    icon: Icons.help_outline,
                    title: 'Ayuda',
                    route: AppRouter.driverHelpPath,
                  ),
                  _navTile(
                    context,
                    icon: Icons.settings,
                    title: 'Configuración',
                    route: AppRouter.driverSettingsPath,
                  ),
                  BlocBuilder<AuthBloc, AuthState>(
                    buildWhen: (p, c) =>
                        p.runtimeType != c.runtimeType ||
                        (p is AuthAuthenticated &&
                            c is AuthAuthenticated &&
                            p.user.role != c.user.role),
                    builder: (context, authState) {
                      if (authState is! AuthAuthenticated ||
                          !userCanTogglePassengerDriver(authState.user)) {
                        return const SizedBox.shrink();
                      }
                      return ListTile(
                        leading: const Icon(
                          Icons.local_taxi,
                          color: _accent,
                          size: 26,
                        ),
                        title: const Text(
                          'Pedir taxi',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w500,
                            fontSize: 15,
                          ),
                        ),
                        trailing: const Icon(
                          Icons.chevron_right,
                          color: AppTheme.darkTextSecondary,
                        ),
                        onTap: () {
                          Navigator.of(context).pop();
                          WidgetsBinding.instance.addPostFrameCallback((_) {
                            if (!hostContext.mounted) return;
                            hostContext
                                .read<PassengerDriverModeCubit>()
                                .setPassengerMode();
                            GoRouter.of(hostContext).go('/client-dashboard');
                          });
                        },
                      );
                    },
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

  Widget _cityRequestsTile(BuildContext drawerContext) {
    return ListTile(
      leading: const Icon(
        Icons.location_city,
        color: _accent,
        size: 26,
      ),
      title: const Text(
        'Ciudad (solicitudes)',
        style: TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w500,
          fontSize: 15,
        ),
      ),
      trailing: const Icon(
        Icons.chevron_right,
        color: AppTheme.darkTextSecondary,
      ),
      onTap: () => Navigator.of(drawerContext).pop(),
    );
  }

  Widget _walletTile(BuildContext drawerContext) {
    return BlocBuilder<DriverWalletCubit, DriverWalletState>(
      builder: (context, wallet) {
        final subtitle = wallet.isLoading
            ? 'Saldo adeudado: …'
            : 'Saldo adeudado: ${AppConstants.currencySymbol} ${wallet.owedBalance.toStringAsFixed(2)}';

        return ListTile(
          leading: const Icon(
            Icons.account_balance_wallet,
            color: _accent,
            size: 26,
          ),
          title: const Text(
            'Cartera (nuestro interés, saldo...)',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w500,
              fontSize: 15,
            ),
          ),
          subtitle: Text(
            subtitle,
            style: const TextStyle(
              color: AppTheme.darkTextSecondary,
              fontSize: 13,
            ),
          ),
          trailing: const Icon(
            Icons.chevron_right,
            color: AppTheme.darkTextSecondary,
          ),
          onTap: () => _closeDrawerThen(
            drawerContext,
            () {
              if (hostContext.mounted) {
                GoRouter.of(hostContext).push(AppRouter.driverWalletPath);
              }
            },
          ),
        );
      },
    );
  }

  Widget _navTile(
    BuildContext drawerContext, {
    required IconData icon,
    required String title,
    required String route,
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
      onTap: () => _closeDrawerThen(
        drawerContext,
        () {
          if (hostContext.mounted) {
            GoRouter.of(hostContext).push(route);
          }
        },
      ),
    );
  }
}
