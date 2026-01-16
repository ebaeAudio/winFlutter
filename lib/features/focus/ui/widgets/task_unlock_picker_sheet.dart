import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../ui/spacing.dart';
import '../../../today/today_controller.dart';
import '../../../today/today_models.dart';

class TaskUnlockPickerSheetResult {
  const TaskUnlockPickerSheetResult(this.taskIds);
  final List<String> taskIds;
}

class TaskUnlockPickerSheet extends ConsumerStatefulWidget {
  const TaskUnlockPickerSheet({
    super.key,
    required this.ymd,
    required this.requiredCount,
    required this.initialSelectedTaskIds,
  });

  final String ymd;
  final int requiredCount;
  final List<String> initialSelectedTaskIds;

  static Future<TaskUnlockPickerSheetResult?> show(
    BuildContext context, {
    required String ymd,
    required int requiredCount,
    required List<String> initialSelectedTaskIds,
  }) {
    return showModalBottomSheet<TaskUnlockPickerSheetResult>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) => TaskUnlockPickerSheet(
        ymd: ymd,
        requiredCount: requiredCount,
        initialSelectedTaskIds: initialSelectedTaskIds,
      ),
    );
  }

  @override
  ConsumerState<TaskUnlockPickerSheet> createState() =>
      _TaskUnlockPickerSheetState();
}

class _TaskUnlockPickerSheetState extends ConsumerState<TaskUnlockPickerSheet> {
  final _newTaskController = TextEditingController();
  TodayTaskType _newTaskType = TodayTaskType.mustWin;
  final Set<String> _selected = <String>{};
  String? _inlineError;
  bool _adding = false;

  @override
  void initState() {
    super.initState();
    for (final id in widget.initialSelectedTaskIds) {
      final trimmed = id.trim();
      if (trimmed.isNotEmpty) _selected.add(trimmed);
    }
  }

  @override
  void dispose() {
    _newTaskController.dispose();
    super.dispose();
  }

  void _setInlineError(String? text) {
    setState(() => _inlineError = text);
  }

  Future<void> _addTask() async {
    final title = _newTaskController.text.trim();
    if (title.isEmpty) return;
    if (_adding) return;
    setState(() => _adding = true);
    try {
      final controller = ref.read(todayControllerProvider(widget.ymd).notifier);
      final ok = await controller.addTask(title: title, type: _newTaskType);
      if (!ok) {
        _setInlineError('Could not create that task.');
        return;
      }

      _newTaskController.clear();

      // Best-effort auto-select: pick the newest matching title if we still need tasks.
      if (_selected.length < widget.requiredCount) {
        final today = ref.read(todayControllerProvider(widget.ymd));
        final reversed = today.tasks.reversed.toList(growable: false);
        for (final t in reversed) {
          if (t.title.trim() == title) {
            _selected.add(t.id);
            break;
          }
        }
      }
      if (mounted) setState(() {});
    } catch (e) {
      _setInlineError('Failed to create task: $e');
    } finally {
      if (mounted) setState(() => _adding = false);
    }
  }

  void _toggle(String id, bool next) {
    _setInlineError(null);
    setState(() {
      if (next) {
        if (_selected.length >= widget.requiredCount) return;
        _selected.add(id);
      } else {
        _selected.remove(id);
      }
    });
  }

  void _confirm() {
    final ids = _selected.toList(growable: false);
    if (ids.length != widget.requiredCount) {
      _setInlineError('Select exactly ${widget.requiredCount} tasks.');
      return;
    }
    Navigator.pop(context, TaskUnlockPickerSheetResult(ids));
  }

  @override
  Widget build(BuildContext context) {
    final today = ref.watch(todayControllerProvider(widget.ymd));
    final tasks = today.tasks;

    final sorted = [
      ...tasks.where((t) => t.type == TodayTaskType.mustWin),
      ...tasks.where((t) => t.type == TodayTaskType.niceToDo),
    ];

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: AppSpace.s16,
          right: AppSpace.s16,
          bottom: AppSpace.s16 + MediaQuery.of(context).viewInsets.bottom,
          top: AppSpace.s8,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Unlock tasks',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 6),
            Text(
              'Select exactly ${widget.requiredCount} tasks to unlock ending this session early.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            Gap.h12,
            if (_inlineError != null) ...[
              Text(
                _inlineError!,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.error,
                      fontWeight: FontWeight.w700,
                    ),
              ),
              Gap.h8,
            ],
            Flexible(
              child: sorted.isEmpty
                  ? Card(
                      child: Padding(
                        padding: const EdgeInsets.all(AppSpace.s12),
                        child: Text(
                          'No tasks for ${widget.ymd} yet. Create a couple below.',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ),
                    )
                  : ListView(
                      shrinkWrap: true,
                      children: [
                        for (final t in sorted)
                          CheckboxListTile(
                            value: _selected.contains(t.id),
                            onChanged: (v) =>
                                _toggle(t.id, (v ?? false) == true),
                            title: Text(t.title),
                            subtitle: Text(
                              t.type == TodayTaskType.mustWin
                                  ? 'Must‑Win'
                                  : 'Nice‑to‑Do',
                            ),
                            secondary: t.completed
                                ? const Icon(Icons.check_circle)
                                : const Icon(Icons.circle_outlined),
                            controlAffinity: ListTileControlAffinity.leading,
                          ),
                      ],
                    ),
            ),
            Gap.h12,
            Text(
              'Quick create',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            Gap.h8,
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _newTaskController,
                    textInputAction: TextInputAction.done,
                    onSubmitted: (_) => unawaited(_addTask()),
                    decoration: const InputDecoration(
                      labelText: 'New task',
                      hintText: 'e.g., Submit report',
                    ),
                  ),
                ),
                Gap.w12,
                FilledButton.icon(
                  onPressed: _adding ? null : _addTask,
                  icon: const Icon(Icons.add),
                  label: const Text('Add'),
                ),
              ],
            ),
            Gap.h8,
            SegmentedButton<TodayTaskType>(
              segments: const [
                ButtonSegment(
                  value: TodayTaskType.mustWin,
                  label: Text('Must‑Win'),
                ),
                ButtonSegment(
                  value: TodayTaskType.niceToDo,
                  label: Text('Nice‑to‑Do'),
                ),
              ],
              selected: {_newTaskType},
              onSelectionChanged: (s) {
                if (s.isEmpty) return;
                setState(() => _newTaskType = s.first);
              },
            ),
            Gap.h16,
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context, null),
                    child: const Text('Cancel'),
                  ),
                ),
                Gap.w12,
                Expanded(
                  child: FilledButton(
                    onPressed: _confirm,
                    child: Text('Use ${_selected.length}/${widget.requiredCount}'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

