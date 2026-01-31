import 'package:supabase_flutter/supabase_flutter.dart';

class RemoteFocusCommand {
  const RemoteFocusCommand({
    required this.id,
    required this.userId,
    required this.command,
    required this.policyId,
    required this.durationMinutes,
    required this.status,
    required this.createdAt,
  });

  final String id;
  final String userId;
  final String command; // "start" | "stop"
  final String? policyId;
  final int? durationMinutes;
  final String status; // "pending" | "processing" | "completed" | "failed" | "expired"
  final DateTime createdAt;

  static RemoteFocusCommand fromRow(Map<String, Object?> row) {
    final createdAtRaw = row['created_at'] as String?;
    return RemoteFocusCommand(
      id: (row['id'] as String?) ?? '',
      userId: (row['user_id'] as String?) ?? '',
      command: (row['command'] as String?) ?? '',
      policyId: row['policy_id'] as String?,
      durationMinutes: (row['duration_minutes'] as num?)?.toInt(),
      status: (row['status'] as String?) ?? '',
      createdAt: createdAtRaw != null
          ? DateTime.parse(createdAtRaw).toLocal()
          : DateTime.now(),
    );
  }
}

class RemoteFocusCommandRepository {
  RemoteFocusCommandRepository(this._client);

  final SupabaseClient _client;

  static const _table = 'remote_focus_commands';

  Future<RemoteFocusCommand?> getById(String id) async {
    final row =
        await _client.from(_table).select().eq('id', id).maybeSingle();
    if (row == null) return null;
    return RemoteFocusCommand.fromRow(row);
  }

  /// Atomically claim a pending command for processing.
  ///
  /// Returns true only for the first caller that transitions it pending->processing.
  Future<bool> markProcessing(String id) async {
    final rows = await _client
        .from(_table)
        .update({
          'status': 'processing',
          'processed_at': DateTime.now().toUtc().toIso8601String(),
        })
        .eq('id', id)
        .eq('status', 'pending')
        .select('id');
    return (rows as List).isNotEmpty;
  }

  Future<void> markCompleted(String id) async {
    await _client.from(_table).update({
      'status': 'completed',
      'processed_at': DateTime.now().toUtc().toIso8601String(),
      'error_message': null,
    }).eq('id', id);
  }

  Future<void> markFailed(String id, String message) async {
    await _client.from(_table).update({
      'status': 'failed',
      'processed_at': DateTime.now().toUtc().toIso8601String(),
      'error_message': message,
    }).eq('id', id);
  }

  /// List pending commands newest-first.
  ///
  /// Used for polling fallback when push notifications don't arrive.
  Future<List<RemoteFocusCommand>> listPending({int limit = 10}) async {
    final rows = await _client
        .from(_table)
        .select()
        .eq('status', 'pending')
        .order('created_at', ascending: false)
        .limit(limit);
    return (rows as List)
        .map((r) => RemoteFocusCommand.fromRow(r as Map<String, Object?>))
        .toList(growable: false);
  }
}

