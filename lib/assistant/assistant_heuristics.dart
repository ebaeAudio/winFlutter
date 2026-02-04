import 'assistant_models.dart';

String _clamp(String s, int max) {
  final t = s.trim();
  if (t.length <= max) return t;
  return t.substring(0, max);
}

AssistantTaskType? _inferTaskType(String s) {
  final t = s.toLowerCase();
  if (t.contains('must win') ||
      t.contains('must-win') ||
      t.contains('mustwin')) {
    return AssistantTaskType.mustWin;
  }
  if (t.contains('nice to do') ||
      t.contains('nice-to-do') ||
      t.contains('nice todo') ||
      t.contains('nicetodo')) {
    return AssistantTaskType.niceToDo;
  }
  return null;
}

String _stripPrefix(String input, List<String> prefixes) {
  final s = input.trimLeft();
  final lower = s.toLowerCase();
  for (final p in prefixes) {
    if (lower.startsWith(p)) return s.substring(p.length).trim();
  }
  return s.trim();
}

String? _extractYmd(String s) {
  final match = RegExp(r'\b(\d{4}-\d{2}-\d{2})\b').firstMatch(s);
  return match?.group(1);
}

AssistantTranslation heuristicTranslate({
  required String transcript,
  required String baseDateYmd,
}) {
  final raw = _clamp(transcript, 2000);
  final lower = raw.toLowerCase();

  final commands = <AssistantCommand>[];

  // Date intent.
  if (lower.contains('tomorrow')) {
    commands.add(const DateShiftCommand(days: 1));
  } else if (lower.contains('yesterday')) {
    commands.add(const DateShiftCommand(days: -1));
  } else if (lower.contains('today')) {
    commands.add(const DateShiftCommand(days: 0));
  }

  final explicitYmd = _extractYmd(lower);
  if (explicitYmd != null) {
    commands.removeWhere((c) => c.kind == 'date.shift');
    commands.add(DateSetCommand(ymd: explicitYmd));
  }

  String stripLeadingDateWord(String input) {
    var s = input.trimLeft();
    final l = s.toLowerCase();
    for (final w in const ['tomorrow', 'yesterday', 'today']) {
      if (l.startsWith(w)) {
        s = s.substring(w.length).trimLeft();
        // Optional separators: ":" or "," after the date word.
        s = s.replaceFirst(RegExp(r'^[:\,]\s*'), '');
        return s;
      }
    }
    return s;
  }

  // For commands like "tomorrow add task ...", parse the action from the remainder.
  final actionRaw = stripLeadingDateWord(raw);
  final actionLower = actionRaw.toLowerCase();

  // Reflection.
  if (actionLower.startsWith('note:') ||
      actionLower.startsWith('note ') ||
      actionLower.startsWith('reflection:') ||
      actionLower.startsWith('reflection ')) {
    final text = _stripPrefix(
      actionRaw,
      ['note:', 'note ', 'reflection:', 'reflection '],
    );
    if (text.isNotEmpty) {
      commands.add(ReflectionAppendCommand(text: _clamp(text, 1500)));
      return AssistantTranslation(say: 'Noted.', commands: commands);
    }
  }
  if (actionLower.startsWith('set reflection:') ||
      actionLower.startsWith('set reflection ')) {
    final text =
        _stripPrefix(actionRaw, ['set reflection:', 'set reflection ']);
    commands.add(ReflectionSetCommand(text: _clamp(text, 4000)));
    return AssistantTranslation(say: 'Saved.', commands: commands);
  }

  // Habits.
  if (actionLower.startsWith('add habit ') ||
      actionLower.startsWith('create habit ') ||
      actionLower.startsWith('habit ') ||
      actionLower.startsWith('track ')) {
    final name = _stripPrefix(
      actionRaw,
      ['add habit ', 'create habit ', 'habit ', 'track '],
    );
    if (name.isNotEmpty) {
      commands.add(HabitCreateCommand(name: _clamp(name, 140)));
    }
  } else if (actionLower.contains(' every day') ||
      actionLower.contains(' daily')) {
    final name = actionRaw
        .replaceAll(RegExp(r' every day', caseSensitive: false), '')
        .replaceAll(RegExp(r' daily', caseSensitive: false), '')
        .trim();
    if (name.isNotEmpty) {
      commands.add(HabitCreateCommand(name: _clamp(name, 140)));
    }
  }

  if (actionLower.startsWith('complete habit ') ||
      actionLower.startsWith('mark habit ')) {
    final name = _stripPrefix(actionRaw, ['complete habit ', 'mark habit ']);
    if (name.isNotEmpty) {
      commands.add(
          HabitSetCompletedCommand(name: _clamp(name, 140), completed: true),);
    }
  } else if (actionLower.startsWith('uncomplete habit ') ||
      actionLower.startsWith('unmark habit ') ||
      actionLower.startsWith('undo habit ')) {
    final name = _stripPrefix(
      actionRaw,
      ['uncomplete habit ', 'unmark habit ', 'undo habit '],
    );
    if (name.isNotEmpty) {
      commands.add(
          HabitSetCompletedCommand(name: _clamp(name, 140), completed: false),);
    }
  }

  // Tasks.
  if (actionLower.startsWith('add task ') ||
      actionLower.startsWith('create task ') ||
      actionLower.startsWith('task ')) {
    final title =
        _stripPrefix(actionRaw, ['add task ', 'create task ', 'task ']);
    if (title.isNotEmpty) {
      commands.add(TaskCreateCommand(
        title: _clamp(title, 140),
        taskType: _inferTaskType(actionRaw),
      ),);
    }
  } else if (actionLower.startsWith('add must win ') ||
      actionLower.startsWith('add must win task') ||
      actionLower.startsWith('add must-win task')) {
    final title = _stripPrefix(
      actionRaw,
      ['add must win ', 'add must win task', 'add must-win task'],
    ).replaceFirst(RegExp(r'^:\s*'), '');
    if (title.isNotEmpty) {
      commands.add(TaskCreateCommand(
          title: _clamp(title, 140), taskType: AssistantTaskType.mustWin,),);
    }
  } else if (actionLower.startsWith('add nice to do ') ||
      actionLower.startsWith('add nice to do task') ||
      actionLower.startsWith('add nice-to-do task')) {
    final title = _stripPrefix(actionRaw, [
      'add nice to do ',
      'add nice to do task',
      'add nice-to-do task',
    ]).replaceFirst(RegExp(r'^:\s*'), '');
    if (title.isNotEmpty) {
      commands.add(TaskCreateCommand(
          title: _clamp(title, 140), taskType: AssistantTaskType.niceToDo,),);
    }
  }

  if (actionLower.startsWith('complete task ') ||
      actionLower.startsWith('mark task ')) {
    final title = _stripPrefix(actionRaw, ['complete task ', 'mark task ']);
    if (title.isNotEmpty) {
      commands.add(
          TaskSetCompletedCommand(title: _clamp(title, 140), completed: true),);
    }
  } else if (actionLower.startsWith('uncomplete task ') ||
      actionLower.startsWith('unmark task ') ||
      actionLower.startsWith('undo task ')) {
    final title = _stripPrefix(
        actionRaw, ['uncomplete task ', 'unmark task ', 'undo task '],);
    if (title.isNotEmpty) {
      commands.add(
          TaskSetCompletedCommand(title: _clamp(title, 140), completed: false),);
    }
  }

  if (actionLower.startsWith('delete task ') ||
      actionLower.startsWith('remove task ')) {
    final title = _stripPrefix(actionRaw, ['delete task ', 'remove task ']);
    if (title.isNotEmpty) {
      commands.add(TaskDeleteCommand(title: _clamp(title, 140)));
    }
  }

  final capped = commands.take(5).toList();
  final hasAction =
      capped.any((c) => c.kind != 'date.shift' && c.kind != 'date.set');
  final say = hasAction
      ? 'Got it.'
      : 'Try: "tomorrow add task ...", "complete task ...", "note: ...", or "add habit ...".';
  return AssistantTranslation(say: say, commands: capped);
}
