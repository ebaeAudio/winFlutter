import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../app/theme.dart' show sharedPreferencesProvider;
import '../../domain/focus/focus_session.dart';
import 'focus_providers.dart';
import 'focus_session_controller.dart';

@immutable
class DumbPhoneSessionGateState {
  const DumbPhoneSessionGateState({
    required this.sessionActive,
    required this.sessionStartedAt,
    required this.pairedCardKeyHash,
    required this.requireCardToEndEarly,
    required this.requireSelfieToEndEarly,
    required this.requireCardToStart,
  });

  final bool sessionActive;
  final DateTime? sessionStartedAt;

  /// SHA-256 hash (hex) of the paired NFC tag.
  ///
  /// We store only the hash, never the raw tag data (NDEF contents or UID).
  final String? pairedCardKeyHash;

  /// Optional friction: when ON, ending a session early requires scanning the
  /// paired card. Normal timer completion still ends automatically.
  final bool requireCardToEndEarly;

  /// Optional friction: when ON, ending a session early requires taking a selfie
  /// (camera capture + explicit confirmation). Normal timer completion still ends
  /// automatically.
  final bool requireSelfieToEndEarly;

  /// (Future) Require scanning the paired card to start a session.
  ///
  /// v1: always false; start remains software-driven via UI.
  final bool requireCardToStart;

  bool get hasPairedCard => pairedCardKeyHash != null && pairedCardKeyHash!.isNotEmpty;

  DumbPhoneSessionGateState copyWith({
    bool? sessionActive,
    Object? sessionStartedAt = _unset,
    Object? pairedCardKeyHash = _unset,
    bool? requireCardToEndEarly,
    bool? requireSelfieToEndEarly,
    bool? requireCardToStart,
  }) {
    return DumbPhoneSessionGateState(
      sessionActive: sessionActive ?? this.sessionActive,
      sessionStartedAt: (sessionStartedAt == _unset)
          ? this.sessionStartedAt
          : sessionStartedAt as DateTime?,
      pairedCardKeyHash: (pairedCardKeyHash == _unset)
          ? this.pairedCardKeyHash
          : pairedCardKeyHash as String?,
      requireCardToEndEarly: requireCardToEndEarly ?? this.requireCardToEndEarly,
      requireSelfieToEndEarly:
          requireSelfieToEndEarly ?? this.requireSelfieToEndEarly,
      requireCardToStart: requireCardToStart ?? this.requireCardToStart,
    );
  }
}

const Object _unset = Object();

final _secureStorageProvider = Provider<FlutterSecureStorage>((ref) {
  // Intentionally non-const so widget/unit tests can replace
  // `FlutterSecureStoragePlatform.instance` before the first instance is created.
  return FlutterSecureStorage();
});

final dumbPhoneSessionGateControllerProvider = AsyncNotifierProvider<
    DumbPhoneSessionGateController, DumbPhoneSessionGateState>(
  DumbPhoneSessionGateController.new,
);

class DumbPhoneSessionGateController extends AsyncNotifier<DumbPhoneSessionGateState> {
  static const _kPairedCardKeyHash = 'dumb_phone_paired_card_key_hash_v1';
  // New split flags (v1 for this split).
  static const _kRequireCardToEndEarly =
      'settings_dumb_phone_require_card_to_end_early_v1';
  static const _kRequireSelfieToEndEarly =
      'settings_dumb_phone_require_selfie_to_end_early_v1';
  static const _kRequireCardToStart =
      'settings_dumb_phone_require_card_to_start_v1';

  // Legacy combined flag (start + end).
  // Migration rule: legacy=true -> requireCardToEndEarly=true, requireCardToStart=false.
  static const _kLegacyCardRequired = 'settings_dumb_phone_card_required_v1';

  FlutterSecureStorage get _secure => ref.read(_secureStorageProvider);

  @override
  Future<DumbPhoneSessionGateState> build() async {
    final prefs = ref.watch(sharedPreferencesProvider);
    final engine = ref.watch(restrictionEngineProvider);

    final session = ref.watch(activeFocusSessionProvider).valueOrNull;
    final pairedHash = await _secure.read(key: _kPairedCardKeyHash);

    // v1 default: OFF (optional friction).
    // If upgrading from a legacy combined flag, map it to end-early only.
    final storedEnd = prefs.getBool(_kRequireCardToEndEarly);
    final storedStart = prefs.getBool(_kRequireCardToStart);

    bool requireEndEarly;
    if (storedEnd != null) {
      requireEndEarly = storedEnd;
    } else {
      final legacy = prefs.getBool(_kLegacyCardRequired);
      requireEndEarly = legacy ?? false;
      // Best-effort persistence; don't block provider initialization.
      unawaited(prefs.setBool(_kRequireCardToEndEarly, requireEndEarly));
    }

    // v1 default: OFF (optional friction).
    final requireSelfieEndEarly =
        prefs.getBool(_kRequireSelfieToEndEarly) ?? false;

    // v1: never require card to start.
    final requireStart = storedStart ?? false;
    if (storedStart == null) {
      // Best-effort persistence; don't block provider initialization.
      unawaited(prefs.setBool(_kRequireCardToStart, false));
    }

    // Safety rule: if the card is missing, requireEndEarly cannot be ON.
    if (pairedHash == null || pairedHash.isEmpty) {
      if (requireEndEarly) {
        requireEndEarly = false;
        // Best-effort persistence; don't block provider initialization.
        unawaited(prefs.setBool(_kRequireCardToEndEarly, false));
      }
    }

    // Inform native layers (Android blocking screen) to disable any native bypass
    // controls when end-early card friction is ON.
    unawaited(engine.setCardRequired(required: requireEndEarly));

    return DumbPhoneSessionGateState(
      sessionActive: session?.isActive == true,
      sessionStartedAt: session?.startedAt,
      pairedCardKeyHash: pairedHash,
      requireCardToEndEarly: requireEndEarly,
      requireSelfieToEndEarly: requireSelfieEndEarly,
      requireCardToStart: requireStart,
    );
  }

  Future<void> setRequireCardToEndEarly(BuildContext context, bool enabled) async {
    final prefs = ref.read(sharedPreferencesProvider);
    final engine = ref.read(restrictionEngineProvider);
    final current = state.valueOrNull;
    final hasPaired = current?.hasPairedCard == true;
    final sessionActive = current?.sessionActive == true;

    if (sessionActive) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('You can change this after the current session ends.'),
          ),
        );
      }
      return;
    }

    if (enabled && !hasPaired) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Pair a card to enable this setting.')),
        );
      }
      await prefs.setBool(_kRequireCardToEndEarly, false);
      await engine.setCardRequired(required: false);
      state = AsyncData(
        (current ??
                const DumbPhoneSessionGateState(
                  sessionActive: false,
                  sessionStartedAt: null,
                  pairedCardKeyHash: null,
                  requireCardToEndEarly: false,
                  requireSelfieToEndEarly: false,
                  requireCardToStart: false,
                ))
            .copyWith(requireCardToEndEarly: false),
      );
      return;
    }

    await prefs.setBool(_kRequireCardToEndEarly, enabled);
    await engine.setCardRequired(required: enabled);
    if (current != null) {
      state = AsyncData(current.copyWith(requireCardToEndEarly: enabled));
    } else {
      ref.invalidateSelf();
    }
  }

  Future<void> setRequireSelfieToEndEarly(
    BuildContext context,
    bool enabled,
  ) async {
    if (kIsWeb && enabled) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Selfie verification is not supported on web.'),
          ),
        );
      }
      return;
    }

    final prefs = ref.read(sharedPreferencesProvider);
    final current = state.valueOrNull;
    final sessionActive = current?.sessionActive == true;

    if (sessionActive) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('You can change this after the current session ends.'),
          ),
        );
      }
      return;
    }

    await prefs.setBool(_kRequireSelfieToEndEarly, enabled);
    if (current != null) {
      state = AsyncData(current.copyWith(requireSelfieToEndEarly: enabled));
    } else {
      ref.invalidateSelf();
    }
  }

  /// Remove the paired card hash from secure storage.
  ///
  /// Caller owns confirmation UI. This method enforces the edge case:
  /// if requireCardToEndEarly was ON, it is automatically turned OFF.
  Future<void> unpairCard() async {
    final prefs = ref.read(sharedPreferencesProvider);
    final engine = ref.read(restrictionEngineProvider);
    await _secure.delete(key: _kPairedCardKeyHash);

    // If the requirement was enabled, automatically disable it.
    await prefs.setBool(_kRequireCardToEndEarly, false);
    await engine.setCardRequired(required: false);

    final current = state.valueOrNull;
    if (current != null) {
      state = AsyncData(
        current.copyWith(pairedCardKeyHash: null, requireCardToEndEarly: false),
      );
    } else {
      ref.invalidateSelf();
    }
  }

  /// Save a newly paired card hash.
  ///
  /// Caller owns the pairing scan flow and any UI.
  Future<void> savePairedCardHash(String hash) async {
    final prefs = ref.read(sharedPreferencesProvider);
    await _secure.write(key: _kPairedCardKeyHash, value: hash);

    // v1: default is OFF. Pairing only enables the *ability* to turn the setting ON.
    // If the user already enabled it, keep it enabled through replace.
    final requireEndEarly =
        prefs.getBool(_kRequireCardToEndEarly) ??
        prefs.getBool(_kLegacyCardRequired) ??
        false;
    await prefs.setBool(_kRequireCardToEndEarly, requireEndEarly);

    final current = state.valueOrNull;
    if (current != null) {
      state = AsyncData(
        current.copyWith(
          pairedCardKeyHash: hash,
          requireCardToEndEarly: requireEndEarly,
        ),
      );
    } else {
      ref.invalidateSelf();
    }
  }

  Future<bool> startSession({
    required BuildContext context,
    required String policyId,
    Duration? duration,
    DateTime? endsAt,
  }) async {
    return await ref.read(activeFocusSessionProvider.notifier).startSession(
          policyId: policyId,
          duration: duration,
          endsAt: endsAt,
        );
  }

  Future<void> endSession({
    required BuildContext context,
    required FocusSessionEndReason reason,
    required Future<bool> Function(BuildContext context) ensureCardValidated,
    required Future<bool> Function(BuildContext context) ensureSelfieValidated,
  }) async {
    final current = state.valueOrNull;
    if (current?.requireCardToEndEarly == true &&
        reason == FocusSessionEndReason.userEarlyExit) {
      final ok = await ensureCardValidated(context);
      if (!ok) return;
    }
    if (current?.requireSelfieToEndEarly == true &&
        reason == FocusSessionEndReason.userEarlyExit) {
      final ok = await ensureSelfieValidated(context);
      if (!ok) return;
    }
    await ref.read(activeFocusSessionProvider.notifier).endSession(reason: reason);
  }
}

