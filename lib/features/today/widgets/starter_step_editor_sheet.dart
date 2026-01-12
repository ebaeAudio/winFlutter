import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/tasks/task_details_providers.dart';
import '../../../ui/spacing.dart';
import '../today_controller.dart';

class StarterStepEditorSheet extends ConsumerStatefulWidget {
  const StarterStepEditorSheet({
    super.key,
    required this.taskId,
    required this.ymd,
    required this.taskTitle,
  });

  final String taskId;
  final String ymd;
  final String taskTitle;

  @override
  ConsumerState<StarterStepEditorSheet> createState() =>
      _StarterStepEditorSheetState();
}

class _StarterStepEditorSheetState extends ConsumerState<StarterStepEditorSheet> {
  static const int maxChars = 200;

  final _controller = TextEditingController();
  bool _seeded = false;

  bool _saving = false;
  String? _errorText;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _seedIfNeeded({required String initial}) {
    if (_seeded) return;
    _seeded = true;
    _controller.text = initial;
  }

  Future<void> _save() async {
    if (_saving) return;
    setState(() {
      _saving = true;
      _errorText = null;
    });

    try {
      final next = _controller.text.trimRight();
      if (next.length > maxChars) {
        setState(() {
          _saving = false;
          _errorText = 'Keep it under $maxChars characters.';
        });
        return;
      }

      final repo = ref.read(taskDetailsRepositoryProvider);
      if (repo != null) {
        await repo.updateDetails(taskId: widget.taskId, nextStep: next);
      } else {
        await ref.read(todayControllerProvider(widget.ymd).notifier).updateTaskDetails(
              taskId: widget.taskId,
              nextStep: next,
            );
      }

      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _errorText = 'Could not save. Try again.';
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to save starter step')),
      );
    }
  }

  void _clear() {
    _controller.clear();
    setState(() => _errorText = null);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final repo = ref.watch(taskDetailsRepositoryProvider);

    String? initial;
    if (repo == null) {
      final today = ref.watch(todayControllerProvider(widget.ymd));
      final match =
          today.tasks.where((t) => t.id == widget.taskId).toList(growable: false);
      initial = match.isEmpty ? '' : (match.first.nextStep ?? '');
    } else {
      final detailsAsync = ref.watch(taskDetailsProvider(widget.taskId));
      if (detailsAsync.hasError) {
        initial = '';
      } else {
        initial = detailsAsync.valueOrNull?.nextStep ?? '';
      }
    }

    _seedIfNeeded(initial: initial);

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: AppSpace.s16,
          right: AppSpace.s16,
          top: AppSpace.s12,
          bottom: MediaQuery.of(context).viewInsets.bottom + AppSpace.s16,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Starter step',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            Gap.h4,
            Text(
              widget.taskTitle,
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
            Gap.h12,
            TextField(
              controller: _controller,
              autofocus: true,
              maxLength: maxChars,
              minLines: 2,
              maxLines: 4,
              decoration: InputDecoration(
                labelText: 'Next 2 minutes',
                hintText: 'Ex: Open laptop and write the first line',
                errorText: _errorText,
              ),
              enabled: !_saving,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _save(),
            ),
            Gap.h8,
            Row(
              children: [
                TextButton(
                  onPressed: _saving ? null : _clear,
                  child: const Text('Clear'),
                ),
                const Spacer(),
                TextButton(
                  onPressed: _saving ? null : () => Navigator.of(context).pop(false),
                  child: const Text('Cancel'),
                ),
                Gap.w8,
                FilledButton(
                  onPressed: _saving ? null : _save,
                  child: Text(_saving ? 'Saving…' : 'Save'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

