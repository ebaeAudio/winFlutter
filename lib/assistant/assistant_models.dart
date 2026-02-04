enum AssistantTaskType {
  mustWin,
  niceToDo;

  static AssistantTaskType? fromJson(Object? raw) {
    if (raw is! String) return null;
    final v = raw.trim().toLowerCase();
    if (v == 'must-win') return AssistantTaskType.mustWin;
    if (v == 'nice-to-do') return AssistantTaskType.niceToDo;
    return null;
  }

  String get jsonValue => switch (this) {
        AssistantTaskType.mustWin => 'must-win',
        AssistantTaskType.niceToDo => 'nice-to-do',
      };
}

sealed class AssistantCommand {
  const AssistantCommand({required this.kind});

  final String kind;

  Map<String, Object?> toJson();

  static AssistantCommand? fromJson(Object? raw) {
    if (raw is! Map) return null;
    final map = Map<String, Object?>.from(raw);
    final kind = map['kind'];
    if (kind is! String) return null;

    switch (kind) {
      case 'date.shift':
        final days = map['days'];
        if (days is! num) return null;
        final intDays = days.toInt();
        if (intDays < -365 || intDays > 365) return null;
        return DateShiftCommand(days: intDays);
      case 'date.set':
        final ymd = map['ymd'];
        if (ymd is! String) return null;
        return DateSetCommand(ymd: ymd.trim());
      case 'habit.create':
        final name = map['name'];
        if (name is! String) return null;
        return HabitCreateCommand(name: name.trim());
      case 'habit.setCompleted':
        final name = map['name'];
        final completed = map['completed'];
        if (name is! String || completed is! bool) return null;
        return HabitSetCompletedCommand(
            name: name.trim(), completed: completed,);
      case 'task.create':
        final title = map['title'];
        if (title is! String) return null;
        final taskType = AssistantTaskType.fromJson(map['taskType']);
        return TaskCreateCommand(title: title.trim(), taskType: taskType);
      case 'task.setCompleted':
        final title = map['title'];
        final completed = map['completed'];
        if (title is! String || completed is! bool) return null;
        return TaskSetCompletedCommand(
            title: title.trim(), completed: completed,);
      case 'task.delete':
        final title = map['title'];
        if (title is! String) return null;
        return TaskDeleteCommand(title: title.trim());
      case 'reflection.append':
        final text = map['text'];
        if (text is! String) return null;
        return ReflectionAppendCommand(text: text);
      case 'reflection.set':
        final text = map['text'];
        if (text is! String) return null;
        return ReflectionSetCommand(text: text);
      default:
        return null;
    }
  }
}

class DateShiftCommand extends AssistantCommand {
  const DateShiftCommand({required this.days}) : super(kind: 'date.shift');

  final int days;

  @override
  Map<String, Object?> toJson() => {'kind': kind, 'days': days};
}

class DateSetCommand extends AssistantCommand {
  const DateSetCommand({required this.ymd}) : super(kind: 'date.set');

  final String ymd;

  @override
  Map<String, Object?> toJson() => {'kind': kind, 'ymd': ymd};
}

class HabitCreateCommand extends AssistantCommand {
  const HabitCreateCommand({required this.name}) : super(kind: 'habit.create');

  final String name;

  @override
  Map<String, Object?> toJson() => {'kind': kind, 'name': name};
}

class HabitSetCompletedCommand extends AssistantCommand {
  const HabitSetCompletedCommand({required this.name, required this.completed})
      : super(kind: 'habit.setCompleted');

  final String name;
  final bool completed;

  @override
  Map<String, Object?> toJson() =>
      {'kind': kind, 'name': name, 'completed': completed};
}

class TaskCreateCommand extends AssistantCommand {
  const TaskCreateCommand({required this.title, this.taskType})
      : super(kind: 'task.create');

  final String title;
  final AssistantTaskType? taskType;

  @override
  Map<String, Object?> toJson() => {
        'kind': kind,
        'title': title,
        if (taskType != null) 'taskType': taskType!.jsonValue,
      };
}

class TaskSetCompletedCommand extends AssistantCommand {
  const TaskSetCompletedCommand({required this.title, required this.completed})
      : super(kind: 'task.setCompleted');

  final String title;
  final bool completed;

  @override
  Map<String, Object?> toJson() =>
      {'kind': kind, 'title': title, 'completed': completed};
}

class TaskDeleteCommand extends AssistantCommand {
  const TaskDeleteCommand({required this.title}) : super(kind: 'task.delete');

  final String title;

  @override
  Map<String, Object?> toJson() => {'kind': kind, 'title': title};
}

class ReflectionAppendCommand extends AssistantCommand {
  const ReflectionAppendCommand({required this.text})
      : super(kind: 'reflection.append');

  final String text;

  @override
  Map<String, Object?> toJson() => {'kind': kind, 'text': text};
}

class ReflectionSetCommand extends AssistantCommand {
  const ReflectionSetCommand({required this.text})
      : super(kind: 'reflection.set');

  final String text;

  @override
  Map<String, Object?> toJson() => {'kind': kind, 'text': text};
}

class AssistantTranslation {
  const AssistantTranslation({
    required this.say,
    required this.commands,
  });

  final String say;
  final List<AssistantCommand> commands;

  static AssistantTranslation fromJson(Map<String, Object?> json) {
    final say = (json['say'] as String?)?.trim() ?? '';
    final raw = json['commands'];
    final commands = <AssistantCommand>[];
    if (raw is List) {
      for (final item in raw) {
        final cmd = AssistantCommand.fromJson(item);
        if (cmd != null) commands.add(cmd);
        if (commands.length >= 5) break;
      }
    }
    return AssistantTranslation(
      say: say.isNotEmpty ? say : (commands.isNotEmpty ? 'Got it.' : ''),
      commands: commands,
    );
  }
}
