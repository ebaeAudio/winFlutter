import 'package:flutter_test/flutter_test.dart';
import 'package:win_flutter/data/tasks/task.dart';
import 'package:win_flutter/domain/focus/active_timebox.dart';
import 'package:win_flutter/features/today/today_models.dart';

void main() {
  test('Task.fromDbJson reads starter_step + estimated_minutes', () {
    final t = Task.fromDbJson({
      'id': 't1',
      'user_id': 'u1',
      'title': 'Do the thing',
      'details': null,
      'starter_step': 'Open the doc',
      'estimated_minutes': 25,
      'type': 'must-win',
      'date': '2026-01-12',
      'completed': false,
      'created_at': '2026-01-12T10:00:00.000Z',
      'updated_at': '2026-01-12T10:00:00.000Z',
    });

    expect(t.starterStep, 'Open the doc');
    expect(t.estimatedMinutes, 25);
  });

  test('local Task JSON back-compat: legacy nextStep/estimateMinutes populate canonical Focus v2 fields', () {
    final parsed = Task.fromLocalJson({
      'id': 't1',
      'title': 'Do the thing',
      'type': 'must-win',
      'completed': false,
      'createdAtMs': 123,
      'nextStep': 'Open the doc',
      'estimateMinutes': 15,
    }, fallbackDate: '2026-01-12',);

    expect(parsed.starterStep, 'Open the doc');
    expect(parsed.estimatedMinutes, 15);
  });

  test('ActiveTimebox JSON round-trip', () {
    final box = ActiveTimebox(
      taskId: 't1',
      startedAt: DateTime.utc(2026, 1, 12, 10),
      durationMinutes: 25,
    );

    final raw = ActiveTimebox.toJsonString(box);
    final parsed = ActiveTimebox.fromJsonString(raw);

    expect(parsed, isNotNull);
    expect(parsed!.taskId, 't1');
    expect(parsed.durationMinutes, 25);
    expect(parsed.startedAt.toUtc(), DateTime.utc(2026, 1, 12, 10));
  });

  test('TodayDayData JSON round-trip includes activeTimebox', () {
    final day = TodayDayData(
      ymd: '2026-01-12',
      tasks: const [],
      habits: const [],
      reflection: '',
      focusModeEnabled: true,
      focusTaskId: 't1',
      activeTimebox: ActiveTimebox(
        taskId: 't1',
        startedAt: DateTime.utc(2026, 1, 12, 10),
        durationMinutes: 2,
      ),
    );

    final raw = day.toJsonString();
    final parsed = TodayDayData.fromJsonString(raw, fallbackYmd: '2026-01-12');

    expect(parsed.activeTimebox, isNotNull);
    expect(parsed.activeTimebox!.taskId, 't1');
    expect(parsed.activeTimebox!.durationMinutes, 2);
  });
}

