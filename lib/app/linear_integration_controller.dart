import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../app/theme.dart' show sharedPreferencesProvider;
import '../data/linear/linear_client.dart';

@immutable
class LinearIntegrationState {
  const LinearIntegrationState({
    required this.apiKey,
    required this.lastSyncAtMs,
    required this.lastSyncError,
  });

  /// Stored in OS keychain/keystore. Null/empty means not configured.
  final String? apiKey;

  /// Stored in SharedPreferences (best-effort status visibility).
  final int? lastSyncAtMs;
  final String? lastSyncError;

  bool get hasApiKey => (apiKey ?? '').trim().isNotEmpty;

  String get maskedApiKey {
    final raw = (apiKey ?? '').trim();
    if (raw.isEmpty) return '';
    if (raw.length <= 8) return '••••••••';
    final tail = raw.substring(raw.length - 4);
    return '•••• •••• •••• $tail';
  }

  LinearIntegrationState copyWith({
    Object? apiKey = _unset,
    Object? lastSyncAtMs = _unset,
    Object? lastSyncError = _unset,
  }) {
    return LinearIntegrationState(
      apiKey: apiKey == _unset ? this.apiKey : apiKey as String?,
      lastSyncAtMs:
          lastSyncAtMs == _unset ? this.lastSyncAtMs : lastSyncAtMs as int?,
      lastSyncError: lastSyncError == _unset
          ? this.lastSyncError
          : lastSyncError as String?,
    );
  }
}

const Object _unset = Object();

final _secureStorageProvider = Provider<FlutterSecureStorage>((ref) {
  // Intentionally non-const so widget/unit tests can replace
  // `FlutterSecureStoragePlatform.instance` before the first instance is created.
  return const FlutterSecureStorage();
});

final linearIntegrationControllerProvider = AsyncNotifierProvider<
    LinearIntegrationController, LinearIntegrationState>(
  LinearIntegrationController.new,
);

class LinearIntegrationController extends AsyncNotifier<LinearIntegrationState> {
  static const _kApiKey = 'linear_personal_api_key_v1';
  static const _kLastSyncAtMs = 'linear_last_sync_at_ms_v1';
  static const _kLastSyncError = 'linear_last_sync_error_v1';

  FlutterSecureStorage get _secure => ref.read(_secureStorageProvider);

  @override
  Future<LinearIntegrationState> build() async {
    final prefs = ref.watch(sharedPreferencesProvider);
    final apiKey = await _secure.read(key: _kApiKey);
    final lastSyncAtMs = prefs.getInt(_kLastSyncAtMs);
    final lastSyncError = prefs.getString(_kLastSyncError);
    return LinearIntegrationState(
      apiKey: apiKey,
      lastSyncAtMs: lastSyncAtMs,
      lastSyncError: lastSyncError,
    );
  }

  Future<void> saveApiKey(String apiKey) async {
    final trimmed = apiKey.trim();
    if (trimmed.isEmpty) {
      await clearApiKey();
      return;
    }
    await _secure.write(key: _kApiKey, value: trimmed);
    final current = state.valueOrNull;
    if (current != null) {
      state = AsyncData(current.copyWith(apiKey: trimmed));
    } else {
      ref.invalidateSelf();
    }
  }

  Future<void> clearApiKey() async {
    await _secure.delete(key: _kApiKey);
    final current = state.valueOrNull;
    if (current != null) {
      state = AsyncData(current.copyWith(apiKey: null));
    } else {
      ref.invalidateSelf();
    }
  }

  Future<void> recordSyncStatus({required DateTime at, String? error}) async {
    final prefs = ref.read(sharedPreferencesProvider);
    await prefs.setInt(_kLastSyncAtMs, at.millisecondsSinceEpoch);
    if (error == null || error.trim().isEmpty) {
      await prefs.remove(_kLastSyncError);
    } else {
      await prefs.setString(_kLastSyncError, error.trim());
    }

    final current = state.valueOrNull;
    if (current != null) {
      state = AsyncData(
        current.copyWith(
          lastSyncAtMs: at.millisecondsSinceEpoch,
          lastSyncError: (error == null || error.trim().isEmpty)
              ? null
              : error.trim(),
        ),
      );
    }
  }

  /// Lightweight connectivity check.
  ///
  /// Uses Linear GraphQL `viewer` query to validate the key.
  Future<LinearViewer> testConnection() async {
    final current = state.valueOrNull;
    final key = (current?.apiKey ?? '').trim();
    if (key.isEmpty) throw StateError('Linear API key not set');
    final client = LinearClient(apiKey: key);
    // We parse only a few fields; keep it deterministic.
    final viewer = await client.fetchViewer();
    // Store a success marker (clear error).
    await recordSyncStatus(at: DateTime.now(), error: null);
    return viewer;
  }

  /// For debugging/support: export a minimal status blob (no secrets).
  String exportStatusJson() {
    final s = state.valueOrNull;
    return jsonEncode({
      'hasApiKey': s?.hasApiKey == true,
      'lastSyncAtMs': s?.lastSyncAtMs,
      'lastSyncError': s?.lastSyncError,
    });
  }
}

