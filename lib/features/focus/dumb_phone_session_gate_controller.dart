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
    required this.cardRequired,
  });

  final bool sessionActive;
  final DateTime? sessionStartedAt;

  /// SHA-256 hash (hex) of the paired NFC tag.
  ///
  /// We store only the hash, never the raw tag data (NDEF contents or UID).
  final String? pairedCardKeyHash;

  final bool cardRequired;

  bool get hasPairedCard => pairedCardKeyHash != null && pairedCardKeyHash!.isNotEmpty;

  DumbPhoneSessionGateState copyWith({
    bool? sessionActive,
    Object? sessionStartedAt = _unset,
    Object? pairedCardKeyHash = _unset,
    bool? cardRequired,
  }) {
    return DumbPhoneSessionGateState(
      sessionActive: sessionActive ?? this.sessionActive,
      sessionStartedAt: (sessionStartedAt == _unset)
          ? this.sessionStartedAt
          : sessionStartedAt as DateTime?,
      pairedCardKeyHash: (pairedCardKeyHash == _unset)
          ? this.pairedCardKeyHash
          : pairedCardKeyHash as String?,
      cardRequired: cardRequired ?? this.cardRequired,
    );
  }
}

const Object _unset = Object();

final _secureStorageProvider = Provider<FlutterSecureStorage>((ref) {
  return const FlutterSecureStorage();
});

final dumbPhoneSessionGateControllerProvider = AsyncNotifierProvider<
    DumbPhoneSessionGateController, DumbPhoneSessionGateState>(
  DumbPhoneSessionGateController.new,
);

class DumbPhoneSessionGateController extends AsyncNotifier<DumbPhoneSessionGateState> {
  static const _kPairedCardKeyHash = 'dumb_phone_paired_card_key_hash_v1';
  static const _kCardRequired = 'settings_dumb_phone_card_required_v1';

  FlutterSecureStorage get _secure => ref.read(_secureStorageProvider);

  @override
  Future<DumbPhoneSessionGateState> build() async {
    final prefs = ref.watch(sharedPreferencesProvider);
    final engine = ref.watch(restrictionEngineProvider);

    final session = ref.watch(activeFocusSessionProvider).valueOrNull;
    final pairedHash = await _secure.read(key: _kPairedCardKeyHash);

    final stored = prefs.getBool(_kCardRequired);
    var cardRequired = stored ?? (pairedHash != null && pairedHash.isNotEmpty);

    // Persist the derived default so it survives restarts.
    if (stored == null) {
      await prefs.setBool(_kCardRequired, cardRequired);
    }

    // Safety rule: if the card is missing, cardRequired cannot be ON.
    if (pairedHash == null || pairedHash.isEmpty) {
      if (cardRequired) {
        cardRequired = false;
        await prefs.setBool(_kCardRequired, false);
      }
    }

    // Inform native layers (Android blocking screen) to disable any bypass paths.
    await engine.setCardRequired(required: cardRequired);

    return DumbPhoneSessionGateState(
      sessionActive: session?.isActive == true,
      sessionStartedAt: session?.startedAt,
      pairedCardKeyHash: pairedHash,
      cardRequired: cardRequired,
    );
  }

  Future<void> setCardRequired(BuildContext context, bool enabled) async {
    final prefs = ref.read(sharedPreferencesProvider);
    final engine = ref.read(restrictionEngineProvider);
    final current = state.valueOrNull;
    final hasPaired = current?.hasPairedCard == true;

    if (enabled && !hasPaired) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Pair a card to enable this setting.')),
        );
      }
      await prefs.setBool(_kCardRequired, false);
      await engine.setCardRequired(required: false);
      state = AsyncData((current ?? const DumbPhoneSessionGateState(
        sessionActive: false,
        sessionStartedAt: null,
        pairedCardKeyHash: null,
        cardRequired: false,
      ))
          .copyWith(cardRequired: false));
      return;
    }

    await prefs.setBool(_kCardRequired, enabled);
    await engine.setCardRequired(required: enabled);
    if (current != null) {
      state = AsyncData(current.copyWith(cardRequired: enabled));
    } else {
      ref.invalidateSelf();
    }
  }

  /// Remove the paired card hash from secure storage.
  ///
  /// Caller owns confirmation UI. This method enforces the edge case:
  /// if cardRequired was ON, it is automatically turned OFF.
  Future<void> unpairCard() async {
    final prefs = ref.read(sharedPreferencesProvider);
    final engine = ref.read(restrictionEngineProvider);
    await _secure.delete(key: _kPairedCardKeyHash);

    // If the requirement was enabled, automatically disable it.
    await prefs.setBool(_kCardRequired, false);
    await engine.setCardRequired(required: false);

    final current = state.valueOrNull;
    if (current != null) {
      state = AsyncData(
        current.copyWith(pairedCardKeyHash: null, cardRequired: false),
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
    final engine = ref.read(restrictionEngineProvider);
    await _secure.write(key: _kPairedCardKeyHash, value: hash);

    // Secure default: once paired, require the card unless user explicitly turns it off.
    await prefs.setBool(_kCardRequired, true);
    await engine.setCardRequired(required: true);

    final current = state.valueOrNull;
    if (current != null) {
      state = AsyncData(
        current.copyWith(pairedCardKeyHash: hash, cardRequired: true),
      );
    } else {
      ref.invalidateSelf();
    }
  }

  Future<bool> startSession({
    required BuildContext context,
    required String policyId,
    required Duration duration,
    required Future<bool> Function(BuildContext context) ensureCardValidated,
  }) async {
    final current = state.valueOrNull;
    if (current?.cardRequired == true) {
      final ok = await ensureCardValidated(context);
      if (!ok) return false;
    }

    return await ref.read(activeFocusSessionProvider.notifier).startSession(
          policyId: policyId,
          duration: duration,
        );
  }

  Future<void> endSession({
    required BuildContext context,
    required FocusSessionEndReason reason,
    required Future<bool> Function(BuildContext context) ensureCardValidated,
  }) async {
    final current = state.valueOrNull;
    if (current?.cardRequired == true) {
      final ok = await ensureCardValidated(context);
      if (!ok) return;
    }
    await ref.read(activeFocusSessionProvider.notifier).endSession(reason: reason);
  }
}

