import 'package:flutter_test/flutter_test.dart';
import 'package:win_flutter/data/habits/habit.dart';
import 'package:win_flutter/data/habits/habits_repository.dart';
import 'package:win_flutter/features/today/controllers/today_habits_controller.dart';

void main() {
  test('loads habits and completion for day', () async {
    final repo = _MemHabitsRepo()
      ..habits = const [
        Habit(id: 'h1', name: 'H1', createdAtMs: 1),
        Habit(id: 'h2', name: 'H2', createdAtMs: 2),
      ]
      ..completedByDay['2026-01-31'] = {'h2'};

    final c = TodayHabitsController(habitsRepository: repo, ymd: '2026-01-31');
    addTearDown(c.dispose);

    // Allow the async load kicked off in the constructor to run.
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);

    expect(c.state.isLoading, false);
    expect(c.state.habits.map((h) => h.id), ['h1', 'h2']);
    expect(c.state.habits.firstWhere((h) => h.id == 'h1').completed, false);
    expect(c.state.habits.firstWhere((h) => h.id == 'h2').completed, true);
  });

  test('setHabitCompleted is optimistic and persists in repo', () async {
    final repo = _MemHabitsRepo()
      ..habits = const [
        Habit(id: 'h1', name: 'H1', createdAtMs: 1),
      ];

    final c = TodayHabitsController(habitsRepository: repo, ymd: '2026-01-31');
    addTearDown(c.dispose);
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);

    final ok = await c.setHabitCompleted(habitId: 'h1', completed: true);
    expect(ok, true);
    expect(c.state.habits.single.completed, true);
    expect(repo.completedByDay['2026-01-31'], contains('h1'));
  });
}

class _MemHabitsRepo implements HabitsRepository {
  List<Habit> habits = const [];
  final Map<String, Set<String>> completedByDay = {};

  @override
  Future<Habit> create({required String name}) async {
    final h = Habit(
      id: 'h_${habits.length + 1}',
      name: name,
      createdAtMs: DateTime.now().millisecondsSinceEpoch,
    );
    habits = [...habits, h];
    return h;
  }

  @override
  Future<Set<String>> getCompletedHabitIds({required String ymd}) async {
    return completedByDay[ymd] ?? <String>{};
  }

  @override
  Future<List<Habit>> listHabits() async => habits;

  @override
  Future<void> setCompleted({
    required String habitId,
    required String ymd,
    required bool completed,
  }) async {
    final current = completedByDay[ymd] ?? <String>{};
    final next = {...current};
    if (completed) {
      next.add(habitId);
    } else {
      next.remove(habitId);
    }
    completedByDay[ymd] = next;
  }
}

