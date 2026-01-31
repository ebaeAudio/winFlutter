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
  //
  // Security configuration:
  // - iOS: Keychain with "WhenUnlockedThisDeviceOnly" prevents backup/restore
  //   of credentials to a different device (mitigates device theft scenarios).
  // - Android: EncryptedSharedPreferences with AES-256-GCM encryption.
  //   resetOnError clears corrupted data rather than crashing.
  return const FlutterSecureStorage(
    iOptions: IOSOptions(
      accessibility: KeychainAccessibility.first_unlock_this_device,
      accountName: 'com.winFlutter.credentials',
    ),
    aOptions: AndroidOptions(
      encryptedSharedPreferences: true,
      resetOnError: true,
    ),
    mOptions: MacOsOptions(
      accessibility: KeychainAccessibility.first_unlock_this_device,
      accountName: 'com.winFlutter.credentials',
    ),
  );
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
    final raw = await _secure.read(key: _kApiKey);
    // Sanitize on read to fix iOS keychain issues with invisible characters.
    final apiKey = raw != null ? _sanitizeApiKey(raw) : null;
    final lastSyncAtMs = prefs.getInt(_kLastSyncAtMs);
    final lastSyncError = prefs.getString(_kLastSyncError);
    return LinearIntegrationState(
      apiKey: (apiKey?.isEmpty ?? true) ? null : apiKey,
      lastSyncAtMs: lastSyncAtMs,
      lastSyncError: lastSyncError,
    );
  }

  /// Sanitize API key by removing invisible Unicode characters.
  ///
  /// iOS copy-paste often introduces zero-width characters, non-breaking spaces,
  /// BOM markers, and other invisible Unicode that cause 401 errors.
  static String _sanitizeApiKey(String raw) {
    // Remove common invisible characters:
    // - BOM (U+FEFF)
    // - Zero-width space (U+200B)
    // - Zero-width non-joiner (U+200C)
    // - Zero-width joiner (U+200D)
    // - Non-breaking space (U+00A0)
    // - Soft hyphen (U+00AD)
    // - Word joiner (U+2060)
    // - Left-to-right/right-to-left marks
    final cleaned = raw
        .replaceAll('\u{FEFF}', '') // BOM
        .replaceAll('\u{200B}', '') // Zero-width space
        .replaceAll('\u{200C}', '') // Zero-width non-joiner
        .replaceAll('\u{200D}', '') // Zero-width joiner
        .replaceAll('\u{00A0}', ' ') // Non-breaking space → regular space
        .replaceAll('\u{00AD}', '') // Soft hyphen
        .replaceAll('\u{2060}', '') // Word joiner
        .replaceAll('\u{200E}', '') // Left-to-right mark
        .replaceAll('\u{200F}', '') // Right-to-left mark
        .replaceAll('\u{202A}', '') // Left-to-right embedding
        .replaceAll('\u{202B}', '') // Right-to-left embedding
        .replaceAll('\u{202C}', '') // Pop directional formatting
        .replaceAll('\u{202D}', '') // Left-to-right override
        .replaceAll('\u{202E}', '') // Right-to-left override
        .replaceAll('\r\n', '') // Windows newlines
        .replaceAll('\r', '') // Mac classic newlines
        .replaceAll('\n', '') // Unix newlines
        .trim();

    // Final pass: keep only printable ASCII + underscore (Linear keys are ASCII-only)
    final buffer = StringBuffer();
    for (final char in cleaned.codeUnits) {
      // Allow: 0-9 (48-57), A-Z (65-90), a-z (97-122), underscore (95)
      if ((char >= 48 && char <= 57) ||
          (char >= 65 && char <= 90) ||
          (char >= 97 && char <= 122) ||
          char == 95) {
        buffer.writeCharCode(char);
      }
    }
    return buffer.toString();
  }

  /// Validate Linear API key format.
  ///
  /// Linear personal API keys start with `lin_api_` and OAuth tokens with `lin_oauth_`.
  static bool isValidLinearKeyFormat(String key) {
    return key.startsWith('lin_api_') || key.startsWith('lin_oauth_');
  }

  Future<void> saveApiKey(String apiKey) async {
    final sanitized = _sanitizeApiKey(apiKey);
    if (sanitized.isEmpty) {
      await clearApiKey();
      return;
    }
    await _secure.write(key: _kApiKey, value: sanitized);
    final current = state.valueOrNull;
    if (current != null) {
      state = AsyncData(current.copyWith(apiKey: sanitized));
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

