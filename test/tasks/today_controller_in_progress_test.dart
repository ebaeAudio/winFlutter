import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:win_flutter/data/habits/habit.dart';
import 'package:win_flutter/data/habits/habits_repository.dart';
import 'package:win_flutter/features/today/controllers/today_tasks_controller.dart';
import 'package:win_flutter/features/today/today_models.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('TodayTasksController in progress', () {
    setUp(() async {
      SharedPreferences.setMockInitialValues({});
    });

    test('setTaskInProgress(true) clears completed and persists to local day',
        () async {
      const ymd = '2026-01-12';
      final prefs = await SharedPreferences.getInstance();

      final controller = TodayTasksController(
        prefs: prefs,
        ymd: ymd,
        tasksRepository: null,
        taskDetailsRepository: null,
        habitsRepository: _FakeHabitsRepo(),
        linearIssueRepository: null,
        recordLinearSyncStatus: ({required at, String? error}) async {},
      );
      addTearDown(controller.dispose);

      final ok = await controller.addTask(
        title: 'Write report',
        type: TodayTaskType.mustWin,
      );
      expect(ok, true);
      final id = controller.state.tasks.single.id;

      await controller.setTaskCompleted(id, true);
      expect(controller.state.tasks.single.completed, true);
      expect(controller.state.tasks.single.inProgress, false);

      await controller.setTaskInProgress(id, true);
      expect(controller.state.tasks.single.inProgress, true);
      expect(controller.state.tasks.single.completed, false);

      final raw = prefs.getString('today_day_$ymd');
      expect(raw, isNotNull);
      final parsed = TodayDayData.fromJsonString(raw!, fallbackYmd: ymd);
      expect(parsed.tasks.single.inProgress, true);
      expect(parsed.tasks.single.completed, false);
    });

    test('existing local day JSON without inProgress defaults to false',
        () async {
      const ymd = '2026-01-12';
      final prefs = await SharedPreferences.getInstance();

      // Simulate older app versions that didn't include `inProgress` on tasks.
      await prefs.setString('today_day_$ymd', '''
{"ymd":"$ymd","tasks":[{"id":"1","title":"Old task","type":"mustWin","completed":false,"createdAtMs":0}],"reflection":"","focusModeEnabled":false,"focusTaskId":null}
''');

      final controller = TodayTasksController(
        prefs: prefs,
        ymd: ymd,
        tasksRepository: null,
        taskDetailsRepository: null,
        habitsRepository: _FakeHabitsRepo(),
        linearIssueRepository: null,
        recordLinearSyncStatus: ({required at, String? error}) async {},
      );
      addTearDown(controller.dispose);

      expect(controller.state.tasks.single.id, '1');
      expect(controller.state.tasks.single.inProgress, false);
    });
  });
}

class _FakeHabitsRepo implements HabitsRepository {
  @override
  Future<List<Habit>> listHabits() async => const [];

  @override
  Future<Habit> create({required String name}) async {
    throw UnimplementedError();
  }

  @override
  Future<Set<String>> getCompletedHabitIds({required String ymd}) async =>
      const {};

  @override
  Future<void> setCompleted({
    required String habitId,
    required String ymd,
    required bool completed,
  }) async {}
}

