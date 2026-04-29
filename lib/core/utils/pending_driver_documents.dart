import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// Rutas locales de imágenes del registro conductor (evita URIs largos hacia SMS).
/// La subida a Storage ocurre en [AuthBloc] al registrar el perfil.
class PendingDriverDocuments {
  static const _key = 'lleva_driver_pending_doc_paths';

  static const dniFrontPath = 'dni_front_path';
  static const dniBackPath = 'dni_back_path';
  static const licensePath = 'license_path';
  static const soatPath = 'soat_path';
  static const propertyCardPath = 'property_card_path';
  static const profilePicPath = 'profile_pic_path';

  static const requiredKeys = <String>[
    dniFrontPath,
    dniBackPath,
    licensePath,
    soatPath,
    propertyCardPath,
    profilePicPath,
  ];

  static Future<void> save(Map<String, String> urls) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, jsonEncode(urls));
  }

  static Future<Map<String, String>?> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null || raw.isEmpty) return null;
    final decoded = jsonDecode(raw);
    if (decoded is! Map) return null;
    return decoded.map((k, v) => MapEntry(k.toString(), v.toString()));
  }

  static Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }

  static bool isComplete(Map<String, String>? m) {
    if (m == null) return false;
    for (final k in requiredKeys) {
      final v = m[k]?.trim();
      if (v == null || v.isEmpty) return false;
    }
    return true;
  }
}
