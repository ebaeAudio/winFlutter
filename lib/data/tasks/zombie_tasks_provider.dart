import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../utils/ymd_utils.dart';
import 'all_tasks_models.dart';
import 'all_tasks_providers.dart';

/// Stalled Task Detector ("Zombie Task Alert")
///
/// Returns tasks that are:
/// - incomplete
/// - scheduled for a day that is 3+ days before today
///
/// Sorted oldest-first (by scheduled date, then created-at).
final zombieTasksProvider = FutureProvider<List<AllTask>>((ref) async {
  final repo = ref.watch(allTasksRepositoryProvider);
  if (repo == null) return const [];

  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final cutoff = today.subtract(const Duration(days: 3));
  final cutoffYmd =
      '${cutoff.year.toString().padLeft(4, '0')}-${cutoff.month.toString().padLeft(2, '0')}-${cutoff.day.toString().padLeft(2, '0')}';

  final zombies = <AllTask>[];

  String? cursor;
  for (var page = 0; page < 50; page++) {
    final res = await repo.listAll(limit: 200, cursor: cursor);
    final items = res.items;
    if (items.isEmpty) break;

    for (final t in items) {
      if (t.completed) continue;
      final snoozedUntil = t.snoozedUntil;
      if (snoozedUntil != null && snoozedUntil.isAfter(now)) continue;
      final dt = parseYmd(t.ymd);
      if (dt == null) continue;
      final day = DateTime(dt.year, dt.month, dt.day);
      if (day.isAfter(cutoff)) continue;
      zombies.add(t);
    }

    // Tasks are sorted ascending by date; stop once we've paged past cutoff.
    if (items.last.ymd.compareTo(cutoffYmd) > 0) break;
    if (!res.hasMore || res.nextCursor == null) break;
    cursor = res.nextCursor;
  }

  zombies.sort((a, b) {
    final y = a.ymd.compareTo(b.ymd);
    if (y != 0) return y;
    final c = a.createdAtMs.compareTo(b.createdAtMs);
    if (c != 0) return c;
    return a.id.compareTo(b.id);
  });

  return zombies;
});

