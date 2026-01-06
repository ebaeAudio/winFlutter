import 'package:flutter/services.dart';

import '../../domain/focus/app_identifier.dart';
import '../../domain/focus/focus_friction.dart';
import 'restriction_engine.dart';

/// Method-channel implementation.
///
/// Channel contract (initial scaffold):
/// - getPermissions -> {isSupported, isAuthorized, needsOnboarding, platformDetails}
/// - requestPermissions -> void
/// - configureApps -> void (iOS: show app picker; Android: no-op)
/// - startSession -> void (args: endsAtMillis, allowedApps[], friction{})
/// - endSession -> void
/// - startEmergencyException -> void (args: durationMillis)
class MethodChannelRestrictionEngine implements RestrictionEngine {
  const MethodChannelRestrictionEngine();

  static const _channel = MethodChannel('win_flutter/restriction_engine');

  @override
  Future<RestrictionPermissions> getPermissions() async {
    try {
      final raw =
          await _channel.invokeMapMethod<String, Object?>('getPermissions');
      return RestrictionPermissions(
        isSupported: (raw?['isSupported'] as bool?) ?? false,
        isAuthorized: (raw?['isAuthorized'] as bool?) ?? false,
        needsOnboarding: (raw?['needsOnboarding'] as bool?) ?? true,
        platformDetails: (raw?['platformDetails'] as String?) ?? '',
      );
    } on MissingPluginException {
      return const RestrictionPermissions(
        isSupported: false,
        isAuthorized: false,
        needsOnboarding: true,
        platformDetails: 'Restriction engine not available on this platform.',
      );
    }
  }

  @override
  Future<void> requestPermissions() async {
    try {
      await _channel.invokeMethod<void>('requestPermissions');
    } on MissingPluginException {
      // No-op.
    }
  }

  @override
  Future<void> configureApps() async {
    try {
      await _channel.invokeMethod<void>('configureApps');
    } on MissingPluginException {
      // No-op.
    }
  }

  @override
  Future<void> startSession({
    required DateTime endsAt,
    required List<AppIdentifier> allowedApps,
    required FocusFrictionSettings friction,
  }) async {
    try {
      await _channel.invokeMethod<void>('startSession', {
        'endsAtMillis': endsAt.millisecondsSinceEpoch,
        'allowedApps': allowedApps.map((a) => a.toJson()).toList(growable: false),
        'friction': friction.toJson(),
      });
    } on MissingPluginException {
      // No-op.
    }
  }

  @override
  Future<void> endSession() async {
    try {
      await _channel.invokeMethod<void>('endSession');
    } on MissingPluginException {
      // No-op.
    }
  }

  @override
  Future<void> startEmergencyException({required Duration duration}) async {
    try {
      await _channel.invokeMethod<void>('startEmergencyException', {
        'durationMillis': duration.inMilliseconds,
      });
    } on MissingPluginException {
      // No-op.
    }
  }
}


