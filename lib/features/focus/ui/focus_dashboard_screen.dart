import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../domain/focus/focus_session.dart';
import '../../../domain/focus/focus_policy.dart';
import '../../../domain/focus/focus_friction.dart';
import '../../../ui/app_scaffold.dart';
import '../../../app/user_settings.dart';
import '../../../platform/nfc/nfc_card_service.dart';
import '../../../platform/nfc/nfc_scan_purpose.dart';
import '../../../platform/nfc/nfc_scan_service.dart';
import '../../today/today_controller.dart';
import '../../today/today_timebox_controller.dart';
import '../dumb_phone_session_gate_controller.dart';
import '../focus_policy_controller.dart';
import '../focus_session_controller.dart';
import '../focus_ticker_provider.dart';
import 'widgets/hold_to_confirm_button.dart';

class FocusDashboardScreen extends ConsumerWidget {
  const FocusDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final active = ref.watch(activeFocusSessionProvider);
    final policies = ref.watch(focusPolicyListProvider);

    return AppScaffold(
      title: 'Dumb Phone Mode',
      actions: [
        IconButton(
          tooltip: 'History',
          onPressed: () => context.go('/focus/history'),
          icon: const Icon(Icons.history),
        ),
        IconButton(
          tooltip: 'Policies',
          onPressed: () => context.go('/focus/policies'),
          icon: const Icon(Icons.tune),
        ),
      ],
      children: [
        Builder(
          builder: (context) {
            final session = active.valueOrNull;
            // If we're loading but still have the previous session, treat this as
            // "ending..." rather than a full blank loading state.
            final isEnding = active.isLoading && session != null;

            if (active.isLoading && session == null) {
              return const Center(child: CircularProgressIndicator());
            }

            if (active.hasError && session == null) {
              return Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Text('Session error: ${active.error}'),
                ),
              );
            }

            return _ActiveSessionCard(
              session: session,
              isEnding: isEnding,
              error: active.hasError ? active.error : null,
            );
          },
        ),
        const SizedBox(height: 12),
        policies.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Text('Failed to load policies: $e'),
            ),
          ),
          data: (items) => _StartSessionCard(policies: items),
        ),
      ],
    );
  }
}

class _ActiveSessionCard extends ConsumerStatefulWidget {
  const _ActiveSessionCard({
    required this.session,
    this.isEnding = false,
    this.error,
  });

  final FocusSession? session;
  final bool isEnding;
  final Object? error;

  @override
  ConsumerState<_ActiveSessionCard> createState() => _ActiveSessionCardState();
}

class _ActiveSessionCardState extends ConsumerState<_ActiveSessionCard> {
  String? _didScheduleReconcileForSessionId;

  @override
  void didUpdateWidget(covariant _ActiveSessionCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    final nextId = widget.session?.id;
    if (nextId == null) {
      _didScheduleReconcileForSessionId = null;
      return;
    }
    if (oldWidget.session?.id != nextId) {
      _didScheduleReconcileForSessionId = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = widget.session;
    if (session == null) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Text(
            'No active Focus Session.',
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ),
      );
    }

    final now = ref.watch(nowTickerProvider).valueOrNull ?? DateTime.now();
    final remaining = session.plannedEndAt.difference(now);
    final mmss = _formatRemaining(remaining);

    final policies =
        ref.watch(focusPolicyListProvider).valueOrNull ?? const <FocusPolicy>[];
    FocusPolicy? policy;
    for (final p in policies) {
      if (p.id == session.policyId) {
        policy = p;
        break;
      }
    }
    final friction = policy?.friction ?? FocusFrictionSettings.defaults;
    final gate = ref.watch(dumbPhoneSessionGateControllerProvider).valueOrNull;
    final cardRequired = gate?.cardRequired == true;

    // Ensure we auto-complete once the timer elapses.
    // IMPORTANT: Do not modify providers during build; defer to after the frame.
    if (remaining <= Duration.zero &&
        _didScheduleReconcileForSessionId != session.id) {
      _didScheduleReconcileForSessionId = session.id;
      final activeController = ref.read(activeFocusSessionProvider.notifier);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        // Avoid using `ref` in an async/post-frame callback; the widget might be disposed.
        activeController.reconcileIfExpired();
      });
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Session active',
                style: Theme.of(context).textTheme.titleMedium),
            if (widget.isEnding) ...[
              const SizedBox(height: 8),
              const LinearProgressIndicator(),
              const SizedBox(height: 6),
              Text(
                'Ending session…',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
            if (!widget.isEnding && widget.error != null) ...[
              const SizedBox(height: 8),
              Text(
                'Session warning: ${widget.error}',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.error,
                      fontWeight: FontWeight.w700,
                    ),
              ),
            ],
            const SizedBox(height: 6),
            Text('Ends at: ${DateFormat.Hm().format(session.plannedEndAt)}'),
            Text('Remaining: $mmss'),
            const SizedBox(height: 12),
            HoldToConfirmButton(
              holdDuration: Duration(seconds: friction.holdToUnlockSeconds),
              label: cardRequired
                  ? 'Hold, then scan card to end'
                  : 'Hold to end session early',
              icon: Icons.stop_circle,
              enabled: !widget.isEnding,
              busyLabel: 'Ending…',
              onConfirmed: () async {
                // Capture the controller before any await; `ref` can't be used after dispose.
                final gateController =
                    ref.read(dumbPhoneSessionGateControllerProvider.notifier);
                final pairedHash = ref
                    .read(dumbPhoneSessionGateControllerProvider)
                    .valueOrNull
                    ?.pairedCardKeyHash;
                final nfc = ref.read(nfcCardServiceProvider);

                // Apply the configured "unlock delay" as a baseline.
                // (Android also enforces this delay on the native blocking screen.)
                if (friction.unlockDelaySeconds > 0) {
                  await Future<void>.delayed(
                    Duration(seconds: friction.unlockDelaySeconds),
                  );
                }

                Future<bool> ensureCardValidated(BuildContext ctx) async {
                  if (!cardRequired) return true;
                  if (pairedHash == null || pairedHash.isEmpty) {
                    if (ctx.mounted) {
                      ScaffoldMessenger.of(ctx).showSnackBar(
                        const SnackBar(
                          content: Text('Pair a card to enable card-required mode.'),
                        ),
                      );
                    }
                    return false;
                  }

                  final scan = await ref
                      .read(nfcScanServiceProvider)
                      .scanKeyHash(ctx, purpose: NfcScanPurpose.validateEnd);
                  if (scan == null) return false;

                  final ok = nfc.constantTimeEquals(scan, pairedHash);
                  if (!ok && ctx.mounted) {
                    ScaffoldMessenger.of(ctx).showSnackBar(
                      const SnackBar(content: Text('That is not the paired card.')),
                    );
                  }
                  return ok;
                }

                await gateController.endSession(
                  context: context,
                  reason: FocusSessionEndReason.userEarlyExit,
                  ensureCardValidated: ensureCardValidated,
                );
              },
            ),
            const SizedBox(height: 8),
            Text(
              cardRequired
                  ? 'To turn this off early: open Dumb Phone Mode and hold for ${friction.holdToUnlockSeconds}s, wait ${friction.unlockDelaySeconds}s, then scan your card.'
                  : 'To turn this off early: open Dumb Phone Mode and hold for ${friction.holdToUnlockSeconds}s, then wait ${friction.unlockDelaySeconds}s.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }

  static String _formatRemaining(Duration d) {
    if (d.isNegative) return '0:00';
    final m = d.inMinutes;
    final s = d.inSeconds - (m * 60);
    return '$m:${s.toString().padLeft(2, '0')}';
  }
}

class _StartSessionCard extends ConsumerStatefulWidget {
  const _StartSessionCard({required this.policies});

  final List<FocusPolicy> policies;

  @override
  ConsumerState<_StartSessionCard> createState() => _StartSessionCardState();
}

class _StartSessionCardState extends ConsumerState<_StartSessionCard> {
  String? _policyId;
  double _minutes = 25;

  @override
  void initState() {
    super.initState();
    _policyId = widget.policies.isEmpty ? null : widget.policies.first.id;
  }

  @override
  Widget build(BuildContext context) {
    final policies = widget.policies;
    final startState = ref.watch(activeFocusSessionProvider);
    final settings = ref.watch(userSettingsControllerProvider);
    final gate = ref.watch(dumbPhoneSessionGateControllerProvider).valueOrNull;
    final cardRequired = gate?.cardRequired == true;
    FocusPolicy? selected;
    if (_policyId != null) {
      for (final p in policies) {
        if (p.id == _policyId) {
          selected = p;
          break;
        }
      }
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Start a session',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            if (policies.isEmpty)
              const Text('Create a policy to get started.')
            else
              DropdownButtonFormField<String>(
                value: _policyId,
                items: [
                  for (final p in policies)
                    DropdownMenuItem(
                      value: p.id,
                      child: Text(p.name),
                    ),
                ],
                onChanged: (v) => setState(() => _policyId = v),
                decoration: const InputDecoration(labelText: 'Policy'),
              ),
            const SizedBox(height: 12),
            Text('Duration: ${_minutes.toInt()} min'),
            Slider(
              value: _minutes,
              min: 5,
              max: 180,
              divisions: 35,
              label: '${_minutes.toInt()} min',
              onChanged: (v) => setState(() => _minutes = v),
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: startState.isLoading
                  ? null
                  : policies.isEmpty || _policyId == null
                  ? () => context.go('/focus/policies')
                  : () async {
                      final policy = selected;
                      if (policy == null) return;

                      final ok = await _confirmStart(
                        context: context,
                        policy: policy,
                        duration: Duration(minutes: _minutes.toInt()),
                      );
                      if (!ok) return;
                      if (!context.mounted) return;

                      final gateController = ref.read(
                        dumbPhoneSessionGateControllerProvider.notifier,
                      );
                      final pairedHash = ref
                          .read(dumbPhoneSessionGateControllerProvider)
                          .valueOrNull
                          ?.pairedCardKeyHash;
                      final nfc = ref.read(nfcCardServiceProvider);

                      Future<bool> ensureCardValidated(BuildContext ctx) async {
                        if (!cardRequired) return true;
                        if (pairedHash == null || pairedHash.isEmpty) {
                          if (ctx.mounted) {
                            ScaffoldMessenger.of(ctx).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'Pair a card to enable card-required mode.',
                                ),
                              ),
                            );
                          }
                          return false;
                        }

                      final scan = await ref
                          .read(nfcScanServiceProvider)
                          .scanKeyHash(ctx, purpose: NfcScanPurpose.validateStart);
                      if (scan == null) return false;

                        final ok = nfc.constantTimeEquals(
                        scan,
                          pairedHash,
                        );
                        if (!ok && ctx.mounted) {
                          ScaffoldMessenger.of(ctx).showSnackBar(
                            const SnackBar(
                              content: Text('That is not the paired card.'),
                            ),
                          );
                        }
                        return ok;
                      }

                      final started = await gateController.startSession(
                        context: context,
                        policyId: policy.id,
                        duration: Duration(minutes: _minutes.toInt()),
                        ensureCardValidated: ensureCardValidated,
                      );
                      if (!started) return;

                      if (!context.mounted) return;
                      final ymd =
                          DateFormat('yyyy-MM-dd').format(DateTime.now());
                      await ref
                          .read(todayControllerProvider(ymd).notifier)
                          .enableFocusModeAndSelectDefaultTask();
                      if (settings.dumbPhoneAutoStart25mTimebox) {
                        await ref
                            .read(todayTimeboxControllerProvider(ymd).notifier)
                            .queuePendingAutoStart25m();
                      }
                      if (!context.mounted) return;
                      context.go('/today');
                    },
              icon: const Icon(Icons.play_arrow),
              label: Text(
                policies.isEmpty
                    ? 'Create a policy'
                    : cardRequired
                        ? 'Scan card to start'
                        : 'Start session',
              ),
            ),
          ],
        ),
      ),
    );
  }

  static Future<bool> _confirmStart({
    required BuildContext context,
    required FocusPolicy policy,
    required Duration duration,
  }) async {
    final isIOS = !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;
    final isAndroid =
        !kIsWeb && defaultTargetPlatform == TargetPlatform.android;
    final endsAt = DateTime.now().add(duration);
    final friction = policy.friction;
    final allowedCount = policy.allowedApps.length;

    final platformWhatHappens = isAndroid
        ? 'Android will show a blocking screen when you open any app that is not on your Allowed apps list.'
        : isIOS
            ? 'iOS will use Screen Time to shield the apps you selected in the iOS app picker (Policy → “Choose apps to block”).'
            : 'This platform may not support app blocking.';

    final ok = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Start Dumb Phone Mode?'),
            content: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Policy: ${policy.name}'),
                  Text(
                      'Duration: ${duration.inMinutes} min (ends at ${DateFormat.Hm().format(endsAt)})'),
                  const SizedBox(height: 12),
                  Text(
                    'What will happen',
                    style: Theme.of(ctx).textTheme.titleSmall,
                  ),
                  const SizedBox(height: 6),
                  Text(platformWhatHappens),
                  const SizedBox(height: 8),
                  Text('Allowed apps: $allowedCount'),
                  if (allowedCount == 0) ...[
                    const SizedBox(height: 6),
                    Text(
                      'Warning: with 0 allowed apps, almost everything will be blocked (except this app, so you can still end the session).',
                      style: Theme.of(ctx).textTheme.bodySmall?.copyWith(
                            color: Theme.of(ctx).colorScheme.error,
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                  ],
                  const SizedBox(height: 12),
                  Text(
                    'How to turn it off',
                    style: Theme.of(ctx).textTheme.titleSmall,
                  ),
                  const SizedBox(height: 6),
                  Text(
                      'It will end automatically at ${DateFormat.Hm().format(endsAt)}.'),
                  const SizedBox(height: 6),
                  Text(
                    'To end early: open Dumb Phone Mode → “Hold to end session early” (${friction.holdToUnlockSeconds}s hold, then ${friction.unlockDelaySeconds}s delay).',
                  ),
                  if (isAndroid) ...[
                    const SizedBox(height: 6),
                    Text(
                      'Android tip: the blocking screen also has “Hold ${friction.holdToUnlockSeconds}s” to end the session, plus an “Emergency unlock (${friction.emergencyUnlockMinutes} min)” button.',
                    ),
                  ],
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Start'),
              ),
            ],
          ),
        ) ??
        false;
    return ok;
  }
}
