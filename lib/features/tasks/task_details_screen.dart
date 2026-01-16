import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../app/errors.dart';
import '../../data/tasks/task_details_models.dart';
import '../../data/tasks/task_details_providers.dart';
import '../../data/linear/linear_issue_repository.dart';
import '../../data/linear/linear_models.dart';
import '../today/today_controller.dart';
import '../today/today_models.dart';
import '../../ui/app_scaffold.dart';
import '../../ui/components/reachability_fab_cluster.dart';
import '../../ui/components/linear_issue_card.dart';
import '../../ui/nav_shell.dart';
import '../../ui/spacing.dart';

class TaskDetailsScreen extends ConsumerStatefulWidget {
  const TaskDetailsScreen({
    super.key,
    required this.taskId,
    required this.ymd,
  });

  final String taskId;

  /// In Supabase mode this is optional; in local/demo mode this is required to
  /// locate the day payload in SharedPreferences.
  final String ymd;

  @override
  ConsumerState<TaskDetailsScreen> createState() => _TaskDetailsScreenState();
}

class _TaskDetailsScreenState extends ConsumerState<TaskDetailsScreen> {
  final _titleController = TextEditingController();
  final _notesController = TextEditingController();
  final _nextStepController = TextEditingController();
  final _estimateController = TextEditingController();
  final _actualController = TextEditingController();
  final _subtaskAddController = TextEditingController();

  final _notesKey = GlobalKey();
  final _subtasksKey = GlobalKey();

  bool _loading = true;
  String? _loadError;

  // Details fields
  String _notes = '';
  String _nextStep = '';
  int? _estimateMinutes;
  int? _actualMinutes;

  // Subtasks
  List<TaskSubtask> _subtasks = const [];

  bool _saving = false;
  String? _saveError;

  bool get _hasYmd => widget.ymd.trim().isNotEmpty;

  Future<void> _scrollTo(GlobalKey key) async {
    final ctx = key.currentContext;
    if (ctx == null) return;
    await Scrollable.ensureVisible(
      ctx,
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeInOutCubic,
      alignment: 0.10,
    );
  }

  static DateTime? _parseYmd(String ymd) {
    try {
      return DateTime.parse(ymd);
    } catch (_) {
      return null;
    }
  }

  static String _formatYmd(DateTime dt) => DateFormat('yyyy-MM-dd').format(dt);

  static String _friendlyDate(String ymd) {
    final dt = _parseYmd(ymd);
    if (dt == null) return ymd;
    return DateFormat('EEE, MMM d').format(dt);
  }

  Future<void> _pickGoalDate({
    required String ymd,
    required String taskId,
    required String? currentGoalYmd,
  }) async {
    final initial =
        _parseYmd(currentGoalYmd ?? '') ?? _parseYmd(ymd) ?? DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked == null) return;
    final nextYmd = _formatYmd(picked);
    await ref
        .read(todayControllerProvider(ymd).notifier)
        .setTaskGoalDate(taskId, nextYmd);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Goal date set to ${_friendlyDate(nextYmd)}')),
    );
  }

  Future<void> _clearGoalDate(
      {required String ymd, required String taskId}) async {
    await ref
        .read(todayControllerProvider(ymd).notifier)
        .setTaskGoalDate(taskId, null);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Goal date cleared')),
    );
  }

  @override
  void initState() {
    super.initState();
    _notesController.addListener(() {
      // Update Linear embed visibility as the user edits notes.
      if (mounted) setState(() {});
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  @override
  void dispose() {
    _titleController.dispose();
    _notesController.dispose();
    _nextStepController.dispose();
    _estimateController.dispose();
    _actualController.dispose();
    _subtaskAddController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _loadError = null;
      _saveError = null;
    });

    try {
      // Always try to seed from Today state if available (fast).
      if (_hasYmd) {
        final today = ref.read(todayControllerProvider(widget.ymd));
        final match = today.tasks
            .where((t) => t.id == widget.taskId)
            .toList(growable: false);
        if (match.isNotEmpty) {
          _seedFromTodayTask(match.first);
        }
      }

      final repo = ref.read(taskDetailsRepositoryProvider);
      if (repo != null) {
        final details = await repo.getDetails(taskId: widget.taskId);
        final subtasks = await repo.listSubtasks(taskId: widget.taskId);
        _seedFromRepo(details: details, subtasks: subtasks);
      } else {
        // Local/demo mode: details are stored on the Today task itself.
        if (_hasYmd) {
          final today = ref.read(todayControllerProvider(widget.ymd));
          final match = today.tasks
              .where((t) => t.id == widget.taskId)
              .toList(growable: false);
          if (match.isNotEmpty) _seedFromTodayTask(match.first);
        }
      }

      if (!mounted) return;
      setState(() => _loading = false);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _loadError = 'Could not load task details.';
      });
    }
  }

  void _seedFromRepo(
      {required TaskDetails details, required List<TaskSubtask> subtasks}) {
    _notes = details.notes ?? '';
    _nextStep = details.nextStep ?? '';
    _estimateMinutes = details.estimateMinutes;
    _actualMinutes = details.actualMinutes;
    _subtasks = subtasks;

    _notesController.text = _notes;
    _nextStepController.text = _nextStep;
    _estimateController.text = _estimateMinutes?.toString() ?? '';
    _actualController.text = _actualMinutes?.toString() ?? '';
  }

  void _seedFromTodayTask(TodayTask t) {
    _titleController.text = t.title;
    _notes = t.notes ?? '';
    _nextStep = t.nextStep ?? '';
    _estimateMinutes = t.estimateMinutes;
    _actualMinutes = t.actualMinutes;
    _subtasks = [
      for (final s in t.subtasks)
        TaskSubtask(
          id: s.id,
          localId: s.id,
          taskId: t.id,
          title: s.title,
          completed: s.completed,
          sortOrder: null,
        ),
    ];

    _notesController.text = _notes;
    _nextStepController.text = _nextStep;
    _estimateController.text = _estimateMinutes?.toString() ?? '';
    _actualController.text = _actualMinutes?.toString() ?? '';
  }

  int? _parseMinutes(String raw) {
    final t = raw.trim();
    if (t.isEmpty) return null;
    final n = int.tryParse(t);
    if (n == null) return null;
    if (n < 0) return 0;
    if (n > 24 * 60) return 24 * 60;
    return n;
  }

  Future<void> _saveDetails() async {
    if (_saving) return;
    setState(() {
      _saving = true;
      _saveError = null;
    });

    try {
      final nextNotes = _notesController.text.trimRight();
      final nextNextStep = _nextStepController.text.trimRight();
      final nextEstimate = _parseMinutes(_estimateController.text);
      final nextActual = _parseMinutes(_actualController.text);

      final repo = ref.read(taskDetailsRepositoryProvider);
      if (repo != null) {
        await repo.updateDetails(
          taskId: widget.taskId,
          notes: nextNotes,
          nextStep: nextNextStep,
          estimateMinutes: nextEstimate,
          actualMinutes: nextActual,
        );
      } else {
        // Local/demo mode
        if (!_hasYmd) throw StateError('Missing ymd in local mode');
        await ref
            .read(todayControllerProvider(widget.ymd).notifier)
            .updateTaskDetails(
              taskId: widget.taskId,
              notes: nextNotes,
              nextStep: nextNextStep,
              estimateMinutes: nextEstimate,
              actualMinutes: nextActual,
            );
      }

      if (!mounted) return;
      setState(() {
        _saving = false;
        _notes = nextNotes;
        _nextStep = nextNextStep;
        _estimateMinutes = nextEstimate;
        _actualMinutes = nextActual;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Saved')),
      );
      // After a successful save, return to the previous screen.
      context.pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _saveError = friendlyError(e);
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(friendlyError(e))),
      );
    }
  }

  Future<void> _addSubtask() async {
    final title = _subtaskAddController.text.trim();
    if (title.isEmpty) return;

    final repo = ref.read(taskDetailsRepositoryProvider);
    try {
      if (repo != null) {
        final created =
            await repo.createSubtask(taskId: widget.taskId, title: title);
        if (!mounted) return;
        setState(() {
          _subtasks = [..._subtasks, created];
          _subtaskAddController.clear();
        });
        return;
      }

      if (!_hasYmd) throw StateError('Missing ymd in local mode');
      await ref
          .read(todayControllerProvider(widget.ymd).notifier)
          .addSubtask(taskId: widget.taskId, title: title);

      // Refresh local from Today state.
      final today = ref.read(todayControllerProvider(widget.ymd));
      final match = today.tasks
          .where((t) => t.id == widget.taskId)
          .toList(growable: false);
      if (!mounted) return;
      if (match.isNotEmpty) {
        setState(() {
          _seedFromTodayTask(match.first);
          _subtaskAddController.clear();
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _saveError = friendlyError(e));
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(friendlyError(e))),
      );
    }
  }

  Future<void> _toggleSubtask(TaskSubtask s) async {
    final repo = ref.read(taskDetailsRepositoryProvider);
    try {
      if (repo != null) {
        final updated = await repo.setSubtaskCompleted(
          subtaskId: s.id,
          completed: !s.completed,
        );
        if (!mounted) return;
        setState(() {
          _subtasks = [
            for (final x in _subtasks)
              if (x.id == s.id) updated else x,
          ];
        });
        return;
      }

      if (!_hasYmd) throw StateError('Missing ymd in local mode');
      await ref
          .read(todayControllerProvider(widget.ymd).notifier)
          .setSubtaskCompleted(
            taskId: widget.taskId,
            subtaskId: s.localIdOrId,
            completed: !s.completed,
          );

      final today = ref.read(todayControllerProvider(widget.ymd));
      final match = today.tasks
          .where((t) => t.id == widget.taskId)
          .toList(growable: false);
      if (!mounted) return;
      if (match.isNotEmpty) {
        setState(() => _seedFromTodayTask(match.first));
      }
    } catch (_) {
      if (!mounted) return;
      setState(() => _saveError = 'Could not update subtask.');
    }
  }

  Future<void> _deleteSubtask(TaskSubtask s) async {
    final repo = ref.read(taskDetailsRepositoryProvider);
    try {
      if (repo != null) {
        await repo.deleteSubtask(subtaskId: s.id);
        if (!mounted) return;
        setState(
            () => _subtasks = _subtasks.where((x) => x.id != s.id).toList());
        return;
      }

      if (!_hasYmd) throw StateError('Missing ymd in local mode');
      await ref
          .read(todayControllerProvider(widget.ymd).notifier)
          .deleteSubtask(taskId: widget.taskId, subtaskId: s.localIdOrId);

      final today = ref.read(todayControllerProvider(widget.ymd));
      final match = today.tasks
          .where((t) => t.id == widget.taskId)
          .toList(growable: false);
      if (!mounted) return;
      if (match.isNotEmpty) {
        setState(() => _seedFromTodayTask(match.first));
      }
    } catch (_) {
      if (!mounted) return;
      setState(() => _saveError = 'Could not delete subtask.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final ymd = widget.ymd.trim();
    final today = ymd.isEmpty ? null : ref.watch(todayControllerProvider(ymd));
    final task =
        today?.tasks.where((t) => t.id == widget.taskId).toList().firstOrNull;

    final title = task?.title ?? _titleController.text;
    final linearRef = LinearIssueRef.tryParseFromText(_notesController.text);

    return AppScaffold(
      title: 'Task Details',
      actions: [
        IconButton(
          tooltip: 'Save',
          onPressed: _saving ? null : _saveDetails,
          icon: _saving
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.save),
        ),
      ],
      floatingActionButton: ReachabilityFabCluster(
        bottomBarHeight: NavShell.navBarHeight,
        actions: [
          ReachabilityFabAction(
            icon: Icons.keyboard_arrow_up,
            tooltip: 'Notes',
            onPressed: _loading ? null : () => _scrollTo(_notesKey),
            semanticLabel: 'Jump to notes',
          ),
          ReachabilityFabAction(
            icon: Icons.list_alt,
            tooltip: 'Subtasks',
            onPressed: _loading ? null : () => _scrollTo(_subtasksKey),
            semanticLabel: 'Jump to subtasks',
          ),
          if (task != null)
            ReachabilityFabAction(
              icon: task.completed ? Icons.undo : Icons.check,
              tooltip: task.completed ? 'Mark not completed' : 'Mark completed',
              onPressed: (_loading || _saving)
                  ? null
                  : () => ref
                      .read(todayControllerProvider(ymd).notifier)
                      .setTaskCompleted(widget.taskId, !task.completed),
              semanticLabel: task.completed
                  ? 'Mark task not completed'
                  : 'Mark task completed',
            ),
          ReachabilityFabAction(
            icon: Icons.save,
            tooltip: 'Save',
            label: 'Save',
            isPrimary: true,
            onPressed: (_loading || _saving) ? null : _saveDetails,
          ),
        ],
      ),
      children: [
        if (_loading)
          const Card(
            child: Padding(
              padding: EdgeInsets.all(AppSpace.s16),
              child: Center(child: CircularProgressIndicator()),
            ),
          )
        else if (_loadError != null)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(AppSpace.s16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(_loadError!,
                      style: Theme.of(context).textTheme.bodyLarge),
                  Gap.h12,
                  FilledButton.icon(
                    onPressed: _load,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Retry'),
                  ),
                ],
              ),
            ),
          )
        else ...[
          Card(
            child: Padding(
              padding: const EdgeInsets.all(AppSpace.s16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SelectionArea(
                    child: Text(
                      title.isEmpty ? '—' : title,
                      style: Theme.of(context)
                          .textTheme
                          .titleLarge
                          ?.copyWith(fontWeight: FontWeight.w900),
                    ),
                  ),
                  Gap.h8,
                  Wrap(
                    spacing: AppSpace.s8,
                    runSpacing: AppSpace.s8,
                    children: [
                      FilterChip(
                        label: const Text('Completed'),
                        selected: task?.completed == true,
                        onSelected: task == null
                            ? null
                            : (v) async {
                                setState(() => _saveError = null);
                                try {
                                  await ref
                                      .read(
                                          todayControllerProvider(ymd).notifier)
                                      .setTaskCompleted(widget.taskId, v);
                                } catch (e) {
                                  if (!mounted) return;
                                  setState(() => _saveError = friendlyError(e));
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text(friendlyError(e))),
                                  );
                                }
                              },
                      ),
                      FilterChip(
                        label: const Text('In progress'),
                        selected:
                            task?.inProgress == true && task?.completed != true,
                        onSelected: task == null
                            ? null
                            : (v) async {
                                setState(() => _saveError = null);
                                try {
                                  await ref
                                      .read(
                                          todayControllerProvider(ymd).notifier)
                                      .setTaskInProgress(widget.taskId, v);
                                } catch (e) {
                                  if (!mounted) return;
                                  setState(() => _saveError = friendlyError(e));
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text(friendlyError(e))),
                                  );
                                }
                              },
                      ),
                      if (task != null)
                        SegmentedButton<TodayTaskType>(
                          segments: const [
                            ButtonSegment(
                                value: TodayTaskType.mustWin,
                                label: Text('Must‑Win')),
                            ButtonSegment(
                                value: TodayTaskType.niceToDo,
                                label: Text('Nice‑to‑Do')),
                          ],
                          selected: {task.type},
                          onSelectionChanged: (s) => ref
                              .read(todayControllerProvider(ymd).notifier)
                              .moveTaskType(widget.taskId, s.first),
                        ),
                      if (task != null) ...[
                        if ((task.goalYmd ?? '').trim().isEmpty)
                          ActionChip(
                            avatar: const Icon(Icons.event),
                            label: const Text('Add goal date'),
                            onPressed: (_loading || _saving || ymd.isEmpty)
                                ? null
                                : () => _pickGoalDate(
                                      ymd: ymd,
                                      taskId: widget.taskId,
                                      currentGoalYmd: task.goalYmd,
                                    ),
                          )
                        else
                          InputChip(
                            avatar: const Icon(Icons.event),
                            label: Text('Due ${_friendlyDate(task.goalYmd!)}'),
                            onPressed: (_loading || _saving || ymd.isEmpty)
                                ? null
                                : () => _pickGoalDate(
                                      ymd: ymd,
                                      taskId: widget.taskId,
                                      currentGoalYmd: task.goalYmd,
                                    ),
                            onDeleted: (_loading || _saving || ymd.isEmpty)
                                ? null
                                : () => _clearGoalDate(
                                      ymd: ymd,
                                      taskId: widget.taskId,
                                    ),
                            deleteIcon: const Icon(Icons.close),
                          ),
                      ],
                      OutlinedButton.icon(
                        onPressed: () => context.pop(),
                        icon: const Icon(Icons.close),
                        label: const Text('Close'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          if (_saveError != null) ...[
            Gap.h8,
            Text(_saveError!,
                style: Theme.of(context)
                    .textTheme
                    .bodyMedium
                    ?.copyWith(color: Theme.of(context).colorScheme.error)),
          ],
          Gap.h16,
          if (linearRef != null) ...[
            Builder(
              builder: (context) {
                final repo = ref.watch(linearIssueRepositoryProvider);
                if (repo == null) {
                  return Card(
                    child: Padding(
                      padding: const EdgeInsets.all(AppSpace.s16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Linear link detected',
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.copyWith(fontWeight: FontWeight.w800),
                          ),
                          Gap.h8,
                          const Text(
                            'Add your Linear API key in Settings to show an issue preview and enable sync.',
                          ),
                          Gap.h12,
                          FilledButton.icon(
                            onPressed: () => context.go('/settings'),
                            icon: const Icon(Icons.settings),
                            label: const Text('Open settings'),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                final issueAsync = ref.watch(
                    linearIssueByIdentifierProvider(linearRef.identifier));
                return issueAsync.when(
                  loading: () => const Card(
                    child: Padding(
                      padding: EdgeInsets.all(AppSpace.s16),
                      child: Row(
                        children: [
                          SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                          Gap.w12,
                          Text('Loading Linear issue…'),
                        ],
                      ),
                    ),
                  ),
                  error: (e, _) => Card(
                    child: Padding(
                      padding: const EdgeInsets.all(AppSpace.s16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Could not load Linear issue.',
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.copyWith(fontWeight: FontWeight.w800),
                          ),
                          Gap.h8,
                          Text(e.toString(),
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(
                                    color: Theme.of(context).colorScheme.error,
                                  )),
                        ],
                      ),
                    ),
                  ),
                  data: (issue) {
                    if (issue == null) {
                      return Card(
                        child: Padding(
                          padding: const EdgeInsets.all(AppSpace.s16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Linear issue not found',
                                style: Theme.of(context)
                                    .textTheme
                                    .titleMedium
                                    ?.copyWith(fontWeight: FontWeight.w800),
                              ),
                              Gap.h8,
                              Text('Identifier: ${linearRef.identifier}'),
                            ],
                          ),
                        ),
                      );
                    }
                    return LinearIssueCard(
                      issue: issue,
                      onRefresh: () => ref.invalidate(
                        linearIssueByIdentifierProvider(linearRef.identifier),
                      ),
                    );
                  },
                );
              },
            ),
            Gap.h16,
          ],
          Card(
            key: _notesKey,
            child: Padding(
              padding: const EdgeInsets.all(AppSpace.s16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Notes',
                      style: Theme.of(context)
                          .textTheme
                          .titleMedium
                          ?.copyWith(fontWeight: FontWeight.w800)),
                  Gap.h8,
                  TextField(
                    controller: _notesController,
                    maxLines: 6,
                    decoration: const InputDecoration(
                      hintText: 'Add context, blockers, or the next tiny step…',
                    ),
                  ),
                ],
              ),
            ),
          ),
          Gap.h16,
          Card(
            child: Padding(
              padding: const EdgeInsets.all(AppSpace.s16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Tracking',
                      style: Theme.of(context)
                          .textTheme
                          .titleMedium
                          ?.copyWith(fontWeight: FontWeight.w800)),
                  Gap.h8,
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _estimateController,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'Estimate (min)',
                          ),
                        ),
                      ),
                      Gap.w12,
                      Expanded(
                        child: TextField(
                          controller: _actualController,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'Actual (min)',
                          ),
                        ),
                      ),
                    ],
                  ),
                  Gap.h12,
                  TextField(
                    controller: _nextStepController,
                    maxLines: 2,
                    decoration: const InputDecoration(
                      labelText: 'Next step',
                      hintText: 'Ex: Draft the first 3 sentences',
                    ),
                  ),
                ],
              ),
            ),
          ),
          Gap.h16,
          Card(
            key: _subtasksKey,
            child: Padding(
              padding: const EdgeInsets.all(AppSpace.s16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Subtasks',
                      style: Theme.of(context)
                          .textTheme
                          .titleMedium
                          ?.copyWith(fontWeight: FontWeight.w800)),
                  Gap.h8,
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _subtaskAddController,
                          textInputAction: TextInputAction.done,
                          onSubmitted: (_) => _addSubtask(),
                          decoration: const InputDecoration(
                            labelText: 'Add subtask',
                            hintText: 'Ex: Find the document',
                          ),
                        ),
                      ),
                      Gap.w8,
                      FilledButton(
                        onPressed: _addSubtask,
                        child: const Text('Add'),
                      ),
                    ],
                  ),
                  Gap.h12,
                  if (_subtasks.isEmpty)
                    Text(
                      'No subtasks yet.',
                      style: Theme.of(context).textTheme.bodySmall,
                    )
                  else ...[
                    for (final s in _subtasks)
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: Checkbox(
                          value: s.completed,
                          onChanged: (_) => _toggleSubtask(s),
                        ),
                        title: Text(s.title),
                        trailing: IconButton(
                          tooltip: 'Delete',
                          onPressed: () => _deleteSubtask(s),
                          icon: const Icon(Icons.delete_outline),
                        ),
                      ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }
}

extension<T> on List<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
