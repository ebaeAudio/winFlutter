import 'package:flutter/material.dart';

import '../spacing.dart';

class TaskDetailsSheet extends StatefulWidget {
  const TaskDetailsSheet({
    super.key,
    required this.title,
    required this.initialDetails,
    required this.maxLength,
    required this.onSave,
  });

  final String title;
  final String initialDetails;
  final int maxLength;
  final Future<void> Function(String nextDetails) onSave;

  @override
  State<TaskDetailsSheet> createState() => _TaskDetailsSheetState();
}

class _TaskDetailsSheetState extends State<TaskDetailsSheet> {
  late final TextEditingController _controller =
      TextEditingController(text: widget.initialDetails);

  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving) return;
    final next = _controller.text;
    if (next.trim().length > widget.maxLength) {
      setState(() => _error = 'Keep it under ${widget.maxLength} characters.');
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      await widget.onSave(next);
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = 'Could not save changes.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
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
              'Task details',
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.w800),
            ),
            Gap.h8,
            Text(widget.title, style: Theme.of(context).textTheme.bodyMedium),
            Gap.h12,
            TextField(
              controller: _controller,
              minLines: 3,
              maxLines: 8,
              maxLength: widget.maxLength,
              decoration: InputDecoration(
                labelText: 'Note',
                hintText: 'Add context (optional)',
                errorText: _error,
              ),
              enabled: !_saving,
            ),
            Gap.h8,
            Row(
              children: [
                TextButton(
                  onPressed: _saving ? null : () => Navigator.of(context).pop(false),
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

