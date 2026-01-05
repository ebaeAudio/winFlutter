import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../features/today/today_controller.dart';
import '../features/today/today_models.dart';
import 'assistant_matching.dart';
import 'assistant_models.dart';

class AssistantExecutionResult {
  const AssistantExecutionResult({
    required this.executedCount,
    required this.messages,
    required this.errors,
  });

  final int executedCount;
  final List<String> messages;
  final List<String> errors;
}

typedef AssistantConfirm = Future<bool> Function(String title, String message);

class AssistantExecutor {
  const AssistantExecutor();

  static DateTime? _parseYmd(String ymd) {
    final parts = ymd.split('-');
    if (parts.length != 3) return null;
    final y = int.tryParse(parts[0]);
    final m = int.tryParse(parts[1]);
    final d = int.tryParse(parts[2]);
    if (y == null || m == null || d == null) return null;
    return DateTime(y, m, d);
  }

  static String _ymd(DateTime dt) => DateFormat('yyyy-MM-dd').format(dt);

  static String? _matchTaskIdByTitle(List<TodayTask> tasks, String query) {
    return matchTaskIdByTitle(tasks, query);
  }

  static String? _matchHabitIdByName(List<TodayHabit> habits, String query) {
    return matchHabitIdByName(habits, query);
  }

  Future<AssistantExecutionResult> execute({
    required BuildContext context,
    required WidgetRef ref,
    required DateTime baseDate,
    required void Function(DateTime nextDate) onSelectDate,
    required List<AssistantCommand> commands,
    required AssistantConfirm confirm,
  }) async {
    final messages = <String>[];
    final errors = <String>[];

    final actionCount = commands
        .where((c) => c.kind != 'date.shift' && c.kind != 'date.set')
        .length;
    final hasDelete = commands.any((c) => c.kind == 'task.delete');

    if (commands.isEmpty) {
      return const AssistantExecutionResult(
        executedCount: 0,
        messages: [],
        errors: [],
      );
    }

    if (hasDelete || actionCount > 1) {
      final ok = await confirm(
        'Run assistant actions?',
        'This will run ${actionCount == 0 ? 1 : actionCount} action(s) for you.',
      );
      if (!ok) {
        return const AssistantExecutionResult(
          executedCount: 0,
          messages: [],
          errors: [],
        );
      }
    }

    var execDate = DateTime(baseDate.year, baseDate.month, baseDate.day);
    var executed = 0;

    for (final cmd in commands) {
      final ymd = _ymd(execDate);
      final today = ref.read(todayControllerProvider(ymd));
      final controller = ref.read(todayControllerProvider(ymd).notifier);

      try {
        switch (cmd) {
          case DateShiftCommand():
            execDate = execDate.add(Duration(days: cmd.days));
            onSelectDate(execDate);
            messages.add('Date set to ${_ymd(execDate)}');
            break;

          case DateSetCommand():
            final parsed = _parseYmd(cmd.ymd);
            if (parsed == null) {
              errors.add('Invalid date: ${cmd.ymd}');
              break;
            }
            execDate = DateTime(parsed.year, parsed.month, parsed.day);
            onSelectDate(execDate);
            messages.add('Date set to ${_ymd(execDate)}');
            break;

          case TaskCreateCommand():
            final type = switch (cmd.taskType) {
              AssistantTaskType.mustWin => TodayTaskType.mustWin,
              AssistantTaskType.niceToDo => TodayTaskType.niceToDo,
              null => TodayTaskType.mustWin,
            };
            final ok = await controller.addTask(title: cmd.title, type: type);
            if (!ok) {
              errors.add('Could not add task "${cmd.title}"');
              break;
            }
            executed++;
            messages.add('Added task: ${cmd.title}');
            break;

          case TaskSetCompletedCommand():
            final taskId = _matchTaskIdByTitle(today.tasks, cmd.title);
            if (taskId == null) {
              errors.add('Task not found: "${cmd.title}" ($ymd)');
              break;
            }
            await controller.setTaskCompleted(taskId, cmd.completed);
            executed++;
            messages.add(
                '${cmd.completed ? "Completed" : "Uncompleted"}: ${cmd.title}');
            break;

          case TaskDeleteCommand():
            final taskId = _matchTaskIdByTitle(today.tasks, cmd.title);
            if (taskId == null) {
              errors.add('Task not found: "${cmd.title}" ($ymd)');
              break;
            }
            final ok = await confirm(
              'Delete task?',
              'Delete "${cmd.title}" for $ymd?',
            );
            if (!ok) break;
            await controller.deleteTask(taskId);
            executed++;
            messages.add('Deleted: ${cmd.title}');
            break;

          case HabitCreateCommand():
            final ok = await controller.addHabit(name: cmd.name);
            if (!ok) {
              errors.add('Could not add habit "${cmd.name}"');
              break;
            }
            executed++;
            messages.add('Added habit: ${cmd.name}');
            break;

          case HabitSetCompletedCommand():
            final habitId = _matchHabitIdByName(today.habits, cmd.name);
            if (habitId == null) {
              errors.add('Habit not found: "${cmd.name}" ($ymd)');
              break;
            }
            await controller.setHabitCompleted(
              habitId: habitId,
              completed: cmd.completed,
            );
            executed++;
            messages.add(
                '${cmd.completed ? "Completed" : "Uncompleted"} habit: ${cmd.name}');
            break;

          case ReflectionAppendCommand():
            final base = today.reflection.trimRight();
            final appended =
                base.isEmpty ? cmd.text : '$base\n${cmd.text}'.trimRight();
            await controller.setReflection(appended);
            executed++;
            messages.add('Updated reflection');
            break;

          case ReflectionSetCommand():
            await controller.setReflection(cmd.text);
            executed++;
            messages.add('Updated reflection');
            break;

          default:
            // Unknown command kind (shouldn't happen after validation).
            break;
        }
      } catch (_) {
        errors.add('Failed: ${cmd.kind} ($ymd)');
      }
    }

    return AssistantExecutionResult(
      executedCount: executed,
      messages: messages,
      errors: errors,
    );
  }
}


