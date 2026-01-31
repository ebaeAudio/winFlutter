import 'dart:io' show Platform;

import 'package:shared_preferences/shared_preferences.dart';

import '../../domain/focus/focus_session.dart';
import 'focus_session_repository.dart';
import 'local_focus_session_repository.dart';
import 'supabase_focus_session_sync.dart';

/// A [FocusSessionRepository] that syncs active sessions to Supabase.
///
/// - Reads from both local storage and Supabase remote.
/// - For active session: local is authoritative for the device that started it,
///   but other devices can see the session via Supabase.
/// - History is local-only (not synced to Supabase).
class SyncedFocusSessionRepository implements FocusSessionRepository {
  SyncedFocusSessionRepository({
    required SharedPreferences prefs,
    required SupabaseFocusSessionSync remoteSync,
  })  : _local = LocalFocusSessionRepository(prefs),
        _remote = remoteSync;

  final LocalFocusSessionRepository _local;
  final SupabaseFocusSessionSync _remote;

  /// The last fetched remote session (cached for quick access).
  RemoteFocusSession? _cachedRemoteSession;

  /// Get the cached remote session metadata (e.g., for showing platform label).
  RemoteFocusSession? get cachedRemoteSession => _cachedRemoteSession;

  /// Get the current platform name for source_platform metadata.
  String get _currentPlatform {
    try {
      if (Platform.isIOS) return 'iOS';
      if (Platform.isMacOS) return 'macOS';
      if (Platform.isAndroid) return 'android';
      if (Platform.isLinux) return 'linux';
      if (Platform.isWindows) return 'windows';
    } catch (_) {
      // Platform not available (web)
    }
    return 'web';
  }

  @override
  Future<FocusSession?> getActiveSession() async {
    // First check local storage (authoritative for this device).
    final local = await _local.getActiveSession();
    if (local != null && local.isActive) {
      _cachedRemoteSession = null;
      return local;
    }

    // No local session - check remote for sessions from other devices.
    final remote = await _remote.getActiveSession();
    if (remote != null && remote.isActive) {
      _cachedRemoteSession = remote;
      return remote.toFocusSession();
    }

    _cachedRemoteSession = null;
    return null;
  }

  /// Fetch only the remote session without checking local.
  ///
  /// Useful for macOS to poll for iPhone sessions without interfering
  /// with local session state.
  Future<RemoteFocusSession?> getRemoteSession() async {
    final remote = await _remote.getActiveSession();
    if (remote != null && remote.isActive) {
      _cachedRemoteSession = remote;
      return remote;
    }
    _cachedRemoteSession = null;
    return null;
  }

  @override
  Future<void> saveActiveSession(FocusSession session) async {
    // Save locally first (authoritative).
    await _local.saveActiveSession(session);

    // Then sync to Supabase (best-effort, non-blocking for UX).
    // We don't await this to avoid slowing down the start flow.
    _remote.saveActiveSession(
      session,
      sourcePlatform: _currentPlatform,
    );
  }

  @override
  Future<void> clearActiveSession() async {
    // Clear locally first.
    await _local.clearActiveSession();

    // Clear from Supabase.
    await _remote.clearActiveSession();

    _cachedRemoteSession = null;
  }

  // History operations remain local-only.

  @override
  Future<List<FocusSession>> listHistory() => _local.listHistory();

  @override
  Future<void> appendToHistory(FocusSession session) =>
      _local.appendToHistory(session);

  @override
  Future<void> clearHistory() => _local.clearHistory();
}
