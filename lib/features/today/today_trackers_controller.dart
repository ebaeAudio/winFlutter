import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/trackers/tracker_models.dart';
import '../../data/trackers/tracker_tallies_repository.dart';
import '../../data/trackers/trackers_providers.dart';
import '../../data/trackers/trackers_repository.dart';

final todayTrackersControllerProvider = StateNotifierProvider.family<
    TodayTrackersController, TodayTrackersData, String>((ref, ymd) {
  final TrackersRepository trackersRepo =
      ref.watch(trackersRepositoryProvider) ??
          ref.watch(localTrackersRepositoryProvider);
  final TrackerTalliesRepository talliesRepo =
      ref.watch(trackerTalliesRepositoryProvider) ??
          ref.watch(localTrackerTalliesRepositoryProvider);
  return TodayTrackersController(
    ymd: ymd,
    trackersRepository: trackersRepo,
    talliesRepository: talliesRepo,
  );
});

class TodayTrackerItemView {
  const TodayTrackerItemView({
    required this.item,
    required this.todayCount,
    required this.progressCount,
  });

  final TrackerItem item;
  final int todayCount;

  /// For daily targets this equals todayCount; for weekly/yearly it is the range sum.
  final int progressCount;
}

class TodayTrackerView {
  const TodayTrackerView({
    required this.tracker,
    required this.items,
  });

  final Tracker tracker;
  final List<TodayTrackerItemView> items;
}

class TodayTrackersData {
  const TodayTrackersData({
    required this.ymd,
    required this.isLoading,
    required this.trackers,
    required this.error,
  });

  final String ymd;
  final bool isLoading;
  final List<TodayTrackerView> trackers;
  final String? error;

  static TodayTrackersData empty(String ymd) => TodayTrackersData(
        ymd: ymd,
        isLoading: true,
        trackers: const [],
        error: null,
      );

  TodayTrackersData copyWith({
    bool? isLoading,
    List<TodayTrackerView>? trackers,
    String? error,
  }) {
    return TodayTrackersData(
      ymd: ymd,
      isLoading: isLoading ?? this.isLoading,
      trackers: trackers ?? this.trackers,
      error: error,
    );
  }
}

class TodayTrackersController extends StateNotifier<TodayTrackersData> {
  TodayTrackersController({
    required String ymd,
    required TrackersRepository trackersRepository,
    required TrackerTalliesRepository talliesRepository,
  })  : _ymd = ymd,
        _trackersRepository = trackersRepository,
        _talliesRepository = talliesRepository,
        super(TodayTrackersData.empty(ymd)) {
    unawaited(_load());
  }

  final String _ymd;
  final TrackersRepository _trackersRepository;
  final TrackerTalliesRepository _talliesRepository;

  static String _k(String trackerId, String itemKey) => '$trackerId::$itemKey';

  Future<void> _load() async {
    try {
      final all = await _trackersRepository.listAll();
      final active = all.where((t) => !t.archived && t.items.isNotEmpty).toList();
      final trackerIds = [for (final t in active) t.id];

      final todayTallies = await _talliesRepository.listForDate(ymd: _ymd);
      final todayMap = <String, int>{
        for (final t in todayTallies) _k(t.trackerId, t.itemKey): t.count,
      };

      final needsWeekly = active.any(
        (t) => t.items.any((i) => i.hasTarget && i.targetCadence == TargetCadence.weekly),
      );
      final needsYearly = active.any(
        (t) => t.items.any((i) => i.hasTarget && i.targetCadence == TargetCadence.yearly),
      );

      final weeklyMap = <String, int>{};
      final yearlyMap = <String, int>{};

      if (needsWeekly && trackerIds.isNotEmpty) {
        final range = _weekRange(_ymd);
        final rows = await _talliesRepository.listForDateRange(
          startYmd: range.startYmd,
          endYmd: range.endYmd,
          trackerIds: trackerIds,
        );
        for (final r in rows) {
          final key = _k(r.trackerId, r.itemKey);
          weeklyMap[key] = (weeklyMap[key] ?? 0) + r.count;
        }
      }

      if (needsYearly && trackerIds.isNotEmpty) {
        final range = _yearRange(_ymd);
        final rows = await _talliesRepository.listForDateRange(
          startYmd: range.startYmd,
          endYmd: range.endYmd,
          trackerIds: trackerIds,
        );
        for (final r in rows) {
          final key = _k(r.trackerId, r.itemKey);
          yearlyMap[key] = (yearlyMap[key] ?? 0) + r.count;
        }
      }

      final views = <TodayTrackerView>[
        for (final tracker in active)
          TodayTrackerView(
            tracker: tracker,
            items: [
              for (final it in tracker.items)
                () {
                  final key = _k(tracker.id, it.key);
                  final today = todayMap[key] ?? 0;
                  final progress = switch (it.targetCadence) {
                    TargetCadence.weekly => weeklyMap[key] ?? 0,
                    TargetCadence.yearly => yearlyMap[key] ?? 0,
                    _ => today,
                  };
                  return TodayTrackerItemView(
                    item: it,
                    todayCount: today,
                    progressCount: progress,
                  );
                }(),
            ],
          ),
      ];

      state = state.copyWith(isLoading: false, trackers: views, error: null);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: '$e');
    }
  }

  Future<void> increment({
    required String trackerId,
    required String itemKey,
  }) async {
    await _applyDelta(trackerId: trackerId, itemKey: itemKey, delta: 1);
  }

  Future<void> decrement({
    required String trackerId,
    required String itemKey,
  }) async {
    await _applyDelta(trackerId: trackerId, itemKey: itemKey, delta: -1);
  }

  Future<void> _applyDelta({
    required String trackerId,
    required String itemKey,
    required int delta,
  }) async {
    final tid = trackerId.trim();
    final ik = itemKey.trim();
    if (tid.isEmpty || ik.isEmpty) return;

    try {
      // Find current counts so we can adjust progress correctly even when the repo clamps (min 0).
      int? prevToday;
      TargetCadence? cadence;
      int? prevProgress;
      for (final tv in state.trackers) {
        if (tv.tracker.id != tid) continue;
        for (final iv in tv.items) {
          if (iv.item.key != ik) continue;
          prevToday = iv.todayCount;
          prevProgress = iv.progressCount;
          cadence = iv.item.targetCadence;
          break;
        }
      }

      final next = await _talliesRepository.applyDelta(
        ymd: _ymd,
        trackerId: tid,
        itemKey: ik,
        delta: delta,
      );

      final actualDelta = (prevToday == null) ? 0 : (next - prevToday);

      final updated = [
        for (final tv in state.trackers)
          if (tv.tracker.id != tid)
            tv
          else
            TodayTrackerView(
              tracker: tv.tracker,
              items: [
                for (final iv in tv.items)
                  if (iv.item.key != ik)
                    iv
                  else
                    TodayTrackerItemView(
                      item: iv.item,
                      todayCount: next,
                      progressCount: switch (cadence) {
                        TargetCadence.weekly || TargetCadence.yearly =>
                          ((prevProgress ?? iv.progressCount) + actualDelta) < 0
                              ? 0
                              : ((prevProgress ?? iv.progressCount) + actualDelta),
                        _ => next,
                      },
                    ),
              ],
            ),
      ];

      state = state.copyWith(trackers: updated, error: null);
    } catch (e) {
      state = state.copyWith(error: '$e');
    }
  }

  static _DateRange _weekRange(String ymd) {
    final dt = DateTime.tryParse(ymd);
    if (dt == null) return _DateRange(startYmd: ymd, endYmd: ymd);
    final day = DateTime(dt.year, dt.month, dt.day);
    // ISO-ish week: Monday = start
    final start = day.subtract(Duration(days: day.weekday - 1));
    final end = start.add(const Duration(days: 6));
    return _DateRange(startYmd: _formatYmd(start), endYmd: _formatYmd(end));
  }

  static _DateRange _yearRange(String ymd) {
    final dt = DateTime.tryParse(ymd);
    if (dt == null) return _DateRange(startYmd: ymd, endYmd: ymd);
    final start = DateTime(dt.year, 1, 1);
    final end = DateTime(dt.year, 12, 31);
    return _DateRange(startYmd: _formatYmd(start), endYmd: _formatYmd(end));
  }

  static String _formatYmd(DateTime dt) {
    final y = dt.year.toString().padLeft(4, '0');
    final m = dt.month.toString().padLeft(2, '0');
    final d = dt.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }
}

class _DateRange {
  const _DateRange({required this.startYmd, required this.endYmd});
  final String startYmd;
  final String endYmd;
}


