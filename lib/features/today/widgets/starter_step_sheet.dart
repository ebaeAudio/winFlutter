import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/tasks/task_details_providers.dart';
import '../../../ui/spacing.dart';
import '../today_controller.dart';
import '../today_models.dart';

class StarterStepSheet extends ConsumerStatefulWidget {
  const StarterStepSheet({
    super.key,
    required this.ymd,
    required this.task,
    this.initialText,
  });

  final String ymd;
  final TodayTask task;
  final String? initialText;

  @override
  ConsumerState<StarterStepSheet> createState() => _StarterStepSheetState();
}

class _StarterStepSheetState extends ConsumerState<StarterStepSheet> {
  late final _controller =
      TextEditingController(text: widget.initialText ?? widget.task.starterStep);
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving) return;
    final next = _controller.text.trimRight();

    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      final repo = ref.read(taskDetailsRepositoryProvider);
      if (repo != null) {
        await repo.updateDetails(taskId: widget.task.id, nextStep: next);
        ref.invalidate(taskDetailsProvider(widget.task.id));
      } else {
        await ref
            .read(todayControllerProvider(widget.ymd).notifier)
            .updateTaskDetails(taskId: widget.task.id, nextStep: next);
      }
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = 'Could not save.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: AppSpace.s16,
          right: AppSpace.s16,
          top: AppSpace.s16,
          bottom: MediaQuery.viewInsetsOf(context).bottom + AppSpace.s16,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Make it smaller',
              style: theme.textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w800),
            ),
            Gap.h8,
            Text(
              'What’s the next 2 minutes? Keep it tiny and specific.',
              style: theme.textTheme.bodyMedium,
            ),
            Gap.h12,
            TextField(
              controller: _controller,
              maxLines: 2,
              decoration: InputDecoration(
                labelText: '2‑minute starter step',
                hintText: 'Ex: Open the doc and write the title',
                errorText: _error,
              ),
              enabled: !_saving,
              autofocus: true,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _save(),
            ),
            Gap.h12,
            Row(
              children: [
                TextButton(
                  onPressed:
                      _saving ? null : () => Navigator.of(context).pop(false),
                  child: const Text('Cancel'),
                ),
                const Spacer(),
                FilledButton(
                  onPressed: _saving ? null : _save,
                  child: _saving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Save'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

