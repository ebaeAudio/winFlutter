import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'tracker_models.dart';
import 'tracker_tallies_repository.dart';

class LocalTrackerTalliesRepository implements TrackerTalliesRepository {
  LocalTrackerTalliesRepository(this._prefs);

  final SharedPreferences _prefs;

  static String _keyForDay(String ymd) => 'tracker_tallies_$ymd';

  Map<String, int> _decodeDay(String raw) {
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map) {
        final map = <String, int>{};
        decoded.forEach((k, v) {
          if (k is! String) return;
          final n = (v as num?)?.toInt();
          if (n == null) return;
          map[k] = n < 0 ? 0 : n;
        });
        return map;
      }
    } catch (_) {
      // ignore
    }
    return <String, int>{};
  }

  Future<Map<String, int>> _loadDay(String ymd) async {
    final raw = _prefs.getString(_keyForDay(ymd));
    if (raw == null || raw.trim().isEmpty) return <String, int>{};
    return _decodeDay(raw);
  }

  Future<void> _saveDay(String ymd, Map<String, int> map) async {
    await _prefs.setString(_keyForDay(ymd), jsonEncode(map));
  }

  static String _k(String trackerId, String itemKey) => '$trackerId::$itemKey';

  @override
  Future<List<TrackerTally>> listForDate({required String ymd}) async {
    final map = await _loadDay(ymd);
    return [
      for (final entry in map.entries)
        () {
          final parts = entry.key.split('::');
          if (parts.length != 2) return null;
          return TrackerTally(
            trackerId: parts[0],
            itemKey: parts[1],
            ymd: ymd,
            count: entry.value < 0 ? 0 : entry.value,
          );
        }()
    ].whereType<TrackerTally>().toList();
  }

  @override
  Future<List<TrackerTally>> listForDateRange({
    required String startYmd,
    required String endYmd,
    List<String>? trackerIds,
  }) async {
    final start = DateTime.tryParse(startYmd);
    final end = DateTime.tryParse(endYmd);
    if (start == null || end == null) return const [];

    final allowed = trackerIds == null ? null : trackerIds.toSet();
    final out = <TrackerTally>[];

    for (var d = DateTime(start.year, start.month, start.day);
        !d.isAfter(end);
        d = d.add(const Duration(days: 1))) {
      final ymd = _ymd(d);
      final day = await listForDate(ymd: ymd);
      if (allowed == null) {
        out.addAll(day);
      } else {
        out.addAll(day.where((t) => allowed.contains(t.trackerId)));
      }
    }
    return out;
  }

  @override
  Future<int> applyDelta({
    required String ymd,
    required String trackerId,
    required String itemKey,
    required int delta,
  }) async {
    final tid = trackerId.trim();
    final ik = itemKey.trim();
    if (tid.isEmpty || ik.isEmpty) return 0;
    if (delta == 0) return 0;

    final map = await _loadDay(ymd);
    final key = _k(tid, ik);
    final current = map[key] ?? 0;
    final next = (current + delta);
    final clamped = next < 0 ? 0 : next;
    map[key] = clamped;
    await _saveDay(ymd, map);
    return clamped;
  }

  static String _ymd(DateTime dt) {
    final y = dt.year.toString().padLeft(4, '0');
    final m = dt.month.toString().padLeft(2, '0');
    final d = dt.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }
}


