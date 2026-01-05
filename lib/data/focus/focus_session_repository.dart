import '../../domain/focus/focus_session.dart';

abstract class FocusSessionRepository {
  Future<FocusSession?> getActiveSession();
  Future<void> saveActiveSession(FocusSession session);
  Future<void> clearActiveSession();

  Future<List<FocusSession>> listHistory();
  Future<void> appendToHistory(FocusSession session);
  Future<void> clearHistory();
}


