import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'habit.dart';
import 'habits_repository.dart';

class LocalHabitsRepository implements HabitsRepository {
  LocalHabitsRepository(this._prefs);

  final SharedPreferences _prefs;

  static const _habitsKey = 'habits_v1';
  static String _completedKey(String ymd) => 'habits_completed_$ymd';

  List<Habit> _decodeHabits(String raw) {
    try {
      final decoded = jsonDecode(raw);
      if (decoded is List) {
        final out = <Habit>[];
        for (final item in decoded) {
          if (item is Map<String, Object?>) {
            out.add(Habit.fromJson(item));
          } else if (item is Map) {
            out.add(Habit.fromJson(Map<String, Object?>.from(item)));
          }
        }
        return out.where((h) => h.id.trim().isNotEmpty && h.name.trim().isNotEmpty).toList();
      }
    } catch (_) {
      // ignore
    }
    return const [];
  }

  Future<void> _saveHabits(List<Habit> habits) async {
    final raw = jsonEncode([for (final h in habits) h.toJson()]);
    await _prefs.setString(_habitsKey, raw);
  }

  @override
  Future<List<Habit>> listHabits() async {
    final raw = _prefs.getString(_habitsKey);
    if (raw == null || raw.trim().isEmpty) return const [];
    return _decodeHabits(raw);
  }

  @override
  Future<Habit> create({required String name}) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) {
      throw ArgumentError.value(name, 'name', 'Habit name cannot be empty');
    }
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    final id = '${nowMs}_${DateTime.now().microsecondsSinceEpoch}';
    final habit = Habit(id: id, name: trimmed, createdAtMs: nowMs);

    final existing = await listHabits();
    await _saveHabits([...existing, habit]);
    return habit;
  }

  @override
  Future<Set<String>> getCompletedHabitIds({required String ymd}) async {
    final raw = _prefs.getString(_completedKey(ymd));
    if (raw == null || raw.trim().isEmpty) return <String>{};
    try {
      final decoded = jsonDecode(raw);
      if (decoded is List) {
        return {
          for (final v in decoded)
            if (v is String && v.trim().isNotEmpty) v,
        };
      }
    } catch (_) {
      // ignore
    }
    return <String>{};
  }

  @override
  Future<void> setCompleted({
    required String habitId,
    required String ymd,
    required bool completed,
  }) async {
    final id = habitId.trim();
    if (id.isEmpty) return;
    final set = await getCompletedHabitIds(ymd: ymd);
    if (completed) {
      set.add(id);
    } else {
      set.remove(id);
    }
    await _prefs.setString(_completedKey(ymd), jsonEncode(set.toList()));
  }
}


