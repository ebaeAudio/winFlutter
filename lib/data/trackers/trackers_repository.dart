import 'tracker_models.dart';

abstract interface class TrackersRepository {
  Future<List<Tracker>> listAll();

  Future<Tracker?> getById({required String id});

  Future<Tracker> create({
    required String name,
    required List<TrackerItem> items, // must be length 3
  });

  Future<Tracker> update({
    required String id,
    String? name,
    List<TrackerItem>? items, // must be length 3 if provided
    bool? archived,
  });
}


