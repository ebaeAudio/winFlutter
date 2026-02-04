import 'dart:convert';

import '../../domain/focus/active_timebox.dart';
import '../../domain/tasks/task.dart';

/// Back-compat typedefs: keep the Today feature API stable while using the
/// canonical domain model.
typedef TodayTask = Task;
typedef TodayTaskType = TaskType;
typedef TodaySubtask = TaskSubtask;

class TodayHabit {
  const TodayHabit({
    required this.id,
    required this.name,
    required this.completed,
    required this.createdAtMs,
  });

  final String id;
  final String name;
  final bool completed;
  final int createdAtMs;

  TodayHabit copyWith({bool? completed}) {
    return TodayHabit(
      id: id,
      name: name,
      completed: completed ?? this.completed,
      createdAtMs: createdAtMs,
    );
  }
}

class TodayDayData {
  const TodayDayData({
    required this.ymd,
    required this.tasks,
    required this.habits,
    required this.reflection,
    required this.focusModeEnabled,
    required this.focusTaskId,
    required this.activeTimebox,
    this.updatingTaskIds = const {},
    this.updatingHabitIds = const {},
  });

  final String ymd;
  final List<Task> tasks;
  final List<TodayHabit> habits;
  final String reflection;

  /// ADHD-friendly “1 thing now” mode.
  final bool focusModeEnabled;

  /// Optional: user-picked focus task for the day.
  final String? focusTaskId;

  /// Optional: active timebox for the day (persisted locally).
  final ActiveTimebox? activeTimebox;

  /// Task IDs currently being updated (prevents double-click issues).
  final Set<String> updatingTaskIds;

  /// Habit IDs currently being updated (prevents double-click issues).
  final Set<String> updatingHabitIds;

  /// Returns true if the given task is currently being updated.
  bool isTaskUpdating(String taskId) => updatingTaskIds.contains(taskId);

  /// Returns true if the given habit is currently being updated.
  bool isHabitUpdating(String habitId) => updatingHabitIds.contains(habitId);

  TodayDayData copyWith({
    List<Task>? tasks,
    List<TodayHabit>? habits,
    String? reflection,
    bool? focusModeEnabled,
    String? focusTaskId,
    ActiveTimebox? activeTimebox,
    Set<String>? updatingTaskIds,
    Set<String>? updatingHabitIds,
  }) {
    return TodayDayData(
      ymd: ymd,
      tasks: tasks ?? this.tasks,
      habits: habits ?? this.habits,
      reflection: reflection ?? this.reflection,
      focusModeEnabled: focusModeEnabled ?? this.focusModeEnabled,
      focusTaskId: focusTaskId,
      activeTimebox: activeTimebox ?? this.activeTimebox,
      updatingTaskIds: updatingTaskIds ?? this.updatingTaskIds,
      updatingHabitIds: updatingHabitIds ?? this.updatingHabitIds,
    );
  }

  Map<String, Object?> toJson() => {
        'ymd': ymd,
        'tasks': tasks.map((t) => t.toLocalJson()).toList(),
        'reflection': reflection,
        'focusModeEnabled': focusModeEnabled,
        'focusTaskId': focusTaskId,
        if (activeTimebox != null) 'activeTimebox': activeTimebox!.toJson(),
      };

  static TodayDayData empty(String ymd) => TodayDayData(
        ymd: ymd,
        tasks: const [],
        habits: const [],
        reflection: '',
        focusModeEnabled: false,
        focusTaskId: null,
        activeTimebox: null,
      );

  static TodayDayData fromJson(
    Map<String, Object?> json, {
    required String fallbackYmd,
  }) {
    final rawYmd = (json['ymd'] as String?) ?? '';
    final resolvedYmd = rawYmd.trim().isEmpty ? fallbackYmd : rawYmd;

    final rawTasks = json['tasks'];
    final tasks = <Task>[];
    if (rawTasks is List) {
      for (final t in rawTasks) {
        if (t is Map<String, Object?>) {
          tasks.add(Task.fromLocalJson(t, fallbackDate: resolvedYmd));
        } else if (t is Map) {
          tasks.add(
            Task.fromLocalJson(
              Map<String, Object?>.from(t),
              fallbackDate: resolvedYmd,
            ),
          );
        }
      }
    }

    final rawTimebox = json['activeTimebox'];
    ActiveTimebox? activeTimebox;
    if (rawTimebox is Map<String, Object?>) {
      activeTimebox = ActiveTimebox.fromJson(rawTimebox);
    } else if (rawTimebox is Map) {
      activeTimebox = ActiveTimebox.fromJson(rawTimebox.cast<String, Object?>());
    }

    return TodayDayData(
      ymd: resolvedYmd,
      tasks: tasks,
      habits: const [],
      reflection: (json['reflection'] as String?) ?? '',
      focusModeEnabled: (json['focusModeEnabled'] as bool?) ?? false,
      focusTaskId: json['focusTaskId'] as String?,
      activeTimebox: activeTimebox,
    );
  }

  String toJsonString() => jsonEncode(toJson());

  static TodayDayData fromJsonString(String raw,
      {required String fallbackYmd,}) {
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map) {
        return TodayDayData.fromJson(
          Map<String, Object?>.from(decoded),
          fallbackYmd: fallbackYmd,
        );
      }
    } catch (_) {
      // ignore
    }
    return TodayDayData.empty(fallbackYmd);
  }
}
