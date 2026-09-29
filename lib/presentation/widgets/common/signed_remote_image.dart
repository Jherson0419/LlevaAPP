import 'package:flutter/material.dart';

import '../../../core/di/injection_container.dart' as di;
import '../../../core/services/storage_service.dart';
import '../../../core/theme/app_theme.dart';

/// Pinta una imagen remota que puede venir como:
/// - URL absoluta ya pública (p. ej. `profile_pic_url`, que sigue siendo
///   público a propósito), o
/// - path de Storage privado (p. ej. `dni_front_url` desde que el bucket
///   `driver-documents` dejó de ser público — ver BLOQUE 1.2 de la auditoría),
///   en cuyo caso pide una signed URL de corta duración antes de pintar.
///
/// Centraliza esa resolución para no repetir el `FutureBuilder` en cada
/// pantalla que muestra documentos del conductor.
class SignedRemoteImage extends StatefulWidget {
  const SignedRemoteImage({
    super.key,
    required this.value,
    this.fit = BoxFit.cover,
  });

  /// Puede ser una URL http(s) o un path de Storage (`profiles/<uid>/archivo.jpg`).
  final String value;
  final BoxFit fit;

  @override
  State<SignedRemoteImage> createState() => _SignedRemoteImageState();
}

class _SignedRemoteImageState extends State<SignedRemoteImage> {
  late Future<String?> _resolved;

  @override
  void initState() {
    super.initState();
    _resolved = di.sl<StorageService>().getSignedUrl(widget.value);
  }

  @override
  void didUpdateWidget(SignedRemoteImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value) {
      _resolved = di.sl<StorageService>().getSignedUrl(widget.value);
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<String?>(
      future: _resolved,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const ColoredBox(
            color: AppTheme.darkSurfaceElevated,
            child: Center(
              child: SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          );
        }
        final url = snapshot.data;
        if (url == null || url.isEmpty) {
          return const ColoredBox(
            color: AppTheme.darkSurfaceElevated,
            child: Icon(
              Icons.broken_image_outlined,
              color: AppTheme.darkTextSecondary,
            ),
          );
        }
        return Image.network(
          url,
          fit: widget.fit,
          width: double.infinity,
          height: double.infinity,
          errorBuilder: (_, __, ___) => const ColoredBox(
            color: AppTheme.darkSurfaceElevated,
            child: Icon(
              Icons.broken_image_outlined,
              color: AppTheme.darkTextSecondary,
            ),
          ),
        );
      },
    );
  }
}
