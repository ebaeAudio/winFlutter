import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../spacing.dart';

/// Result of a quick capture action.
class QuickCaptureResult {
  const QuickCaptureResult({
    required this.text,
    required this.type,
    this.targetDate,
  });

  final String text;
  final QuickCaptureType type;
  final DateTime? targetDate;
}

/// Type of item being captured.
enum QuickCaptureType {
  task,
  mustWin,
  habit,
  note,
  focusStart,
}

/// Shows the quick capture overlay as a floating dialog.
///
/// Returns the captured result, or null if dismissed.
Future<QuickCaptureResult?> showQuickCapture(BuildContext context) {
  return showDialog<QuickCaptureResult>(
    context: context,
    barrierColor: Colors.black54,
    builder: (context) => const QuickCaptureDialog(),
  );
}

/// The quick capture dialog widget.
///
/// Supports smart parsing of input:
/// - "Buy groceries" → Task (Nice-to-Do, today)
/// - "!Call client" → Must-Win (! prefix)
/// - "tomorrow !Review contract" → Must-Win for tomorrow
/// - "#Water 8 glasses" → Habit (# prefix)
/// - "note: Great idea..." → Reflection append
/// - "/focus 25" → Start 25-min focus session
class QuickCaptureDialog extends StatefulWidget {
  const QuickCaptureDialog({super.key});

  @override
  State<QuickCaptureDialog> createState() => _QuickCaptureDialogState();
}

class _QuickCaptureDialogState extends State<QuickCaptureDialog> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();

  QuickCaptureType _inferredType = QuickCaptureType.task;
  DateTime? _inferredDate;
  String _displayText = '';

  @override
  void initState() {
    super.initState();
    _controller.addListener(_parseInput);

    // Auto-focus the input field.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _parseInput() {
    final text = _controller.text.trim();
    if (text.isEmpty) {
      setState(() {
        _inferredType = QuickCaptureType.task;
        _inferredDate = null;
        _displayText = '';
      });
      return;
    }

    var workingText = text;
    QuickCaptureType type = QuickCaptureType.task;
    DateTime? targetDate;

    // Check for focus command: /focus N
    if (workingText.startsWith('/focus')) {
      setState(() {
        _inferredType = QuickCaptureType.focusStart;
        _inferredDate = null;
        _displayText = workingText.replaceFirst('/focus', '').trim();
      });
      return;
    }

    // Check for note prefix: note:
    if (workingText.toLowerCase().startsWith('note:')) {
      setState(() {
        _inferredType = QuickCaptureType.note;
        _inferredDate = null;
        _displayText = workingText.substring(5).trim();
      });
      return;
    }

    // Check for habit prefix: #
    if (workingText.startsWith('#')) {
      setState(() {
        _inferredType = QuickCaptureType.habit;
        _inferredDate = null;
        _displayText = workingText.substring(1).trim();
      });
      return;
    }

    // Check for date prefixes: "today", "tomorrow", etc.
    final lowerText = workingText.toLowerCase();
    final now = DateTime.now();

    if (lowerText.startsWith('today ')) {
      targetDate = DateTime(now.year, now.month, now.day);
      workingText = workingText.substring(6).trim();
    } else if (lowerText.startsWith('tomorrow ')) {
      targetDate = DateTime(now.year, now.month, now.day).add(const Duration(days: 1));
      workingText = workingText.substring(9).trim();
    }

    // Check for must-win prefix: !
    if (workingText.startsWith('!')) {
      type = QuickCaptureType.mustWin;
      workingText = workingText.substring(1).trim();
    }

    setState(() {
      _inferredType = type;
      _inferredDate = targetDate;
      _displayText = workingText;
    });
  }

  void _submit() {
    final text = _displayText.trim();
    if (text.isEmpty && _inferredType != QuickCaptureType.focusStart) return;

    Navigator.of(context).pop(QuickCaptureResult(
      text: text,
      type: _inferredType,
      targetDate: _inferredDate,
    ));
  }

  String get _typeLabel {
    switch (_inferredType) {
      case QuickCaptureType.task:
        return 'Task';
      case QuickCaptureType.mustWin:
        return 'Must-Win';
      case QuickCaptureType.habit:
        return 'Habit';
      case QuickCaptureType.note:
        return 'Note';
      case QuickCaptureType.focusStart:
        return 'Focus';
    }
  }

  IconData get _typeIcon {
    switch (_inferredType) {
      case QuickCaptureType.task:
        return Icons.check_circle_outline;
      case QuickCaptureType.mustWin:
        return Icons.flag;
      case QuickCaptureType.habit:
        return Icons.repeat;
      case QuickCaptureType.note:
        return Icons.note_add;
      case QuickCaptureType.focusStart:
        return Icons.timer;
    }
  }

  Color _typeColor(ColorScheme scheme) {
    switch (_inferredType) {
      case QuickCaptureType.task:
        return scheme.primary;
      case QuickCaptureType.mustWin:
        return scheme.error;
      case QuickCaptureType.habit:
        return scheme.tertiary;
      case QuickCaptureType.note:
        return scheme.secondary;
      case QuickCaptureType.focusStart:
        return scheme.primary;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return KeyboardListener(
      focusNode: FocusNode(),
      autofocus: false,
      onKeyEvent: (event) {
        if (event is! KeyDownEvent) return;
        if (event.logicalKey == LogicalKeyboardKey.escape) {
          Navigator.of(context).pop();
        }
      },
      child: Center(
        child: Material(
          color: Colors.transparent,
          child: Container(
            width: 480,
            decoration: BoxDecoration(
              color: scheme.surface,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.25),
                  blurRadius: 24,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // ─────────────────────────────────────────────────────────────
                // Header
                // ─────────────────────────────────────────────────────────────
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpace.s16,
                    AppSpace.s16,
                    AppSpace.s16,
                    AppSpace.s8,
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.bolt,
                        color: scheme.primary,
                        size: 20,
                      ),
                      Gap.w8,
                      Text(
                        'Quick Capture',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: scheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          'esc',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // ─────────────────────────────────────────────────────────────
                // Input Field
                // ─────────────────────────────────────────────────────────────
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpace.s16,
                  ),
                  child: TextField(
                    controller: _controller,
                    focusNode: _focusNode,
                    style: theme.textTheme.bodyLarge,
                    decoration: InputDecoration(
                      hintText: 'What needs to be done?',
                      hintStyle: theme.textTheme.bodyLarge?.copyWith(
                        color: scheme.onSurfaceVariant.withOpacity(0.5),
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(
                          color: scheme.outlineVariant,
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(
                          color: scheme.primary,
                          width: 2,
                        ),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: AppSpace.s16,
                        vertical: AppSpace.s12,
                      ),
                    ),
                    onSubmitted: (_) => _submit(),
                  ),
                ),

                Gap.h12,

                // ─────────────────────────────────────────────────────────────
                // Inferred Type Indicator
                // ─────────────────────────────────────────────────────────────
                if (_displayText.isNotEmpty || _controller.text.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpace.s16,
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: _typeColor(scheme).withOpacity(0.15),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                _typeIcon,
                                size: 16,
                                color: _typeColor(scheme),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                _typeLabel,
                                style: theme.textTheme.labelMedium?.copyWith(
                                  color: _typeColor(scheme),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (_inferredDate != null) ...[
                          Gap.w8,
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: scheme.surfaceContainerHighest,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.calendar_today,
                                  size: 14,
                                  color: scheme.onSurfaceVariant,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  _formatDate(_inferredDate!),
                                  style: theme.textTheme.labelMedium?.copyWith(
                                    color: scheme.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),

                Gap.h16,

                // ─────────────────────────────────────────────────────────────
                // Tips
                // ─────────────────────────────────────────────────────────────
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpace.s16,
                  ),
                  child: Wrap(
                    spacing: AppSpace.s12,
                    runSpacing: AppSpace.s8,
                    children: [
                      _HintChip(label: '!task', description: 'Must-Win'),
                      _HintChip(label: '#habit', description: 'Habit'),
                      _HintChip(label: 'note:', description: 'Reflection'),
                      _HintChip(label: 'tomorrow', description: 'Schedule'),
                      _HintChip(label: '/focus 25', description: 'Timer'),
                    ],
                  ),
                ),

                Gap.h16,

                // ─────────────────────────────────────────────────────────────
                // Actions
                // ─────────────────────────────────────────────────────────────
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpace.s16,
                    0,
                    AppSpace.s16,
                    AppSpace.s16,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: const Text('Cancel'),
                      ),
                      Gap.w8,
                      FilledButton.icon(
                        onPressed: _displayText.trim().isEmpty &&
                                _inferredType != QuickCaptureType.focusStart
                            ? null
                            : _submit,
                        icon: const Icon(Icons.add, size: 18),
                        label: const Text('Add'),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final tomorrow = today.add(const Duration(days: 1));
    final targetDay = DateTime(date.year, date.month, date.day);

    if (targetDay == today) return 'Today';
    if (targetDay == tomorrow) return 'Tomorrow';
    return '${date.month}/${date.day}';
  }
}

class _HintChip extends StatelessWidget {
  const _HintChip({
    required this.label,
    required this.description,
  });

  final String label;
  final String description;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: scheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(
              color: scheme.onSurfaceVariant,
              fontFamily: 'monospace',
            ),
          ),
        ),
        const SizedBox(width: 4),
        Text(
          description,
          style: theme.textTheme.labelSmall?.copyWith(
            color: scheme.onSurfaceVariant.withOpacity(0.7),
          ),
        ),
      ],
    );
  }
}
