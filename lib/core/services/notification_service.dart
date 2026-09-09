import 'dart:convert';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../utils/logger.dart';

/// Handles a push that arrives while the app is terminated.
///
/// Must be a top-level function — the isolate that runs it has no access to
/// anything captured from the app's own isolate. It deliberately does no work:
/// the notification document is already written server-side, so there is
/// nothing to sync here.
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  log.d('background push ${message.messageId}');
}

/// Push registration, permission and foreground display.
///
/// Firebase only *displays* a notification automatically when the app is in
/// the background. In the foreground the message arrives silently, so this
/// class re-renders it through flutter_local_notifications — otherwise a user
/// sitting on the home screen would never see "your redemption was approved".
class NotificationService {
  NotificationService(this._messaging, this._local);

  final FirebaseMessaging _messaging;
  final FlutterLocalNotificationsPlugin _local;

  /// Must match the channel declared in AndroidManifest.xml, or Android
  /// silently drops the notification into a default channel with no sound.
  static const _channel = AndroidNotificationChannel(
    'robux_box_default',
    'General',
    description: 'Rewards, redemptions and account updates',
    importance: Importance.high,
  );

  /// Called when the user taps a notification. Set by the router so a tap can
  /// deep-link; left null until then.
  void Function(String route)? onDeeplink;

  bool _initialised = false;

  Future<void> initialise() async {
    if (_initialised) return;
    _initialised = true;

    try {
      await _local.initialize(
        const InitializationSettings(
          android: AndroidInitializationSettings('@mipmap/ic_launcher'),
          iOS: DarwinInitializationSettings(
            // Permission is requested explicitly in requestPermission() so the
            // prompt appears at a moment the user understands, not on launch.
            requestAlertPermission: false,
            requestBadgePermission: false,
            requestSoundPermission: false,
          ),
        ),
        onDidReceiveNotificationResponse: (response) {
          final route = response.payload;
          if (route != null && route.isNotEmpty) onDeeplink?.call(route);
        },
      );

      await _local
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >()
          ?.createNotificationChannel(_channel);

      FirebaseMessaging.onMessage.listen(_showForeground);
      FirebaseMessaging.onMessageOpenedApp.listen(_handleTap);

      // A push that launched the app from cold start is not delivered through
      // onMessageOpenedApp; it has to be pulled once, here.
      final initial = await _messaging.getInitialMessage();
      if (initial != null) _handleTap(initial);
    } catch (e, s) {
      log.e('notification init failed', e, s);
    }
  }

  /// Asks for permission and returns whether push is usable.
  ///
  /// Call this from a screen that has just explained *why* — a cold prompt on
  /// first launch is the single biggest cause of permanent denials, and on
  /// Android 13+ a denial cannot be re-prompted.
  Future<bool> requestPermission() async {
    try {
      final settings = await _messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );
      return settings.authorizationStatus == AuthorizationStatus.authorized ||
          settings.authorizationStatus == AuthorizationStatus.provisional;
    } catch (e) {
      log.w('push permission request failed', e);
      return false;
    }
  }

  /// The FCM token, or null when push is unavailable.
  ///
  /// The token is stored against the user by the auth trigger, not here —
  /// writing it needs an authenticated uid, which this class does not have.
  Future<String?> token() async {
    try {
      return await _messaging.getToken();
    } catch (e) {
      log.w('FCM token unavailable', e);
      return null;
    }
  }

  /// Fires whenever FCM rotates the token, which it does on reinstall and
  /// occasionally on its own. Without handling this, pushes stop silently.
  Stream<String> get tokenRefresh => _messaging.onTokenRefresh;

  Future<void> _showForeground(RemoteMessage message) async {
    final n = message.notification;
    if (n == null) return;
    try {
      await _local.show(
        message.hashCode,
        n.title,
        n.body,
        NotificationDetails(
          android: AndroidNotificationDetails(
            _channel.id,
            _channel.name,
            channelDescription: _channel.description,
            importance: Importance.high,
            priority: Priority.high,
            icon: '@mipmap/ic_launcher',
          ),
          iOS: const DarwinNotificationDetails(),
        ),
        payload: _routeOf(message),
      );
    } catch (e) {
      log.w('foreground notification failed', e);
    }
  }

  void _handleTap(RemoteMessage message) {
    final route = _routeOf(message);
    if (route != null && route.isNotEmpty) onDeeplink?.call(route);
  }

  /// Only ever an in-app route. A push payload is attacker-influenced in
  /// principle, so this never yields anything the app could treat as a URL.
  String? _routeOf(RemoteMessage message) {
    final raw = message.data['route'] ?? message.data['deeplink'];
    if (raw is! String || !raw.startsWith('/')) return null;
    return raw;
  }

  @visibleForTesting
  static String encodePayload(Map<String, dynamic> data) => jsonEncode(data);
}
