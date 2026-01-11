import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../domain/focus/focus_session.dart';
import 'focus_session_repository.dart';

class LocalFocusSessionRepository implements FocusSessionRepository {
  LocalFocusSessionRepository(this._prefs);

  final SharedPreferences _prefs;

  static const _activeKey = 'focus_active_session_v1';
  static const _historyKey = 'focus_session_history_v1';

  @override
  Future<FocusSession?> getActiveSession() async {
    final raw = _prefs.getString(_activeKey);
    if (raw == null || raw.isEmpty) return null;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return null;
      return FocusSession.fromJson(decoded.cast<String, Object?>());
    } catch (_) {
      // Backstop: if parsing fails, treat as no session.
      return null;
    }
  }

  @override
  Future<void> saveActiveSession(FocusSession session) async {
    await _prefs.setString(_activeKey, jsonEncode(session.toJson()));
  }

  @override
  Future<void> clearActiveSession() async {
    await _prefs.remove(_activeKey);
  }

  @override
  Future<List<FocusSession>> listHistory() async {
    final raw = _prefs.getString(_historyKey);
    if (raw == null || raw.isEmpty) return const [];
    return FocusSession.listFromJsonString(raw);
  }

  @override
  Future<void> appendToHistory(FocusSession session) async {
    final history = await listHistory();
    final updated = [session, ...history].take(200).toList(growable: false);
    await _prefs.setString(_historyKey, FocusSession.listToJsonString(updated));
  }

  @override
  Future<void> clearHistory() async {
    await _prefs.remove(_historyKey);
  }
}
