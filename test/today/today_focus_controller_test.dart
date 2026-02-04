import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:win_flutter/domain/focus/active_timebox.dart';
import 'package:win_flutter/features/today/controllers/today_focus_controller.dart';
import 'package:win_flutter/features/today/today_models.dart';

void main() {
  test('local mode: reads/writes focus fields via today_day_ key', () async {
    const ymd = '2026-01-31';

    final initialDay = TodayDayData(
      ymd: ymd,
      tasks: [
        TodayTask(
          id: 't1',
          title: 'Task',
          type: TodayTaskType.mustWin,
          date: ymd,
          completed: false,
          inProgress: false,
          createdAt: DateTime.fromMillisecondsSinceEpoch(1),
        ),
      ],
      habits: const [],
      reflection: 'r',
      focusModeEnabled: true,
      focusTaskId: 't1',
      activeTimebox: null,
    );

    SharedPreferences.setMockInitialValues({
      'today_day_$ymd': initialDay.toJsonString(),
    });
    final prefs = await SharedPreferences.getInstance();

    final c = TodayFocusController(prefs: prefs, ymd: ymd, isSupabaseMode: false);
    addTearDown(c.dispose);

    expect(c.state.focusModeEnabled, true);
    expect(c.state.focusTaskId, 't1');

    await c.setFocusTaskId(null);
    await c.setFocusModeEnabled(false);

    final raw = prefs.getString('today_day_$ymd');
    expect(raw, isNotNull);
    final day = TodayDayData.fromJsonString(raw!, fallbackYmd: ymd);
    expect(day.focusModeEnabled, false);
    expect(day.focusTaskId, isNull);
    expect(day.tasks.map((t) => t.id), ['t1']); // preserved
    expect(day.reflection, 'r'); // preserved
  });

  test('supabase mode: auto-select chooses first incomplete mustWin', () async {
    const ymd = '2026-01-31';
    SharedPreferences.setMockInitialValues({
      'today_focus_enabled_$ymd': true,
    });
    final prefs = await SharedPreferences.getInstance();

    final c = TodayFocusController(prefs: prefs, ymd: ymd, isSupabaseMode: true);
    addTearDown(c.dispose);

    c.onTasksChanged([
      TodayTask(
        id: 'a',
        title: 'Done',
        type: TodayTaskType.mustWin,
        date: ymd,
        completed: true,
        inProgress: false,
        createdAt: DateTime.fromMillisecondsSinceEpoch(1),
      ),
      TodayTask(
        id: 'b',
        title: 'Pick me',
        type: TodayTaskType.mustWin,
        date: ymd,
        completed: false,
        inProgress: false,
        createdAt: DateTime.fromMillisecondsSinceEpoch(2),
      ),
    ]);

    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);

    expect(c.state.focusTaskId, 'b');
    expect(prefs.getString('today_focus_task_id_$ymd'), 'b');
  });

  test('supabase mode: clears focusTaskId when task disappears', () async {
    const ymd = '2026-01-31';
    SharedPreferences.setMockInitialValues({
      'today_focus_enabled_$ymd': true,
      'today_focus_task_id_$ymd': 'gone',
    });
    final prefs = await SharedPreferences.getInstance();

    final c = TodayFocusController(prefs: prefs, ymd: ymd, isSupabaseMode: true);
    addTearDown(c.dispose);

    c.onTasksChanged(const []);
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);

    expect(c.state.focusTaskId, isNull);
    expect(prefs.getString('today_focus_task_id_$ymd'), isNull);
  });

  test('supabase mode: setActiveTimebox persists to prefs', () async {
    const ymd = '2026-01-31';
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();

    final c = TodayFocusController(prefs: prefs, ymd: ymd, isSupabaseMode: true);
    addTearDown(c.dispose);

    final tb = ActiveTimebox(
      taskId: 't1',
      startedAt: DateTime.fromMillisecondsSinceEpoch(123),
      durationMinutes: 25,
    );
    await c.setActiveTimebox(tb);
    expect(prefs.getString('today_active_timebox_$ymd'), isNotNull);
  });
}

