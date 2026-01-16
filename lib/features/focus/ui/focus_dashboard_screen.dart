import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../domain/focus/focus_session.dart';
import '../../../domain/focus/focus_policy.dart';
import '../../../domain/focus/focus_friction.dart';
import '../../../ui/app_scaffold.dart';
import '../../../ui/spacing.dart';
import '../../../app/user_settings.dart';
import '../../../platform/nfc/nfc_card_service.dart';
import '../../../platform/nfc/nfc_scan_purpose.dart';
import '../../../platform/nfc/nfc_scan_service.dart';
import '../../../ui/components/w_drop_celebration_overlay.dart';
import '../../today/today_controller.dart';
import '../../today/today_models.dart';
import '../../today/today_timebox_controller.dart';
import '../dumb_phone_session_gate_controller.dart';
import '../focus_policy_controller.dart';
import '../focus_session_controller.dart';
import '../focus_ticker_provider.dart';
import '../w_celebration_decider.dart';
import '../task_unlock/active_session_task_unlock_controller.dart';
import 'widgets/hold_to_confirm_button.dart';
import 'widgets/task_unlock_picker_sheet.dart';
import '../../../ui/components/clown_cam_gate_sheet.dart';

class FocusDashboardScreen extends ConsumerStatefulWidget {
  const FocusDashboardScreen({super.key});

  @override
  ConsumerState<FocusDashboardScreen> createState() =>
      _FocusDashboardScreenState();
}

class _FocusDashboardScreenState extends ConsumerState<FocusDashboardScreen> {
  static const double _kWCelebrationChance = 0.28;
  late final WCelebrationDecider _wCelebration =
      WCelebrationDecider(chance: _kWCelebrationChance);

  bool _showW = false;

  void _triggerWTest() {
    // The overlay plays when `play` flips false -> true.
    if (_showW) {
      setState(() => _showW = false);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        setState(() => _showW = true);
      });
      return;
    }
    setState(() => _showW = true);
  }

  void _maybeTriggerWCelebration({
    required AsyncValue<FocusSession?>? previous,
    required AsyncValue<FocusSession?> next,
  }) {
    final prevSession = previous?.valueOrNull;
    final nextSession = next.valueOrNull;
    if (prevSession == null) return;

    // Transition: active -> none (ended)
    if (prevSession.isActive && nextSession == null && !next.isLoading) {
      final now = DateTime.now();
      final shouldPlay = _wCelebration.shouldCelebrateCompletedSession(
        session: prevSession,
        now: now,
      );
      if (!shouldPlay) return;

      if (mounted) {
        setState(() => _showW = true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<AsyncValue<FocusSession?>>(
      activeFocusSessionProvider,
      (previous, next) => _maybeTriggerWCelebration(previous: previous, next: next),
    );

    final active = ref.watch(activeFocusSessionProvider);
    final policies = ref.watch(focusPolicyListProvider);

    return AppScaffold(
      title: 'Dumb Phone Mode',
      children: const [],
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
      body: Stack(
        children: [
          ListView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: const EdgeInsets.all(AppSpace.s16),
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
                        padding: const EdgeInsets.all(AppSpace.s12),
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
              Gap.h12,
              Builder(
                builder: (context) {
                  final sessionActive = active.valueOrNull?.isActive == true;
                  if (sessionActive) {
                    return Card(
                      child: Padding(
                        padding: const EdgeInsets.all(AppSpace.s12),
                        child: Text(
                          'Session already running. End it to start a new one.',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ),
                    );
                  }

                  return policies.when(
                    loading: () =>
                        const Center(child: CircularProgressIndicator()),
                    error: (e, _) => Card(
                      child: Padding(
                        padding: const EdgeInsets.all(AppSpace.s12),
                        child: Text('Failed to load policies: $e'),
                      ),
                    ),
                    data: (items) => _StartSessionCard(
                      policies: items,
                      onTestCelebration: kDebugMode ? _triggerWTest : null,
                    ),
                  );
                },
              ),
            ],
          ),
          Positioned.fill(
            child: WDropCelebrationOverlay(
              play: _showW,
              // Rain W's for 3 seconds, and let each one fall through after spawning.
              particleCount: 90,
              emitDuration: const Duration(seconds: 3),
              fallDuration: const Duration(milliseconds: 1800),
              onSpawn: null,
              onCompleted: () {
                if (!mounted) return;
                setState(() => _showW = false);
              },
            ),
          ),
        ],
      ),
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
    final totalDuration = session.plannedEndAt.difference(session.startedAt);
    final elapsed = now.difference(session.startedAt);
    final progress = totalDuration.inSeconds > 0
        ? (elapsed.inSeconds / totalDuration.inSeconds).clamp(0.0, 1.0)
        : 0.0;

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
    final effectiveFriction = session.friction ?? friction;
    final gate = ref.watch(dumbPhoneSessionGateControllerProvider).valueOrNull;
    final requireCardToEndEarly = gate?.requireCardToEndEarly == true;
    final requireSelfieToEndEarly = gate?.requireSelfieToEndEarly == true;
    final unlockConfig =
        ref.watch(activeSessionTaskUnlockControllerProvider).valueOrNull;
    final unlockRequiredCount = unlockConfig?.requiredCount ?? 0;
    final unlockTaskIds = unlockConfig?.requiredTaskIds ?? const <String>[];
    final unlockYmd = unlockConfig?.ymd;

    int unlockDone = 0;
    int unlockMissing = 0;
    if (unlockRequiredCount > 0 && unlockYmd != null && unlockYmd.isNotEmpty) {
      final today = ref.watch(todayControllerProvider(unlockYmd));
      final byId = <String, TodayTask>{for (final t in today.tasks) t.id: t};
      for (final id in unlockTaskIds) {
        final t = byId[id];
        if (t == null) {
          unlockMissing++;
        } else if (t.completed) {
          unlockDone++;
        }
      }
    }
    final unlockSatisfied = unlockRequiredCount <= 0
        ? true
        : (unlockDone >= unlockRequiredCount &&
            unlockMissing == 0 &&
            unlockTaskIds.length == unlockRequiredCount);

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

    final scheme = Theme.of(context).colorScheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.timer, color: scheme.onSurfaceVariant),
                Gap.w12,
                Expanded(
                  child: Text(
                    'Focus Session Active',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
              ],
            ),
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
            Gap.h12,
            // Large prominent timer display
            Center(
              child: Text(
                mmss,
                style: Theme.of(context).textTheme.displayMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
              ),
            ),
            Gap.h8,
            Center(
              child: Text(
                'remaining',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
              ),
            ),
            Gap.h12,
            LinearProgressIndicator(value: progress),
            Gap.h8,
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Started ${DateFormat.Hm().format(session.startedAt)}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                Text(
                  'Ends ${DateFormat.Hm().format(session.plannedEndAt)}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (unlockRequiredCount > 0 && unlockYmd != null) ...[
              _UnlockToEndEarlySection(
                ymd: unlockYmd,
                requiredCount: unlockRequiredCount,
                requiredTaskIds: unlockTaskIds,
                doneCount: unlockDone,
                missingCount: unlockMissing,
                onEdit: () async {
                  final result = await TaskUnlockPickerSheet.show(
                    context,
                    ymd: unlockYmd,
                    requiredCount: unlockRequiredCount,
                    initialSelectedTaskIds: unlockTaskIds,
                  );
                  if (result == null) return;
                  try {
                    await ref
                        .read(activeSessionTaskUnlockControllerProvider.notifier)
                        .updateRequiredTaskIds(requiredTaskIds: result.taskIds);
                  } catch (e) {
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Failed to update unlock tasks: $e')),
                    );
                  }
                },
                onGoToToday: () => context.go('/today?ymd=$unlockYmd'),
                onToggleTask: (taskId) async {
                  final todayController =
                      ref.read(todayControllerProvider(unlockYmd).notifier);
                  final beforeDay = ref.read(todayControllerProvider(unlockYmd));
                  bool wasCompleted = false;
                  for (final t in beforeDay.tasks) {
                    if (t.id == taskId) {
                      wasCompleted = t.completed;
                      break;
                    }
                  }

                  await todayController.toggleTaskCompleted(taskId);

                  final afterDay = ref.read(todayControllerProvider(unlockYmd));
                  bool isCompleted = false;
                  for (final t in afterDay.tasks) {
                    if (t.id == taskId) {
                      isCompleted = t.completed;
                      break;
                    }
                  }

                  if (!wasCompleted && isCompleted) {
                  }
                },
              ),
              const SizedBox(height: 12),
            ],
            HoldToConfirmButton(
              holdDuration: Duration(seconds: effectiveFriction.holdToUnlockSeconds),
              label: requireCardToEndEarly && requireSelfieToEndEarly
                  ? 'Hold, scan card, then clown cam to end'
                  : requireCardToEndEarly
                      ? 'Hold, then scan card to end'
                      : requireSelfieToEndEarly
                          ? 'Hold, then clown cam to end'
                          : unlockSatisfied
                              ? 'Hold to end session early'
                              : 'Complete unlock tasks to end early',
              icon: Icons.stop_circle,
              enabled: !widget.isEnding && unlockSatisfied,
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
                if (effectiveFriction.unlockDelaySeconds > 0) {
                  await Future<void>.delayed(
                    Duration(seconds: effectiveFriction.unlockDelaySeconds),
                  );
                }

                Future<bool> ensureCardValidated(BuildContext ctx) async {
                  if (!requireCardToEndEarly) return true;
                  if (pairedHash == null || pairedHash.isEmpty) {
                    if (ctx.mounted) {
                      ScaffoldMessenger.of(ctx).showSnackBar(
                        const SnackBar(
                          content: Text('Pair a card to enable this setting.'),
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

                Future<bool> ensureSelfieValidated(BuildContext ctx) async {
                  if (!requireSelfieToEndEarly) return true;
                  if (kIsWeb) {
                    if (ctx.mounted) {
                      ScaffoldMessenger.of(ctx).showSnackBar(
                        const SnackBar(
                          content: Text('Selfie verification is not supported on web.'),
                        ),
                      );
                    }
                    return false;
                  }
                  return await ClownCamGateSheet.show(ctx);
                }

                await gateController.endSession(
                  context: context,
                  reason: FocusSessionEndReason.userEarlyExit,
                  ensureCardValidated: ensureCardValidated,
                  ensureSelfieValidated: ensureSelfieValidated,
                );

                if (!context.mounted) return;
                final stillActive =
                    ref.read(activeFocusSessionProvider).valueOrNull?.isActive ==
                        true;
                if (!stillActive) {}
              },
            ),
            const SizedBox(height: 8),
            Text(
              requireCardToEndEarly && requireSelfieToEndEarly
                  ? 'To end early: open Dumb Phone Mode → hold for ${effectiveFriction.holdToUnlockSeconds}s, wait ${effectiveFriction.unlockDelaySeconds}s, scan your paired card, then do the clown cam check.'
                  : requireCardToEndEarly
                      ? 'To end early: open Dumb Phone Mode → hold for ${effectiveFriction.holdToUnlockSeconds}s, wait ${effectiveFriction.unlockDelaySeconds}s, then scan your paired card.'
                      : requireSelfieToEndEarly
                          ? 'To end early: open Dumb Phone Mode → hold for ${effectiveFriction.holdToUnlockSeconds}s, wait ${effectiveFriction.unlockDelaySeconds}s, then do the clown cam check.'
                          : unlockRequiredCount > 0
                              ? 'To end early: complete your unlock tasks, then hold for ${effectiveFriction.holdToUnlockSeconds}s and wait ${effectiveFriction.unlockDelaySeconds}s.'
                              : 'To end early: open Dumb Phone Mode → hold for ${effectiveFriction.holdToUnlockSeconds}s, then wait ${effectiveFriction.unlockDelaySeconds}s.',
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
  const _StartSessionCard({
    required this.policies,
    this.onTestCelebration,
  });

  final List<FocusPolicy> policies;
  final VoidCallback? onTestCelebration;

  @override
  ConsumerState<_StartSessionCard> createState() => _StartSessionCardState();
}

class _StartSessionCardState extends ConsumerState<_StartSessionCard> {
  String? _policyId;
  double _minutes = 25;
  _StartSessionMode _mode = _StartSessionMode.duration;
  TimeOfDay? _endTime;
  _SessionPreset _preset = _SessionPreset.normal;

  @override
  void initState() {
    super.initState();
    _policyId = widget.policies.isEmpty ? null : widget.policies.first.id;
  }

  DateTime? _endAtForToday({required DateTime now}) {
    final t = _endTime;
    if (t == null) return null;
    return DateTime(now.year, now.month, now.day, t.hour, t.minute);
  }

  @override
  Widget build(BuildContext context) {
    final policies = widget.policies;
    final startState = ref.watch(activeFocusSessionProvider);
    final settings = ref.watch(userSettingsControllerProvider);
    final gate = ref.watch(dumbPhoneSessionGateControllerProvider).valueOrNull;
    final requireCardToEndEarly = gate?.requireCardToEndEarly == true;
    final requireSelfieToEndEarly = gate?.requireSelfieToEndEarly == true;
    final now = DateTime.now();
    final endAt = _endAtForToday(now: now);
    final endAtIsValid = endAt != null && endAt.isAfter(now);
    final endAtDurationMinutes =
        endAt == null ? null : endAt.difference(now).inMinutes;
    final missingPolicySelection = policies.isEmpty || _policyId == null;
    final startDisabled = startState.isLoading ||
        (!missingPolicySelection &&
            _mode == _StartSessionMode.endAt &&
            (!endAtIsValid));
    FocusPolicy? selected;
    if (_policyId != null) {
      for (final p in policies) {
        if (p.id == _policyId) {
          selected = p;
          break;
        }
      }
    }

    final presetFriction = _SessionPreset.frictionFor(_preset);
    final requiredUnlockCount = _SessionPreset.requiredUnlockTaskCount(_preset);

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
            SegmentedButton<_StartSessionMode>(
              segments: const [
                ButtonSegment(
                  value: _StartSessionMode.duration,
                  label: Text('Duration'),
                ),
                ButtonSegment(
                  value: _StartSessionMode.endAt,
                  label: Text('End at'),
                ),
              ],
              selected: {_mode},
              onSelectionChanged: (set) {
                if (set.isEmpty) return;
                setState(() => _mode = set.first);
              },
            ),
            const SizedBox(height: 12),
            if (_mode == _StartSessionMode.duration) ...[
              Text('Duration: ${_minutes.toInt()} min'),
              Slider(
                value: _minutes,
                min: 5,
                max: 180,
                divisions: 35,
                label: '${_minutes.toInt()} min',
                onChanged: (v) => setState(() => _minutes = v),
              ),
            ] else ...[
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: startState.isLoading
                          ? null
                          : () async {
                              final picked = await showTimePicker(
                                context: context,
                                initialTime: _endTime ??
                                    TimeOfDay.fromDateTime(
                                      now.add(const Duration(minutes: 60)),
                                    ),
                              );
                              if (picked == null) return;
                              if (!mounted) return;
                              setState(() => _endTime = picked);
                            },
                      icon: const Icon(Icons.schedule),
                      label: Text(
                        _endTime == null
                            ? 'Pick end time'
                            : 'End at ${_endTime!.format(context)}',
                      ),
                    ),
                  ),
                ],
              ),
              if (_endTime != null && !endAtIsValid) ...[
                const SizedBox(height: 8),
                Text(
                  'End time must be in the future.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.error,
                        fontWeight: FontWeight.w700,
                      ),
                ),
              ],
              if (_endTime != null && endAtIsValid && endAtDurationMinutes != null)
                ...[
                  const SizedBox(height: 8),
                  Text(
                    'Duration: $endAtDurationMinutes min',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
            ],
            const SizedBox(height: 12),
            Text('Preset', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            SegmentedButton<_SessionPreset>(
              segments: const [
                ButtonSegment(value: _SessionPreset.light, label: Text('Light')),
                ButtonSegment(value: _SessionPreset.normal, label: Text('Normal')),
                ButtonSegment(value: _SessionPreset.extreme, label: Text('Extreme')),
              ],
              selected: {_preset},
              onSelectionChanged: (set) {
                if (set.isEmpty) return;
                setState(() => _preset = set.first);
              },
            ),
            const SizedBox(height: 8),
            Text(
              requiredUnlockCount <= 0
                  ? 'Early-exit requirement: None'
                  : 'Early-exit requirement: Complete $requiredUnlockCount tasks to unlock',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: startDisabled
                        ? null
                        : policies.isEmpty || _policyId == null
                            ? () => context.go('/focus/policies')
                            : () async {
                                final now = DateTime.now();
                                final policy = selected;
                                if (policy == null) return;
                                final ymd =
                                    DateFormat('yyyy-MM-dd').format(now);

                                final computedEndsAt =
                                    _mode == _StartSessionMode.duration
                                        ? now.add(
                                            Duration(minutes: _minutes.toInt()),
                                          )
                                        : _endAtForToday(now: now)!;
                                final computedDuration =
                                    _mode == _StartSessionMode.duration
                                        ? Duration(minutes: _minutes.toInt())
                                        : computedEndsAt.difference(now);

                                final ok = await _confirmStart(
                                  context: context,
                                  policy: policy,
                                  endsAt: computedEndsAt,
                                  duration: computedDuration,
                                  friction: presetFriction,
                                  requiredUnlockTaskCount: requiredUnlockCount,
                                  requireCardToEndEarly: requireCardToEndEarly,
                                  requireSelfieToEndEarly:
                                      requireSelfieToEndEarly,
                                );
                                if (!ok) return;
                                if (!context.mounted) return;

                                List<String> unlockTaskIds = const [];
                                if (requiredUnlockCount > 0) {
                                  final picked =
                                      await TaskUnlockPickerSheet.show(
                                    context,
                                    ymd: ymd,
                                    requiredCount: requiredUnlockCount,
                                    initialSelectedTaskIds: const [],
                                  );
                                  if (picked == null) return;
                                  unlockTaskIds = picked.taskIds;
                                }

                                final gateController = ref.read(
                                  dumbPhoneSessionGateControllerProvider.notifier,
                                );

                                final started = await gateController.startSession(
                                  context: context,
                                  policyId: policy.id,
                                  duration: _mode == _StartSessionMode.duration
                                      ? Duration(minutes: _minutes.toInt())
                                      : null,
                                  endsAt: _mode == _StartSessionMode.endAt
                                      ? computedEndsAt
                                      : null,
                                  frictionOverride: presetFriction,
                                );
                                if (!started) return;

                                final session = ref
                                    .read(activeFocusSessionProvider)
                                    .valueOrNull;
                                if (session != null && session.isActive) {
                                  final unlockController = ref.read(
                                    activeSessionTaskUnlockControllerProvider
                                        .notifier,
                                  );
                                  if (requiredUnlockCount > 0) {
                                    await unlockController.safeSetForActiveSession(
                                      context: context,
                                      session: session,
                                      ymd: ymd,
                                      requiredCount: requiredUnlockCount,
                                      requiredTaskIds: unlockTaskIds,
                                    );
                                  } else {
                                    // Preset says none: ensure we clear any stale config.
                                    await unlockController.clear();
                                  }
                                }

                                if (!context.mounted) return;
                                await ref
                                    .read(todayControllerProvider(ymd).notifier)
                                    .enableFocusModeAndSelectDefaultTask();
                                if (settings.dumbPhoneAutoStart25mTimebox) {
                                  await ref
                                      .read(todayTimeboxControllerProvider(ymd)
                                          .notifier)
                                      .queuePendingAutoStart25m();
                                }
                                if (!context.mounted) return;
                                context.go('/today?ymd=$ymd');
                              },
                    icon: const Icon(Icons.play_arrow),
                    label: Text(
                      policies.isEmpty ? 'Create a policy' : 'Start session',
                    ),
                  ),
                ),
                if (widget.onTestCelebration != null) ...[
                  Gap.w12,
                  OutlinedButton.icon(
                    onPressed: widget.onTestCelebration,
                    icon: const Text(
                      'W',
                      style: TextStyle(fontWeight: FontWeight.w900),
                    ),
                    label: const Text('Test'),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  static Future<bool> _confirmStart({
    required BuildContext context,
    required FocusPolicy policy,
    required DateTime endsAt,
    required Duration duration,
    required FocusFrictionSettings friction,
    required int requiredUnlockTaskCount,
    required bool requireCardToEndEarly,
    required bool requireSelfieToEndEarly,
  }) async {
    final isIOS = !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;
    final isAndroid =
        !kIsWeb && defaultTargetPlatform == TargetPlatform.android;
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
                      'Ends at: ${DateFormat.Hm().format(endsAt)} (${duration.inMinutes} min)'),
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
                  if (requiredUnlockTaskCount > 0) ...[
                    const SizedBox(height: 6),
                    Text(
                      'Because “Complete tasks to unlock” is enabled, you must complete $requiredUnlockTaskCount selected tasks before the early-exit hold will work.',
                    ),
                  ],
                  if (requireCardToEndEarly) ...[
                    const SizedBox(height: 6),
                    const Text(
                      'Because “Require NFC card to end early” is enabled, you’ll also need to scan your paired card.',
                    ),
                  ],
                  if (requireSelfieToEndEarly) ...[
                    const SizedBox(height: 6),
                    const Text(
                      'Because “Require clown camera check to end early” is enabled, you’ll also need to open the selfie camera with the overlay (a photo is saved on your device).',
                    ),
                  ],
                  if (isAndroid) ...[
                    const SizedBox(height: 6),
                    Text(
                      'Android tip: the blocking screen also has “Hold ${friction.holdToUnlockSeconds}s” to end the session, plus an “Emergency end (${friction.emergencyUnlockMinutes} min)” button.',
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

enum _StartSessionMode {
  duration,
  endAt,
}

enum _SessionPreset {
  light,
  normal,
  extreme;

  static FocusFrictionSettings frictionFor(_SessionPreset preset) {
    // v1 sensible defaults (independent of policy): consistent mental model.
    // Light: low friction, still not instant.
    // Normal: current defaults.
    // Extreme: higher friction and (optionally) no emergency exceptions.
    return switch (preset) {
      _SessionPreset.light => const FocusFrictionSettings(
          holdToUnlockSeconds: 2,
          unlockDelaySeconds: 5,
          emergencyUnlockMinutes: 3,
          maxEmergencyUnlocksPerSession: 1,
        ),
      _SessionPreset.normal => FocusFrictionSettings.defaults,
      _SessionPreset.extreme => const FocusFrictionSettings(
          holdToUnlockSeconds: 5,
          unlockDelaySeconds: 20,
          emergencyUnlockMinutes: 3,
          maxEmergencyUnlocksPerSession: 0,
        ),
    };
  }

  static int requiredUnlockTaskCount(_SessionPreset preset) {
    return switch (preset) {
      _SessionPreset.light => 0,
      _SessionPreset.normal => 2,
      _SessionPreset.extreme => 3,
    };
  }
}

class _UnlockToEndEarlySection extends ConsumerWidget {
  const _UnlockToEndEarlySection({
    required this.ymd,
    required this.requiredCount,
    required this.requiredTaskIds,
    required this.doneCount,
    required this.missingCount,
    required this.onEdit,
    required this.onGoToToday,
    required this.onToggleTask,
  });

  final String ymd;
  final int requiredCount;
  final List<String> requiredTaskIds;
  final int doneCount;
  final int missingCount;
  final VoidCallback onEdit;
  final VoidCallback onGoToToday;
  final Future<void> Function(String taskId) onToggleTask;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final today = ref.watch(todayControllerProvider(ymd));
    final byId = <String, TodayTask>{for (final t in today.tasks) t.id: t};

    final remaining = (requiredCount - doneCount).clamp(0, requiredCount);
    final blocked = remaining > 0 || missingCount > 0 || requiredTaskIds.length != requiredCount;

    return Card(
      color: blocked
          ? Theme.of(context).colorScheme.surfaceContainerHighest
          : null,
      child: Padding(
        padding: const EdgeInsets.all(AppSpace.s12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Unlock to end early',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                ),
                TextButton(
                  onPressed: onEdit,
                  child: const Text('Edit'),
                ),
              ],
            ),
            Text(
              '$doneCount/$requiredCount done',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            Text(
              'Tap a task to mark it complete',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
            if (missingCount > 0) ...[
              Gap.h8,
              Text(
                '$missingCount missing task${missingCount == 1 ? '' : 's'} (deleted or moved). Replace them to unlock.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.error,
                      fontWeight: FontWeight.w700,
                    ),
              ),
            ],
            Gap.h8,
            for (final id in requiredTaskIds) ...[
              Builder(
                builder: (context) {
                  final t = byId[id];
                  if (t == null) {
                    return ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.error_outline),
                      title: const Text('Missing task'),
                      subtitle: Text('ID: $id'),
                    );
                  }
                  return ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(
                      t.completed
                          ? Icons.check_circle
                          : Icons.radio_button_unchecked,
                    ),
                    title: Text(t.title),
                    subtitle: Text(
                      t.type == TodayTaskType.mustWin ? 'Must‑Win' : 'Nice‑to‑Do',
                    ),
                    onTap: () => onToggleTask(t.id),
                  );
                },
              ),
            ],
            if (blocked) ...[
              Gap.h12,
              FilledButton.icon(
                onPressed: onGoToToday,
                icon: const Icon(Icons.today),
                label: const Text('Go to Today to complete tasks'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

