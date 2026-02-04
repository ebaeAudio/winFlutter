import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:win_flutter/data/habits/habit.dart';
import 'package:win_flutter/data/habits/habits_repository.dart';
import 'package:win_flutter/features/today/controllers/today_tasks_controller.dart';
import 'package:win_flutter/features/today/morning_wizard/morning_wizard_data.dart';
import 'package:win_flutter/features/today/today_models.dart';

void main() {
  test('local mode: addTask persists into today_day_ key', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();

    const ymd = '2026-01-31';
    final habits = _MemHabitsRepo();

    final c = TodayTasksController(
      prefs: prefs,
      ymd: ymd,
      tasksRepository: null,
      taskDetailsRepository: null,
      habitsRepository: habits,
      linearIssueRepository: null,
      recordLinearSyncStatus: ({required DateTime at, String? error}) async {},
    );
    addTearDown(c.dispose);

    final ok = await c.addTask(title: 'Test', type: TodayTaskType.mustWin);
    expect(ok, true);
    expect(c.state.tasks, hasLength(1));

    final raw = prefs.getString('today_day_$ymd');
    expect(raw, isNotNull);
    final day = TodayDayData.fromJsonString(raw!, fallbackYmd: ymd);
    expect(day.tasks, hasLength(1));
    expect(day.tasks.first.title, 'Test');
  });

  test('local mode: toggleTaskCompleted updates state + persists', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();

    const ymd = '2026-01-31';
    final habits = _MemHabitsRepo();

    final c = TodayTasksController(
      prefs: prefs,
      ymd: ymd,
      tasksRepository: null,
      taskDetailsRepository: null,
      habitsRepository: habits,
      linearIssueRepository: null,
      recordLinearSyncStatus: ({required DateTime at, String? error}) async {},
    );
    addTearDown(c.dispose);

    await c.addTask(title: 'Test', type: TodayTaskType.mustWin);
    final id = c.state.tasks.single.id;

    final ok = await c.toggleTaskCompleted(id);
    expect(ok, true);
    expect(c.state.tasks.single.completed, true);

    final raw = prefs.getString('today_day_$ymd');
    expect(raw, isNotNull);
    final day = TodayDayData.fromJsonString(raw!, fallbackYmd: ymd);
    expect(day.tasks.single.completed, true);
  });

  test('local mode: rolloverYesterdayTasks moves incomplete tasks', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();

    const todayYmd = '2026-01-31';
    const yesterdayYmd = '2026-01-30';

    final yesterday = TodayDayData(
      ymd: yesterdayYmd,
      tasks: [
        TodayTask(
          id: 'a',
          title: 'Must',
          type: TodayTaskType.mustWin,
          date: yesterdayYmd,
          completed: false,
          inProgress: false,
          createdAt: DateTime.fromMillisecondsSinceEpoch(1),
        ),
        TodayTask(
          id: 'b',
          title: 'Done',
          type: TodayTaskType.niceToDo,
          date: yesterdayYmd,
          completed: true,
          inProgress: false,
          createdAt: DateTime.fromMillisecondsSinceEpoch(2),
        ),
      ],
      habits: const [],
      reflection: '',
      focusModeEnabled: false,
      focusTaskId: null,
      activeTimebox: null,
    );
    await prefs.setString('today_day_$yesterdayYmd', yesterday.toJsonString());

    final habits = _MemHabitsRepo();
    final c = TodayTasksController(
      prefs: prefs,
      ymd: todayYmd,
      tasksRepository: null,
      taskDetailsRepository: null,
      habitsRepository: habits,
      linearIssueRepository: null,
      recordLinearSyncStatus: ({required DateTime at, String? error}) async {},
    );
    addTearDown(c.dispose);

    final moved = await c.rolloverYesterdayTasks();
    expect(moved, 1);
    expect(c.state.tasks.map((t) => t.id), ['a']);

    final rawYesterday = prefs.getString('today_day_$yesterdayYmd');
    expect(rawYesterday, isNotNull);
    final yDay = TodayDayData.fromJsonString(rawYesterday!, fallbackYmd: yesterdayYmd);
    expect(yDay.tasks.map((t) => t.id), ['b']);
  });

  test('local mode: getYesterdayRecap counts tasks + habits', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();

    const todayYmd = '2026-01-31';
    const yesterdayYmd = '2026-01-30';

    final yesterday = TodayDayData(
      ymd: yesterdayYmd,
      tasks: [
        TodayTask(
          id: 'm1',
          title: 'Must 1',
          type: TodayTaskType.mustWin,
          date: yesterdayYmd,
          completed: true,
          inProgress: false,
          createdAt: DateTime.fromMillisecondsSinceEpoch(1),
        ),
        TodayTask(
          id: 'm2',
          title: 'Must 2',
          type: TodayTaskType.mustWin,
          date: yesterdayYmd,
          completed: false,
          inProgress: false,
          createdAt: DateTime.fromMillisecondsSinceEpoch(2),
        ),
        TodayTask(
          id: 'n1',
          title: 'Nice 1',
          type: TodayTaskType.niceToDo,
          date: yesterdayYmd,
          completed: true,
          inProgress: false,
          createdAt: DateTime.fromMillisecondsSinceEpoch(3),
        ),
      ],
      habits: const [],
      reflection: '',
      focusModeEnabled: false,
      focusTaskId: null,
      activeTimebox: null,
    );
    await prefs.setString('today_day_$yesterdayYmd', yesterday.toJsonString());

    final habits = _MemHabitsRepo()
      ..habits = const [
        Habit(id: 'h1', name: 'H1', createdAtMs: 1),
        Habit(id: 'h2', name: 'H2', createdAtMs: 2),
      ]
      ..completedByDay[yesterdayYmd] = {'h2'};

    final c = TodayTasksController(
      prefs: prefs,
      ymd: todayYmd,
      tasksRepository: null,
      taskDetailsRepository: null,
      habitsRepository: habits,
      linearIssueRepository: null,
      recordLinearSyncStatus: ({required DateTime at, String? error}) async {},
    );
    addTearDown(c.dispose);

    final recap = await c.getYesterdayRecap();
    expect(recap.mustWinTotal, 2);
    expect(recap.mustWinDone, 1);
    expect(recap.niceToDoTotal, 1);
    expect(recap.niceToDoDone, 1);
    expect(recap.habitsTotal, 2);
    expect(recap.habitsDone, 1);
    expect(recap.incompleteMustWins.map((t) => t.id), ['m2']);

    final expectedPercent = computeScorePercent(
      mustWinDone: 1,
      mustWinTotal: 2,
      niceToDoDone: 1,
      niceToDoTotal: 1,
      habitsDone: 1,
      habitsTotal: 2,
    );
    expect(recap.percent, expectedPercent);
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

