import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:win_flutter/data/trackers/local_tracker_tallies_repository.dart';

void main() {
  test('LocalTrackerTalliesRepository: applyDelta clamps at 0', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final repo = LocalTrackerTalliesRepository(prefs);

    const ymd = '2026-01-06';
    const trackerId = 't1';
    const itemKey = 'a';

    expect(
      await repo.applyDelta(
          ymd: ymd, trackerId: trackerId, itemKey: itemKey, delta: 1,),
      1,
    );
    expect(
      await repo.applyDelta(
          ymd: ymd, trackerId: trackerId, itemKey: itemKey, delta: 1,),
      2,
    );
    expect(
      await repo.applyDelta(
          ymd: ymd, trackerId: trackerId, itemKey: itemKey, delta: -5,),
      0,
    );
  });

  test('LocalTrackerTalliesRepository: listForDate and listForDateRange',
      () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final repo = LocalTrackerTalliesRepository(prefs);

    await repo.applyDelta(
        ymd: '2026-01-01', trackerId: 't1', itemKey: 'a', delta: 2,);
    await repo.applyDelta(
        ymd: '2026-01-02', trackerId: 't1', itemKey: 'a', delta: 3,);
    await repo.applyDelta(
        ymd: '2026-01-02', trackerId: 't2', itemKey: 'b', delta: 4,);

    final day = await repo.listForDate(ymd: '2026-01-02');
    expect(day.length, 2);

    final range = await repo.listForDateRange(
      startYmd: '2026-01-01',
      endYmd: '2026-01-02',
      trackerIds: ['t1'],
    );
    // Only t1 rows should be returned.
    expect(range.every((t) => t.trackerId == 't1'), true);
    final sum = range.fold<int>(0, (acc, t) => acc + t.count);
    expect(sum, 5);
  });
}
