import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme.dart' show sharedPreferencesProvider;
import '../../domain/focus/focus_friction.dart';
import '../../domain/focus/focus_session.dart';
import 'focus_session_controller.dart';
import 'task_unlock/active_session_task_unlock_controller.dart';
import '../today/today_controller.dart';

@immutable
class DumbPhoneSessionGateState {
  const DumbPhoneSessionGateState({
    required this.sessionActive,
    required this.sessionStartedAt,
    required this.requireSelfieToEndEarly,
  });

  final bool sessionActive;
  final DateTime? sessionStartedAt;

  /// Optional friction: when ON, ending a session early requires taking a selfie
  /// (camera capture + explicit confirmation). Normal timer completion still ends
  /// automatically.
  final bool requireSelfieToEndEarly;

  DumbPhoneSessionGateState copyWith({
    bool? sessionActive,
    Object? sessionStartedAt = _unset,
    bool? requireSelfieToEndEarly,
  }) {
    return DumbPhoneSessionGateState(
      sessionActive: sessionActive ?? this.sessionActive,
      sessionStartedAt: (sessionStartedAt == _unset)
          ? this.sessionStartedAt
          : sessionStartedAt as DateTime?,
      requireSelfieToEndEarly:
          requireSelfieToEndEarly ?? this.requireSelfieToEndEarly,
    );
  }
}

const Object _unset = Object();

final dumbPhoneSessionGateControllerProvider = AsyncNotifierProvider<
    DumbPhoneSessionGateController, DumbPhoneSessionGateState>(
  DumbPhoneSessionGateController.new,
);

class DumbPhoneSessionGateController extends AsyncNotifier<DumbPhoneSessionGateState> {
  static const _kRequireSelfieToEndEarly =
      'settings_dumb_phone_require_selfie_to_end_early_v1';

  @override
  Future<DumbPhoneSessionGateState> build() async {
    final prefs = ref.watch(sharedPreferencesProvider);

    final session = ref.watch(activeFocusSessionProvider).valueOrNull;

    // v1 default: OFF (optional friction).
    final requireSelfieEndEarly =
        prefs.getBool(_kRequireSelfieToEndEarly) ?? false;

    return DumbPhoneSessionGateState(
      sessionActive: session?.isActive == true,
      sessionStartedAt: session?.startedAt,
      requireSelfieToEndEarly: requireSelfieEndEarly,
    );
  }

  Future<void> setRequireSelfieToEndEarly(
    BuildContext context,
    bool enabled,
  ) async {
    if (kIsWeb && enabled) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Selfie verification is not supported on web.'),
          ),
        );
      }
      return;
    }

    final prefs = ref.read(sharedPreferencesProvider);
    final current = state.valueOrNull;
    final sessionActive = current?.sessionActive == true;

    if (sessionActive) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('You can change this after the current session ends.'),
          ),
        );
      }
      return;
    }

    await prefs.setBool(_kRequireSelfieToEndEarly, enabled);
    if (current != null) {
      state = AsyncData(current.copyWith(requireSelfieToEndEarly: enabled));
    } else {
      ref.invalidateSelf();
    }
  }

  Future<bool> startSession({
    required BuildContext context,
    required String policyId,
    Duration? duration,
    DateTime? endsAt,
    FocusFrictionSettings? frictionOverride,
  }) async {
    return await ref.read(activeFocusSessionProvider.notifier).startSession(
          policyId: policyId,
          duration: duration,
          endsAt: endsAt,
          frictionOverride: frictionOverride,
        );
  }

  Future<void> endSession({
    required BuildContext context,
    required FocusSessionEndReason reason,
    required Future<bool> Function(BuildContext context) ensureSelfieValidated,
  }) async {
    if (reason == FocusSessionEndReason.userEarlyExit) {
      final ok = await _ensureUnlockTasksSatisfied(context);
      if (!ok) return;
    }
    final current = state.valueOrNull;
    if (current?.requireSelfieToEndEarly == true &&
        reason == FocusSessionEndReason.userEarlyExit) {
      if (!context.mounted) return;
      final ok = await ensureSelfieValidated(context);
      if (!ok) return;
    }
    await ref.read(activeFocusSessionProvider.notifier).endSession(reason: reason);
  }

  Future<bool> _ensureUnlockTasksSatisfied(BuildContext context) async {
    final config =
        ref.read(activeSessionTaskUnlockControllerProvider).valueOrNull;
    final requiredCount = config?.requiredCount ?? 0;
    final ymd = config?.ymd;
    if (requiredCount <= 0 || ymd == null || ymd.isEmpty) return true;

    final today = ref.read(todayControllerProvider(ymd));
    final byId = {for (final t in today.tasks) t.id: t};
    int done = 0;
    int missing = 0;
    for (final id in config!.requiredTaskIds) {
      final t = byId[id];
      if (t == null) {
        missing++;
      } else if (t.completed) {
        done++;
      }
    }

    final satisfied = done >= requiredCount &&
        missing == 0 &&
        config.requiredTaskIds.length == requiredCount;
    if (satisfied) return true;

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            missing > 0
                ? 'You have $missing missing unlock task(s). Edit your unlock tasks first.'
                : 'Complete unlock tasks to end early ($done/$requiredCount).',
          ),
          action: SnackBarAction(
            label: 'Today',
            onPressed: () => GoRouter.of(context).go('/today?ymd=$ymd'),
          ),
        ),
      );
    }
    return false;
  }
}

