import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:win_flutter/data/trackers/local_trackers_repository.dart';
import 'package:win_flutter/data/trackers/tracker_models.dart';

void main() {
  test('LocalTrackersRepository: create/list/update/archive', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final repo = LocalTrackersRepository(prefs);

    final created = await repo.create(
      name: 'Water',
      items: const [
        TrackerItem(key: 'a', emoji: '🥤', description: 'Cup', targetCadence: TargetCadence.daily, targetValue: 8),
      ],
    );

    final all = await repo.listAll();
    expect(all.length, 1);
    expect(all.first.name, 'Water');
    expect(all.first.items.length, 1);
    expect(all.first.archived, false);

    final updated = await repo.update(
      id: created.id,
      name: 'Hydration',
      items: const [
        TrackerItem(key: 'a', emoji: '🥤', description: 'Cup', targetCadence: TargetCadence.daily, targetValue: 10),
        TrackerItem(key: 'b', emoji: '🚰', description: 'Bottle'),
      ],
    );
    expect(updated.name, 'Hydration');
    expect(updated.items.first.targetValue, 10);
    expect(updated.items.length, 2);

    final archived = await repo.update(id: created.id, archived: true);
    expect(archived.archived, true);

    final fetched = await repo.getById(id: created.id);
    expect(fetched?.id, created.id);
    expect(fetched?.archived, true);
  });

  test('LocalTrackersRepository: requires exactly 3 items', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final repo = LocalTrackersRepository(prefs);

    expect(
      () => repo.create(
        name: 'Bad',
        items: const [
          TrackerItem(key: 'a', emoji: 'A', description: 'One'),
        ],
      ),
      returnsNormally,
    );
  });

  test('LocalTrackersRepository: rejects 0 items and >3 items', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final repo = LocalTrackersRepository(prefs);

    expect(
      () => repo.create(name: 'Bad', items: const []),
      throwsArgumentError,
    );
    expect(
      () => repo.create(
        name: 'Bad',
        items: const [
          TrackerItem(key: 'a', emoji: 'A', description: 'One'),
          TrackerItem(key: 'b', emoji: 'B', description: 'Two'),
          TrackerItem(key: 'c', emoji: 'C', description: 'Three'),
          TrackerItem(key: 'd', emoji: 'D', description: 'Four'),
        ],
      ),
      throwsArgumentError,
    );
  });
}


