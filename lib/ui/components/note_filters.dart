import 'package:flutter/material.dart';

import '../../data/notes/note.dart';
import '../spacing.dart';

class NoteFilters extends StatelessWidget {
  const NoteFilters({
    super.key,
    required this.selectedType,
    required this.showPinned,
    required this.showArchived,
    required this.onTypeChanged,
    required this.onPinnedToggled,
    required this.onArchivedToggled,
  });

  final NoteType? selectedType;
  final bool showPinned;
  final bool showArchived;
  final ValueChanged<NoteType?> onTypeChanged;
  final ValueChanged<bool> onPinnedToggled;
  final ValueChanged<bool> onArchivedToggled;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpace.s16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Filter',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            Gap.h12,
            // Type filter
            SegmentedButton<NoteType?>(
              segments: const [
                ButtonSegment<NoteType?>(
                  value: null,
                  label: Text('All'),
                ),
                ButtonSegment<NoteType?>(
                  value: NoteType.inbox,
                  label: Text('Inbox'),
                ),
                ButtonSegment<NoteType?>(
                  value: NoteType.note,
                  label: Text('Notes'),
                ),
                ButtonSegment<NoteType?>(
                  value: NoteType.project,
                  label: Text('Projects'),
                ),
                ButtonSegment<NoteType?>(
                  value: NoteType.daily,
                  label: Text('Daily'),
                ),
              ],
              selected: {selectedType},
              onSelectionChanged: (Set<NoteType?> selection) {
                onTypeChanged(selection.firstOrNull);
              },
            ),
            Gap.h12,
            // Pinned and Archived toggles
            Row(
              children: [
                FilterChip(
                  label: const Text('Pinned'),
                  selected: showPinned,
                  onSelected: onPinnedToggled,
                  avatar: Icon(
                    Icons.push_pin,
                    size: 16,
                    color: showPinned ? scheme.onSecondaryContainer : null,
                  ),
                ),
                Gap.w8,
                FilterChip(
                  label: const Text('Archived'),
                  selected: showArchived,
                  onSelected: onArchivedToggled,
                  avatar: Icon(
                    Icons.archive,
                    size: 16,
                    color: showArchived ? scheme.onSecondaryContainer : null,
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
