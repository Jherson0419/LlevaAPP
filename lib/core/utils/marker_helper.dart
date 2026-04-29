import 'dart:ui' as ui;

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
}
