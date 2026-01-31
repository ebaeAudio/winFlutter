import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../data/notes/note.dart';
import '../spacing.dart';

class NoteCard extends StatelessWidget {
  const NoteCard({
    super.key,
    required this.note,
    required this.onTap,
    this.onPin,
    this.onArchive,
  });

  final Note note;
  final VoidCallback onTap;
  final VoidCallback? onPin;
  final VoidCallback? onArchive;

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final noteDate = DateTime(date.year, date.month, date.day);

    if (noteDate == today) {
      return 'Today';
    } else if (noteDate == today.subtract(const Duration(days: 1))) {
      return 'Yesterday';
    } else if (date.year == now.year) {
      return DateFormat('MMM d').format(date);
    } else {
      return DateFormat('MMM d, yyyy').format(date);
    }
  }

  String _getTypeLabel(NoteType type) {
    return switch (type) {
      NoteType.note => 'Note',
      NoteType.project => 'Project',
      NoteType.daily => 'Daily',
      NoteType.inbox => 'Inbox',
    };
  }

  IconData _getTypeIcon(NoteType type) {
    return switch (type) {
      NoteType.note => Icons.note_outlined,
      NoteType.project => Icons.workspaces_outlined,
      NoteType.daily => Icons.calendar_today_outlined,
      NoteType.inbox => Icons.inbox_outlined,
    };
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    // Preview of content (first 100 chars)
    final contentPreview = note.content.trim();
    final preview = contentPreview.length > 100
        ? '${contentPreview.substring(0, 100)}...'
        : contentPreview;

    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(AppSpace.s16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  if (note.pinned) ...[
                    Icon(
                      Icons.push_pin,
                      size: 16,
                      color: scheme.primary,
                    ),
                    Gap.w8,
                  ],
                  Expanded(
                    child: Text(
                      note.title,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (onPin != null || onArchive != null) ...[
                    Gap.w8,
                    PopupMenuButton<String>(
                      icon: Icon(
                        Icons.more_vert,
                        size: 20,
                        color: scheme.onSurfaceVariant,
                      ),
                      onSelected: (value) {
                        switch (value) {
                          case 'pin':
                            onPin?.call();
                            break;
                          case 'archive':
                            onArchive?.call();
                            break;
                        }
                      },
                      itemBuilder: (context) => [
                        PopupMenuItem(
                          value: 'pin',
                          child: Row(
                            children: [
                              Icon(
                                note.pinned
                                    ? Icons.push_pin
                                    : Icons.push_pin_outlined,
                                size: 20,
                              ),
                              Gap.w12,
                              Text(note.pinned ? 'Unpin' : 'Pin'),
                            ],
                          ),
                        ),
                        const PopupMenuItem(
                          value: 'archive',
                          child: Row(
                            children: [
                              Icon(Icons.archive_outlined, size: 20),
                              Gap.w12,
                              Text('Archive'),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
              if (preview.isNotEmpty) ...[
                Gap.h8,
                Text(
                  preview,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
              Gap.h12,
              Row(
                children: [
                  Chip(
                    label: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          _getTypeIcon(note.type),
                          size: 14,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          _getTypeLabel(note.type),
                          style: theme.textTheme.labelSmall,
                        ),
                      ],
                    ),
                    visualDensity: VisualDensity.compact,
                    padding: EdgeInsets.zero,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  Gap.w8,
                  Text(
                    _formatDate(note.updatedAt),
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                  const Spacer(),
                  if (note.archived)
                    Text(
                      'Archived',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
