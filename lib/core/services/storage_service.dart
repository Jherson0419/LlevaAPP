import 'dart:developer' as developer;
import 'dart:io';

import 'package:supabase_flutter/supabase_flutter.dart';

/// Subida al bucket `driver-documents` con rutas `profiles/{userId}/{fileName}`.
class StorageService {
  StorageService(this._client);

  static const bucket = 'driver-documents';

  final SupabaseClient _client;

  /// Sin sesión de Supabase Auth no se puede subir a Storage con las políticas habituales.
  /// Esta app usa [signInAnonymously] como respaldo; en el panel de Supabase debe estar
  /// activo **Authentication → Sign In / Providers → Anonymous sign-ins**.
  /// Si prefieres no usar anónimos, hay que iniciar sesión con otro proveedor (p. ej. OTP
  /// por teléfono vía Supabase) antes de subir archivos.
  Future<void> ensureAuthenticatedForUpload() async {
    if (_client.auth.currentSession != null) {
      developer.log(
        'ensureAuthenticatedForUpload: sesión ya activa (upload)',
        name: 'StorageService',
      );
      return;
    }
    developer.log(
      'ensureAuthenticatedForUpload: no hay sesión, intentando signInAnonymously…',
      name: 'StorageService',
    );
    try {
      await _client.auth.signInAnonymously();
    } on AuthException catch (e) {
      if (e.code == 'anonymous_provider_disabled' ||
          e.statusCode == '422' &&
              e.message.toLowerCase().contains('anonymous')) {
        developer.log(
          'ensureAuthenticatedForUpload: proveedor anónimo desactivado en Supabase: '
          '$e',
          name: 'StorageService',
          error: e,
        );
        throw StateError(
          'La subida de fotos requiere sesión en Supabase. Los inicios de sesión '
          'anónimos están desactivados en tu proyecto (código ${e.code ?? e.statusCode}). '
          'En Supabase: Authentication → Sign In / Providers → Anonymous → '
          'activar "Anonymous sign-ins" y guardar. '
          'Alternativa: integrar otro login (p. ej. teléfono con OTP de Supabase) '
          'para obtener JWT antes de subir.',
        );
      }
      rethrow;
    }
    final uid = _client.auth.currentUser?.id;
    developer.log(
      'ensureAuthenticatedForUpload: anónimo ok userId=${uid ?? "(null)"}',
      name: 'StorageService',
    );
  }

  String get _userId {
    final id = _client.auth.currentUser?.id;
    if (id == null || id.isEmpty) {
      throw StateError('No hay sesión de Supabase para subir archivos');
    }
    return id;
  }

  static String _extensionFromPath(String path) {
    final dot = path.lastIndexOf('.');
    if (dot < 0 || dot >= path.length - 1) return 'jpg';
    return path.substring(dot + 1).toLowerCase();
  }

  static String _contentTypeForExt(String ext) {
    switch (ext) {
      case 'png':
        return 'image/png';
      case 'webp':
        return 'image/webp';
      case 'heic':
      case 'heif':
        return 'image/heic';
      default:
        return 'image/jpeg';
    }
  }

  /// Sube [imageFile] a `profiles/{uid}/[fileName]` y devuelve la URL pública.
  ///
  /// [fileName] debe incluir extensión (p. ej. `dni_front.jpg`). Si no la tiene,
  /// se toma la extensión del archivo local.
  Future<String> uploadImage(File imageFile, String fileName) async {
    final localPath = imageFile.path;
    final exists = await imageFile.exists();
    var size = -1;
    if (exists) {
      try {
        size = await imageFile.length();
      } catch (_) {
        size = -2;
      }
    }
    developer.log(
      'uploadImage inicio fileName=$fileName localPath=$localPath '
      'exists=$exists sizeBytes=$size',
      name: 'StorageService',
    );

    String? storagePath;
    try {
      await ensureAuthenticatedForUpload();
      final uid = _userId;
      var name = fileName.trim();
      if (!name.contains('.')) {
        final ext = _extensionFromPath(imageFile.path);
        name = '$name.$ext';
      }
      final ext = _extensionFromPath(name);
      storagePath = 'profiles/$uid/$name';

      developer.log(
        'uploadImage subiendo bucket=$bucket path=$storagePath '
        'contentType=${_contentTypeForExt(ext)}',
        name: 'StorageService',
      );

      await _client.storage.from(bucket).upload(
            storagePath,
            imageFile,
            fileOptions: FileOptions(
              upsert: true,
              contentType: _contentTypeForExt(ext),
            ),
          );

      final url = _client.storage.from(bucket).getPublicUrl(storagePath);
      developer.log(
        'uploadImage ok path=$storagePath',
        name: 'StorageService',
      );
      return url;
    } catch (e, st) {
      developer.log(
        'uploadImage falló fileName=$fileName localPath=$localPath '
        'storagePath=${storagePath ?? "(no calculado)"}: $e',
        name: 'StorageService',
        error: e,
        stackTrace: st,
      );
      if (e is StorageException) {
        final msg = e.message.toLowerCase();
        final code = e.statusCode ?? '';
        if (code == '403' ||
            msg.contains('row-level security') ||
            msg.contains('unauthorized')) {
          throw StateError(
            'No se pudieron subir las fotos: el bucket de Storage bloqueó la subida '
            '(políticas RLS). En Supabase → SQL Editor, ejecuta el script '
            'supabase/storage_driver_documents_policies.sql del repositorio, '
            'o crea políticas en storage.objects para el bucket driver-documents '
            'que permitan INSERT en profiles/{tu id de usuario}/. '
            'Detalle: ${e.message}',
          );
        }
      }
      rethrow;
    }
  }
}
