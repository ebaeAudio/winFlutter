import 'package:flutter_test/flutter_test.dart';

import 'package:win_flutter/data/tasks/all_tasks_models.dart';
import 'package:win_flutter/data/tasks/task.dart';
import 'package:win_flutter/features/tasks/all_tasks_query.dart';

AllTask _t({
  required String id,
  required String title,
  required TaskType type,
  required String ymd,
  String? goalYmd,
  required bool completed,
  bool inProgress = false,
  required int createdAtMs,
}) {
  return AllTask(
    id: id,
    title: title,
    type: type,
    ymd: ymd,
    goalYmd: goalYmd,
    completed: completed,
    inProgress: inProgress,
    createdAtMs: createdAtMs,
  );
}

void main() {
  test('applyAllTasksQuery filters by status + type + search', () {
    const today = '2026-01-12';
    final all = <AllTask>[
      _t(
        id: '1',
        title: 'Pay rent',
        type: TaskType.mustWin,
        ymd: today,
        completed: false,
        createdAtMs: 1,
      ),
      _t(
        id: '2',
        title: 'Read book',
        type: TaskType.niceToDo,
        ymd: today,
        completed: true,
        createdAtMs: 2,
      ),
    ];

    const query = AllTasksQuery(
      status: AllTasksStatusFilter.open,
      types: {TaskType.mustWin},
      searchQuery: 'rent',
      dateScope: AllTasksDateScope.any,
      sortField: AllTasksSortField.date,
      sortDescending: false,
    );

    final out = applyAllTasksQuery(all: all, query: query, todayYmd: today);
    expect(out.map((t) => t.id).toList(), ['1']);
  });

  test('applyAllTasksQuery filters by date scope', () {
    const today = '2026-01-12';
    final all = <AllTask>[
      _t(
        id: 'overdue',
        title: 'Overdue',
        type: TaskType.mustWin,
        ymd: '2026-01-10',
        completed: false,
        createdAtMs: 1,
      ),
      _t(
        id: 'today',
        title: 'Today',
        type: TaskType.mustWin,
        ymd: today,
        completed: false,
        createdAtMs: 2,
      ),
      _t(
        id: 'upcoming',
        title: 'Upcoming',
        type: TaskType.mustWin,
        ymd: '2026-01-20',
        completed: false,
        createdAtMs: 3,
      ),
    ];

    const base = AllTasksQuery(
      status: AllTasksStatusFilter.all,
      types: {TaskType.mustWin, TaskType.niceToDo},
      searchQuery: '',
      dateScope: AllTasksDateScope.any,
      sortField: AllTasksSortField.date,
      sortDescending: false,
    );

    expect(
      applyAllTasksQuery(
        all: all,
        query: base.copyWith(dateScope: AllTasksDateScope.overdue),
        todayYmd: today,
      ).map((t) => t.id).toList(),
      ['overdue'],
    );

    expect(
      applyAllTasksQuery(
        all: all,
        query: base.copyWith(dateScope: AllTasksDateScope.today),
        todayYmd: today,
      ).map((t) => t.id).toList(),
      ['today'],
    );

    expect(
      applyAllTasksQuery(
        all: all,
        query: base.copyWith(dateScope: AllTasksDateScope.upcoming),
        todayYmd: today,
      ).map((t) => t.id).toList(),
      ['upcoming'],
    );
  });

  test('applyAllTasksQuery sorts by title (asc/desc)', () {
    const today = '2026-01-12';
    final all = <AllTask>[
      _t(
        id: 'b',
        title: 'Bravo',
        type: TaskType.mustWin,
        ymd: today,
        completed: false,
        createdAtMs: 2,
      ),
      _t(
        id: 'a',
        title: 'Alpha',
        type: TaskType.mustWin,
        ymd: today,
        completed: false,
        createdAtMs: 1,
      ),
    ];

    const base = AllTasksQuery(
      status: AllTasksStatusFilter.all,
      types: {TaskType.mustWin, TaskType.niceToDo},
      searchQuery: '',
      dateScope: AllTasksDateScope.any,
      sortField: AllTasksSortField.title,
      sortDescending: false,
    );

    final asc = applyAllTasksQuery(all: all, query: base, todayYmd: today);
    expect(asc.map((t) => t.id).toList(), ['a', 'b']);

    final desc = applyAllTasksQuery(
      all: all,
      query: base.copyWith(sortDescending: true),
      todayYmd: today,
    );
    expect(desc.map((t) => t.id).toList(), ['b', 'a']);
  });
}

