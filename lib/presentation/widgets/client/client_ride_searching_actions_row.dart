import 'dart:developer' as developer;

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/enums/client_ride_status.dart';
import '../../../core/theme/app_theme.dart';
import '../../bloc/client_ride/client_ride_bloc.dart';
import 'client_payment_method_ui.dart';
import 'client_ride_preferences_sheet.dart';

Future<void> showClientCancelRideRequestDialog(BuildContext context) async {
  final shouldCancel = await showDialog<bool>(
    context: context,
    builder: (dialogContext) {
      return AlertDialog(
        backgroundColor: const Color(0xFF141414),
        title: const Text(
          'Cancelar solicitud',
          style: TextStyle(color: Colors.white),
        ),
        content: const Text(
          'Si cancelas, dejarás de buscar conductores para este viaje.',
          style: TextStyle(color: AppTheme.darkTextSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text(
              'Atrás',
              style: TextStyle(color: Colors.white70),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.errorRed,
              foregroundColor: Colors.white,
            ),
            child: const Text('Sí, cancelar'),
          ),
        ],
      );
    },
  );

  if (shouldCancel == true && context.mounted) {
    developer.log(
      'CancelRide: confirmado desde acciones de búsqueda',
      name: 'ClientUI',
    );
    context.read<ClientRideBloc>().add(const CancelRide());
  }
}

/// Fila de 3 acciones: pago | cancelar | preferencias (búsqueda y negociación).
class ClientRideSearchingActionsRow extends StatelessWidget {
  const ClientRideSearchingActionsRow({
    super.key,
    required this.state,
    this.enabled = true,
  });

  final ClientRideState state;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final canAct =
        enabled && state.status != ClientRideStatus.requesting;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: _ActionTile(
            onTap: canAct
                ? () => showClientPaymentMethodPicker(context)
                : null,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ClientPaymentMethodImage(
                  method: state.paymentMethod,
                  size: 28,
                ),
                const SizedBox(height: 6),
                Text(
                  clientPaymentMethodLabel(state.paymentMethod),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: canAct ? Colors.white : Colors.white38,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _ActionTile(
            onTap: canAct
                ? () => showClientCancelRideRequestDialog(context)
                : null,
            backgroundColor: AppTheme.errorRed.withValues(alpha: 0.15),
            borderColor: AppTheme.errorRed.withValues(alpha: 0.65),
            child: Text(
              'Cancelar\nsolicitud',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: canAct ? AppTheme.errorRed : AppTheme.errorRed.withValues(alpha: 0.45),
                fontSize: 12,
                fontWeight: FontWeight.w700,
                height: 1.2,
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _ActionTile(
            onTap: canAct
                ? () => showClientRidePreferencesSheet(context, state)
                : null,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.tune,
                  color: canAct ? AppTheme.primaryBlue : AppTheme.primaryBlue.withValues(alpha: 0.4),
                  size: 26,
                ),
                const SizedBox(height: 6),
                Text(
                  _prefsSummary(state),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: canAct ? Colors.white70 : Colors.white38,
                    fontSize: 10.5,
                    fontWeight: FontWeight.w600,
                    height: 1.15,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  static String _prefsSummary(ClientRideState state) {
    final parts = <String>[];
    if (state.moreThanFourPassengers) parts.add('+4 pax');
    if (state.babySeat) parts.add('Bebé');
    if (state.pet) parts.add('Mascota');
    if (state.rideComments.trim().isNotEmpty) parts.add('Notas');
    if (parts.isEmpty) return 'Preferencias';
    return parts.join(' · ');
  }
}

class _ActionTile extends StatelessWidget {
  const _ActionTile({
    required this.child,
    this.onTap,
    this.backgroundColor,
    this.borderColor,
  });

  final Widget child;
  final VoidCallback? onTap;
  final Color? backgroundColor;
  final Color? borderColor;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: backgroundColor ?? const Color(0xFF141414),
      borderRadius: BorderRadius.circular(14),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          constraints: const BoxConstraints(minHeight: 72),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: borderColor ?? Colors.white24,
            ),
          ),
          alignment: Alignment.center,
          child: child,
        ),
      ),
    );
  }
}
