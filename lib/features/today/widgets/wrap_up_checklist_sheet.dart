import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/tasks/task_details_providers.dart';
import '../../../ui/spacing.dart';
import '../today_controller.dart';
import '../today_models.dart';

class WrapUpChecklistSheet extends ConsumerStatefulWidget {
  const WrapUpChecklistSheet({
    super.key,
    required this.ymd,
    required this.taskId,
    required this.taskTitle,
    required this.mustWins,
    this.taskNotes,
  });

  final String ymd;
  final String taskId;
  final String taskTitle;
  final List<TodayTask> mustWins;
  final String? taskNotes;

  static Future<void> show(
    BuildContext context, {
    required String ymd,
    required String taskId,
    required String taskTitle,
    required List<TodayTask> mustWins,
    String? taskNotes,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) => WrapUpChecklistSheet(
        ymd: ymd,
        taskId: taskId,
        taskTitle: taskTitle,
        mustWins: mustWins,
        taskNotes: taskNotes,
      ),
    );
  }

  @override
  ConsumerState<WrapUpChecklistSheet> createState() =>
      _WrapUpChecklistSheetState();
}

class _WrapUpChecklistSheetState
    extends ConsumerState<WrapUpChecklistSheet> {
  final _noteController = TextEditingController();
  bool _savedWork = false;
  bool _noteSaved = false;
  bool _savingNote = false;
  String? _noteError;
  String? _nextFocusTitle;

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final nextTask = _nextIncompleteMustWin();
    final canSetNext = nextTask != null && !_savingNote;

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: AppSpace.s16,
          right: AppSpace.s16,
          top: AppSpace.s8,
          bottom: AppSpace.s16 + MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Time's up",
              style: theme.textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w800),
            ),
            Gap.h8,
            Text(
              "Let's wrap up smoothly.",
              style: theme.textTheme.bodyMedium,
            ),
            if (widget.taskTitle.trim().isNotEmpty) ...[
              Gap.h12,
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(AppSpace.s12),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  color: theme.colorScheme.primaryContainer.withOpacity(0.35),
                  border: Border.all(color: theme.dividerColor.withOpacity(0.4)),
                ),
                child: Text(
                  widget.taskTitle,
                  style: theme.textTheme.titleSmall
                      ?.copyWith(fontWeight: FontWeight.w800),
                ),
              ),
            ],
            Gap.h12,
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              value: _savedWork,
              onChanged: (v) => setState(() => _savedWork = v ?? false),
              title: const Text('Save your work'),
              subtitle: const Text('Pause to put files, tabs, or notes somewhere safe.'),
              controlAffinity: ListTileControlAffinity.leading,
            ),
            Gap.h8,
            Text(
              'Note where you left off',
              style: theme.textTheme.titleSmall
                  ?.copyWith(fontWeight: FontWeight.w800),
            ),
            Gap.h8,
            TextField(
              controller: _noteController,
              minLines: 2,
              maxLines: 4,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _saveNote(context, showSnack: true),
              decoration: const InputDecoration(
                labelText: 'Quick note (optional)',
                hintText: 'What should you remember next time?',
              ),
            ),
            if (_noteError != null) ...[
              Gap.h8,
              Text(
                _noteError!,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.error,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
            Gap.h8,
            Row(
              children: [
                TextButton(
                  onPressed: _savingNote
                      ? null
                      : () => _saveNote(context, showSnack: true),
                  child: Text(_noteSaved ? 'Note saved' : 'Save note'),
                ),
                if (_savingNote) ...[
                  Gap.w8,
                  const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ],
              ],
            ),
            Gap.h12,
            Text(
              'Set next session focus',
              style: theme.textTheme.titleSmall
                  ?.copyWith(fontWeight: FontWeight.w800),
            ),
            Gap.h8,
            Row(
              children: [
                Expanded(
                  child: Text(
                    _nextFocusTitle != null
                        ? 'Next up: $_nextFocusTitle'
                        : nextTask == null
                            ? 'No incomplete Must-Wins.'
                            : 'Pick the next Must-Win to resume.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
                Gap.w12,
                OutlinedButton(
                  onPressed: canSetNext ? () => _setNextFocus(context) : null,
                  child: const Text('Set next'),
                ),
              ],
            ),
            Gap.h16,
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton(
                onPressed: () async {
                  if (!_noteSaved &&
                      _noteController.text.trim().isNotEmpty &&
                      !_savingNote) {
                    await _saveNote(context, showSnack: false);
                  }
                  if (!context.mounted) return;
                  Navigator.of(context).pop();
                },
                child: const Text('Done'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  TodayTask? _nextIncompleteMustWin() {
    for (final t in widget.mustWins) {
      if (!t.completed && t.id != widget.taskId) return t;
    }
    return null;
  }

  Future<void> _setNextFocus(BuildContext context) async {
    final next = _nextIncompleteMustWin();
    if (next == null) return;

    await ref
        .read(todayControllerProvider(widget.ymd).notifier)
        .setFocusTaskId(next.id);

    if (!context.mounted) return;
    setState(() => _nextFocusTitle = next.title);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("Next focus set to '${next.title}'")),
    );
  }

  Future<void> _saveNote(BuildContext context,
      {required bool showSnack}) async {
    final raw = _noteController.text.trim();
    if (raw.isEmpty) return;

    setState(() {
      _savingNote = true;
      _noteError = null;
    });

    try {
      final repo = ref.read(taskDetailsRepositoryProvider);
      String existing = widget.taskNotes ?? '';
      if (repo != null) {
        final details = await repo.getDetails(taskId: widget.taskId);
        existing = details.notes ?? '';
      }
      final merged = _mergeLastTimeNote(existing, raw);
      if (repo != null) {
        await repo.updateDetails(taskId: widget.taskId, notes: merged);
        ref.invalidate(taskDetailsProvider(widget.taskId));
      } else {
        await ref
            .read(todayControllerProvider(widget.ymd).notifier)
            .updateTaskDetails(taskId: widget.taskId, notes: merged);
      }

      if (!context.mounted) return;
      setState(() {
        _savingNote = false;
        _noteSaved = true;
      });
      if (showSnack) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Saved to task notes')),
        );
      }
    } catch (e) {
      if (!context.mounted) return;
      setState(() {
        _savingNote = false;
        _noteError = 'Could not save the note. Try again.';
      });
      if (showSnack) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not save the note')),
        );
      }
    }
  }
}

String _mergeLastTimeNote(String existing, String note) {
  final trimmedNote = note.trim();
  if (trimmedNote.isEmpty) return existing;

  final line = 'Last time: $trimmedNote';
  final lines = existing.split('\n');
  final idx = lines.indexWhere(
    (l) => l.trimLeft().startsWith('Last time:'),
  );
  if (idx != -1) {
    lines[idx] = line;
    return lines.join('\n').trimRight();
  }
  if (existing.trim().isEmpty) return line;
  return '${existing.trimRight()}\n\n$line';
}
