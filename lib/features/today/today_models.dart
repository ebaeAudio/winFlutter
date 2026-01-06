import 'dart:convert';

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
    required this.createdAtMs,
    this.notes,
    this.nextStep,
    this.estimateMinutes,
    this.actualMinutes,
    this.subtasks = const [],
  });

  final String id;
  final String title;
  final TodayTaskType type;
  final bool completed;
  final int createdAtMs;
  final String? notes;
  final String? nextStep;
  final int? estimateMinutes;
  final int? actualMinutes;
  final List<TodaySubtask> subtasks;

  TodayTask copyWith({
    String? title,
    TodayTaskType? type,
    bool? completed,
    String? notes,
    String? nextStep,
    int? estimateMinutes,
    int? actualMinutes,
    List<TodaySubtask>? subtasks,
  }) {
    return TodayTask(
      id: id,
      title: title ?? this.title,
      type: type ?? this.type,
      completed: completed ?? this.completed,
      createdAtMs: createdAtMs,
      notes: notes ?? this.notes,
      nextStep: nextStep ?? this.nextStep,
      estimateMinutes: estimateMinutes ?? this.estimateMinutes,
      actualMinutes: actualMinutes ?? this.actualMinutes,
      subtasks: subtasks ?? this.subtasks,
    );
  }

  Map<String, Object?> toJson() => {
        'id': id,
        'title': title,
        'type': type.name,
        'completed': completed,
        'createdAtMs': createdAtMs,
        if (notes != null) 'notes': notes,
        if (nextStep != null) 'nextStep': nextStep,
        if (estimateMinutes != null) 'estimateMinutes': estimateMinutes,
        if (actualMinutes != null) 'actualMinutes': actualMinutes,
        if (subtasks.isNotEmpty) 'subtasks': [for (final s in subtasks) s.toJson()],
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

    return TodayTask(
      id: (json['id'] as String?) ?? '',
      title: (json['title'] as String?) ?? '',
      type: TodayTaskType.fromString(
          (json['type'] as String?) ?? TodayTaskType.mustWin.name),
      completed: (json['completed'] as bool?) ?? false,
      createdAtMs: (json['createdAtMs'] as num?)?.toInt() ?? 0,
      notes: (json['notes'] as String?),
      nextStep: (json['nextStep'] as String?),
      estimateMinutes: (json['estimateMinutes'] as num?)?.toInt(),
      actualMinutes: (json['actualMinutes'] as num?)?.toInt(),
      subtasks: subtasks,
    );
  }
}

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
  });

  final String ymd;
  final List<TodayTask> tasks;
  final List<TodayHabit> habits;
  final String reflection;

  /// ADHD-friendly “1 thing now” mode.
  final bool focusModeEnabled;

  /// Optional: user-picked focus task for the day.
  final String? focusTaskId;

  TodayDayData copyWith({
    List<TodayTask>? tasks,
    List<TodayHabit>? habits,
    String? reflection,
    bool? focusModeEnabled,
    String? focusTaskId,
  }) {
    return TodayDayData(
      ymd: ymd,
      tasks: tasks ?? this.tasks,
      habits: habits ?? this.habits,
      reflection: reflection ?? this.reflection,
      focusModeEnabled: focusModeEnabled ?? this.focusModeEnabled,
      focusTaskId: focusTaskId,
    );
  }

  Map<String, Object?> toJson() => {
        'ymd': ymd,
        'tasks': tasks.map((t) => t.toJson()).toList(),
        'reflection': reflection,
        'focusModeEnabled': focusModeEnabled,
        'focusTaskId': focusTaskId,
      };

  static TodayDayData empty(String ymd) => TodayDayData(
        ymd: ymd,
        tasks: const [],
        habits: const [],
        reflection: '',
        focusModeEnabled: false,
        focusTaskId: null,
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

    return TodayDayData(
      ymd: (json['ymd'] as String?) ?? '',
      tasks: tasks,
      habits: const [],
      reflection: (json['reflection'] as String?) ?? '',
      focusModeEnabled: (json['focusModeEnabled'] as bool?) ?? false,
      focusTaskId: json['focusTaskId'] as String?,
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
    );
  }
}
