import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/today/today_controller.dart';
import '../../features/today/today_models.dart';
import '../../ui/responsive.dart';
import 'dock_badge_service.dart';

/// Provider that manages the macOS Dock badge based on incomplete Must-Win tasks.
///
/// This provider watches today's tasks and updates the Dock badge
/// to show the count of incomplete Must-Win tasks.
final dockBadgeControllerProvider = Provider<DockBadgeController>((ref) {
  return DockBadgeController(ref);
});

/// A provider that should be watched to keep the dock badge in sync.
///
/// Call this from a widget that's always mounted (like the app shell).
final dockBadgeSyncProvider = Provider<void>((ref) {
  // Only run on macOS.
  if (!isMacOS) return;

  // Get today's YMD.
  final now = DateTime.now();
  final ymd = _formatYmd(now);

  // Watch today's tasks and update badge when they change.
  final todayData = ref.watch(todayControllerProvider(ymd));
  final incompleteMustWins = todayData.tasks
      .where((t) => t.type == TodayTaskType.mustWin && !t.completed)
      .length;

  // Update the badge.
  DockBadgeService.instance.setBadgeCount(incompleteMustWins);
});

String _formatYmd(DateTime dt) {
  final y = dt.year.toString().padLeft(4, '0');
  final m = dt.month.toString().padLeft(2, '0');
  final d = dt.day.toString().padLeft(2, '0');
  return '$y-$m-$d';
}

class DockBadgeController {
  DockBadgeController(this._ref);

  final Ref _ref;

  /// Manually refresh the dock badge based on current task state.
  Future<void> refresh() async {
    if (!isMacOS) return;

    final now = DateTime.now();
    final ymd = _formatYmd(now);
    final todayData = _ref.read(todayControllerProvider(ymd));
    final incompleteMustWins = todayData.tasks
        .where((t) => t.type == TodayTaskType.mustWin && !t.completed)
        .length;

    await DockBadgeService.instance.setBadgeCount(incompleteMustWins);
  }

  /// Clear the dock badge.
  Future<void> clear() async {
    await DockBadgeService.instance.clearBadge();
  }
}
