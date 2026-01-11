import 'package:flutter_test/flutter_test.dart';

import 'package:win_flutter/assistant/assistant_heuristics.dart';
import 'package:win_flutter/assistant/assistant_models.dart';

void main() {
  group('assistant heuristics', () {
    test('tomorrow add must-win task emits date.shift then task.create', () {
      final t = heuristicTranslate(
        transcript: 'tomorrow add must win task: renew passport',
        baseDateYmd: '2026-01-05',
      );
      expect(t.commands.length, 2);
      expect(t.commands[0] is DateShiftCommand, true);
      expect((t.commands[0] as DateShiftCommand).days, 1);
      expect(t.commands[1] is TaskCreateCommand, true);
      final c = t.commands[1] as TaskCreateCommand;
      expect(c.title.toLowerCase().contains('renew passport'), true);
      expect(c.taskType, AssistantTaskType.mustWin);
    });

    test('note: emits reflection.append', () {
      final t = heuristicTranslate(
        transcript: 'note: shipped v1',
        baseDateYmd: '2026-01-05',
      );
      expect(t.commands.length, 1);
      expect(t.commands.first is ReflectionAppendCommand, true);
    });

    test('complete task emits task.setCompleted true', () {
      final t = heuristicTranslate(
        transcript: 'complete task call mom',
        baseDateYmd: '2026-01-05',
      );
      expect(t.commands.length, 1);
      final cmd = t.commands.first as TaskSetCompletedCommand;
      expect(cmd.completed, true);
      expect(cmd.title.toLowerCase().contains('call mom'), true);
    });
  });
}
