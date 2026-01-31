import 'dart:convert';

import '../../domain/focus/active_timebox.dart';

enum TodayTaskType {
  mustWin,
  niceToDo;

  static TodayTaskType fromString(String raw) {
    final normalized = raw.trim().toLowerCase();
    if (normalized == 'must-win') return TodayTaskType.mustWin;
    if (normalized == 'nice-to-do') return TodayTaskType.niceToDo;

    return TodayTaskType.values.firstWhere(
      (e) => e.name.toLowerCase() == normalized,
      orElse: () => TodayTaskType.mustWin,
    );
  }

  String get dbValue => switch (this) {
        TodayTaskType.mustWin => 'must-win',
        TodayTaskType.niceToDo => 'nice-to-do',
      };
}

class TodayTask {
  const TodayTask({
    required this.id,
    required this.title,
    required this.type,
    required this.completed,
    required this.inProgress,
    required this.createdAtMs,
    this.details,
    this.goalYmd,
    this.notes,
    this.starterStep,
    this.estimatedMinutes,
    this.nextStep,
    this.estimateMinutes,
    this.actualMinutes,
    this.subtasks = const [],
    this.deletedAtMs,
  });

  final String id;
  final String title;
  final TodayTaskType type;
  final bool completed;
  final bool inProgress;
  final int createdAtMs;
  final String? details;
  final String? goalYmd;
  final String? notes;

  /// Focus v2: micro-step scaffolding for task initiation.
  final String? starterStep;

  /// Focus v2: estimate in minutes (optional).
  final int? estimatedMinutes;

  /// Legacy alias for starterStep (kept for local/demo mode details screen).
  final String? nextStep;

  /// Legacy alias for estimatedMinutes (kept for local/demo mode details screen).
  final int? estimateMinutes;
  final int? actualMinutes;
  final List<TodaySubtask> subtasks;

  /// Soft delete timestamp (local mode only).
  final int? deletedAtMs;

  /// Returns true if the task has been soft-deleted.
  bool get isDeleted => deletedAtMs != null;

  TodayTask copyWith({
    String? title,
    TodayTaskType? type,
    bool? completed,
    bool? inProgress,
    String? details,
    Object? goalYmd = _todayTaskUnset,
    String? notes,
    String? starterStep,
    int? estimatedMinutes,
    String? nextStep,
    int? estimateMinutes,
    int? actualMinutes,
    List<TodaySubtask>? subtasks,
    Object? deletedAtMs = _todayTaskUnset,
  }) {
    final resolvedStarterStep = starterStep ?? this.starterStep ?? nextStep ?? this.nextStep;
    final resolvedEstimatedMinutes =
        estimatedMinutes ?? this.estimatedMinutes ?? estimateMinutes ?? this.estimateMinutes;
    return TodayTask(
      id: id,
      title: title ?? this.title,
      type: type ?? this.type,
      completed: completed ?? this.completed,
      inProgress: inProgress ?? this.inProgress,
      createdAtMs: createdAtMs,
      details: details ?? this.details,
      goalYmd: goalYmd == _todayTaskUnset ? this.goalYmd : goalYmd as String?,
      notes: notes ?? this.notes,
      starterStep: resolvedStarterStep,
      estimatedMinutes: resolvedEstimatedMinutes,
      // Keep legacy aliases in sync for existing local/demo mode screens.
      nextStep: resolvedStarterStep,
      estimateMinutes: resolvedEstimatedMinutes,
      actualMinutes: actualMinutes ?? this.actualMinutes,
      subtasks: subtasks ?? this.subtasks,
      deletedAtMs: deletedAtMs == _todayTaskUnset ? this.deletedAtMs : deletedAtMs as int?,
    );
  }

  Map<String, Object?> toJson() => {
        'id': id,
        'title': title,
        'type': type.name,
        'completed': completed,
        'inProgress': inProgress,
        'createdAtMs': createdAtMs,
        if (details != null) 'details': details,
        if (goalYmd != null) 'goalYmd': goalYmd,
        if (notes != null) 'notes': notes,
        // Focus v2 canonical keys
        if (starterStep != null) 'starterStep': starterStep,
        if (estimatedMinutes != null) 'estimatedMinutes': estimatedMinutes,
        // Legacy keys (still written for back-compat with existing local/demo payloads)
        if (nextStep != null) 'nextStep': nextStep,
        if (estimateMinutes != null) 'estimateMinutes': estimateMinutes,
        if (actualMinutes != null) 'actualMinutes': actualMinutes,
        if (subtasks.isNotEmpty)
          'subtasks': [for (final s in subtasks) s.toJson()],
        if (deletedAtMs != null) 'deletedAtMs': deletedAtMs,
      };

  static TodayTask fromJson(Map<String, Object?> json) {
    final subtasks = <TodaySubtask>[];
    final rawSubtasks = json['subtasks'];
    if (rawSubtasks is List) {
      for (final s in rawSubtasks) {
        if (s is Map<String, Object?>) {
          subtasks.add(TodaySubtask.fromJson(s));
        } else if (s is Map) {
          subtasks.add(TodaySubtask.fromJson(Map<String, Object?>.from(s)));
        }
      }
    }

    final starterStep =
        (json['starterStep'] as String?) ?? (json['nextStep'] as String?);
    final estimatedMinutes =
        (json['estimatedMinutes'] as num?)?.toInt() ??
            (json['estimateMinutes'] as num?)?.toInt();

    return TodayTask(
      id: (json['id'] as String?) ?? '',
      title: (json['title'] as String?) ?? '',
      type: TodayTaskType.fromString(
          (json['type'] as String?) ?? TodayTaskType.mustWin.name),
      completed: (json['completed'] as bool?) ?? false,
      inProgress: (json['inProgress'] as bool?) ?? false,
      createdAtMs: (json['createdAtMs'] as num?)?.toInt() ?? 0,
      details: (json['details'] as String?) ?? (json['notes'] as String?),
      goalYmd: (json['goalYmd'] as String?),
      notes: (json['notes'] as String?),
      starterStep: starterStep,
      estimatedMinutes: estimatedMinutes,
      // Keep legacy aliases populated for existing screens.
      nextStep: starterStep,
      estimateMinutes: estimatedMinutes,
      actualMinutes: (json['actualMinutes'] as num?)?.toInt(),
      subtasks: subtasks,
      deletedAtMs: (json['deletedAtMs'] as num?)?.toInt(),
    );
  }
}

class _TodayTaskUnset {
  const _TodayTaskUnset();
}

const _todayTaskUnset = _TodayTaskUnset();

class TodaySubtask {
  const TodaySubtask({
    required this.id,
    required this.title,
    required this.completed,
    required this.createdAtMs,
  });

  final String id;
  final String title;
  final bool completed;
  final int createdAtMs;

  TodaySubtask copyWith({
    String? title,
    bool? completed,
  }) {
    return TodaySubtask(
      id: id,
      title: title ?? this.title,
      completed: completed ?? this.completed,
      createdAtMs: createdAtMs,
    );
  }

  Map<String, Object?> toJson() => {
        'id': id,
        'title': title,
        'completed': completed,
        'createdAtMs': createdAtMs,
      };

  static TodaySubtask fromJson(Map<String, Object?> json) {
    return TodaySubtask(
      id: (json['id'] as String?) ?? '',
      title: (json['title'] as String?) ?? '',
      completed: (json['completed'] as bool?) ?? false,
      createdAtMs: (json['createdAtMs'] as num?)?.toInt() ?? 0,
    );
  }
}

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
  final List<TodayTask> tasks;
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
    List<TodayTask>? tasks,
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
        'tasks': tasks.map((t) => t.toJson()).toList(),
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

  static TodayDayData fromJson(Map<String, Object?> json) {
    final rawTasks = json['tasks'];
    final tasks = <TodayTask>[];
    if (rawTasks is List) {
      for (final t in rawTasks) {
        if (t is Map<String, Object?>) {
          tasks.add(TodayTask.fromJson(t));
        } else if (t is Map) {
          tasks.add(TodayTask.fromJson(Map<String, Object?>.from(t)));
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
      ymd: (json['ymd'] as String?) ?? '',
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
      {required String fallbackYmd}) {
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map) {
        final parsed =
            TodayDayData.fromJson(Map<String, Object?>.from(decoded));
        final ymd = parsed.ymd.trim().isEmpty ? fallbackYmd : parsed.ymd;
        return parsed.copyWith()._withYmd(ymd);
      }
    } catch (_) {
      // ignore
    }
    return TodayDayData.empty(fallbackYmd);
  }

  TodayDayData _withYmd(String ymd) {
    return TodayDayData(
      ymd: ymd,
      tasks: tasks,
      habits: habits,
      reflection: reflection,
      focusModeEnabled: focusModeEnabled,
      focusTaskId: focusTaskId,
      activeTimebox: activeTimebox,
    );
  }
}
