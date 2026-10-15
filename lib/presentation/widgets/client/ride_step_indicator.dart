import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';

/// Paso numerado del flujo de pedido (Destino → Pago → Vehículo).
///
/// - [isDone]: paso completado, check verde.
/// - [isActive]: paso actual, azul.
/// - ninguno: paso pendiente, gris.
class RideStepIndicator extends StatelessWidget {
  const RideStepIndicator({
    super.key,
    required this.number,
    required this.label,
    required this.isActive,
    this.isDone = false,
  });

  final int number;
  final String label;
  final bool isActive;
  final bool isDone;

  static const Color _doneGreen = Color(0xFF00AA44);
  static const Color _pending = Color(0xFFAAAAAA);

  @override
  Widget build(BuildContext context) {
    final highlighted = isDone || isActive;
    final accent = isDone
        ? _doneGreen
        : (isActive ? AppTheme.primaryBlue : _pending);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 22,
          height: 22,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: highlighted ? accent : const Color(0xFFEEEEEE),
          ),
          child: Center(
            child: isDone
                ? const Icon(Icons.check_rounded, color: Colors.white, size: 14)
                : Text(
                    number.toString(),
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: isActive ? Colors.white : _pending,
                    ),
                  ),
          ),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: highlighted ? FontWeight.w600 : FontWeight.w400,
            color: accent,
          ),
        ),
      ],
    );
  }
}

/// Línea entre dos [RideStepIndicator]; ocupa el espacio libre de la fila.
class RideStepDivider extends StatelessWidget {
  const RideStepDivider({super.key});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        height: 1,
        margin: const EdgeInsets.symmetric(horizontal: 6),
        color: const Color(0xFFEEEEEE),
      ),
    );
  }
}
