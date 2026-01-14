import 'dart:async';
import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

/// Stores a pending in-app route that should be navigated to.
///
/// This is written by [NotificationService] when a notification is tapped and
/// consumed by the root app widget (which has access to the [GoRouter]).
final pendingNotificationRouteProvider = StateProvider<String?>((ref) => null);

final notificationServiceProvider = Provider<NotificationService>((ref) {
  return NotificationService();
});

int notificationIdForFocusSession(String sessionId) {
  final bytes = sha256.convert(utf8.encode(sessionId)).bytes;
  final raw =
      (bytes[0] << 24) | (bytes[1] << 16) | (bytes[2] << 8) | bytes[3];
  // Ensure a positive 31-bit id to keep things simple across platforms.
  return raw & 0x7fffffff;
}

class NotificationService {
  NotificationService();

  static const String _channelId = 'focus_session';
  static const String _channelName = 'Focus sessions';
  static const String _channelDescription =
      'Notifications when a Dumb Phone session completes.';

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;

  Future<void> init({required void Function(String route) onDeepLink}) async {
    if (_initialized) return;
    _initialized = true;

    // Time zone init for exact scheduling. Best-effort: if it fails we still
    // allow immediate notifications and skip scheduling.
    try {
      tzdata.initializeTimeZones();
      final tzName = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(tzName));
    } catch (_) {
      // Ignore; scheduling will be best-effort.
    }

    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const darwinInit = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );

    await _plugin.initialize(
      const InitializationSettings(
        android: androidInit,
        iOS: darwinInit,
        macOS: darwinInit,
      ),
      onDidReceiveNotificationResponse: (response) {
        final route = _routeFromPayload(response.payload);
        if (route != null) onDeepLink(route);
      },
    );

    // Android channel.
    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    if (android != null) {
      await android.createNotificationChannel(
        const AndroidNotificationChannel(
          _channelId,
          _channelName,
          description: _channelDescription,
          importance: Importance.high,
        ),
      );
    }

    // If the app was launched from a notification tap, surface it as a deep link.
    final details = await _plugin.getNotificationAppLaunchDetails();
    final launchedPayload = details?.notificationResponse?.payload;
    final route = _routeFromPayload(launchedPayload);
    if (route != null) onDeepLink(route);
  }

  Future<bool> _ensurePermissions() async {
    // Web: no local notifications.
    if (kIsWeb) return false;

    if (defaultTargetPlatform == TargetPlatform.iOS) {
      final ios = _plugin.resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin>();
      final granted =
          await ios?.requestPermissions(alert: true, badge: true, sound: true);
      return granted ?? false;
    }

    if (defaultTargetPlatform == TargetPlatform.macOS) {
      final macos = _plugin.resolvePlatformSpecificImplementation<
          MacOSFlutterLocalNotificationsPlugin>();
      final granted = await macos?.requestPermissions(
        alert: true,
        badge: true,
        sound: true,
      );
      return granted ?? false;
    }

    if (defaultTargetPlatform == TargetPlatform.android) {
      final android = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      // On Android < 13 this typically resolves to true/no-op.
      final granted = await android?.requestNotificationsPermission();
      return granted ?? true;
    }

    return true;
  }

  Future<void> scheduleFocusSessionComplete({
    required int notificationId,
    required DateTime endsAt,
    required String title,
    required String body,
    required String route,
  }) async {
    final ok = await _ensurePermissions();
    if (!ok) return;

    // If TZ init failed we can't reliably schedule; skip rather than scheduling
    // at an incorrect time zone.
    tz.TZDateTime? when;
    try {
      when = tz.TZDateTime.from(endsAt, tz.local);
    } catch (_) {
      when = null;
    }
    if (when == null) return;

    final now = tz.TZDateTime.now(tz.local);
    if (!when.isAfter(now)) return;

    await _plugin.zonedSchedule(
      notificationId,
      title,
      body,
      when,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          _channelId,
          _channelName,
          channelDescription: _channelDescription,
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(),
        macOS: DarwinNotificationDetails(),
      ),
      payload: route,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
    );
  }

  Future<void> cancel(int notificationId) async {
    await _plugin.cancel(notificationId);
  }

  static String? _routeFromPayload(String? payload) {
    if (payload == null || payload.trim().isEmpty) return null;
    final uri = Uri.tryParse(payload.trim());
    if (uri == null) return null;
    // Keep this intentionally strict: only allow app-internal relative paths.
    if (!uri.toString().startsWith('/')) return null;
    if (uri.hasScheme || uri.hasAuthority) return null;
    return uri.toString();
  }
}

