import 'assistant_models.dart';

String _clamp(String s, int max) {
  final t = s.trim();
  if (t.length <= max) return t;
  return t.substring(0, max);
}

AssistantTaskType? _inferTaskType(String s) {
  final t = s.toLowerCase();
  if (t.contains('must win') || t.contains('must-win') || t.contains('mustwin')) {
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

  // Reflection.
  if (lower.startsWith('note:') ||
      lower.startsWith('note ') ||
      lower.startsWith('reflection:') ||
      lower.startsWith('reflection ')) {
    final text = _stripPrefix(raw, ['note:', 'note ', 'reflection:', 'reflection ']);
    if (text.isNotEmpty) {
      commands.add(ReflectionAppendCommand(text: _clamp(text, 1500)));
      return AssistantTranslation(say: 'Noted.', commands: commands);
    }
  }
  if (lower.startsWith('set reflection:') || lower.startsWith('set reflection ')) {
    final text = _stripPrefix(raw, ['set reflection:', 'set reflection ']);
    commands.add(ReflectionSetCommand(text: _clamp(text, 4000)));
    return AssistantTranslation(say: 'Saved.', commands: commands);
  }

  // Habits.
  if (lower.startsWith('add habit ') ||
      lower.startsWith('create habit ') ||
      lower.startsWith('habit ') ||
      lower.startsWith('track ')) {
    final name = _stripPrefix(raw, ['add habit ', 'create habit ', 'habit ', 'track ']);
    if (name.isNotEmpty) commands.add(HabitCreateCommand(name: _clamp(name, 140)));
  } else if (lower.contains(' every day') || lower.contains(' daily')) {
    final name =
        raw.replaceAll(RegExp(r' every day', caseSensitive: false), '').replaceAll(RegExp(r' daily', caseSensitive: false), '').trim();
    if (name.isNotEmpty) commands.add(HabitCreateCommand(name: _clamp(name, 140)));
  }

  if (lower.startsWith('complete habit ') || lower.startsWith('mark habit ')) {
    final name = _stripPrefix(raw, ['complete habit ', 'mark habit ']);
    if (name.isNotEmpty) {
      commands.add(HabitSetCompletedCommand(name: _clamp(name, 140), completed: true));
    }
  } else if (lower.startsWith('uncomplete habit ') ||
      lower.startsWith('unmark habit ') ||
      lower.startsWith('undo habit ')) {
    final name = _stripPrefix(raw, ['uncomplete habit ', 'unmark habit ', 'undo habit ']);
    if (name.isNotEmpty) {
      commands.add(HabitSetCompletedCommand(name: _clamp(name, 140), completed: false));
    }
  }

  // Tasks.
  if (lower.startsWith('add task ') || lower.startsWith('create task ') || lower.startsWith('task ')) {
    final title = _stripPrefix(raw, ['add task ', 'create task ', 'task ']);
    if (title.isNotEmpty) {
      commands.add(TaskCreateCommand(title: _clamp(title, 140), taskType: _inferTaskType(raw)));
    }
  } else if (lower.startsWith('add must win ') ||
      lower.startsWith('add must win task') ||
      lower.startsWith('add must-win task')) {
    final title = _stripPrefix(raw, ['add must win ', 'add must win task', 'add must-win task']).replaceFirst(RegExp(r'^:\s*'), '');
    if (title.isNotEmpty) commands.add(TaskCreateCommand(title: _clamp(title, 140), taskType: AssistantTaskType.mustWin));
  } else if (lower.startsWith('add nice to do ') ||
      lower.startsWith('add nice to do task') ||
      lower.startsWith('add nice-to-do task')) {
    final title =
        _stripPrefix(raw, ['add nice to do ', 'add nice to do task', 'add nice-to-do task']).replaceFirst(RegExp(r'^:\s*'), '');
    if (title.isNotEmpty) commands.add(TaskCreateCommand(title: _clamp(title, 140), taskType: AssistantTaskType.niceToDo));
  }

  if (lower.startsWith('complete task ') || lower.startsWith('mark task ')) {
    final title = _stripPrefix(raw, ['complete task ', 'mark task ']);
    if (title.isNotEmpty) commands.add(TaskSetCompletedCommand(title: _clamp(title, 140), completed: true));
  } else if (lower.startsWith('uncomplete task ') ||
      lower.startsWith('unmark task ') ||
      lower.startsWith('undo task ')) {
    final title = _stripPrefix(raw, ['uncomplete task ', 'unmark task ', 'undo task ']);
    if (title.isNotEmpty) commands.add(TaskSetCompletedCommand(title: _clamp(title, 140), completed: false));
  }

  if (lower.startsWith('delete task ') || lower.startsWith('remove task ')) {
    final title = _stripPrefix(raw, ['delete task ', 'remove task ']);
    if (title.isNotEmpty) commands.add(TaskDeleteCommand(title: _clamp(title, 140)));
  }

  final capped = commands.take(5).toList();
  final hasAction = capped.any((c) => c.kind != 'date.shift' && c.kind != 'date.set');
  final say = hasAction
      ? 'Got it.'
      : 'Try: "tomorrow add task ...", "complete task ...", "note: ...", or "add habit ...".';
  return AssistantTranslation(say: say, commands: capped);
}


