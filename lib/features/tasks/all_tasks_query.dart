import 'package:flutter/foundation.dart';

import '../../data/tasks/all_tasks_models.dart';
import '../../data/tasks/task.dart';

enum AllTasksStatusFilter { open, done, all }

enum AllTasksDateScope { any, overdue, today, upcoming }

enum AllTasksSortField { date, created, title, type }

@immutable
class AllTasksQuery {
  const AllTasksQuery({
    required this.status,
    required this.types,
    required this.searchQuery,
    required this.dateScope,
    required this.sortField,
    required this.sortDescending,
  });

  final AllTasksStatusFilter status;
  final Set<TaskType> types;
  final String searchQuery;
  final AllTasksDateScope dateScope;
  final AllTasksSortField sortField;
  final bool sortDescending;

  AllTasksQuery copyWith({
    AllTasksStatusFilter? status,
    Set<TaskType>? types,
    String? searchQuery,
    AllTasksDateScope? dateScope,
    AllTasksSortField? sortField,
    bool? sortDescending,
  }) {
    return AllTasksQuery(
      status: status ?? this.status,
      types: types ?? this.types,
      searchQuery: searchQuery ?? this.searchQuery,
      dateScope: dateScope ?? this.dateScope,
      sortField: sortField ?? this.sortField,
      sortDescending: sortDescending ?? this.sortDescending,
    );
  }
}

List<AllTask> applyAllTasksQuery({
  required List<AllTask> all,
  required AllTasksQuery query,
  required String todayYmd,
}) {
  final q = query.searchQuery.trim().toLowerCase();

  final filtered = <AllTask>[
    for (final t in all)
      if (_matchesTypes(t, query.types))
        if (_matchesStatus(t, query.status))
          if (_matchesDateScope(t, query.dateScope, todayYmd))
            if (q.isEmpty || t.title.toLowerCase().contains(q)) t,
  ];

  filtered.sort(
    allTaskComparator(field: query.sortField, descending: query.sortDescending),
  );
  return filtered;
}

Comparator<AllTask> allTaskComparator({
  required AllTasksSortField field,
  required bool descending,
}) {
  int base(AllTask a, AllTask b) {
    switch (field) {
      case AllTasksSortField.date:
        final y = a.ymd.compareTo(b.ymd);
        if (y != 0) return y;
        break;
      case AllTasksSortField.created:
        final c = a.createdAtMs.compareTo(b.createdAtMs);
        if (c != 0) return c;
        break;
      case AllTasksSortField.title:
        final at = a.title.trim().toLowerCase();
        final bt = b.title.trim().toLowerCase();
        final t = at.compareTo(bt);
        if (t != 0) return t;
        break;
      case AllTasksSortField.type:
        final ty = a.type.index.compareTo(b.type.index);
        if (ty != 0) return ty;
        break;
    }

    // Stable-ish fallbacks: date, created, then id.
    final y = a.ymd.compareTo(b.ymd);
    if (y != 0) return y;
    final c = a.createdAtMs.compareTo(b.createdAtMs);
    if (c != 0) return c;
    return a.id.compareTo(b.id);
  }

  return (a, b) => descending ? -base(a, b) : base(a, b);
}

bool _matchesTypes(AllTask t, Set<TaskType> enabled) {
  return enabled.contains(t.type);
}

bool _matchesStatus(AllTask t, AllTasksStatusFilter status) {
  return switch (status) {
    AllTasksStatusFilter.all => true,
    AllTasksStatusFilter.open => !t.completed,
    AllTasksStatusFilter.done => t.completed,
  };
}

bool _matchesDateScope(AllTask t, AllTasksDateScope scope, String todayYmd) {
  return switch (scope) {
    AllTasksDateScope.any => true,
    AllTasksDateScope.overdue => t.ymd.compareTo(todayYmd) < 0,
    AllTasksDateScope.today => t.ymd == todayYmd,
    AllTasksDateScope.upcoming => t.ymd.compareTo(todayYmd) > 0,
  };
}

