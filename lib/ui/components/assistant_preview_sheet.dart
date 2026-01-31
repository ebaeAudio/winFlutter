import 'package:flutter/material.dart';

import '../../assistant/assistant_models.dart';
import '../../utils/ymd_utils.dart';
import '../spacing.dart';

class AssistantPreviewSheet extends StatelessWidget {
  const AssistantPreviewSheet({
    super.key,
    required this.baseDate,
    required this.say,
    required this.commands,
  });

  final DateTime baseDate;
  final String? say;
  final List<AssistantCommand> commands;

  static String _ymd(DateTime dt) => formatYmd(dt);

  static DateTime? _parseYmd(String ymd) => parseYmd(ymd);

  static String _taskTypeLabel(AssistantTaskType? t) {
    return switch (t) {
      AssistantTaskType.mustWin => 'Must‑Win',
      AssistantTaskType.niceToDo => 'Nice‑to‑Do',
      null => 'Must‑Win',
    };
  }

  List<_PreviewRow> _buildRows() {
    final rows = <_PreviewRow>[];
    var execDate = DateTime(baseDate.year, baseDate.month, baseDate.day);

    for (final cmd in commands) {
      switch (cmd) {
        case DateShiftCommand():
          execDate = execDate.add(Duration(days: cmd.days));
          rows.add(
            _PreviewRow(
              icon: Icons.calendar_month,
              title: 'Set date',
              subtitle: _ymd(execDate),
            ),
          );
          break;

        case DateSetCommand():
          final parsed = _parseYmd(cmd.ymd);
          if (parsed == null) {
            rows.add(
              _PreviewRow(
                icon: Icons.error_outline,
                title: 'Invalid date',
                subtitle: cmd.ymd,
                isError: true,
              ),
            );
            break;
          }
          execDate = DateTime(parsed.year, parsed.month, parsed.day);
          rows.add(
            _PreviewRow(
              icon: Icons.calendar_month,
              title: 'Set date',
              subtitle: _ymd(execDate),
            ),
          );
          break;

        case TaskCreateCommand():
          rows.add(
            _PreviewRow(
              icon: Icons.add_task,
              title: 'Add ${_taskTypeLabel(cmd.taskType)} task',
              subtitle: '“${cmd.title}” (${_ymd(execDate)})',
            ),
          );
          break;

        case TaskSetCompletedCommand():
          rows.add(
            _PreviewRow(
              icon: cmd.completed ? Icons.check_circle : Icons.radio_button_unchecked,
              title: cmd.completed ? 'Complete task' : 'Uncomplete task',
              subtitle: '“${cmd.title}” (${_ymd(execDate)})',
            ),
          );
          break;

        case TaskDeleteCommand():
          rows.add(
            _PreviewRow(
              icon: Icons.delete_outline,
              title: 'Delete task',
              subtitle: '“${cmd.title}” (${_ymd(execDate)})',
              isDestructive: true,
            ),
          );
          break;

        case HabitCreateCommand():
          rows.add(
            _PreviewRow(
              icon: Icons.add,
              title: 'Add habit',
              subtitle: '“${cmd.name}”',
            ),
          );
          break;

        case HabitSetCompletedCommand():
          rows.add(
            _PreviewRow(
              icon: cmd.completed ? Icons.check_circle : Icons.radio_button_unchecked,
              title: cmd.completed ? 'Complete habit' : 'Uncomplete habit',
              subtitle: '“${cmd.name}” (${_ymd(execDate)})',
            ),
          );
          break;

        case ReflectionAppendCommand():
          rows.add(
            _PreviewRow(
              icon: Icons.note_add_outlined,
              title: 'Append to reflection',
              subtitle: _ymd(execDate),
            ),
          );
          break;

        case ReflectionSetCommand():
          rows.add(
            _PreviewRow(
              icon: Icons.edit_note_outlined,
              title: 'Set reflection',
              subtitle: _ymd(execDate),
            ),
          );
          break;

        default:
          rows.add(
            _PreviewRow(
              icon: Icons.help_outline,
              title: 'Unknown action',
              subtitle: cmd.kind,
              isError: true,
            ),
          );
          break;
      }
    }

    return rows;
  }

  @override
  Widget build(BuildContext context) {
    final rows = _buildRows();
    final hasDestructive = rows.any((r) => r.isDestructive);
    final hasError = rows.any((r) => r.isError);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.only(
          left: AppSpace.s16,
          right: AppSpace.s16,
          top: AppSpace.s16,
          bottom: AppSpace.s16,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Preview assistant actions',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
            ),
            if ((say ?? '').trim().isNotEmpty) ...[
              Gap.h8,
              Text(
                (say ?? '').trim(),
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ],
            if (hasDestructive) ...[
              Gap.h12,
              Text(
                'Includes a delete — you’ll be asked to confirm before deleting.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
            if (hasError) ...[
              Gap.h8,
              Text(
                'Some items look invalid and may fail.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.error,
                    ),
              ),
            ],
            Gap.h16,
            Flexible(
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: rows.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (context, i) {
                  final r = rows[i];
                  final colorScheme = Theme.of(context).colorScheme;
                  final iconColor = r.isError
                      ? colorScheme.error
                      : (r.isDestructive ? colorScheme.error : null);
                  return ListTile(
                    dense: true,
                    leading: Icon(r.icon, color: iconColor),
                    title: Text(
                      r.title,
                      style: r.isDestructive
                          ? Theme.of(context).textTheme.bodyLarge?.copyWith(
                                color: colorScheme.error,
                                fontWeight: FontWeight.w700,
                              )
                          : null,
                    ),
                    subtitle: Text(r.subtitle),
                  );
                },
              ),
            ),
            Gap.h16,
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(false),
                    child: const Text('Cancel'),
                  ),
                ),
                Gap.w12,
                Expanded(
                  child: FilledButton(
                    onPressed: rows.isEmpty ? null : () => Navigator.of(context).pop(true),
                    child: const Text('Run'),
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

class _PreviewRow {
  const _PreviewRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.isDestructive = false,
    this.isError = false,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool isDestructive;
  final bool isError;
}

