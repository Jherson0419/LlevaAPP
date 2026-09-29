import 'dart:ui' as ui;
import 'dart:math' as math;

import 'package:flutter/material.dart' show Color, Colors, Icons;
import 'package:flutter/painting.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

/// Icono de mapa con ancla normalizada (0–1) alineada al punto geográfico.
class MapMarkerAsset {
  const MapMarkerAsset({
    required this.descriptor,
    required this.anchor,
  });

  final BitmapDescriptor descriptor;
  /// Punto del bitmap que coincide con [Marker.position] (centro del círculo A/B).
  final Offset anchor;
}

/// Marcadores dibujados en [Canvas] para el mapa del cliente (estética Lleva).
class CustomMapMarkers {
  CustomMapMarkers._();

  static const int _originDestSize = 120;
  static const int _carSize = 140;
  static const int _driverCarSize = 140;
  static const Color _cyan = Color(0xFF00D4FF);
  static const Color _originGreen = Color(0xFF32D74B);

  /// Primera línea de una dirección (calle o vía principal).
  static String streetLabelFromAddress(String? address) {
    if (address == null || address.trim().isEmpty) return 'Buscando…';
    final line = address.split('\n').first.trim();
    final parts = line
        .split(',')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
    if (parts.isEmpty) return line;
    return parts.first;
  }

  /// Círculo blanco (r 15) y halo cyan semitransparente (r 30) sobre lienzo 80×80.
  static Future<BitmapDescriptor> createOriginMarker() async {
    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(recorder);
    const center = ui.Offset(_originDestSize / 2, _originDestSize / 2);
    final scale = _originDestSize / 150.0;
    final halo = ui.Paint()
      ..color = const Color(0xFF32D74B).withValues(alpha: 0.15)
      ..style = ui.PaintingStyle.fill;
    canvas.drawCircle(center, 30 * scale, halo);
    final core = ui.Paint()
      ..color = const Color(0xFF121212)
      ..style = ui.PaintingStyle.fill;
    canvas.drawCircle(center, 20 * scale, core);
    final border = ui.Paint()
      ..color = const Color(0xFF32D74B).withValues(alpha: 0.95)
      ..style = ui.PaintingStyle.stroke
      ..strokeWidth = 2.8 * scale;
    canvas.drawCircle(center, 20 * scale, border);
    final textPainter = TextPainter(
      textDirection: TextDirection.ltr,
      text: TextSpan(
        text: 'A',
        style: TextStyle(
          color: Colors.white,
          fontSize: 20 * scale,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
    textPainter.layout();
    textPainter.paint(
      canvas,
      ui.Offset(center.dx - (textPainter.width / 2), center.dy - (textPainter.height / 2)),
    );

    final picture = recorder.endRecording();
    final image = await picture.toImage(_originDestSize, _originDestSize);
    try {
      final bd = await image.toByteData(format: ui.ImageByteFormat.png);
      if (bd == null) {
        throw StateError('toByteData devolvió null');
      }
      return BitmapDescriptor.bytes(bd.buffer.asUint8List());
    } finally {
      image.dispose();
    }
  }

  /// Cuadrado negro 24×24 con borde cyan grueso, centrado en 80×80.
  static Future<BitmapDescriptor> createDestMarker() async {
    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(recorder);
    const center = ui.Offset(_originDestSize / 2, _originDestSize / 2);
    final scale = _originDestSize / 150.0;
    final halo = ui.Paint()
      ..color = _cyan.withValues(alpha: 0.12)
      ..style = ui.PaintingStyle.fill;
    canvas.drawCircle(center, 30 * scale, halo);
    final fill = ui.Paint()
      ..color = const Color(0xFF121212)
      ..style = ui.PaintingStyle.fill;
    canvas.drawCircle(center, 20 * scale, fill);
    final border = ui.Paint()
      ..color = _cyan
      ..style = ui.PaintingStyle.stroke
      ..strokeWidth = 2.8 * scale;
    canvas.drawCircle(center, 20 * scale, border);
    final textPainter = TextPainter(
      textDirection: TextDirection.ltr,
      text: TextSpan(
        text: 'B',
        style: TextStyle(
          color: Colors.white,
          fontSize: 20 * scale,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
    textPainter.layout();
    textPainter.paint(
      canvas,
      ui.Offset(center.dx - (textPainter.width / 2), center.dy - (textPainter.height / 2)),
    );

    final picture = recorder.endRecording();
    final image = await picture.toImage(_originDestSize, _originDestSize);
    try {
      final bd = await image.toByteData(format: ui.ImageByteFormat.png);
      if (bd == null) {
        throw StateError('toByteData devolvió null');
      }
      return BitmapDescriptor.bytes(bd.buffer.asUint8List());
    } finally {
      image.dispose();
    }
  }

  /// Marcador A con etiqueta de calle encima (origen confirmado en el mapa).
  static Future<MapMarkerAsset> createOriginMarkerWithLabel(
    String streetLabel,
  ) {
    return _createLetterMarkerWithLabel(
      streetLabel: streetLabel,
      letter: 'A',
      accentColor: _originGreen,
      haloAlpha: 0.15,
      fallbackLabel: 'Origen',
    );
  }

  /// Marcador B con etiqueta de calle encima (destino confirmado en el mapa).
  static Future<MapMarkerAsset> createDestMarkerWithLabel(
    String streetLabel,
  ) {
    return _createLetterMarkerWithLabel(
      streetLabel: streetLabel,
      letter: 'B',
      accentColor: _cyan,
      haloAlpha: 0.12,
      fallbackLabel: 'Destino',
    );
  }

  /// Marcador B con tiempo estimado y distancia hacia el destino.
  static Future<MapMarkerAsset> createDestMarkerWithRouteInfo({
    required String minutesLine,
    required String kmLine,
  }) {
    return _createLetterMarkerWithLabel(
      streetLabel: '',
      letter: 'B',
      accentColor: _cyan,
      haloAlpha: 0.12,
      fallbackLabel: 'Destino',
      routeMinutesLine: minutesLine,
      routeKmLine: kmLine,
    );
  }

  static Future<MapMarkerAsset> _createLetterMarkerWithLabel({
    required String streetLabel,
    required String letter,
    required Color accentColor,
    required double haloAlpha,
    required String fallbackLabel,
    String? routeMinutesLine,
    String? routeKmLine,
  }) async {
    const horizontalPadding = 10.0;
    const verticalPadding = 6.0;
    const minLabelWidth = 52.0;
    const maxLabelWidth = 168.0;
    const labelRadius = 10.0;
    const pinSize = _originDestSize;
    const gap = 2.0;
    const pinStemHeight = 3.0;

    final useRouteInfo =
        routeMinutesLine != null && routeKmLine != null;
    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(recorder);

    late final double labelWidth;
    late final double labelHeight;

    if (useRouteInfo) {
      final line1Painter = TextPainter(
        textDirection: TextDirection.ltr,
        maxLines: 1,
        ellipsis: '…',
        text: TextSpan(
          text: routeMinutesLine!.trim().isEmpty ? '---' : routeMinutesLine.trim(),
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.92),
            fontSize: 10.5,
            fontWeight: FontWeight.w600,
          ),
        ),
      );
      line1Painter.layout(maxWidth: maxLabelWidth - (horizontalPadding * 2));

      final line2Painter = TextPainter(
        textDirection: TextDirection.ltr,
        maxLines: 1,
        ellipsis: '…',
        text: TextSpan(
          text: routeKmLine!.trim().isEmpty ? '---' : routeKmLine.trim(),
          style: const TextStyle(
            color: Colors.white,
            fontSize: 12.5,
            fontWeight: FontWeight.w700,
          ),
        ),
      );
      line2Painter.layout(maxWidth: maxLabelWidth - (horizontalPadding * 2));

      final contentWidth = math.max(line1Painter.width, line2Painter.width);
      labelWidth =
          (contentWidth + (horizontalPadding * 2)).clamp(minLabelWidth, maxLabelWidth);
      labelHeight = line1Painter.height + line2Painter.height + (verticalPadding * 2) + 2;

      final totalWidthForRoute = math.max(labelWidth, pinSize.toDouble());
      final labelLeftForRoute = (totalWidthForRoute - labelWidth) / 2;
      final labelRect = ui.Rect.fromLTWH(
        labelLeftForRoute,
        0,
        labelWidth,
        labelHeight,
      );

      final labelShadow = ui.Paint()
        ..color = const Color(0x7A000000)
        ..maskFilter = const ui.MaskFilter.blur(ui.BlurStyle.normal, 2.6);
      canvas.drawRRect(
        ui.RRect.fromRectAndRadius(
          labelRect.shift(const ui.Offset(0, 1.2)),
          const ui.Radius.circular(labelRadius),
        ),
        labelShadow,
      );

      final labelFill = ui.Paint()
        ..color = const Color(0xE6121212)
        ..style = ui.PaintingStyle.fill;
      canvas.drawRRect(
        ui.RRect.fromRectAndRadius(labelRect, const ui.Radius.circular(labelRadius)),
        labelFill,
      );

      final labelBorder = ui.Paint()
        ..color = accentColor.withValues(alpha: 0.95)
        ..style = ui.PaintingStyle.stroke
        ..strokeWidth = 2.0;
      canvas.drawRRect(
        ui.RRect.fromRectAndRadius(labelRect, const ui.Radius.circular(labelRadius)),
        labelBorder,
      );

      final line1Dx = labelLeftForRoute +
          math.max(horizontalPadding, (labelWidth - line1Painter.width) / 2);
      final line1Dy = verticalPadding - 0.5;
      line1Painter.paint(canvas, ui.Offset(line1Dx, line1Dy));
      final line2Dx = labelLeftForRoute +
          math.max(horizontalPadding, (labelWidth - line2Painter.width) / 2);
      final line2Dy = line1Dy + line1Painter.height + 1;
      line2Painter.paint(canvas, ui.Offset(line2Dx, line2Dy));
    } else {
      final safeLabel = streetLabel.trim().isEmpty
          ? fallbackLabel
          : streetLabel.trim();

      final labelPainter = TextPainter(
        textDirection: TextDirection.ltr,
        maxLines: 1,
        ellipsis: '…',
        text: TextSpan(
          text: safeLabel,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 12.5,
            fontWeight: FontWeight.w700,
          ),
        ),
      );
      labelPainter.layout(maxWidth: maxLabelWidth - (horizontalPadding * 2));
      labelWidth =
          (labelPainter.width + (horizontalPadding * 2)).clamp(minLabelWidth, maxLabelWidth);
      labelHeight = labelPainter.height + (verticalPadding * 2);

      final totalWidthForStreet = math.max(labelWidth, pinSize.toDouble());
      final labelLeftForStreet = (totalWidthForStreet - labelWidth) / 2;
      final labelRect = ui.Rect.fromLTWH(
        labelLeftForStreet,
        0,
        labelWidth,
        labelHeight,
      );

      final labelShadow = ui.Paint()
        ..color = const Color(0x7A000000)
        ..maskFilter = const ui.MaskFilter.blur(ui.BlurStyle.normal, 2.6);
      canvas.drawRRect(
        ui.RRect.fromRectAndRadius(
          labelRect.shift(const ui.Offset(0, 1.2)),
          const ui.Radius.circular(labelRadius),
        ),
        labelShadow,
      );

      final labelFill = ui.Paint()
        ..color = const Color(0xE6121212)
        ..style = ui.PaintingStyle.fill;
      canvas.drawRRect(
        ui.RRect.fromRectAndRadius(labelRect, const ui.Radius.circular(labelRadius)),
        labelFill,
      );

      final labelBorder = ui.Paint()
        ..color = accentColor.withValues(alpha: 0.95)
        ..style = ui.PaintingStyle.stroke
        ..strokeWidth = 2.0;
      canvas.drawRRect(
        ui.RRect.fromRectAndRadius(labelRect, const ui.Radius.circular(labelRadius)),
        labelBorder,
      );

      labelPainter.paint(
        canvas,
        ui.Offset(
          labelLeftForStreet + (labelWidth - labelPainter.width) / 2,
          verticalPadding,
        ),
      );
    }

    final totalWidth = math.max(labelWidth, pinSize.toDouble());
    final scale = pinSize / 150.0;
    final pinRadius = 20 * scale;
    final haloRadius = 30 * scale;
    // Halo pegado a la etiqueta: separación mínima + tallo visual.
    final pinCenterY = labelHeight + gap + pinStemHeight + haloRadius;
    final totalHeight = pinCenterY + haloRadius;

    final pinCenter = ui.Offset(totalWidth / 2, pinCenterY);

    final stemPaint = ui.Paint()
      ..color = accentColor.withValues(alpha: 0.95)
      ..style = ui.PaintingStyle.fill;
    final stemWidth = 3.0 * scale;
    canvas.drawRect(
      ui.Rect.fromCenter(
        center: ui.Offset(
          totalWidth / 2,
          labelHeight + gap + (pinStemHeight / 2),
        ),
        width: stemWidth,
        height: pinStemHeight,
      ),
      stemPaint,
    );

    final halo = ui.Paint()
      ..color = accentColor.withValues(alpha: haloAlpha)
      ..style = ui.PaintingStyle.fill;
    canvas.drawCircle(pinCenter, haloRadius, halo);
    final fill = ui.Paint()
      ..color = const Color(0xFF121212)
      ..style = ui.PaintingStyle.fill;
    canvas.drawCircle(pinCenter, pinRadius, fill);
    final border = ui.Paint()
      ..color = accentColor
      ..style = ui.PaintingStyle.stroke
      ..strokeWidth = 2.8 * scale;
    canvas.drawCircle(pinCenter, pinRadius, border);
    final letterPainter = TextPainter(
      textDirection: TextDirection.ltr,
      text: TextSpan(
        text: letter,
        style: TextStyle(
          color: Colors.white,
          fontSize: 20 * scale,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
    letterPainter.layout();
    letterPainter.paint(
      canvas,
      ui.Offset(
        pinCenter.dx - (letterPainter.width / 2),
        pinCenter.dy - (letterPainter.height / 2),
      ),
    );

    final imageWidth = totalWidth.ceil();
    final imageHeight = totalHeight.ceil();
    final image = await recorder.endRecording().toImage(imageWidth, imageHeight);
    try {
      final bd = await image.toByteData(format: ui.ImageByteFormat.png);
      if (bd == null) {
        throw StateError('toByteData devolvió null');
      }
      final anchorY = imageHeight > 0 ? pinCenterY / imageHeight : 1.0;
      return MapMarkerAsset(
        descriptor: BitmapDescriptor.bytes(bd.buffer.asUint8List()),
        anchor: Offset(0.5, anchorY.clamp(0.0, 1.0)),
      );
    } finally {
      image.dispose();
    }
  }

  /// Punto azul compacto (debajo del marcador A en z-order del mapa).
  static Future<BitmapDescriptor> createMyLocationDotMarker() async {
    const size = 36;
    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(recorder);
    const c = ui.Offset(size / 2, size / 2);
    final halo = ui.Paint()
      ..color = const Color(0xFF2196F3).withValues(alpha: 0.22)
      ..style = ui.PaintingStyle.fill;
    canvas.drawCircle(c, 11.5, halo);
    final ring = ui.Paint()
      ..color = Colors.white.withValues(alpha: 0.95)
      ..style = ui.PaintingStyle.fill;
    canvas.drawCircle(c, 8.5, ring);
    final core = ui.Paint()
      ..color = const Color(0xFF2196F3)
      ..style = ui.PaintingStyle.fill;
    canvas.drawCircle(c, 6.2, core);
    final inner = ui.Paint()
      ..color = Colors.white.withValues(alpha: 0.35)
      ..style = ui.PaintingStyle.fill;
    canvas.drawCircle(c, 2.8, inner);

    final picture = recorder.endRecording();
    final image = await picture.toImage(size, size);
    try {
      final bd = await image.toByteData(format: ui.ImageByteFormat.png);
      if (bd == null) {
        throw StateError('toByteData devolvió null');
      }
      return BitmapDescriptor.bytes(bd.buffer.asUint8List());
    } finally {
      image.dispose();
    }
  }

  /// Marcador de auto con el mismo estilo visual que A/B.
  static Future<BitmapDescriptor> createCarMarker() async {
    return _createCarMarkerCanvas(_carSize);
  }

  /// Variante más compacta para el mapa del conductor.
  static Future<BitmapDescriptor> createDriverCarMarker() async {
    return _createCarMarkerCanvas(_driverCarSize);
  }

  static Future<BitmapDescriptor> _createCarMarkerCanvas(int size) async {
    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(recorder);
    final center = ui.Offset(size / 2, size / 2);
    final scale = size / 150.0;

    final halo = ui.Paint()
      ..color = _cyan.withValues(alpha: 0.14)
      ..style = ui.PaintingStyle.fill;
    canvas.drawCircle(center, 30 * scale, halo);

    final bg = ui.Paint()
      ..color = const Color(0xFF121212)
      ..style = ui.PaintingStyle.fill;
    canvas.drawCircle(center, 20 * scale, bg);

    final ring = ui.Paint()
      ..color = _cyan
      ..style = ui.PaintingStyle.stroke
      ..strokeWidth = 2.8 * scale;
    canvas.drawCircle(center, 20 * scale, ring);

    final iconPainter = TextPainter(
      textDirection: TextDirection.ltr,
      text: TextSpan(
        text: String.fromCharCode(Icons.local_taxi.codePoint),
        style: TextStyle(
          fontSize: 18 * scale,
          fontFamily: Icons.local_taxi.fontFamily,
          package: Icons.local_taxi.fontPackage,
          color: _cyan,
        ),
      ),
    );
    iconPainter.layout();
    iconPainter.paint(
      canvas,
      ui.Offset(
        size / 2 - iconPainter.width / 2,
        size / 2 - iconPainter.height / 2,
      ),
    );

    final picture = recorder.endRecording();
    final image = await picture.toImage(size, size);
    try {
      final bd = await image.toByteData(format: ui.ImageByteFormat.png);
      if (bd == null) {
        throw StateError('toByteData devolvió null');
      }
      return BitmapDescriptor.bytes(bd.buffer.asUint8List());
    } finally {
      image.dispose();
    }
  }

  /// Badge de 2 lineas para mostrar tiempo + distancia.
  static Future<BitmapDescriptor> createDistanceBadgeMarker({
    required String line1,
    required String line2,
  }) async {
    const horizontalPadding = 10.0;
    const verticalPadding = 6.0;
    const minWidth = 44.0;
    const maxWidth = 158.0;
    const radius = 10.0;
    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(recorder);
    final safeLine1 = line1.trim().isEmpty ? '---' : line1.trim();
    final safeLine2 = line2.trim().isEmpty ? '---' : line2.trim();
    final line1Painter = TextPainter(
      textDirection: TextDirection.ltr,
      maxLines: 1,
      ellipsis: '...',
      text: TextSpan(
        text: safeLine1,
        style: TextStyle(
          color: Colors.white.withValues(alpha: 0.92),
          fontSize: 10.5,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
    line1Painter.layout(maxWidth: maxWidth - (horizontalPadding * 2));

    final line2Painter = TextPainter(
      textDirection: TextDirection.ltr,
      maxLines: 1,
      ellipsis: '...',
      text: TextSpan(
        text: safeLine2,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 12.0,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
    line2Painter.layout(maxWidth: maxWidth - (horizontalPadding * 2));
    final contentWidth = math.max(line1Painter.width, line2Painter.width);
    final width = (contentWidth + (horizontalPadding * 2)).clamp(minWidth, maxWidth);
    const pointerHeight = 7.0;
    const pointerHalfWidth = 6.0;
    final bodyHeight = line1Painter.height + line2Painter.height + (verticalPadding * 2) + 2;
    final height = bodyHeight + pointerHeight;
    final rect = ui.Rect.fromLTWH(0, 0, width, height);
    final bodyRect = ui.Rect.fromLTWH(0, 0, width, bodyHeight);

    final shadow = ui.Paint()
      ..color = const Color(0x7A000000)
      ..maskFilter = const ui.MaskFilter.blur(ui.BlurStyle.normal, 2.8);
    canvas.drawRRect(
      ui.RRect.fromRectAndRadius(
        bodyRect.shift(const ui.Offset(0, 1.5)),
        const ui.Radius.circular(radius),
      ),
      shadow,
    );

    final fill = ui.Paint()
      ..color = const Color(0xE6121212)
      ..style = ui.PaintingStyle.fill;
    canvas.drawRRect(
      ui.RRect.fromRectAndRadius(bodyRect, const ui.Radius.circular(radius)),
      fill,
    );

    final border = ui.Paint()
      ..color = _cyan.withValues(alpha: 0.95)
      ..style = ui.PaintingStyle.stroke
      ..strokeWidth = 2.2;
    canvas.drawRRect(
      ui.RRect.fromRectAndRadius(bodyRect, const ui.Radius.circular(radius)),
      border,
    );

    final pointerPath = ui.Path()
      ..moveTo(width / 2, height)
      ..lineTo((width / 2) - pointerHalfWidth, bodyHeight - 0.2)
      ..lineTo((width / 2) + pointerHalfWidth, bodyHeight - 0.2)
      ..close();
    canvas.drawPath(pointerPath, fill);
    canvas.drawPath(pointerPath, border);

    final line1Dx = math.max(horizontalPadding, (width - line1Painter.width) / 2);
    final line1Dy = verticalPadding - 0.5;
    line1Painter.paint(canvas, ui.Offset(line1Dx, line1Dy));
    final line2Dx = math.max(horizontalPadding, (width - line2Painter.width) / 2);
    final line2Dy = line1Dy + line1Painter.height + 1;
    line2Painter.paint(canvas, ui.Offset(line2Dx, line2Dy));

    final image = await recorder.endRecording().toImage(width.toInt(), height.toInt());
    try {
      final bd = await image.toByteData(format: ui.ImageByteFormat.png);
      if (bd == null) {
        throw StateError('toByteData devolvio null');
      }
      return BitmapDescriptor.bytes(bd.buffer.asUint8List());
    } finally {
      image.dispose();
    }
  }
}
