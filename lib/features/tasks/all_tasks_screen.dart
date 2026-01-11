import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../data/tasks/all_tasks_models.dart';
import '../../data/tasks/all_tasks_providers.dart';
import '../../data/tasks/all_tasks_repository.dart';
import '../../data/tasks/task.dart';
import '../../ui/app_scaffold.dart';
import '../../ui/components/empty_state_card.dart';
import '../../ui/components/section_header.dart';
import '../../ui/spacing.dart';

enum _StatusFilter { open, done, all }

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

  var _status = _StatusFilter.open;
  final _types = <TaskType>{TaskType.mustWin, TaskType.niceToDo};

  bool _selectMode = false;
  final _selected = <String>{};

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

  List<AllTask> _applyFilters(List<AllTask> all) {
    final q = _searchController.text.trim().toLowerCase();

    return [
      for (final t in all)
        if (_types.contains(t.type))
          if (_status == _StatusFilter.all ||
              (_status == _StatusFilter.open && !t.completed) ||
              (_status == _StatusFilter.done && t.completed))
            if (q.isEmpty || t.title.toLowerCase().contains(q)) t,
    ];
  }

  @override
  Widget build(BuildContext context) {
    final repo = ref.watch(allTasksRepositoryProvider);
    final asyncTasks = repo == null ? null : ref.watch(allTasksListProvider);
    final today = _todayYmd();

    return AppScaffold(
      title: 'All Tasks',
      actions: [
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
        Card(
          child: Padding(
            padding: const EdgeInsets.all(AppSpace.s16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Overview',
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontWeight: FontWeight.w800),
                ),
                Gap.h8,
                Text(
                  'A single place to see everything you’ve committed to — and give overdue items a second chance.',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                Gap.h12,
                TextField(
                  controller: _searchController,
                  decoration: const InputDecoration(
                    labelText: 'Search',
                    hintText: 'Find a task by title',
                    prefixIcon: Icon(Icons.search),
                  ),
                  onChanged: (_) => setState(() {}),
                ),
                Gap.h12,
                SegmentedButton<_StatusFilter>(
                  segments: const [
                    ButtonSegment(
                        value: _StatusFilter.open, label: Text('Open')),
                    ButtonSegment(
                        value: _StatusFilter.done, label: Text('Done')),
                    ButtonSegment(value: _StatusFilter.all, label: Text('All')),
                  ],
                  selected: {_status},
                  onSelectionChanged: (s) => setState(() => _status = s.first),
                ),
                Gap.h12,
                Wrap(
                  spacing: AppSpace.s8,
                  runSpacing: AppSpace.s8,
                  children: [
                    FilterChip(
                      label: const Text('Must‑Win'),
                      selected: _types.contains(TaskType.mustWin),
                      onSelected: (v) => setState(() {
                        v
                            ? _types.add(TaskType.mustWin)
                            : _types.remove(TaskType.mustWin);
                      }),
                    ),
                    FilterChip(
                      label: const Text('Nice‑to‑Do'),
                      selected: _types.contains(TaskType.niceToDo),
                      onSelected: (v) => setState(() {
                        v
                            ? _types.add(TaskType.niceToDo)
                            : _types.remove(TaskType.niceToDo);
                      }),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        Gap.h16,
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
              final filtered = _applyFilters(all);

              if (filtered.isEmpty) {
                return EmptyStateCard(
                  icon: Icons.check_circle_outline,
                  title: 'Nothing matches',
                  description:
                      'Try a different search or filter. If you’re empty on purpose — nice.',
                  ctaLabel: 'Go to Today',
                  onCtaPressed: () => context.go('/today'),
                );
              }

              final overdue = <AllTask>[];
              final todayList = <AllTask>[];
              final upcoming = <AllTask>[];
              final done = <AllTask>[];

              for (final t in filtered) {
                if (t.completed) {
                  done.add(t);
                } else if (t.ymd == today) {
                  todayList.add(t);
                } else if (t.ymd.compareTo(today) < 0) {
                  overdue.add(t);
                } else {
                  upcoming.add(t);
                }
              }

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _SummaryStrip(
                    total: filtered.length,
                    overdue: overdue.length,
                    today: todayList.length,
                    upcoming: upcoming.length,
                    done: done.length,
                  ),
                  Gap.h16,
                  if (overdue.isNotEmpty) ...[
                    const SectionHeader(
                        title: 'Overdue (give it a second chance)'),
                    _TasksGroup(
                      tasks: overdue,
                      selectMode: _selectMode,
                      selectedIds: _selected,
                      onToggleSelected: (id) => setState(() {
                        _selected.contains(id)
                            ? _selected.remove(id)
                            : _selected.add(id);
                      }),
                      onToggleCompleted: (t, v) => _setCompleted(repo, t, v),
                      onMoveToToday: (t) => _moveToToday(repo, t),
                      onChangeDate: (t) => _changeDate(repo, t),
                      onOpenDetails: (t) =>
                          context.push('/today/task/${t.id}?ymd=${t.ymd}'),
                    ),
                    Gap.h16,
                  ],
                  if (todayList.isNotEmpty) ...[
                    const SectionHeader(title: 'Today'),
                    _TasksGroup(
                      tasks: todayList,
                      selectMode: _selectMode,
                      selectedIds: _selected,
                      onToggleSelected: (id) => setState(() {
                        _selected.contains(id)
                            ? _selected.remove(id)
                            : _selected.add(id);
                      }),
                      onToggleCompleted: (t, v) => _setCompleted(repo, t, v),
                      onMoveToToday: null,
                      onChangeDate: (t) => _changeDate(repo, t),
                      onOpenDetails: (t) =>
                          context.push('/today/task/${t.id}?ymd=${t.ymd}'),
                    ),
                    Gap.h16,
                  ],
                  if (upcoming.isNotEmpty) ...[
                    const SectionHeader(title: 'Upcoming'),
                    _TasksGroup(
                      tasks: upcoming,
                      selectMode: _selectMode,
                      selectedIds: _selected,
                      onToggleSelected: (id) => setState(() {
                        _selected.contains(id)
                            ? _selected.remove(id)
                            : _selected.add(id);
                      }),
                      onToggleCompleted: (t, v) => _setCompleted(repo, t, v),
                      onMoveToToday: (t) => _moveToToday(repo, t),
                      onChangeDate: (t) => _changeDate(repo, t),
                      onOpenDetails: (t) =>
                          context.push('/today/task/${t.id}?ymd=${t.ymd}'),
                    ),
                    Gap.h16,
                  ],
                  if (done.isNotEmpty) ...[
                    SectionHeader(
                      title: 'Done',
                      trailing: Text('${done.length}'),
                    ),
                    _TasksGroup(
                      tasks: done,
                      selectMode: _selectMode,
                      selectedIds: _selected,
                      onToggleSelected: (id) => setState(() {
                        _selected.contains(id)
                            ? _selected.remove(id)
                            : _selected.add(id);
                      }),
                      onToggleCompleted: (t, v) => _setCompleted(repo, t, v),
                      onMoveToToday: (t) => _moveToToday(repo, t),
                      onChangeDate: (t) => _changeDate(repo, t),
                      onOpenDetails: (t) =>
                          context.push('/today/task/${t.id}?ymd=${t.ymd}'),
                    ),
                  ],
                ],
              );
            },
            loading: () => const Card(
              child: Padding(
                padding: EdgeInsets.all(AppSpace.s16),
                child: Center(child: CircularProgressIndicator()),
              ),
            ),
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

class _SummaryStrip extends StatelessWidget {
  const _SummaryStrip({
    required this.total,
    required this.overdue,
    required this.today,
    required this.upcoming,
    required this.done,
  });

  final int total;
  final int overdue;
  final int today;
  final int upcoming;
  final int done;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpace.s12),
        child: Wrap(
          spacing: AppSpace.s12,
          runSpacing: AppSpace.s8,
          children: [
            _Pill(
                label: 'Total',
                value: '$total',
                color: theme.colorScheme.surfaceContainerHighest),
            _Pill(
                label: 'Overdue',
                value: '$overdue',
                color: theme.colorScheme.errorContainer.withOpacity(0.35)),
            _Pill(
                label: 'Today',
                value: '$today',
                color: theme.colorScheme.primaryContainer.withOpacity(0.35)),
            _Pill(
                label: 'Upcoming',
                value: '$upcoming',
                color: theme.colorScheme.secondaryContainer.withOpacity(0.35)),
            _Pill(
                label: 'Done',
                value: '$done',
                color: theme.colorScheme.tertiaryContainer.withOpacity(0.35)),
          ],
        ),
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.label, required this.value, required this.color});

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpace.s12, vertical: AppSpace.s8),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: theme.dividerColor.withOpacity(0.35)),
      ),
      child: Text(
        '$label: $value',
        style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w700),
      ),
    );
  }
}

class _TasksGroup extends StatelessWidget {
  const _TasksGroup({
    required this.tasks,
    required this.selectMode,
    required this.selectedIds,
    required this.onToggleSelected,
    required this.onToggleCompleted,
    required this.onChangeDate,
    required this.onOpenDetails,
    this.onMoveToToday,
  });

  final List<AllTask> tasks;
  final bool selectMode;
  final Set<String> selectedIds;
  final void Function(String id) onToggleSelected;
  final Future<void> Function(AllTask task, bool completed) onToggleCompleted;
  final Future<void> Function(AllTask task) onChangeDate;
  final void Function(AllTask task) onOpenDetails;
  final Future<void> Function(AllTask task)? onMoveToToday;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpace.s8),
        child: Column(
          children: [
            for (final t in tasks)
              ListTile(
                onTap: selectMode
                    ? () => onToggleSelected(t.id)
                    : () => onOpenDetails(t),
                leading: selectMode
                    ? Checkbox(
                        value: selectedIds.contains(t.id),
                        onChanged: (_) => onToggleSelected(t.id),
                      )
                    : Checkbox(
                        value: t.completed,
                        onChanged: (v) => onToggleCompleted(t, v == true),
                      ),
                title: Text(
                  t.title,
                  style: t.completed
                      ? Theme.of(context).textTheme.bodyLarge?.copyWith(
                            decoration: TextDecoration.lineThrough,
                            color: Theme.of(context)
                                .colorScheme
                                .onSurface
                                .withOpacity(0.6),
                          )
                      : Theme.of(context).textTheme.bodyLarge,
                ),
                subtitle: Wrap(
                  spacing: AppSpace.s8,
                  runSpacing: AppSpace.s4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    _TypeTag(type: t.type),
                    Text(t.ymd, style: Theme.of(context).textTheme.bodySmall),
                  ],
                ),
                trailing: selectMode
                    ? null
                    : PopupMenuButton<String>(
                        onSelected: (value) async {
                          switch (value) {
                            case 'details':
                              onOpenDetails(t);
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
                          const PopupMenuDivider(),
                          if (onMoveToToday != null)
                            const PopupMenuItem(
                              value: 'today',
                              child: Text('Move to Today (second chance)'),
                            ),
                          const PopupMenuItem(
                            value: 'date',
                            child: Text('Change date…'),
                          ),
                        ],
                      ),
              ),
          ],
        ),
      ),
    );
  }
}

class _TypeTag extends StatelessWidget {
  const _TypeTag({required this.type});

  final TaskType type;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final label = switch (type) {
      TaskType.mustWin => 'Must‑Win',
      TaskType.niceToDo => 'Nice‑to‑Do',
    };
    final color = switch (type) {
      TaskType.mustWin => theme.colorScheme.primaryContainer.withOpacity(0.35),
      TaskType.niceToDo =>
        theme.colorScheme.secondaryContainer.withOpacity(0.35),
    };
    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpace.s8, vertical: AppSpace.s4),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: theme.dividerColor.withOpacity(0.35)),
      ),
      child: Text(
        label,
        style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w700),
      ),
    );
  }
}
