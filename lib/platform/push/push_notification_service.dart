import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide AuthState;

import '../../app/auth.dart';
import '../../app/supabase.dart';

/// The most recent remote focus command id delivered via silent push.
///
/// Set by [PushNotificationService] when iOS receives a silent push payload
/// containing `remote_focus_command_id`.
final pendingRemoteFocusCommandIdProvider =
    StateProvider<String?>((ref) => null);

final pushNotificationServiceProvider = Provider<PushNotificationService>((ref) {
  return PushNotificationService(ref);
});

class PushNotificationService {
  PushNotificationService(this._ref);

  final Ref _ref;

  static const MethodChannel _channel =
      MethodChannel('win_flutter/push_notifications');

  bool _initialized = false;
  ProviderSubscription<AsyncValue<AuthState>>? _authSub;

  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;

    // Only supported on iOS (APNs). Other platforms should no-op.
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.iOS) {
      return;
    }

    _channel.setMethodCallHandler(_handleMethodCall);

    // Always register for remote notifications on iOS (no user prompt required
    // for silent pushes; permissions are only needed for alert/badge/sound).
    await _safeInvoke<void>('register');

    // If a token already exists, sync it now.
    final token = await _safeInvoke<String>('getToken');
    if (token != null && token.trim().isNotEmpty) {
      await _upsertDeviceToken(token.trim());
    }

    // If a pending command was stored before Flutter booted, surface it.
    final pendingId = await _safeInvoke<String>('getPendingRemoteFocusCommandId');
    if (pendingId != null && pendingId.trim().isNotEmpty) {
      _ref.read(pendingRemoteFocusCommandIdProvider.notifier).state =
          pendingId.trim();
    }

    // Re-sync token on auth changes (e.g., user signs in later).
    _authSub ??= _ref.listen<AsyncValue<AuthState>>(authStateProvider,
        (previous, next) {
      final auth = next.valueOrNull;
      if (auth == null || !auth.isSignedIn || auth.isDemo) return;
      unawaited(() async {
        final t = await _safeInvoke<String>('getToken');
        if (t != null && t.trim().isNotEmpty) {
          await _upsertDeviceToken(t.trim());
        }
      }());
    });
    _ref.onDispose(() {
      _authSub?.close();
      _authSub = null;
    });
  }

  Future<void> clearPendingRemoteFocusCommandId() async {
    _ref.read(pendingRemoteFocusCommandIdProvider.notifier).state = null;
    await _safeInvoke<void>('clearPendingRemoteFocusCommandId');
  }

  Future<T?> _safeInvoke<T>(String method, [Object? args]) async {
    try {
      final res = await _channel.invokeMethod<T>(method, args);
      return res;
    } on MissingPluginException {
      return null;
    } catch (_) {
      return null;
    }
  }

  Future<void> _handleMethodCall(MethodCall call) async {
    switch (call.method) {
      case 'onToken':
        final token = (call.arguments as Map?)?['token'] as String?;
        if (token != null && token.trim().isNotEmpty) {
          await _upsertDeviceToken(token.trim());
        }
        return;

      case 'onRemoteFocusCommand':
        final id = (call.arguments as Map?)?['commandId'] as String?;
        if (id != null && id.trim().isNotEmpty) {
          _ref.read(pendingRemoteFocusCommandIdProvider.notifier).state =
              id.trim();
        }
        return;
    }
  }

  Future<void> _upsertDeviceToken(String token) async {
    // Only when Supabase is configured + user is signed in.
    final supabaseState = _ref.read(supabaseProvider);
    final auth = _ref.read(authStateProvider).valueOrNull;
    if (!supabaseState.isInitialized) return;
    if (auth == null || !auth.isSignedIn || auth.isDemo) return;

    final now = DateTime.now().toUtc().toIso8601String();
    final data = <String, Object?>{
      'user_id': Supabase.instance.client.auth.currentUser?.id,
      'platform': 'ios',
      'push_provider': 'apns',
      'push_token': token,
      'last_seen_at': now,
      'updated_at': now,
    };

    // If auth.currentUser is unexpectedly null, bail.
    if ((data['user_id'] as String?)?.isNotEmpty != true) return;

    try {
      await Supabase.instance.client.from('user_devices').upsert(
            data,
            onConflict: 'user_id,push_provider,push_token',
          );
    } catch (_) {
      // Best-effort: do not disrupt app startup.
    }
  }
}

