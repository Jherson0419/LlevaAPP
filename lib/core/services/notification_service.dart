import 'dart:developer' as developer;
import 'dart:io' show Platform;

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// TODO: Run in Supabase:
// ALTER TABLE profiles ADD COLUMN IF NOT EXISTS fcm_token TEXT;

/// Notificaciones push (Firebase Cloud Messaging) y locales.
///
/// Si Firebase no está configurado (faltan google-services.json /
/// GoogleService-Info.plist), solo quedan activas las notificaciones locales.
class NotificationService {
  static final NotificationService _instance = NotificationService._();
  factory NotificationService() => _instance;
  NotificationService._();

  static const String channelId = 'lleva_default_channel';
  static const String _channelName = 'Notificaciones Lleva';
  static const String _channelDescription = 'Avisos de viajes y de tu cuenta';

  final FlutterLocalNotificationsPlugin _local =
      FlutterLocalNotificationsPlugin();

  String? _fcmToken;
  String? get fcmToken => _fcmToken;

  bool _initialized = false;

  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;

    try {
      const androidSettings =
          AndroidInitializationSettings('@mipmap/ic_launcher');
      const iosSettings = DarwinInitializationSettings(
        requestAlertPermission: false,
        requestBadgePermission: false,
        requestSoundPermission: false,
      );
      await _local.initialize(
        const InitializationSettings(
          android: androidSettings,
          iOS: iosSettings,
        ),
      );

      const channel = AndroidNotificationChannel(
        channelId,
        _channelName,
        description: _channelDescription,
        importance: Importance.max,
      );
      await _local
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(channel);
    } catch (e, st) {
      developer.log(
        'Notificaciones locales: $e',
        name: 'NotificationService',
        error: e,
        stackTrace: st,
      );
    }

    if (Firebase.apps.isEmpty) {
      developer.log(
        'Firebase no está inicializado: sin notificaciones push.',
        name: 'NotificationService',
      );
      return;
    }

    try {
      final fcm = FirebaseMessaging.instance;
      await fcm.requestPermission(alert: true, badge: true, sound: true);

      // iOS: con la app abierta, el sistema muestra el aviso de FCM (en
      // Android no tiene efecto; ahí lo muestra _handleForegroundMessage).
      await fcm.setForegroundNotificationPresentationOptions(
        alert: true,
        badge: true,
        sound: true,
      );

      _fcmToken = await fcm.getToken();
      fcm.onTokenRefresh.listen((token) {
        _fcmToken = token;
        _saveTokenToSupabase(token);
      });

      FirebaseMessaging.onMessage.listen(_handleForegroundMessage);
    } catch (e, st) {
      developer.log(
        'Firebase Messaging: $e',
        name: 'NotificationService',
        error: e,
        stackTrace: st,
      );
    }
  }

  Future<void> _saveTokenToSupabase(String token) async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) return;
    await _updateToken(userId, token);
  }

  /// Guarda el token FCM de este equipo en `profiles.fcm_token`. Nunca lanza;
  /// sin Firebase configurado no hace nada.
  Future<void> saveTokenForUser(String userId) async {
    if (userId.isEmpty || Firebase.apps.isEmpty) return;
    try {
      // initialize() corre sin await al arrancar: puede no tener token aún.
      _fcmToken ??= await FirebaseMessaging.instance.getToken();
    } catch (e) {
      developer.log('getToken: $e', name: 'NotificationService');
    }
    final token = _fcmToken;
    if (token == null) return;
    await _updateToken(userId, token);
  }

  Future<void> _updateToken(String userId, String token) async {
    try {
      await Supabase.instance.client
          .from('profiles')
          .update({'fcm_token': token}).eq('id', userId);
    } catch (e) {
      developer.log('Guardar fcm_token: $e', name: 'NotificationService');
    }
  }

  /// Con la app abierta, FCM no muestra la notificación en Android: se
  /// muestra local. En iOS ya la muestra el sistema (ver
  /// setForegroundNotificationPresentationOptions); mostrarla aquí también
  /// la duplicaría.
  void _handleForegroundMessage(RemoteMessage message) {
    if (Platform.isIOS) return;
    final notification = message.notification;
    if (notification == null) return;

    _local.show(
      notification.hashCode,
      notification.title,
      notification.body,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          channelId,
          _channelName,
          channelDescription: _channelDescription,
          importance: Importance.max,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      ),
    );
  }
}
