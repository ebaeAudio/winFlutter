import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'tracker_models.dart';
import 'trackers_repository.dart';

class LocalTrackersRepository implements TrackersRepository {
  LocalTrackersRepository(this._prefs);

  final SharedPreferences _prefs;

  static const _trackersKey = 'trackers_v1';

  List<Tracker> _decode(String raw) {
    try {
      final decoded = jsonDecode(raw);
      if (decoded is List) {
        final out = <Tracker>[];
        for (final item in decoded) {
          if (item is Map<String, Object?>) {
            out.add(Tracker.fromJson(item));
          } else if (item is Map) {
            out.add(Tracker.fromJson(Map<String, Object?>.from(item)));
          }
        }
        return out
            .where((t) => t.id.trim().isNotEmpty && t.name.trim().isNotEmpty)
            .toList();
      }
    } catch (_) {
      // ignore
    }
    return const [];
  }

  Future<void> _save(List<Tracker> trackers) async {
    await _prefs.setString(
      _trackersKey,
      jsonEncode([for (final t in trackers) t.toJson()]),
    );
  }

  @override
  Future<List<Tracker>> listAll() async {
    final raw = _prefs.getString(_trackersKey);
    if (raw == null || raw.trim().isEmpty) return const [];
    return _decode(raw);
  }

  @override
  Future<Tracker?> getById({required String id}) async {
    final needle = id.trim();
    if (needle.isEmpty) return null;
    final all = await listAll();
    for (final t in all) {
      if (t.id == needle) return t;
    }
    return null;
  }

  void _validateItems(List<TrackerItem> items) {
    if (items.isEmpty || items.length > 3) {
      throw ArgumentError.value(items.length, 'items', 'Must have 1–3 items');
    }
    for (final it in items) {
      if (it.key.trim().isEmpty) {
        throw ArgumentError('Item key cannot be empty');
      }
      if (it.emoji.trim().isEmpty) {
        throw ArgumentError('Item emoji cannot be empty');
      }
      if (it.description.trim().isEmpty) {
        throw ArgumentError('Item description cannot be empty');
      }
      if (it.targetValue != null && it.targetValue! < 0) {
        throw ArgumentError('Target value cannot be negative');
      }
    }

    final keys = items.map((i) => i.key.trim()).toList();
    if (keys.toSet().length != keys.length) {
      throw ArgumentError('Item keys must be unique');
    }
  }

  @override
  Future<Tracker> create({
    required String name,
    required List<TrackerItem> items,
  }) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) {
      throw ArgumentError.value(name, 'name', 'Tracker name cannot be empty');
    }
    _validateItems(items);

    final now = DateTime.now();
    final nowMs = now.millisecondsSinceEpoch;
    final id = '${nowMs}_${DateTime.now().microsecondsSinceEpoch}';

    final tracker = Tracker(
      id: id,
      name: trimmed,
      items: items,
      archived: false,
      createdAtMs: nowMs,
      updatedAtMs: nowMs,
    );

    final existing = await listAll();
    await _save([...existing, tracker]);
    return tracker;
  }

  @override
  Future<Tracker> update({
    required String id,
    String? name,
    List<TrackerItem>? items,
    bool? archived,
  }) async {
    final needle = id.trim();
    if (needle.isEmpty) throw ArgumentError('id cannot be empty');
    final nextName = name?.trim();
    if (nextName != null && nextName.isEmpty) {
      throw ArgumentError('name cannot be empty');
    }
    if (items != null) _validateItems(items);

    final all = await listAll();
    final nowMs = DateTime.now().millisecondsSinceEpoch;

    Tracker? updated;
    final next = <Tracker>[];
    for (final t in all) {
      if (t.id != needle) {
        next.add(t);
        continue;
      }
      final u = t.copyWith(
        name: nextName,
        items: items,
        archived: archived,
        updatedAtMs: nowMs,
      );
      updated = u;
      next.add(u);
    }
    if (updated == null) throw StateError('Tracker not found');
    await _save(next);
    return updated;
  }
}


