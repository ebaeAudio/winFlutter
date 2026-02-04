import 'dart:async' show unawaited;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../data/tasks/all_tasks_models.dart';
import '../../data/tasks/all_tasks_providers.dart';
import '../../data/tasks/task.dart';
import '../../data/tasks/tasks_providers.dart';
import '../../data/tasks/zombie_tasks_provider.dart';
import '../../ui/app_scaffold.dart';
import '../../ui/spacing.dart';

/// Tinder-style review screen for cleaning up zombie tasks.
///
/// Swipe right → Move to Today
/// Swipe left → Delete
class ZombieTaskReviewScreen extends ConsumerStatefulWidget {
  const ZombieTaskReviewScreen({super.key});

  @override
  ConsumerState<ZombieTaskReviewScreen> createState() =>
      _ZombieTaskReviewScreenState();
}

class _ZombieTaskReviewScreenState
    extends ConsumerState<ZombieTaskReviewScreen> {
  final List<AllTask> _queue = [];
  int _processed = 0;
  int _movedToToday = 0;
  int _deleted = 0;
  bool _initialized = false;

  @override
  Widget build(BuildContext context) {
    final zombiesAsync = ref.watch(zombieTasksProvider);

    return AppScaffold(
      title: 'Clean Up Tasks',
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpace.s16),
        child: zombiesAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => _ErrorState(error: e.toString()),
          data: (zombies) {
            // Initialize queue once
            if (!_initialized) {
              _queue
                ..clear()
                ..addAll(zombies);
              _initialized = true;
            }

            if (_queue.isEmpty) {
              return _CompletionState(
                totalProcessed: _processed,
                movedToToday: _movedToToday,
                deleted: _deleted,
              );
            }

            final current = _queue.first;
            final remaining = _queue.length;

            return Column(
              children: [
                Gap.h16,

                // Progress indicator
                _ProgressHeader(
                  remaining: remaining,
                  processed: _processed,
                ),
                Gap.h16,

                // Swipe instructions
                _SwipeHints(),
                Gap.h12,

                // Swipeable card - expands to fill available space
                Expanded(
                  child: _SwipeableTaskCard(
                    key: ValueKey(current.id),
                    task: current,
                    onSwipeRight: () => _moveToToday(current),
                    onSwipeLeft: () => _deleteTask(current),
                    onViewDetails: () => _viewDetails(current),
                  ),
                ),
                Gap.h16,

                // Action buttons pinned to bottom
                SafeArea(
                  top: false,
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: AppSpace.s8),
                    child: _ActionButtons(
                      onMoveToToday: () => _moveToToday(current),
                      onDelete: () => _deleteTask(current),
                      onSkip: () => _skipTask(current),
                      onViewDetails: () => _viewDetails(current),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
      children: const [],
    );
  }

  Future<void> _moveToToday(AllTask task) async {
    final messenger = ScaffoldMessenger.of(context);
    final repo = ref.read(allTasksRepositoryProvider);
    if (repo == null) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Tasks not available.')),
      );
      return;
    }

    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());

    try {
      await repo.moveToDate(
        fromYmd: task.ymd,
        toYmd: today,
        taskId: task.id,
        resetCompleted: true,
      );

      unawaited(HapticFeedback.mediumImpact());

      setState(() {
        _queue.remove(task);
        _processed++;
        _movedToToday++;
      });

      messenger.showSnackBar(
        SnackBar(
          content: Text('Moved "${_truncate(task.title)}" to Today'),
          duration: const Duration(seconds: 2),
        ),
      );
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text('Failed to move task: $e')),
      );
    }
  }

  Future<void> _deleteTask(AllTask task) async {
    final messenger = ScaffoldMessenger.of(context);
    final repo = ref.read(tasksRepositoryProvider);
    if (repo == null) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Tasks not available.')),
      );
      return;
    }

    try {
      final canUndo = await repo.supportsSoftDelete();
      await repo.delete(id: task.id);

      unawaited(HapticFeedback.mediumImpact());

      setState(() {
        _queue.remove(task);
        _processed++;
        _deleted++;
      });

      if (!canUndo) {
        messenger.showSnackBar(
          SnackBar(content: Text('Deleted "${_truncate(task.title)}"')),
        );
        return;
      }

      messenger.showSnackBar(
        SnackBar(
          content: Text('Deleted "${_truncate(task.title)}"'),
          action: SnackBarAction(
            label: 'Undo',
            onPressed: () async {
              try {
                await repo.restore(id: task.id);
                // Re-add to queue if restored
                setState(() {
                  _queue.insert(0, task);
                  _processed--;
                  _deleted--;
                });
                messenger.showSnackBar(
                  SnackBar(content: Text('Restored "${_truncate(task.title)}"')),
                );
              } catch (_) {
                messenger.showSnackBar(
                  const SnackBar(content: Text('Could not restore task.')),
                );
              }
            },
          ),
        ),
      );
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text('Failed to delete task: $e')),
      );
    }
  }

  void _skipTask(AllTask task) {
    HapticFeedback.lightImpact();
    setState(() {
      _queue.remove(task);
      _queue.add(task); // Move to end of queue
    });
  }

  void _viewDetails(AllTask task) {
    context.push('/today/task/${task.id}?ymd=${task.ymd}');
  }

  String _truncate(String s, [int max = 30]) {
    if (s.length <= max) return s;
    return '${s.substring(0, max)}...';
  }
}

// -----------------------------------------------------------------------------
// Sub-widgets
// -----------------------------------------------------------------------------

class _ProgressHeader extends StatelessWidget {
  const _ProgressHeader({
    required this.remaining,
    required this.processed,
  });

  final int remaining;
  final int processed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final total = remaining + processed;
    final progress = total > 0 ? processed / total : 0.0;

    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              '$remaining',
              style: theme.textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.primary,
              ),
            ),
            Text(
              ' task${remaining == 1 ? '' : 's'} left',
              style: theme.textTheme.titleMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
        Gap.h12,
        SizedBox(
          width: 200,
          child: LinearProgressIndicator(
            value: progress,
            backgroundColor: theme.colorScheme.surfaceContainerHighest,
          ),
        ),
      ],
    );
  }
}

class _SwipeHints extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant.withOpacity(0.7);

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.arrow_back, size: 16, color: theme.colorScheme.error),
            Gap.w4,
            Text('Delete', style: TextStyle(color: muted, fontSize: 13)),
          ],
        ),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Move to Today', style: TextStyle(color: muted, fontSize: 13)),
            Gap.w4,
            const Icon(Icons.arrow_forward, size: 16, color: Colors.green),
          ],
        ),
      ],
    );
  }
}

class _SwipeableTaskCard extends StatefulWidget {
  const _SwipeableTaskCard({
    super.key,
    required this.task,
    required this.onSwipeRight,
    required this.onSwipeLeft,
    required this.onViewDetails,
  });

  final AllTask task;
  final VoidCallback onSwipeRight;
  final VoidCallback onSwipeLeft;
  final VoidCallback onViewDetails;

  @override
  State<_SwipeableTaskCard> createState() => _SwipeableTaskCardState();
}

class _SwipeableTaskCardState extends State<_SwipeableTaskCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  Offset _dragOffset = Offset.zero;

  static const _swipeThreshold = 100.0;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onPanStart(DragStartDetails details) {
    // Start tracking drag
  }

  void _onPanUpdate(DragUpdateDetails details) {
    setState(() {
      _dragOffset += details.delta;
    });
  }

  void _onPanEnd(DragEndDetails details) {
    final dx = _dragOffset.dx;

    if (dx > _swipeThreshold) {
      // Swipe right → move to today
      _animateOffScreen(toRight: true).then((_) {
        widget.onSwipeRight();
      });
    } else if (dx < -_swipeThreshold) {
      // Swipe left → delete
      _animateOffScreen(toRight: false).then((_) {
        widget.onSwipeLeft();
      });
    } else {
      // Snap back
      _animateBack();
    }
  }

  Future<void> _animateOffScreen({required bool toRight}) async {
    final screenWidth = MediaQuery.of(context).size.width;
    final targetX = toRight ? screenWidth : -screenWidth;

    final startOffset = _dragOffset;
    final endOffset = Offset(targetX, _dragOffset.dy);

    _controller.reset();
    _controller.addListener(() {
      setState(() {
        _dragOffset = Offset.lerp(startOffset, endOffset, _controller.value)!;
      });
    });

    await _controller.forward();
  }

  void _animateBack() {
    final startOffset = _dragOffset;

    _controller.reset();
    _controller.addListener(() {
      setState(() {
        _dragOffset = Offset.lerp(startOffset, Offset.zero, _controller.value)!;
      });
    });

    _controller.forward();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    // Calculate rotation based on drag
    final rotation = _dragOffset.dx / 800;

    // Calculate opacity for action hints
    final rightProgress = (_dragOffset.dx / _swipeThreshold).clamp(0.0, 1.0);
    final leftProgress = (-_dragOffset.dx / _swipeThreshold).clamp(0.0, 1.0);

    return Stack(
      alignment: Alignment.center,
      children: [
        // Background hints
        Positioned.fill(
          child: Row(
            children: [
              // Left (delete) hint
              Expanded(
                child: Container(
                  alignment: Alignment.centerLeft,
                  padding: const EdgeInsets.only(left: 32),
                  child: Opacity(
                    opacity: leftProgress,
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: scheme.errorContainer,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.delete_outline,
                        color: scheme.onErrorContainer,
                        size: 32,
                      ),
                    ),
                  ),
                ),
              ),
              // Right (keep) hint
              Expanded(
                child: Container(
                  alignment: Alignment.centerRight,
                  padding: const EdgeInsets.only(right: 32),
                  child: Opacity(
                    opacity: rightProgress,
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.green.shade100,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.today,
                        color: Colors.green.shade700,
                        size: 32,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),

        // Draggable card
        GestureDetector(
          onPanStart: _onPanStart,
          onPanUpdate: _onPanUpdate,
          onPanEnd: _onPanEnd,
          onTap: widget.onViewDetails,
          child: Transform.translate(
            offset: _dragOffset,
            child: Transform.rotate(
              angle: rotation,
              child: _TaskCard(
                task: widget.task,
                onViewDetails: widget.onViewDetails,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _TaskCard extends StatelessWidget {
  const _TaskCard({
    required this.task,
    required this.onViewDetails,
  });

  final AllTask task;
  final VoidCallback onViewDetails;

  String _formatDate(String ymd) {
    try {
      final dt = DateTime.parse(ymd);
      return DateFormat('MMM d, yyyy').format(dt);
    } catch (_) {
      return ymd;
    }
  }

  String _ageLabel(String ymd) {
    try {
      final dt = DateTime.parse(ymd);
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final taskDate = DateTime(dt.year, dt.month, dt.day);
      final days = today.difference(taskDate).inDays;

      if (days == 1) return '1 day old';
      if (days < 7) return '$days days old';
      if (days < 14) return '1 week old';
      if (days < 30) return '${days ~/ 7} weeks old';
      if (days < 60) return '1 month old';
      return '${days ~/ 30} months old';
    } catch (_) {
      return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    final isMustWin = task.type == TaskType.mustWin;
    final typeColor = isMustWin ? scheme.primary : scheme.secondary;
    final typeLabel = isMustWin ? 'Must-Win' : 'Nice-to-Do';
    final age = _ageLabel(task.ymd);

    return ConstrainedBox(
      constraints: const BoxConstraints(
        maxWidth: 340,
        minHeight: 280,
      ),
      child: Container(
        padding: const EdgeInsets.all(AppSpace.s24),
        decoration: BoxDecoration(
          color: scheme.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: scheme.outlineVariant),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.12),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Type badge + age
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpace.s12,
                    vertical: AppSpace.s8,
                  ),
                  decoration: BoxDecoration(
                    color: typeColor.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    typeLabel,
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: typeColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const Spacer(),
                if (age.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpace.s12,
                      vertical: AppSpace.s8,
                    ),
                    decoration: BoxDecoration(
                      color: scheme.errorContainer.withOpacity(0.5),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      age,
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: scheme.error,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
              ],
            ),
            Gap.h24,

            // Title - larger and more prominent
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      task.title,
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                        height: 1.3,
                      ),
                    ),
                    Gap.h16,

                    // Metadata section
                    _MetadataRow(
                      icon: Icons.calendar_today,
                      label: 'Scheduled',
                      value: _formatDate(task.ymd),
                      color: scheme.onSurfaceVariant,
                    ),

                    // Due date if set
                    if (task.goalYmd != null && task.goalYmd!.isNotEmpty) ...[
                      Gap.h8,
                      _MetadataRow(
                        icon: Icons.flag,
                        label: 'Due',
                        value: _formatDate(task.goalYmd!),
                        color: scheme.error,
                      ),
                    ],

                    // In progress indicator
                    if (task.inProgress) ...[
                      Gap.h8,
                      _MetadataRow(
                        icon: Icons.timelapse,
                        label: 'Status',
                        value: 'In progress',
                        color: scheme.primary,
                      ),
                    ],
                  ],
                ),
              ),
            ),

            // View details link at bottom
            Gap.h16,
            Center(
              child: TextButton.icon(
                onPressed: onViewDetails,
                icon: Icon(
                  Icons.open_in_new,
                  size: 18,
                  color: scheme.primary,
                ),
                label: Text(
                  'View Details',
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: scheme.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MetadataRow extends StatelessWidget {
  const _MetadataRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      children: [
        Icon(icon, size: 18, color: color),
        Gap.w8,
        Text(
          '$label: ',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: color,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }
}

class _ActionButtons extends StatelessWidget {
  const _ActionButtons({
    required this.onMoveToToday,
    required this.onDelete,
    required this.onSkip,
    required this.onViewDetails,
  });

  final VoidCallback onMoveToToday;
  final VoidCallback onDelete;
  final VoidCallback onSkip;
  final VoidCallback onViewDetails;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Primary action buttons row
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Delete button
            _CircleActionButton(
              icon: Icons.close,
              color: scheme.error,
              backgroundColor: scheme.errorContainer,
              onPressed: onDelete,
              tooltip: 'Delete',
              label: 'Delete',
            ),
            Gap.w24,

            // Skip button (smaller)
            _CircleActionButton(
              icon: Icons.redo,
              color: scheme.onSurfaceVariant,
              backgroundColor: scheme.surfaceContainerHighest,
              onPressed: onSkip,
              tooltip: 'Skip (review later)',
              label: 'Skip',
              size: 52,
            ),
            Gap.w24,

            // Move to Today button
            _CircleActionButton(
              icon: Icons.check,
              color: Colors.green.shade700,
              backgroundColor: Colors.green.shade100,
              onPressed: onMoveToToday,
              tooltip: 'Move to Today',
              label: 'Today',
            ),
          ],
        ),
        Gap.h12,

        // View Details secondary action
        TextButton.icon(
          onPressed: onViewDetails,
          icon: Icon(
            Icons.edit_note,
            size: 20,
            color: scheme.primary,
          ),
          label: Text(
            'Edit or Add Details',
            style: theme.textTheme.labelLarge?.copyWith(
              color: scheme.primary,
            ),
          ),
        ),
      ],
    );
  }
}

class _CircleActionButton extends StatelessWidget {
  const _CircleActionButton({
    required this.icon,
    required this.color,
    required this.backgroundColor,
    required this.onPressed,
    required this.tooltip,
    this.label,
    this.size = 64,
  });

  final IconData icon;
  final Color color;
  final Color backgroundColor;
  final VoidCallback onPressed;
  final String tooltip;
  final String? label;
  final double size;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Tooltip(
          message: tooltip,
          child: Material(
            color: backgroundColor,
            shape: const CircleBorder(),
            elevation: 2,
            child: InkWell(
              onTap: onPressed,
              customBorder: const CircleBorder(),
              child: SizedBox(
                width: size,
                height: size,
                child: Center(
                  child: Icon(icon, color: color, size: size * 0.45),
                ),
              ),
            ),
          ),
        ),
        if (label != null) ...[
          Gap.h4,
          Text(
            label!,
            style: theme.textTheme.labelSmall?.copyWith(
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ],
    );
  }
}

class _CompletionState extends StatelessWidget {
  const _CompletionState({
    required this.totalProcessed,
    required this.movedToToday,
    required this.deleted,
  });

  final int totalProcessed;
  final int movedToToday;
  final int deleted;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpace.s24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.green.shade100,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.celebration,
                size: 48,
                color: Colors.green.shade700,
              ),
            ),
            Gap.h24,
            Text(
              'All caught up!',
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            Gap.h8,
            Text(
              'No more zombie tasks to review.',
              style: theme.textTheme.bodyLarge?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
            if (totalProcessed > 0) ...[
              Gap.h24,
              Container(
                padding: const EdgeInsets.all(AppSpace.s16),
                decoration: BoxDecoration(
                  color: scheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _StatChip(
                      icon: Icons.today,
                      label: '$movedToToday moved',
                      color: Colors.green,
                    ),
                    Gap.w16,
                    _StatChip(
                      icon: Icons.delete_outline,
                      label: '$deleted deleted',
                      color: scheme.error,
                    ),
                  ],
                ),
              ),
            ],
            Gap.h24,
            FilledButton.icon(
              onPressed: () => context.go('/tasks'),
              icon: const Icon(Icons.check),
              label: const Text('Done'),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  const _StatChip({
    required this.icon,
    required this.label,
    required this.color,
  });

  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 18, color: color),
        Gap.w8,
        Text(
          label,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
        ),
      ],
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.error});

  final String error;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpace.s24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.error_outline,
              size: 48,
              color: theme.colorScheme.error,
            ),
            Gap.h16,
            Text(
              'Failed to load tasks',
              style: theme.textTheme.titleMedium,
            ),
            Gap.h8,
            Text(
              error,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
            Gap.h24,
            FilledButton.icon(
              onPressed: () => context.go('/tasks'),
              icon: const Icon(Icons.arrow_back),
              label: const Text('Back to Tasks'),
            ),
          ],
        ),
      ),
    );
  }
}
