import 'package:supabase_flutter/supabase_flutter.dart';

import '../../domain/focus/focus_session.dart';

/// Remote sync layer for focus sessions using Supabase.
///
/// The `focus_active_sessions` table stores at most one row per user.
/// When a session starts, we upsert; when it ends, we delete.
///
/// This allows cross-device visibility: start a session on iPhone,
/// see the countdown on macOS.
class SupabaseFocusSessionSync {
  SupabaseFocusSessionSync(this._client);

  final SupabaseClient _client;

  static const _table = 'focus_active_sessions';

  String? _requireUserId() {
    final session = _client.auth.currentSession;
    final uid = session?.user.id;
    if (uid == null || uid.isEmpty) return null;
    return uid;
  }

  /// Detect current platform for `source_platform` metadata.
  static String get currentPlatform {
    // Use dart:io Platform if available, otherwise assume web.
    try {
      // ignore: avoid_dynamic_calls
      return _detectPlatform();
    } catch (_) {
      return 'unknown';
    }
  }

  static String _detectPlatform() {
    // We import dart:io conditionally via the main app,
    // but here we use a simple approach based on what's available.
    // This will be set by the caller in practice.
    return 'flutter';
  }

  /// Fetch the current active session from Supabase (if any).
  ///
  /// Returns null if no session exists, user is not signed in,
  /// or the table doesn't exist yet.
  Future<RemoteFocusSession?> getActiveSession() async {
    final uid = _requireUserId();
    if (uid == null) return null;

    try {
      final row = await _client
          .from(_table)
          .select()
          .eq('user_id', uid)
          .maybeSingle();

      if (row == null) return null;
      return _fromRow(row);
    } on PostgrestException catch (e) {
      // Table might not exist yet (migration not applied).
      if (_isMissingTable(e)) return null;
      rethrow;
    }
  }

  /// Upsert the active session to Supabase.
  ///
  /// Call this when starting or updating a session.
  Future<void> saveActiveSession(
    FocusSession session, {
    required String sourcePlatform,
  }) async {
    final uid = _requireUserId();
    if (uid == null) return;

    final data = <String, Object?>{
      'user_id': uid,
      'session_id': session.id,
      'policy_id': session.policyId,
      'started_at': session.startedAt.toUtc().toIso8601String(),
      'planned_end_at': session.plannedEndAt.toUtc().toIso8601String(),
      'emergency_unlocks_used': session.emergencyUnlocksUsed,
      'source_platform': sourcePlatform,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    };

    try {
      await _client.from(_table).upsert(data, onConflict: 'user_id');
    } on PostgrestException catch (e) {
      // Silently ignore if table doesn't exist.
      if (_isMissingTable(e)) return;
      rethrow;
    }
  }

  /// Delete the active session from Supabase.
  ///
  /// Call this when a session ends (completed, early exit, etc).
  Future<void> clearActiveSession() async {
    final uid = _requireUserId();
    if (uid == null) return;

    try {
      await _client.from(_table).delete().eq('user_id', uid);
    } on PostgrestException catch (e) {
      if (_isMissingTable(e)) return;
      rethrow;
    }
  }

  static bool _isMissingTable(PostgrestException e) {
    final msg = e.message.toLowerCase();
    final details = (e.details?.toString() ?? '').toLowerCase();
    final hint = (e.hint?.toString() ?? '').toLowerCase();
    final combined = '$msg $details $hint';
    return combined.contains('could not find the table') ||
        combined.contains('relation') && combined.contains('does not exist') ||
        combined.contains('not found') && combined.contains('focus_active_sessions');
  }

  RemoteFocusSession _fromRow(Map<String, Object?> row) {
    final startedAtRaw = row['started_at'] as String?;
    final plannedEndAtRaw = row['planned_end_at'] as String?;
    final updatedAtRaw = row['updated_at'] as String?;

    return RemoteFocusSession(
      sessionId: (row['session_id'] as String?) ?? '',
      policyId: (row['policy_id'] as String?) ?? '',
      startedAt: startedAtRaw != null
          ? DateTime.parse(startedAtRaw).toLocal()
          : DateTime.now(),
      plannedEndAt: plannedEndAtRaw != null
          ? DateTime.parse(plannedEndAtRaw).toLocal()
          : DateTime.now(),
      emergencyUnlocksUsed:
          (row['emergency_unlocks_used'] as num?)?.toInt() ?? 0,
      sourcePlatform: (row['source_platform'] as String?) ?? 'unknown',
      updatedAt: updatedAtRaw != null
          ? DateTime.parse(updatedAtRaw).toLocal()
          : DateTime.now(),
    );
  }
}

/// A focus session fetched from the remote Supabase table.
///
/// Includes metadata like `sourcePlatform` to show "Started on iPhone".
class RemoteFocusSession {
  const RemoteFocusSession({
    required this.sessionId,
    required this.policyId,
    required this.startedAt,
    required this.plannedEndAt,
    required this.emergencyUnlocksUsed,
    required this.sourcePlatform,
    required this.updatedAt,
  });

  final String sessionId;
  final String policyId;
  final DateTime startedAt;
  final DateTime plannedEndAt;
  final int emergencyUnlocksUsed;

  /// Platform that started the session: "iOS", "macOS", "android", etc.
  final String sourcePlatform;

  /// Last time this record was updated in Supabase.
  final DateTime updatedAt;

  bool get isActive => DateTime.now().isBefore(plannedEndAt);

  Duration get remaining {
    final now = DateTime.now();
    final rem = plannedEndAt.difference(now);
    return rem.isNegative ? Duration.zero : rem;
  }

  /// Convert to a [FocusSession] for use with existing UI/controllers.
  FocusSession toFocusSession() => FocusSession(
        id: sessionId,
        policyId: policyId,
        startedAt: startedAt,
        plannedEndAt: plannedEndAt,
        status: isActive ? FocusSessionStatus.active : FocusSessionStatus.ended,
        emergencyUnlocksUsed: emergencyUnlocksUsed,
      );

  /// User-friendly platform label for UI.
  String get platformLabel {
    switch (sourcePlatform.toLowerCase()) {
      case 'ios':
        return 'iPhone';
      case 'macos':
        return 'Mac';
      case 'android':
        return 'Android';
      case 'web':
        return 'Web';
      default:
        return sourcePlatform;
    }
  }
}
