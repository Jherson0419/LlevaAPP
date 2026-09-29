import 'dart:ui' as ui;
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

/// Utilidades para construir [BitmapDescriptor] desde assets PNG.
class MarkerHelper {
  MarkerHelper._();

  /// Diámetro lógico (dp) del punto central del indicador «mi ubicación» de Google
  /// Maps (punto azul con borde), no el halo de precisión en metros. Origen/destino
  /// se escalan con [devicePixelRatio] para verse del mismo tamaño en pantalla.
  static const double mapMyLocationDotDiameterDp = 22;

  /// Ancho en píxeles de dispositivo para iconos de origen/destino, alineado al punto
  /// de mi ubicación según la densidad de pantalla.
  static int originDestIconWidthPx(double devicePixelRatio) {
    final w = (mapMyLocationDotDiameterDp * devicePixelRatio).round();
    return w.clamp(16, 256);
  }

  /// Carga un asset, redimensiona a [width] px de ancho y devuelve un descriptor
  /// para [Marker.icon]. Usa [ui.instantiateImageCodec] y [ui.FrameInfo].
  static Future<BitmapDescriptor> getBytesFromAsset(
    String path,
    int width,
  ) async {
    final data = await rootBundle.load(path);
    final bytes = data.buffer.asUint8List();
    final codec = await ui.instantiateImageCodec(
      bytes,
      targetWidth: width,
    );
    final ui.FrameInfo frameInfo = await codec.getNextFrame();
    final ui.Image image = frameInfo.image;
    try {
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) {
        throw StateError('toByteData devolvió null');
      }
      return BitmapDescriptor.bytes(byteData.buffer.asUint8List());
    } finally {
      image.dispose();
    }
  }

  /// Crea un marcador para ubicación del conductor:
  /// - Fondo circular con color de marca.
  /// - Halo difuminado exterior.
  /// - Ícono PNG centrado encima.
  static Future<BitmapDescriptor> getDriverLocationMarker({
    required String assetPath,
    required int sizePx,
    required Color backgroundColor,
  }) async {
    final safeSize = sizePx.clamp(48, 256);
    final iconSize = (safeSize * 0.76).round();
    final center = Offset(safeSize / 2, safeSize / 2);
    final haloRadius = safeSize * 0.34;
    final circleRadius = safeSize * 0.27;

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(
      recorder,
      Rect.fromLTWH(0, 0, safeSize.toDouble(), safeSize.toDouble()),
    );

    // Halo difuminado para resaltar el vehículo en el mapa.
    final haloPaint = Paint()
      ..color = backgroundColor.withValues(alpha: 0.35)
      ..maskFilter = MaskFilter.blur(
        BlurStyle.normal,
        safeSize * 0.10,
      );
    canvas.drawCircle(center, haloRadius, haloPaint);

    final basePaint = Paint()
      ..color = backgroundColor.withValues(alpha: 0.96);
    canvas.drawCircle(center, circleRadius, basePaint);

    final borderPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.85)
      ..style = PaintingStyle.stroke
      ..strokeWidth = safeSize * 0.04;
    canvas.drawCircle(center, circleRadius, borderPaint);

    final data = await rootBundle.load(assetPath);
    final bytes = data.buffer.asUint8List();
    final codec = await ui.instantiateImageCodec(
      bytes,
      targetWidth: iconSize,
      targetHeight: iconSize,
    );
    final frame = await codec.getNextFrame();
    final carImage = frame.image;

    try {
      final dstRect = Rect.fromCenter(
        center: center,
        width: iconSize.toDouble(),
        height: iconSize.toDouble(),
      );
      final srcRect = Rect.fromLTWH(
        0,
        0,
        carImage.width.toDouble(),
        carImage.height.toDouble(),
      );
      canvas.drawImageRect(
        carImage,
        srcRect,
        dstRect,
        Paint()
          ..isAntiAlias = true
          ..filterQuality = FilterQuality.high,
      );

      final composed = await recorder
          .endRecording()
          .toImage(safeSize, safeSize);
      try {
        final byteData = await composed.toByteData(format: ui.ImageByteFormat.png);
        if (byteData == null) {
          throw StateError('No se pudo generar bytes del marcador del conductor');
        }
        final pngBytes = Uint8List.fromList(byteData.buffer.asUint8List());
        return BitmapDescriptor.bytes(pngBytes);
      } finally {
        composed.dispose();
      }
    } finally {
      carImage.dispose();
    }
  }
}
