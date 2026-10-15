import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/client_ride_pricing.dart';
import '../../bloc/client_ride/client_ride_bloc.dart';

/// Editor de la oferta del pasajero, con botones − / +, del paso de
/// vehículo. Cada cambio de precio elige también la categoría de vehículo
/// cuya tarifa queda más cerca.
///
/// Usa las mismas reglas que el panel de tarifa ([ClientRidePricing]): pasos
/// de S/ 0.50 y un mínimo de S/ 2.00 por debajo de la tarifa sugerida. Sin
/// ruta calculada muestra «S/ --» y los botones no hacen nada.
class RidePriceControl extends StatelessWidget {
  const RidePriceControl({
    super.key,
    required this.state,
    this.compact = false,
  });

  final ClientRideState state;
  final bool compact;

  static const Color _muted = Color(0xFF888888);
  static const Color _minusRed = Color(0xFFCC2200);

  @override
  Widget build(BuildContext context) {
    final suggested = state.suggestedPrice;
    // offeredPrice vale 0 hasta que hay una ruta con tarifa.
    final hasPrice = suggested != null && suggested > 0;
    final offered = state.offeredPrice > 0 ? state.offeredPrice : suggested;
    final rideBloc = context.read<ClientRideBloc>();

    // Cambiar el precio elige además la categoría cuya tarifa queda más
    // cerca (ver ClientRideBloc._categoryClosestTo).
    void decrease() {
      if (!hasPrice || offered == null) return;
      rideBloc.add(
        PriceChanged(
          ClientRidePricing.decreaseOffered(
            current: offered,
            suggestedPrice: suggested,
          ),
          autoSelectCategory: true,
        ),
      );
    }

    void increase() {
      if (!hasPrice || offered == null) return;
      rideBloc.add(
        PriceChanged(
          ClientRidePricing.increaseOffered(offered),
          autoSelectCategory: true,
        ),
      );
    }

    final priceText = hasPrice && offered != null
        ? 'S/ ${offered.toStringAsFixed(2)}'
        : 'S/ --';
    final suggestedText =
        hasPrice ? 'sugerido: S/ ${suggested.toStringAsFixed(2)}' : null;

    if (compact) {
      return Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Tu oferta',
                  style: TextStyle(fontSize: 11, color: _muted),
                ),
                Text(
                  priceText,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.primaryBlue,
                  ),
                ),
                if (suggestedText != null)
                  Text(
                    suggestedText,
                    style: const TextStyle(fontSize: 10, color: _muted),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          _StepButton(
            icon: Icons.remove_rounded,
            background: const Color(0xFFFFEEEE),
            foreground: _minusRed,
            size: 36,
            radius: 8,
            iconSize: 18,
            onTap: decrease,
          ),
          const SizedBox(width: 8),
          _StepButton(
            icon: Icons.add_rounded,
            background: const Color(0xFFEEF5FF),
            foreground: AppTheme.primaryBlue,
            size: 36,
            radius: 8,
            iconSize: 18,
            onTap: increase,
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text(
          'Tu oferta al conductor',
          style: TextStyle(fontSize: 13, color: _muted),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _StepButton(
              icon: Icons.remove_rounded,
              background: const Color(0xFFFFEEEE),
              border: const Color(0xFFFFCCCC),
              foreground: _minusRed,
              size: 44,
              radius: 12,
              iconSize: 22,
              onTap: decrease,
            ),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Se encoge antes que desbordar en pantallas angostas.
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      priceText,
                      maxLines: 1,
                      style: const TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.primaryBlue,
                      ),
                    ),
                  ),
                  if (suggestedText != null)
                    Text(
                      suggestedText,
                      style: const TextStyle(fontSize: 11, color: _muted),
                    ),
                ],
              ),
            ),
            _StepButton(
              icon: Icons.add_rounded,
              background: const Color(0xFFEEF5FF),
              border: const Color(0xFFBBD5FF),
              foreground: AppTheme.primaryBlue,
              size: 44,
              radius: 12,
              iconSize: 22,
              onTap: increase,
            ),
          ],
        ),
        if (hasPrice && offered != null)
          _DifferenceBadge(difference: offered - suggested),
      ],
    );
  }
}

class _StepButton extends StatelessWidget {
  const _StepButton({
    required this.icon,
    required this.background,
    required this.foreground,
    required this.size,
    required this.radius,
    required this.iconSize,
    required this.onTap,
    this.border,
  });

  final IconData icon;
  final Color background;
  final Color foreground;
  final double size;
  final double radius;
  final double iconSize;
  final VoidCallback onTap;
  final Color? border;

  @override
  Widget build(BuildContext context) {
    final borderColor = border;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(radius),
          border: borderColor == null
              ? null
              : Border.all(color: borderColor, width: 1.5),
        ),
        child: Icon(icon, color: foreground, size: iconSize),
      ),
    );
  }
}

/// Cuánto se aparta la oferta de la tarifa sugerida. No se muestra si son
/// iguales.
class _DifferenceBadge extends StatelessWidget {
  const _DifferenceBadge({required this.difference});

  final double difference;

  @override
  Widget build(BuildContext context) {
    final isAbove = difference > 0.01;
    final isBelow = difference < -0.01;
    if (!isAbove && !isBelow) return const SizedBox.shrink();

    final color = isAbove ? const Color(0xFF2E7D32) : const Color(0xFFE65100);
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: isAbove ? const Color(0xFFE8F5E9) : const Color(0xFFFFF3E0),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isAbove
                  ? Icons.trending_up_rounded
                  : Icons.trending_down_rounded,
              size: 14,
              color: color,
            ),
            const SizedBox(width: 4),
            Text(
              isAbove
                  ? '+S/ ${difference.toStringAsFixed(2)} sobre lo sugerido'
                  : '-S/ ${difference.abs().toStringAsFixed(2)} bajo lo sugerido',
              style: TextStyle(
                fontSize: 11,
                color: color,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
