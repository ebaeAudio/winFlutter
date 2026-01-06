import 'tracker_models.dart';

abstract interface class TrackerTalliesRepository {
  /// Returns tallies for a specific day.
  Future<List<TrackerTally>> listForDate({required String ymd});

  /// Returns tallies in the inclusive date range.
  Future<List<TrackerTally>> listForDateRange({
    required String startYmd,
    required String endYmd,
    List<String>? trackerIds,
  });

  /// Applies a delta (+1/-1) for the given (trackerId,itemKey,ymd).
  /// Implementations must clamp at 0.
  Future<int> applyDelta({
    required String ymd,
    required String trackerId,
    required String itemKey,
    required int delta,
  });
}


