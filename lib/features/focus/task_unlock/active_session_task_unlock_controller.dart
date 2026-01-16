import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme.dart' show sharedPreferencesProvider;
import '../../../domain/focus/focus_session.dart';
import '../focus_session_controller.dart';
import 'active_session_task_unlock_config.dart';

final activeSessionTaskUnlockControllerProvider = AsyncNotifierProvider<
    ActiveSessionTaskUnlockController, ActiveSessionTaskUnlockConfig?>(
  ActiveSessionTaskUnlockController.new,
);

class ActiveSessionTaskUnlockController
    extends AsyncNotifier<ActiveSessionTaskUnlockConfig?> {
  static const _kKey = 'focus_active_session_task_unlock_v1';

  @override
  Future<ActiveSessionTaskUnlockConfig?> build() async {
    final prefs = ref.watch(sharedPreferencesProvider);
    final session = ref.watch(activeFocusSessionProvider).valueOrNull;
    if (session == null || !session.isActive) {
      // Best-effort cleanup: if no active session, an unlock config is meaningless.
      await prefs.remove(_kKey);
      return null;
    }

    final raw = prefs.getString(_kKey);
    final parsed = ActiveSessionTaskUnlockConfig.fromJsonString(raw);
    if (parsed == null) return null;

    // Safety: tie config to the current active session id.
    if (parsed.sessionId != session.id) {
      await prefs.remove(_kKey);
      return null;
    }

    return parsed;
  }

  Future<void> clear() async {
    final prefs = ref.read(sharedPreferencesProvider);
    await prefs.remove(_kKey);
    state = const AsyncData(null);
  }

  Future<void> setForActiveSession({
    required FocusSession session,
    required String ymd,
    required int requiredCount,
    required List<String> requiredTaskIds,
  }) async {
    final prefs = ref.read(sharedPreferencesProvider);

    final normalized = <String>[];
    final seen = <String>{};
    for (final id in requiredTaskIds) {
      final trimmed = id.trim();
      if (trimmed.isEmpty) continue;
      if (seen.add(trimmed)) normalized.add(trimmed);
    }

    final next = ActiveSessionTaskUnlockConfig(
      sessionId: session.id,
      ymd: ymd,
      requiredCount: requiredCount,
      requiredTaskIds: normalized,
    );
    await prefs.setString(_kKey, next.toJsonString());
    state = AsyncData(next);
  }

  Future<void> updateRequiredTaskIds({
    required List<String> requiredTaskIds,
  }) async {
    final current = state.valueOrNull;
    if (current == null) return;
    final session = ref.read(activeFocusSessionProvider).valueOrNull;
    if (session == null || !session.isActive) return;
    await setForActiveSession(
      session: session,
      ymd: current.ymd,
      requiredCount: current.requiredCount,
      requiredTaskIds: requiredTaskIds,
    );
  }

  /// Convenience for UX: show a snackbar if a save fails.
  Future<void> safeSetForActiveSession({
    required BuildContext context,
    required FocusSession session,
    required String ymd,
    required int requiredCount,
    required List<String> requiredTaskIds,
  }) async {
    try {
      await setForActiveSession(
        session: session,
        ymd: ymd,
        requiredCount: requiredCount,
        requiredTaskIds: requiredTaskIds,
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to save unlock tasks: $e')),
      );
    }
  }
}

