import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'dart:async';

import '../../data/tasks/all_tasks_models.dart';
import '../../data/tasks/all_tasks_providers.dart';
import '../../data/tasks/all_tasks_repository.dart';
import '../../data/tasks/zombie_tasks_provider.dart';
import '../../data/tasks/task.dart';
import '../../data/tasks/task_realtime_provider.dart';
import '../../app/theme.dart';
import 'all_tasks_query.dart';
import '../../ui/app_scaffold.dart';
import '../../ui/components/empty_state_card.dart';
import '../../ui/components/section_header.dart';
import '../today/widgets/zombie_task_alert_card.dart';
import '../../ui/components/task_list.dart';
import '../../ui/spacing.dart';

final _allTasksRefreshProvider = StateProvider<int>((_) => 0);

final allTasksListProvider = FutureProvider<List<AllTask>>((ref) async {
  // Change this value to force a refresh after mutations.
  ref.watch(_allTasksRefreshProvider);

  final repo = ref.watch(allTasksRepositoryProvider);
  if (repo == null) return const [];
  return repo.listAll();
});

class AllTasksScreen extends ConsumerStatefulWidget {
  const AllTasksScreen({super.key});

  @override
  ConsumerState<AllTasksScreen> createState() => _AllTasksScreenState();
}

class _AllTasksScreenState extends ConsumerState<AllTasksScreen> {
  final _searchController = TextEditingController();

  var _status = AllTasksStatusFilter.open;
  final _types = <TaskType>{TaskType.mustWin, TaskType.niceToDo};
  var _dateScope = AllTasksDateScope.any;
  var _sortField = AllTasksSortField.date;
  var _sortDescending = false;
  var _groupByBuckets = true;

  bool _selectMode = false;
  final _selected = <String>{};
  bool _showCompleted = false;
  final _sendingToCompleted = <String>{};

  static const _sendOffDuration = Duration(milliseconds: 260);

  @override
  void initState() {
    super.initState();
    _loadViewPrefs();
  }

  void _loadViewPrefs() {
    final prefs = ref.read(sharedPreferencesProvider);
    final dateScopeRaw = prefs.getString(_kDateScope);
    final sortFieldRaw = prefs.getString(_kSortField);

    _dateScope = AllTasksDateScope.values.firstWhere(
      (v) => v.name == dateScopeRaw,
      orElse: () => AllTasksDateScope.any,
    );
    _sortField = AllTasksSortField.values.firstWhere(
      (v) => v.name == sortFieldRaw,
      orElse: () => AllTasksSortField.date,
    );
    _sortDescending = prefs.getBool(_kSortDescending) ?? false;
    _groupByBuckets = prefs.getBool(_kGroupByBuckets) ?? true;
  }

  Future<void> _saveViewPrefs() async {
    final prefs = ref.read(sharedPreferencesProvider);
    await prefs.setString(_kDateScope, _dateScope.name);
    await prefs.setString(_kSortField, _sortField.name);
    await prefs.setBool(_kSortDescending, _sortDescending);
    await prefs.setBool(_kGroupByBuckets, _groupByBuckets);
  }

  static const _kDateScope = 'all_tasks_date_scope';
  static const _kSortField = 'all_tasks_sort_field';
  static const _kSortDescending = 'all_tasks_sort_desc';
  static const _kGroupByBuckets = 'all_tasks_group_by_buckets';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  String _todayYmd() => DateFormat('yyyy-MM-dd').format(DateTime.now());

  void _refresh() {
    ref.read(_allTasksRefreshProvider.notifier).state++;
  }

  Future<void> _moveToToday(AllTasksRepository repo, AllTask t) async {
    final today = _todayYmd();
    await repo.moveToDate(
      fromYmd: t.ymd,
      toYmd: today,
      taskId: t.id,
      resetCompleted: true,
    );
    if (!mounted) return;
    _refresh();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Moved to Today')),
    );
  }

  Future<void> _moveSelectedToToday(
      AllTasksRepository repo, List<AllTask> all) async {
    final today = _todayYmd();
    final selectedTasks = all.where((t) => _selected.contains(t.id)).toList();
    if (selectedTasks.isEmpty) return;

    for (final t in selectedTasks) {
      await repo.moveToDate(
        fromYmd: t.ymd,
        toYmd: today,
        taskId: t.id,
        resetCompleted: true,
      );
    }

    if (!mounted) return;
    setState(() {
      _selected.clear();
      _selectMode = false;
    });
    _refresh();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Moved ${selectedTasks.length} to Today')),
    );
  }

  Future<void> _setCompleted(
      AllTasksRepository repo, AllTask t, bool completed) async {
    await repo.setCompleted(ymd: t.ymd, taskId: t.id, completed: completed);
    if (!mounted) return;
    _refresh();
  }

  Future<void> _setInProgress(
      AllTasksRepository repo, AllTask t, bool inProgress) async {
    try {
      await repo.setInProgress(
        ymd: t.ymd,
        taskId: t.id,
        inProgress: inProgress,
      );
      if (!mounted) return;
      _refresh();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(inProgress ? 'Marked in progress' : 'Cleared in progress'),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not update task.')),
      );
    }
  }

  Future<void> _setCompletedWithSendOff(
      AllTasksRepository repo, AllTask t, bool completed) async {
    // Only animate "send off" when completing an open task (Active list UX).
    if (!completed || t.completed) return _setCompleted(repo, t, completed);
    if (_sendingToCompleted.contains(t.id)) return;

    setState(() => _sendingToCompleted.add(t.id));

    try {
      await Future.wait([
        Future<void>.delayed(_sendOffDuration),
        repo.setCompleted(ymd: t.ymd, taskId: t.id, completed: true),
      ]);
      if (!mounted) return;
      _refresh();

      // Keep the row "collapsed" until at least the next frame to prevent a
      // one-frame pop-back while the provider refreshes.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        setState(() => _sendingToCompleted.remove(t.id));
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _sendingToCompleted.remove(t.id));
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not update task.')),
      );
    }
  }

  Future<void> _changeDate(AllTasksRepository repo, AllTask t) async {
    final initial = _parseYmd(t.ymd) ?? DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked == null) return;
    final nextYmd = DateFormat('yyyy-MM-dd').format(picked);
    await repo.moveToDate(
      fromYmd: t.ymd,
      toYmd: nextYmd,
      taskId: t.id,
      resetCompleted: false,
    );
    if (!mounted) return;
    _refresh();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Moved to $nextYmd')),
    );
  }

  static DateTime? _parseYmd(String ymd) {
    try {
      return DateTime.parse(ymd);
    } catch (_) {
      return null;
    }
  }

  Widget _buildTasksBody({
    required AllTasksRepository repo,
    required List<AllTask> all,
    required AllTasksQuery query,
    required String todayYmd,
  }) {
    final filtered = applyAllTasksQuery(
      all: all,
      query: query,
      todayYmd: todayYmd,
    );

    if (filtered.isEmpty) {
      return EmptyStateCard(
        icon: Icons.check_circle_outline,
        title: 'Nothing matches',
        description: 'Try a different search or filter.',
        ctaLabel: 'Go to Today',
        onCtaPressed: () => context.go('/today'),
      );
    }

    final open = <AllTask>[];
    var done = <AllTask>[];
    for (final t in filtered) {
      (t.completed ? done : open).add(t);
    }

    // `filtered` is already sorted; keep stable-ish ordering.
    //
    // Preserve the previous UX: when sorting by time (date/created)
    // ascending, show Completed newest-first.
    if ((query.sortField == AllTasksSortField.date ||
            query.sortField == AllTasksSortField.created) &&
        !query.sortDescending) {
      done = done.reversed.toList(growable: false);
    }

    final overdue = <AllTask>[];
    final todayList = <AllTask>[];
    final upcoming = <AllTask>[];
    if (_groupByBuckets) {
      for (final t in open) {
        if (t.ymd == todayYmd) {
          todayList.add(t);
        } else if (t.ymd.compareTo(todayYmd) < 0) {
          overdue.add(t);
        } else {
          upcoming.add(t);
        }
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_status != AllTasksStatusFilter.done) ...[
          SectionHeader(
            title: 'Active',
            trailing: Text('${open.length}'),
          ),
          if (open.isEmpty)
            EmptyStateCard(
              icon: Icons.inbox_outlined,
              title: 'No active tasks',
              description: 'You’re clear right now.',
              ctaLabel: 'Go to Today',
              onCtaPressed: () => context.go('/today'),
            )
          else ...[
            if (!_groupByBuckets)
              _TasksListCard(
                tasks: open,
                selectMode: _selectMode,
                selectedIds: _selected,
                sendingToCompletedIds: _sendingToCompleted,
                sendOffDuration: _sendOffDuration,
                onToggleSelected: (id) => setState(() {
                  _selected.contains(id) ? _selected.remove(id) : _selected.add(id);
                }),
                onToggleCompleted: (t, v) => _setCompletedWithSendOff(repo, t, v),
                onToggleInProgress: (t, v) => _setInProgress(repo, t, v),
                onMoveToToday: (t) => _moveToToday(repo, t),
                onChangeDate: (t) => _changeDate(repo, t),
                onOpenDetails: (t) =>
                    context.push('/today/task/${t.id}?ymd=${t.ymd}'),
              )
            else ...[
              if (overdue.isNotEmpty) ...[
                const _ListLabel(title: 'Overdue'),
                _TasksListCard(
                  tasks: overdue,
                  selectMode: _selectMode,
                  selectedIds: _selected,
                  sendingToCompletedIds: _sendingToCompleted,
                  sendOffDuration: _sendOffDuration,
                  onToggleSelected: (id) => setState(() {
                    _selected.contains(id)
                        ? _selected.remove(id)
                        : _selected.add(id);
                  }),
                  onToggleCompleted: (t, v) => _setCompletedWithSendOff(repo, t, v),
                  onToggleInProgress: (t, v) => _setInProgress(repo, t, v),
                  onMoveToToday: (t) => _moveToToday(repo, t),
                  onChangeDate: (t) => _changeDate(repo, t),
                  onOpenDetails: (t) =>
                      context.push('/today/task/${t.id}?ymd=${t.ymd}'),
                ),
                Gap.h12,
              ],
              if (todayList.isNotEmpty) ...[
                const _ListLabel(title: 'Today'),
                _TasksListCard(
                  tasks: todayList,
                  selectMode: _selectMode,
                  selectedIds: _selected,
                  sendingToCompletedIds: _sendingToCompleted,
                  sendOffDuration: _sendOffDuration,
                  onToggleSelected: (id) => setState(() {
                    _selected.contains(id)
                        ? _selected.remove(id)
                        : _selected.add(id);
                  }),
                  onToggleCompleted: (t, v) => _setCompletedWithSendOff(repo, t, v),
                  onToggleInProgress: (t, v) => _setInProgress(repo, t, v),
                  onMoveToToday: null,
                  onChangeDate: (t) => _changeDate(repo, t),
                  onOpenDetails: (t) =>
                      context.push('/today/task/${t.id}?ymd=${t.ymd}'),
                ),
                Gap.h12,
              ],
              if (upcoming.isNotEmpty) ...[
                const _ListLabel(title: 'Upcoming'),
                _TasksListCard(
                  tasks: upcoming,
                  selectMode: _selectMode,
                  selectedIds: _selected,
                  sendingToCompletedIds: _sendingToCompleted,
                  sendOffDuration: _sendOffDuration,
                  onToggleSelected: (id) => setState(() {
                    _selected.contains(id)
                        ? _selected.remove(id)
                        : _selected.add(id);
                  }),
                  onToggleCompleted: (t, v) => _setCompletedWithSendOff(repo, t, v),
                  onToggleInProgress: (t, v) => _setInProgress(repo, t, v),
                  onMoveToToday: (t) => _moveToToday(repo, t),
                  onChangeDate: (t) => _changeDate(repo, t),
                  onOpenDetails: (t) =>
                      context.push('/today/task/${t.id}?ymd=${t.ymd}'),
                ),
              ],
            ],
          ],
        ],
        if (_status != AllTasksStatusFilter.open) ...[
          Gap.h16,
          SectionHeader(
            title: 'Completed',
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('${done.length}'),
                Gap.w8,
                TextButton(
                  onPressed: done.isEmpty
                      ? null
                      : () => setState(() => _showCompleted = !_showCompleted),
                  child: Text(_showCompleted ? 'Hide' : 'Show'),
                ),
              ],
            ),
          ),
          if (done.isEmpty)
            Text(
              'Nothing completed yet.',
              style: Theme.of(context).textTheme.bodySmall,
            )
          else if (_showCompleted)
            _TasksListCard(
              tasks: done,
              selectMode: _selectMode,
              selectedIds: _selected,
              sendingToCompletedIds: const {},
              sendOffDuration: _sendOffDuration,
              onToggleSelected: (id) => setState(() {
                _selected.contains(id) ? _selected.remove(id) : _selected.add(id);
              }),
              onToggleCompleted: (t, v) => _setCompleted(repo, t, v),
              onToggleInProgress: (t, v) => _setInProgress(repo, t, v),
              onMoveToToday: (t) => _moveToToday(repo, t),
              onChangeDate: (t) => _changeDate(repo, t),
              onOpenDetails: (t) =>
                  context.push('/today/task/${t.id}?ymd=${t.ymd}'),
            ),
        ],
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    // Listen for realtime task changes from other devices.
    // Refresh the task list when any change is detected.
    ref.listen<AsyncValue<TaskChangeEvent?>>(
      taskRealtimeChangesProvider,
      (previous, next) {
        final event = next.valueOrNull;
        if (event != null) {
          // Trigger a refresh by incrementing the refresh counter.
          ref.read(_allTasksRefreshProvider.notifier).state++;
        }
      },
    );

    final repo = ref.watch(allTasksRepositoryProvider);
    final asyncTasks = repo == null ? null : ref.watch(allTasksListProvider);
    // Avoid flashing a full-screen loading state during refreshes (e.g. after
    // toggling completion). If we already have data, keep showing it while the
    // provider fetches updated results in the background.
    final cachedTasks = asyncTasks?.valueOrNull;
    final today = _todayYmd();
    final query = AllTasksQuery(
      status: _status,
      types: _types,
      searchQuery: _searchController.text,
      dateScope: _dateScope,
      sortField: _sortField,
      sortDescending: _sortDescending,
    );

    return AppScaffold(
      title: _selectMode ? 'Select tasks (${_selected.length})' : 'Tasks',
      actions: [
        IconButton(
          tooltip: 'Add task',
          onPressed: () => context.go('/today'),
          icon: const Icon(Icons.add),
        ),
        IconButton(
          tooltip: _selectMode ? 'Exit select mode' : 'Select',
          onPressed: () => setState(() {
            _selectMode = !_selectMode;
            _selected.clear();
          }),
          icon: Icon(_selectMode ? Icons.close : Icons.checklist),
        ),
        IconButton(
          tooltip: 'Refresh',
          onPressed: _refresh,
          icon: const Icon(Icons.refresh),
        ),
      ],
      bottomNavigationBar: _selectMode && repo != null
          ? SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.all(AppSpace.s12),
                child: Row(
                  children: [
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: _selected.isEmpty
                            ? null
                            : () async {
                                final all = asyncTasks?.valueOrNull ?? const [];
                                await _moveSelectedToToday(repo, all);
                              },
                        icon: const Icon(Icons.today),
                        label: Text('Move to Today (${_selected.length})'),
                      ),
                    ),
                  ],
                ),
              ),
            )
          : null,
      children: [
        _FiltersCard(
          searchController: _searchController,
          status: _status,
          types: _types,
          dateScope: _dateScope,
          sortField: _sortField,
          sortDescending: _sortDescending,
          groupByBuckets: _groupByBuckets,
          selectMode: _selectMode,
          onStatusChanged: (next) => setState(() {
            _status = next;
            if (_status == AllTasksStatusFilter.done) _showCompleted = true;
            unawaited(_saveViewPrefs());
          }),
          onTypeToggled: (type, enabled) => setState(() {
            enabled ? _types.add(type) : _types.remove(type);
            unawaited(_saveViewPrefs());
          }),
          onDateScopeChanged: (next) => setState(() {
            _dateScope = next;
            unawaited(_saveViewPrefs());
          }),
          onSortFieldChanged: (next) => setState(() {
            _sortField = next;
            unawaited(_saveViewPrefs());
          }),
          onToggleSortDirection: () => setState(() {
            _sortDescending = !_sortDescending;
            unawaited(_saveViewPrefs());
          }),
          onGroupByBucketsChanged: (enabled) => setState(() {
            _groupByBuckets = enabled;
            unawaited(_saveViewPrefs());
          }),
          onSearchChanged: () => setState(() {}),
        ),
        Gap.h16,
        Builder(
          builder: (context) {
            final zombiesAsync = ref.watch(zombieTasksProvider);
            final zombies = zombiesAsync.valueOrNull;
            if (zombies == null || zombies.isEmpty) {
              return const SizedBox.shrink();
            }
            return Padding(
              padding: const EdgeInsets.only(bottom: AppSpace.s16),
              child: ZombieTaskAlertCard(
                zombies: zombies,
                onOpen: () => context.go('/tasks/cleanup'),
              ),
            );
          },
        ),
        if (repo == null)
          EmptyStateCard(
            icon: Icons.cloud_off,
            title: 'Tasks are unavailable',
            description:
                'Connect Supabase or enable Demo Mode to view tasks here.',
            ctaLabel: 'Go to Settings',
            onCtaPressed: () => context.go('/settings'),
          )
        else
          asyncTasks!.when(
            data: (all) {
              return _buildTasksBody(
                repo: repo,
                all: all,
                query: query,
                todayYmd: today,
              );
            },
            loading: () {
              // Keep showing previously loaded results while refreshing.
              final all = cachedTasks;
              if (all != null) {
                return _buildTasksBody(
                  repo: repo,
                  all: all,
                  query: query,
                  todayYmd: today,
                );
              }

              return const Card(
                child: Padding(
                  padding: EdgeInsets.all(AppSpace.s16),
                  child: Center(child: CircularProgressIndicator()),
                ),
              );
            },
            error: (_, __) => Card(
              child: Padding(
                padding: const EdgeInsets.all(AppSpace.s16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Could not load tasks.',
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                    Gap.h12,
                    FilledButton.icon(
                      onPressed: _refresh,
                      icon: const Icon(Icons.refresh),
                      label: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _FiltersCard extends StatelessWidget {
  const _FiltersCard({
    required this.searchController,
    required this.status,
    required this.types,
    required this.dateScope,
    required this.sortField,
    required this.sortDescending,
    required this.groupByBuckets,
    required this.selectMode,
    required this.onStatusChanged,
    required this.onTypeToggled,
    required this.onDateScopeChanged,
    required this.onSortFieldChanged,
    required this.onToggleSortDirection,
    required this.onGroupByBucketsChanged,
    required this.onSearchChanged,
  });

  final TextEditingController searchController;
  final AllTasksStatusFilter status;
  final Set<TaskType> types;
  final AllTasksDateScope dateScope;
  final AllTasksSortField sortField;
  final bool sortDescending;
  final bool groupByBuckets;
  final bool selectMode;
  final ValueChanged<AllTasksStatusFilter> onStatusChanged;
  final void Function(TaskType type, bool enabled) onTypeToggled;
  final ValueChanged<AllTasksDateScope> onDateScopeChanged;
  final ValueChanged<AllTasksSortField> onSortFieldChanged;
  final VoidCallback onToggleSortDirection;
  final ValueChanged<bool> onGroupByBucketsChanged;
  final VoidCallback onSearchChanged;

  String _sortLabel(AllTasksSortField f) {
    return switch (f) {
      AllTasksSortField.date => 'Date',
      AllTasksSortField.created => 'Created',
      AllTasksSortField.title => 'Title',
      AllTasksSortField.type => 'Type',
    };
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpace.s16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: searchController,
              decoration: const InputDecoration(
                labelText: 'Search',
                hintText: 'Find a task',
                prefixIcon: Icon(Icons.search),
              ),
              onChanged: (_) => onSearchChanged(),
            ),
            Gap.h12,
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<AllTasksSortField>(
                    value: sortField,
                    decoration: const InputDecoration(labelText: 'Sort'),
                    items: [
                      for (final f in AllTasksSortField.values)
                        DropdownMenuItem(value: f, child: Text(_sortLabel(f))),
                    ],
                    onChanged: (v) {
                      if (v == null) return;
                      onSortFieldChanged(v);
                    },
                  ),
                ),
                Gap.w8,
                IconButton(
                  tooltip: sortDescending ? 'Descending' : 'Ascending',
                  onPressed: onToggleSortDirection,
                  icon: Icon(
                    sortDescending ? Icons.arrow_downward : Icons.arrow_upward,
                  ),
                ),
              ],
            ),
            Gap.h12,
            Wrap(
              spacing: AppSpace.s8,
              runSpacing: AppSpace.s8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                SegmentedButton<AllTasksStatusFilter>(
                  segments: const [
                    ButtonSegment(
                        value: AllTasksStatusFilter.open,
                        label: Text('Active')),
                    ButtonSegment(
                        value: AllTasksStatusFilter.done,
                        label: Text('Completed')),
                    ButtonSegment(
                        value: AllTasksStatusFilter.all, label: Text('All')),
                  ],
                  selected: {status},
                  onSelectionChanged: (s) => onStatusChanged(s.first),
                ),
                SegmentedButton<AllTasksDateScope>(
                  segments: const [
                    ButtonSegment(value: AllTasksDateScope.any, label: Text('Any')),
                    ButtonSegment(
                        value: AllTasksDateScope.overdue,
                        label: Text('Overdue')),
                    ButtonSegment(
                        value: AllTasksDateScope.today, label: Text('Today')),
                    ButtonSegment(
                        value: AllTasksDateScope.upcoming,
                        label: Text('Upcoming')),
                  ],
                  selected: {dateScope},
                  onSelectionChanged: (s) => onDateScopeChanged(s.first),
                ),
                FilterChip(
                  label: const Text('Must‑Win'),
                  selected: types.contains(TaskType.mustWin),
                  onSelected: (v) => onTypeToggled(TaskType.mustWin, v),
                ),
                FilterChip(
                  label: const Text('Nice‑to‑Do'),
                  selected: types.contains(TaskType.niceToDo),
                  onSelected: (v) => onTypeToggled(TaskType.niceToDo, v),
                ),
                FilterChip(
                  label: const Text('Group by date'),
                  selected: groupByBuckets,
                  onSelected: onGroupByBucketsChanged,
                ),
              ],
            ),
            if (selectMode) ...[
              Gap.h12,
              Text(
                'Select tasks to move them back into Today.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ListLabel extends StatelessWidget {
  const _ListLabel({required this.title});
  final String title;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: AppSpace.s8, bottom: AppSpace.s8),
      child: Text(
        title,
        style: theme.textTheme.bodySmall?.copyWith(
          fontWeight: FontWeight.w700,
          color: theme.colorScheme.onSurfaceVariant.withOpacity(0.95),
        ),
      ),
    );
  }
}

class _TasksListCard extends StatelessWidget {
  const _TasksListCard({
    required this.tasks,
    required this.selectMode,
    required this.selectedIds,
    required this.sendingToCompletedIds,
    required this.sendOffDuration,
    required this.onToggleSelected,
    required this.onToggleCompleted,
    required this.onToggleInProgress,
    required this.onChangeDate,
    required this.onOpenDetails,
    this.onMoveToToday,
  });

  final List<AllTask> tasks;
  final bool selectMode;
  final Set<String> selectedIds;
  final Set<String> sendingToCompletedIds;
  final Duration sendOffDuration;
  final void Function(String id) onToggleSelected;
  final Future<void> Function(AllTask task, bool completed) onToggleCompleted;
  final Future<void> Function(AllTask task, bool inProgress) onToggleInProgress;
  final Future<void> Function(AllTask task) onChangeDate;
  final void Function(AllTask task) onOpenDetails;
  final Future<void> Function(AllTask task)? onMoveToToday;

  String _typeLabel(TaskType type) {
    return switch (type) {
      TaskType.mustWin => 'Must‑Win',
      TaskType.niceToDo => 'Nice‑to‑Do',
    };
  }

  String _dateLabel(String ymd) {
    if (ymd.trim().isEmpty) return '';
    try {
      final dt = DateTime.parse(ymd);
      return DateFormat('MMM d').format(dt);
    } catch (_) {
      return ymd;
    }
  }

  String _dueLabel(String ymd) {
    if (ymd.trim().isEmpty) return '';
    try {
      final dt = DateTime.parse(ymd);
      return DateFormat('MMM d').format(dt);
    } catch (_) {
      return ymd;
    }
  }

  bool _isOverdue({required String? goalYmd, required bool completed}) {
    if (completed) return false;
    final raw = (goalYmd ?? '').trim();
    if (raw.isEmpty) return false;
    try {
      final goal = DateTime.parse(raw);
      final today = DateTime.now();
      final todayDate = DateTime(today.year, today.month, today.day);
      final goalDate = DateTime(goal.year, goal.month, goal.day);
      return goalDate.isBefore(todayDate);
    } catch (_) {
      return false;
    }
  }

  Color _typeDotColor(BuildContext context, TaskType type) {
    final scheme = Theme.of(context).colorScheme;
    return switch (type) {
      TaskType.mustWin => scheme.primary,
      TaskType.niceToDo => scheme.secondary,
    };
  }

  Widget _metadata(BuildContext context, AllTask t) {
    final theme = Theme.of(context);
    final hasDue = (t.goalYmd ?? '').trim().isNotEmpty;
    final overdue = _isOverdue(goalYmd: t.goalYmd, completed: t.completed);
    final dueColor =
        overdue ? theme.colorScheme.error : theme.colorScheme.onSurfaceVariant;
    return Wrap(
      spacing: AppSpace.s8,
      runSpacing: AppSpace.s4,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        if (t.inProgress && !t.completed)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.timelapse, size: 16, color: theme.colorScheme.primary),
              Gap.w8,
              Text(
                'In progress',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: _typeDotColor(context, t.type),
                borderRadius: BorderRadius.circular(999),
              ),
            ),
            Gap.w8,
            Text(_typeLabel(t.type)),
          ],
        ),
        Text(
          _dateLabel(t.ymd),
          style: theme.textTheme.bodySmall,
        ),
        if (hasDue)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.event, size: 16, color: dueColor),
              Gap.w8,
              Text(
                'Due ${_dueLabel(t.goalYmd!)}',
                style: theme.textTheme.bodySmall?.copyWith(color: dueColor),
              ),
            ],
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return TaskListCard(
      children: [
        for (final t in tasks)
          _SendOffTaskRow(
            // Important: keep a stable element association per task id.
            // Without keys, when a row is removed (e.g. after completing a task),
            // Flutter may re-use the previous row's stateful animation elements
            // (TweenAnimationBuilder) for the next task in the list, causing a
            // brief "weird reload" animation.
            key: ValueKey<String>(t.id),
            sending: !selectMode && sendingToCompletedIds.contains(t.id),
            duration: sendOffDuration,
            child: TaskListRow(
              title: t.title,
              completed: (!selectMode && sendingToCompletedIds.contains(t.id))
                  ? true
                  : t.completed,
              leading: selectMode
                  ? Checkbox(
                      value: selectedIds.contains(t.id),
                      onChanged: (_) => onToggleSelected(t.id),
                    )
                  : Checkbox(
                      value: sendingToCompletedIds.contains(t.id)
                          ? true
                          : t.completed,
                      onChanged: sendingToCompletedIds.contains(t.id)
                          ? null
                          : (v) => onToggleCompleted(t, v == true),
                    ),
              onTap: selectMode
                  ? () => onToggleSelected(t.id)
                  : (sendingToCompletedIds.contains(t.id)
                      ? null
                      : () => onOpenDetails(t)),
              metadata: _metadata(context, t),
              trailing: selectMode
                  ? null
                  : (sendingToCompletedIds.contains(t.id)
                      ? Padding(
                          padding: const EdgeInsets.only(top: AppSpace.s4),
                          child: Icon(
                            Icons.check_circle,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        )
                      : PopupMenuButton<String>(
                          tooltip: 'More',
                          icon: const Icon(Icons.more_horiz),
                          onSelected: (value) async {
                            switch (value) {
                              case 'details':
                                onOpenDetails(t);
                                break;
                              case 'progress':
                                await onToggleInProgress(t, !t.inProgress);
                                break;
                              case 'today':
                                final f = onMoveToToday;
                                if (f != null) await f(t);
                                break;
                              case 'date':
                                await onChangeDate(t);
                                break;
                            }
                          },
                          itemBuilder: (context) => [
                            const PopupMenuItem(
                                value: 'details', child: Text('Details')),
                            PopupMenuItem(
                              value: 'progress',
                              child: Text(
                                t.inProgress
                                    ? 'Clear in progress'
                                    : 'Mark in progress',
                              ),
                            ),
                            const PopupMenuDivider(),
                            if (onMoveToToday != null)
                              const PopupMenuItem(
                                value: 'today',
                                child: Text('Move to Today'),
                              ),
                            const PopupMenuItem(
                              value: 'date',
                              child: Text('Change date…'),
                            ),
                          ],
                        )),
            ),
          ),
      ],
    );
  }
}

class _SendOffTaskRow extends StatelessWidget {
  const _SendOffTaskRow({
    super.key,
    required this.sending,
    required this.duration,
    required this.child,
  });

  final bool sending;
  final Duration duration;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: sending ? 1 : 0),
      duration: duration,
      curve: Curves.easeInOutCubic,
      child: child,
      builder: (context, t, child) {
        return ClipRect(
          child: Align(
            heightFactor: 1 - t,
            child: Opacity(
              opacity: 1 - t,
              child: Transform.translate(
                offset: Offset(56 * t, 0),
                child: child,
              ),
            ),
          ),
        );
      },
    );
  }
}
