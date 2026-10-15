import 'package:flutter/material.dart';

import '../../../../core/utils/custom_map_markers.dart';

/// Pin «gota» fijo en el centro de un mapa: la punta cae exactamente en el
/// centro del lienzo, que es el punto que se elige (recojo). Encima, una
/// etiqueta con [label]; con `'...'` muestra tres puntos de carga dentro del
/// pin. Se usa con `Positioned.fill` + `IgnorePointer` sobre el mapa.
class CenterPinPainter extends CustomPainter {
  CenterPinPainter({required this.label, required this.color});

  /// Texto de la etiqueta (calle bajo el pin). Vacío = sin etiqueta.
  final String label;
  final Color color;

  /// Valor de [label] mientras se busca la dirección.
  static const String loadingLabel = '...';

  static const double _radius = 14;

  /// Distancia de la punta al centro del círculo.
  static const double _height = 38;

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final circleCenter = Offset(cx, cy - _height);

    // Sombra en el suelo, bajo la punta.
    canvas.drawOval(
      Rect.fromCenter(center: Offset(cx, cy + 2), width: 14, height: 5),
      Paint()
        ..color = Colors.black.withValues(alpha: 0.25)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
    );

    final path = CustomMapMarkers.teardropPinPath(
      tip: Offset(cx, cy),
      radius: _radius,
      height: _height,
    );
    // Sombra del cuerpo y cuerpo.
    canvas.drawPath(
      path,
      Paint()
        ..color = Colors.black.withValues(alpha: 0.15)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
    );
    canvas.drawPath(path, Paint()..color = color);

    // Círculo blanco interior.
    canvas.drawCircle(
      circleCenter,
      _radius * 0.45,
      Paint()..color = Colors.white,
    );

    if (label == loadingLabel) {
      // Buscando la dirección: tres puntos dentro del círculo blanco.
      final dot = Paint()..color = color;
      for (var i = -1; i <= 1; i++) {
        canvas.drawCircle(circleCenter.translate(i * 3.8, 0), 1.4, dot);
      }
      return;
    }
    if (label.isEmpty) return;

    final textPainter = TextPainter(
      text: TextSpan(
        text: label,
        style: const TextStyle(
          color: Color(0xFF1A1A1A),
          fontSize: 15,
          fontWeight: FontWeight.w600,
        ),
      ),
      textDirection: TextDirection.ltr,
      maxLines: 1,
      ellipsis: '…',
    )..layout(maxWidth: 220);

    const padH = 14.0;
    const padV = 8.0;
    final pillW = textPainter.width + padH * 2;
    final pillH = textPainter.height + padV * 2;
    final pillTop = circleCenter.dy - _radius - pillH - 8;
    final pill = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: Offset(cx, pillTop + pillH / 2),
        width: pillW,
        height: pillH,
      ),
      const Radius.circular(12),
    );

    canvas.drawRRect(
      pill.shift(const Offset(0, 2)),
      Paint()
        ..color = Colors.black.withValues(alpha: 0.1)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
    );
    canvas.drawRRect(pill, Paint()..color = Colors.white);
    canvas.drawRRect(
      pill,
      Paint()
        ..color = color.withValues(alpha: 0.4)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );
    textPainter.paint(
      canvas,
      Offset(cx - textPainter.width / 2, pillTop + padV),
    );
  }

  @override
  bool shouldRepaint(covariant CenterPinPainter oldDelegate) =>
      oldDelegate.label != label || oldDelegate.color != color;
}
