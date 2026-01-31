import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../app/auth.dart';
import '../../app/env.dart';
import '../../app/supabase.dart';

/// Event types for task changes from Supabase Realtime.
enum TaskChangeType { insert, update, delete }

/// A task change event received from Supabase Realtime.
class TaskChangeEvent {
  const TaskChangeEvent({
    required this.type,
    required this.taskId,
    required this.taskDate,
    this.newRecord,
    this.oldRecord,
  });

  /// The type of change (insert, update, delete).
  final TaskChangeType type;

  /// The task ID that changed.
  final String taskId;

  /// The date (YYYY-MM-DD) of the task, used to filter relevant changes.
  final String? taskDate;

  /// The new record data (for insert/update).
  final Map<String, dynamic>? newRecord;

  /// The old record data (for update/delete).
  final Map<String, dynamic>? oldRecord;

  @override
  String toString() =>
      'TaskChangeEvent($type, id: $taskId, date: $taskDate)';
}

/// Provider that streams task changes from Supabase Realtime.
///
/// This enables cross-device sync: when a task is added/edited/deleted
/// on another device (e.g., web or Mac), iOS receives the update instantly.
///
/// Usage: Watch this provider and filter by the date you care about.
/// When a change event arrives for a matching date, refresh your task list.
final taskRealtimeChangesProvider = StreamProvider<TaskChangeEvent?>((ref) async* {
  final env = ref.watch(envProvider);
  final supabase = ref.watch(supabaseProvider);
  final authState = ref.watch(authStateProvider).valueOrNull;

  // Don't subscribe in demo mode or if not signed in.
  if (env.demoMode || !supabase.isInitialized) {
    yield null;
    return;
  }
  if (authState == null || !authState.isSignedIn) {
    yield null;
    return;
  }

  final client = Supabase.instance.client;
  final userId = client.auth.currentSession?.user.id;
  if (userId == null || userId.isEmpty) {
    yield null;
    return;
  }

  final controller = StreamController<TaskChangeEvent?>();
  RealtimeChannel? channel;

  try {
    // Create a realtime channel for task changes.
    // Filter by user_id to only receive events for the current user's tasks.
    channel = client
        .channel('tasks_changes_$userId')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'tasks',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'user_id',
            value: userId,
          ),
          callback: (payload) {
            final event = _parsePayload(payload);
            if (event != null && !controller.isClosed) {
              debugPrint('[taskRealtimeChanges] Received: $event');
              controller.add(event);
            }
          },
        )
        .subscribe((status, [error]) {
          debugPrint('[taskRealtimeChanges] Subscription status: $status');
          if (error != null) {
            debugPrint('[taskRealtimeChanges] Subscription error: $error');
          }
        });

    ref.onDispose(() {
      debugPrint('[taskRealtimeChanges] Disposing subscription');
      channel?.unsubscribe();
      controller.close();
    });

    // Yield events from the stream.
    await for (final event in controller.stream) {
      yield event;
    }
  } catch (e) {
    debugPrint('[taskRealtimeChanges] Setup error: $e');
    yield null;
  }
});

/// Parse a Supabase Realtime payload into a [TaskChangeEvent].
TaskChangeEvent? _parsePayload(PostgresChangePayload payload) {
  try {
    final eventType = switch (payload.eventType) {
      PostgresChangeEvent.insert => TaskChangeType.insert,
      PostgresChangeEvent.update => TaskChangeType.update,
      PostgresChangeEvent.delete => TaskChangeType.delete,
      _ => null,
    };

    if (eventType == null) return null;

    final newRecord = payload.newRecord.isNotEmpty
        ? Map<String, dynamic>.from(payload.newRecord)
        : null;
    final oldRecord = payload.oldRecord.isNotEmpty
        ? Map<String, dynamic>.from(payload.oldRecord)
        : null;

    // Extract task ID from new or old record.
    final taskId = (newRecord?['id'] ?? oldRecord?['id']) as String?;
    if (taskId == null || taskId.isEmpty) return null;

    // Extract date for filtering.
    final taskDate = (newRecord?['date'] ?? oldRecord?['date']) as String?;

    return TaskChangeEvent(
      type: eventType,
      taskId: taskId,
      taskDate: taskDate,
      newRecord: newRecord,
      oldRecord: oldRecord,
    );
  } catch (e) {
    debugPrint('[taskRealtimeChanges] Parse error: $e');
    return null;
  }
}

/// Provider that filters task change events for a specific date.
///
/// Returns `true` when a change affecting the specified date is received.
/// Use this to trigger a refresh in [TodayController].
final taskChangesForDateProvider =
    Provider.family<AsyncValue<bool>, String>((ref, ymd) {
  final changeAsync = ref.watch(taskRealtimeChangesProvider);

  return changeAsync.when(
    data: (event) {
      if (event == null) return const AsyncValue.data(false);

      // Check if this change affects the date we care about.
      final affectsDate = event.taskDate == ymd;

      // For updates, also check the old date (task might have moved dates).
      final oldDate = event.oldRecord?['date'] as String?;
      final affectsOldDate = oldDate != null && oldDate == ymd;

      return AsyncValue.data(affectsDate || affectsOldDate);
    },
    loading: () => const AsyncValue.loading(),
    error: (e, st) => AsyncValue.error(e, st),
  );
});

/// Checks if a [TaskChangeEvent] affects a specific date.
///
/// Returns true if the task is on the given date, or if it was moved
/// from that date (e.g., task date changed from today to tomorrow).
bool taskChangeAffectsDate(TaskChangeEvent? event, String ymd) {
  if (event == null) return false;

  // Check if this change affects the date we care about.
  final affectsDate = event.taskDate == ymd;

  // For updates, also check the old date (task might have moved dates).
  final oldDate = event.oldRecord?['date'] as String?;
  final affectsOldDate = oldDate != null && oldDate == ymd;

  return affectsDate || affectsOldDate;
}
