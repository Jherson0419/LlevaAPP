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

  /// Sube [imageFile] a `profiles/{uid}/[fileName]` y devuelve la **ruta de Storage**
  /// (p. ej. `profiles/<uid>/dni_front.jpg`), NO una URL.
  ///
  /// Antes devolvía `getPublicUrl()` y esa URL se guardaba tal cual en `profiles`
  /// (dni_front_url, license_url, etc.). El bucket `driver-documents` ya no es
  /// público (ver supabase/migrations/003_fix_storage_policies.sql) — esos
  /// documentos son identidad (DNI/licencia/SOAT) y no deben quedar accesibles
  /// por URL directa sin expiración. Para mostrarlos hay que pedir una signed URL
  /// a demanda con [getSignedUrl]; quien llame a este método es responsable de
  /// persistir el path devuelto, no una URL materializada.
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

      developer.log(
        'uploadImage ok path=$storagePath',
        name: 'StorageService',
      );
      // Antes: getPublicUrl(storagePath). El bucket ya no es público
      // (003_fix_storage_policies.sql) — se devuelve el path para persistirlo,
      // y quien necesite mostrar la imagen debe pedir getSignedUrl(path).
      return storagePath;
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

  /// Genera una URL temporal para mostrar un documento privado.
  ///
  /// [storagePath] es el valor devuelto por [uploadImage] (p. ej.
  /// `profiles/<uid>/dni_front.jpg`), tal como se persiste en `profiles.*_url`.
  /// Si [storagePath] ya es una URL absoluta (legado: filas creadas antes de
  /// privatizar el bucket, o `profile_pic_url` que sigue siendo público a
  /// propósito), se devuelve igual sin pedir nada a Storage.
  ///
  /// Expira en [expiresIn] (15 min por defecto) — pedir una nueva cada vez que
  /// se vaya a pintar la imagen, no cachear el resultado más allá de esa ventana.
  Future<String?> getSignedUrl(
    String? storagePath, {
    Duration expiresIn = const Duration(minutes: 15),
  }) async {
    if (storagePath == null || storagePath.trim().isEmpty) return null;
    final path = storagePath.trim();
    if (path.startsWith('http://') || path.startsWith('https://')) {
      return path;
    }
    try {
      return await _client.storage
          .from(bucket)
          .createSignedUrl(path, expiresIn.inSeconds);
    } catch (e, st) {
      developer.log(
        'getSignedUrl falló path=$path: $e',
        name: 'StorageService',
        error: e,
        stackTrace: st,
      );
      return null;
    }
  }
}
