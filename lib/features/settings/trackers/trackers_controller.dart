import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/trackers/tracker_models.dart';
import '../../../data/trackers/trackers_providers.dart';
import '../../../data/trackers/trackers_repository.dart';

final trackersListProvider =
    AsyncNotifierProvider<TrackersListController, List<Tracker>>(
  TrackersListController.new,
);

class TrackersListController extends AsyncNotifier<List<Tracker>> {
  TrackersRepository get _repo =>
      ref.read(trackersRepositoryProvider) ?? ref.read(localTrackersRepositoryProvider);

  @override
  Future<List<Tracker>> build() async {
    return _repo.listAll();
  }

  Future<Tracker> create({
    required String name,
    required List<TrackerItem> items,
  }) async {
    final created = await _repo.create(name: name, items: items);
    state = AsyncData(await _repo.listAll());
    return created;
  }

  Future<Tracker> updateTracker({
    required String id,
    required String name,
    required List<TrackerItem> items,
  }) async {
    final updated = await _repo.update(id: id, name: name, items: items);
    state = AsyncData(await _repo.listAll());
    return updated;
  }

  Future<Tracker> setArchived({
    required String id,
    required bool archived,
  }) async {
    final updated = await _repo.update(id: id, archived: archived);
    state = AsyncData(await _repo.listAll());
    return updated;
  }
}


