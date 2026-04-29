import 'dart:ui' as ui;

import 'package:flutter/material.dart' show Color, Colors, Icons;
import 'package:flutter/painting.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import 'marker_helper.dart';

/// Marcadores dibujados en [Canvas] para el mapa del cliente (estética Lleva).
class CustomMapMarkers {
  CustomMapMarkers._();

  static const int _size = 80;
  static const Color _cyan = Color(0xFF00D4FF);

  /// Círculo blanco (r 15) y halo cyan semitransparente (r 30) sobre lienzo 80×80.
  static Future<BitmapDescriptor> createOriginMarker() async {
    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(recorder);
    const center = ui.Offset(_size / 2, _size / 2);

    final halo = ui.Paint()
      ..color = _cyan.withValues(alpha: 0.3)
      ..style = ui.PaintingStyle.fill;
    canvas.drawCircle(center, 30, halo);

    final core = ui.Paint()
      ..color = Colors.white
      ..style = ui.PaintingStyle.fill;
    canvas.drawCircle(center, 15, core);

    final picture = recorder.endRecording();
    final image = await picture.toImage(_size, _size);
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
    final rect = ui.Rect.fromCenter(
      center: const ui.Offset(_size / 2, _size / 2),
      width: 24,
      height: 24,
    );

    final fill = ui.Paint()
      ..color = const Color(0xFF000000)
      ..style = ui.PaintingStyle.fill;
    canvas.drawRect(rect, fill);

    final border = ui.Paint()
      ..color = _cyan
      ..style = ui.PaintingStyle.stroke
      ..strokeWidth = 4;
    canvas.drawRect(rect, border);

    final picture = recorder.endRecording();
    final image = await picture.toImage(_size, _size);
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

  /// Intenta [assets/icons/car.png]; si falla, círculo oscuro con icono de taxi.
  static Future<BitmapDescriptor> createCarMarker() async {
    try {
      return await MarkerHelper.getBytesFromAsset(
        'assets/icons/car.png',
        _size,
      );
    } catch (_) {
      return _createCarMarkerCanvas();
    }
  }

  static Future<BitmapDescriptor> _createCarMarkerCanvas() async {
    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(recorder);
    const center = ui.Offset(_size / 2, _size / 2);

    final bg = ui.Paint()
      ..color = const Color(0xFF1A1A1A)
      ..style = ui.PaintingStyle.fill;
    canvas.drawCircle(center, 28, bg);

    final ring = ui.Paint()
      ..color = _cyan
      ..style = ui.PaintingStyle.stroke
      ..strokeWidth = 2.5;
    canvas.drawCircle(center, 28, ring);

    final iconPainter = TextPainter(
      textDirection: TextDirection.ltr,
      text: TextSpan(
        text: String.fromCharCode(Icons.local_taxi.codePoint),
        style: TextStyle(
          fontSize: 34,
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
        _size / 2 - iconPainter.width / 2,
        _size / 2 - iconPainter.height / 2,
      ),
    );

    final picture = recorder.endRecording();
    final image = await picture.toImage(_size, _size);
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
}
