import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:io';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import '../constants/app_constants.dart';

/// Estilo de avatar que se le pide al modelo.
typedef _AvatarStyle = ({String id, String name, String prompt});

/// Genera avatares a partir de una foto del usuario con la API de Gemini
/// (un avatar por estilo). La foto se envía a Google para procesarla.
class AvatarGeneratorService {
  /// Modelo de imagen. `gemini-2.0-flash-exp-image-generation` ya no existe
  /// en la API; este es su sucesor estable.
  static const String _model = 'gemini-2.5-flash-image';

  static const String _baseUrl =
      'https://generativelanguage.googleapis.com/v1beta/models/'
      '$_model:generateContent';

  static const Duration _timeout = Duration(seconds: 60);

  static const List<_AvatarStyle> _styles = [
    (
      id: 'pixar',
      name: 'Pixar 3D',
      prompt: 'Transform this photo into a Pixar/Disney 3D animated '
          'character avatar. Keep the facial features and expression '
          'recognizable. Bright colors, smooth 3D rendering, friendly '
          'expression. Square format, centered face, white or simple '
          'background.',
    ),
    (
      id: 'flat',
      name: 'Flat Minimal',
      prompt: 'Transform this photo into a modern flat design avatar '
          'illustration. Minimalist style, solid colors, clean geometric '
          'shapes. Keep the hair color and general facial features. '
          'Square format, centered, simple colored background.',
    ),
    (
      id: 'anime',
      name: 'Anime',
      prompt: 'Transform this photo into a Japanese anime style avatar. '
          'Large expressive eyes, clean line art, vibrant colors. '
          'Keep hair color and facial features recognizable. '
          'Square format, centered face, simple background.',
    ),
    (
      id: 'realistic',
      name: 'Artístico',
      prompt: 'Transform this photo into an artistic digital painting '
          'portrait. Enhanced colors, painterly style, professional '
          'portrait composition. Keep the person recognizable. '
          'Square format, centered face.',
    ),
  ];

  /// true si hay clave de API configurada (`GEMINI_API_KEY`).
  static bool get isConfigured => AppConstants.geminiApiKey.isNotEmpty;

  /// Devuelve un avatar por cada estilo que el modelo logró generar, en el
  /// orden de [_styles]; los que fallan se omiten. Los estilos se piden en
  /// paralelo. Lanza [StateError] si no hay clave de API.
  Future<List<AvatarResult>> generateAvatars(File imageFile) async {
    if (!isConfigured) {
      throw StateError('Falta GEMINI_API_KEY');
    }
    final base64Image = base64Encode(await imageFile.readAsBytes());
    final mimeType = _getMimeType(imageFile.path);

    final results = await Future.wait(
      _styles.map((style) async {
        try {
          return await _generateSingle(
            base64Image: base64Image,
            mimeType: mimeType,
            style: style,
          );
        } catch (e) {
          developer.log(
            'generateAvatars: falló el estilo ${style.id}: $e',
            name: 'AvatarGeneratorService',
          );
          return null;
        }
      }),
    );
    return results.whereType<AvatarResult>().toList();
  }

  Future<AvatarResult?> _generateSingle({
    required String base64Image,
    required String mimeType,
    required _AvatarStyle style,
  }) async {
    final body = jsonEncode({
      'contents': [
        {
          'parts': [
            {
              'inline_data': {'mime_type': mimeType, 'data': base64Image},
            },
            {'text': style.prompt},
          ],
        },
      ],
      'generationConfig': {
        'responseModalities': ['IMAGE', 'TEXT'],
      },
    });

    final response = await http
        .post(
          Uri.parse(_baseUrl),
          headers: {
            'Content-Type': 'application/json',
            // En cabecera y no en la URL, para que la clave no quede en
            // registros de peticiones.
            'x-goog-api-key': AppConstants.geminiApiKey,
          },
          body: body,
        )
        .timeout(_timeout);

    if (response.statusCode != 200) {
      developer.log(
        '_generateSingle ${style.id}: HTTP ${response.statusCode} '
        '${response.body.length > 300 ? response.body.substring(0, 300) : response.body}',
        name: 'AvatarGeneratorService',
      );
      return null;
    }

    final json = jsonDecode(response.body);
    if (json is! Map) return null;
    final candidates = json['candidates'];
    if (candidates is! List || candidates.isEmpty) return null;
    final first = candidates.first;
    final content = first is Map ? first['content'] : null;
    final parts = content is Map ? content['parts'] : null;
    if (parts is! List) return null;

    for (final part in parts) {
      if (part is! Map) continue;
      // La respuesta REST usa `inlineData`; se acepta también snake_case.
      final inlineData = part['inlineData'] ?? part['inline_data'];
      final data = inlineData is Map ? inlineData['data'] : null;
      if (data is String && data.isNotEmpty) {
        return AvatarResult(
          styleId: style.id,
          styleName: style.name,
          imageBytes: base64Decode(data),
        );
      }
    }
    return null;
  }

  String _getMimeType(String path) {
    final ext = path.toLowerCase().split('.').last;
    switch (ext) {
      case 'png':
        return 'image/png';
      case 'webp':
        return 'image/webp';
      default:
        return 'image/jpeg';
    }
  }
}

class AvatarResult {
  final String styleId;
  final String styleName;
  final Uint8List imageBytes;

  const AvatarResult({
    required this.styleId,
    required this.styleName,
    required this.imageBytes,
  });
}
