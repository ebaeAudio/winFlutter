import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../app/auth.dart';
import '../../app/supabase.dart';
import '../../data/focus/remote_focus_command_repository.dart';
import '../../domain/focus/focus_session.dart';
import '../../platform/push/push_notification_service.dart';
import 'focus_providers.dart';
import 'focus_session_controller.dart';

/// Side-effect handler that processes remote focus commands delivered via
/// silent push notifications (and, later, polling fallback).
final remoteFocusCommandHandlerProvider =
    Provider<RemoteFocusCommandHandler>((ref) {
  return RemoteFocusCommandHandler(ref);
});

class RemoteFocusCommandHandler {
  RemoteFocusCommandHandler(this._ref) {
    _setup();
  }

  final Ref _ref;
  bool _processing = false;
  Timer? _pollTimer;

  RemoteFocusCommandRepository? _repo() {
    final supabaseState = _ref.read(supabaseProvider);
    final auth = _ref.read(authStateProvider).valueOrNull;
    if (!supabaseState.isInitialized) return null;
    if (auth == null || !auth.isSignedIn || auth.isDemo) return null;
    return RemoteFocusCommandRepository(Supabase.instance.client);
  }

  void _setup() {
    // Only mobile devices should apply restrictions. For now, limit remote command
    // execution to iOS (APNs-based wake). This can be extended to Android later.
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.iOS) return;

    _ref.listen<String?>(pendingRemoteFocusCommandIdProvider, (prev, next) {
      if (next == null || next.trim().isEmpty) return;
      unawaited(_processCommandId(next.trim()));
    });

    // Polling fallback: if silent push doesn't arrive, we still want the device
    // to pick up pending commands while the app is running.
    _pollTimer = Timer.periodic(const Duration(seconds: 45), (_) {
      unawaited(_pollForPendingCommand());
    });
    _ref.onDispose(() => _pollTimer?.cancel());
  }

  Future<void> _pollForPendingCommand() async {
    if (_processing) return;
    final repo = _repo();
    if (repo == null) return;

    final pending = _ref.read(pendingRemoteFocusCommandIdProvider);
    if (pending != null && pending.trim().isNotEmpty) return;

    final active = _ref.read(activeFocusSessionProvider).valueOrNull;
    if (active != null && active.isActive) return;

    try {
      final items = await repo.listPending(limit: 1);
      if (items.isEmpty) return;
      await _processCommandId(items.first.id);
    } catch (_) {
      // Ignore polling errors.
    }
  }

  Future<void> _processCommandId(String id) async {
    if (_processing) return;
    _processing = true;
    try {
      final repo = _repo();
      if (repo == null) return;

      // Clear local pending id immediately to avoid loops.
      await _ref.read(pushNotificationServiceProvider).clearPendingRemoteFocusCommandId();

      final claimed = await repo.markProcessing(id);
      if (!claimed) return; // Already processed elsewhere.

      final cmd = await repo.getById(id);
      if (cmd == null) {
        await repo.markFailed(id, 'Command not found');
        return;
      }

      // Guard against starting on top of an active local session.
      final active = _ref.read(activeFocusSessionProvider).valueOrNull;

      if (cmd.command == 'start') {
        if (active != null && active.isActive) {
          await repo.markFailed(id, 'Session already active on this device');
          return;
        }

        final policyRepo = _ref.read(focusPolicyRepositoryProvider);
        final policies = await policyRepo.listPolicies();
        final policyId = (cmd.policyId != null &&
                policies.any((p) => p.id == cmd.policyId))
            ? cmd.policyId!
            : (policies.isNotEmpty ? policies.first.id : '');

        if (policyId.isEmpty) {
          await repo.markFailed(
            id,
            'No focus policy found on this device. Complete Focus onboarding first.',
          );
          return;
        }

        final mins = cmd.durationMinutes ?? 25;
        final started = await _ref.read(activeFocusSessionProvider.notifier).startSession(
              policyId: policyId,
              duration: Duration(minutes: mins),
            );

        if (!started) {
          await repo.markFailed(id, 'Failed to start focus session');
          return;
        }

        await repo.markCompleted(id);
        return;
      }

      if (cmd.command == 'stop') {
        if (active == null || !active.isActive) {
          await repo.markCompleted(id);
          return;
        }
        await _ref
            .read(activeFocusSessionProvider.notifier)
            .endSession(reason: FocusSessionEndReason.userEarlyExit);
        await repo.markCompleted(id);
        return;
      }

      await repo.markFailed(id, 'Unknown command: ${cmd.command}');
    } catch (e) {
      final repo = _repo();
      if (repo != null) {
        try {
          await repo.markFailed(id, e.toString());
        } catch (_) {}
      }
    } finally {
      _processing = false;
    }
  }
}

