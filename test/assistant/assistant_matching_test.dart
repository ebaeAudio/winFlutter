import 'package:flutter_test/flutter_test.dart';

import 'package:win_flutter/assistant/assistant_matching.dart';
import 'package:win_flutter/features/today/today_models.dart';

void main() {
  group('assistant matching', () {
    test('exact case-insensitive match wins', () {
      final tasks = [
        const TodayTask(
          id: '1',
          title: 'Call Mom',
          type: TodayTaskType.mustWin,
          completed: false,
          createdAtMs: 0,
        ),
        const TodayTask(
          id: '2',
          title: 'Call Mom ASAP',
          type: TodayTaskType.mustWin,
          completed: false,
          createdAtMs: 0,
        ),
      ];
      expect(matchTaskIdByTitle(tasks, 'call mom'), '1');
    });

    test('substring match prefers shortest', () {
      final tasks = [
        const TodayTask(
          id: 'a',
          title: 'Email Bob about budget',
          type: TodayTaskType.mustWin,
          completed: false,
          createdAtMs: 0,
        ),
        const TodayTask(
          id: 'b',
          title: 'Email Bob',
          type: TodayTaskType.mustWin,
          completed: false,
          createdAtMs: 0,
        ),
      ];
      expect(matchTaskIdByTitle(tasks, 'email bob'), 'b');
    });

    test('habit matching works the same way', () {
      final habits = [
        const TodayHabit(
            id: 'h1', name: 'Workout', completed: false, createdAtMs: 0),
        const TodayHabit(
            id: 'h2',
            name: 'Workout (short)',
            completed: false,
            createdAtMs: 0),
      ];
      expect(matchHabitIdByName(habits, 'workout'), 'h1');
    });
  });
}
