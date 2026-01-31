import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gal/gal.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../app/auth.dart';
import '../../../app/supabase.dart';
import '../../../domain/focus/focus_session.dart';
import '../../../domain/focus/focus_policy.dart';
import '../../../domain/focus/focus_friction.dart';
import '../../../app/theme.dart';
import '../../../app/user_settings.dart';
import '../../../ui/app_scaffold.dart';
import '../../../ui/spacing.dart';
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
import '../../../ui/components/shame_delay_sheet.dart';

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
              // "Start on iPhone" card: show on macOS so user can trigger Dumb Phone on iPhone from Mac.
              if (!kIsWeb && defaultTargetPlatform == TargetPlatform.macOS) ...[
                const RemoteStartOnIPhoneCard(),
                Gap.h12,
              ],
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
      children: const [],
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
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    if (session == null) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpace.s16),
        child: Text(
          'No active session',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: scheme.onSurfaceVariant,
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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header
        Row(
          children: [
            Icon(Icons.timer_outlined, size: 20, color: scheme.primary),
            Gap.w8,
            Expanded(
              child: Text(
                'Session Active',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
        if (widget.isEnding) ...[
          Gap.h8,
          const LinearProgressIndicator(),
          Gap.h4,
          Text(
            'Ending session…',
            style: theme.textTheme.bodySmall?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
        ],
        if (!widget.isEnding && widget.error != null) ...[
          Gap.h8,
          Text(
            'Warning: ${widget.error}',
            style: theme.textTheme.bodySmall?.copyWith(
              color: scheme.error,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
        Gap.h16,
        // Large timer display
        Center(
          child: Text(
            mmss,
            style: theme.textTheme.displayMedium?.copyWith(
              fontWeight: FontWeight.w700,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ),
        Gap.h4,
        Center(
          child: Text(
            'remaining',
            style: theme.textTheme.bodySmall?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
        ),
        Gap.h16,
        LinearProgressIndicator(value: progress),
        Gap.h8,
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Started ${DateFormat.Hm().format(session.startedAt)}',
              style: theme.textTheme.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
            Text(
              'Ends ${DateFormat.Hm().format(session.plannedEndAt)}',
              style: theme.textTheme.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
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
                  SnackBar(content: Text('Failed to update: $e')),
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
                // Task completed
              }
            },
          ),
          Gap.h16,
        ],
        HoldToConfirmButton(
          holdDuration: Duration(seconds: effectiveFriction.holdToUnlockSeconds),
          label: requireSelfieToEndEarly
              ? 'Hold, then selfie to end'
              : unlockSatisfied
                  ? 'Hold to end early'
                  : 'Complete tasks to end early',
          icon: Icons.stop_circle,
          enabled: !widget.isEnding && unlockSatisfied,
          busyLabel: 'Ending…',
          onConfirmed: () async {
                // Capture the controller before any await; `ref` can't be used after dispose.
                final gateController =
                    ref.read(dumbPhoneSessionGateControllerProvider.notifier);

                // Pre-request photo library permission BEFORE the delay if clown cam is required.
                // This avoids the awkward permission prompt after waiting.
                // Note: We use add-only permission (no toAlbum) to avoid "Select Photos" dialog on iOS 14+.
                if (requireSelfieToEndEarly && !kIsWeb) {
                  final hasAccess = await Gal.hasAccess();
                  if (!hasAccess) {
                    final granted = await Gal.requestAccess();
                    if (!granted) {
                      if (!context.mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'Photo Library access is required for the clown cam check.',
                          ),
                        ),
                      );
                      return;
                    }
                  }
                }

                // Apply the configured "unlock delay" as a baseline.
                // (Android also enforces this delay on the native blocking screen.)
                if (effectiveFriction.unlockDelaySeconds > 0) {
                  if (!context.mounted) return;
                  await ShameDelaySheet.show(
                    context,
                    delaySeconds: effectiveFriction.unlockDelaySeconds,
                  );
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

                if (!context.mounted) return;
                await gateController.endSession(
                  context: context,
                  reason: FocusSessionEndReason.userEarlyExit,
                  ensureSelfieValidated: ensureSelfieValidated,
                );

                if (!context.mounted) return;
                final stillActive =
                    ref.read(activeFocusSessionProvider).valueOrNull?.isActive ==
                        true;
                if (!stillActive) {}
              },
        ),
        Gap.h8,
        Text(
          requireSelfieToEndEarly
              ? 'Hold ${effectiveFriction.holdToUnlockSeconds}s → wait ${effectiveFriction.unlockDelaySeconds}s → selfie'
              : unlockRequiredCount > 0
                  ? 'Complete tasks → hold ${effectiveFriction.holdToUnlockSeconds}s → wait ${effectiveFriction.unlockDelaySeconds}s'
                  : 'Hold ${effectiveFriction.holdToUnlockSeconds}s → wait ${effectiveFriction.unlockDelaySeconds}s',
          style: theme.textTheme.bodySmall?.copyWith(
            color: scheme.onSurfaceVariant,
          ),
        ),
      ],
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
  });

  final List<FocusPolicy> policies;

  @override
  ConsumerState<_StartSessionCard> createState() => _StartSessionCardState();
}

class _StartSessionCardState extends ConsumerState<_StartSessionCard> {
  String? _policyId;
  double _minutes = 25;
  _StartSessionMode _mode = _StartSessionMode.duration;
  TimeOfDay? _endTime;
  _SessionPreset _preset = _SessionPreset.two;

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
    final requireSelfieToEndEarly = gate?.requireSelfieToEndEarly == true;
    final now = DateTime.now();
    final endAt = _endAtForToday(now: now);
    final endAtIsValid = endAt != null && endAt.isAfter(now);
    final endAtDurationMinutes = endAt?.difference(now).inMinutes;
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
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Start a session',
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        Gap.h12,
        if (policies.isEmpty)
          Text(
            'Create a policy to get started',
            style: theme.textTheme.bodySmall?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          )
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
        Gap.h16,
        SegmentedButton<_StartSessionMode>(
          segments: const [
            ButtonSegment(value: _StartSessionMode.duration, label: Text('Duration')),
            ButtonSegment(value: _StartSessionMode.endAt, label: Text('End at')),
          ],
          selected: {_mode},
          onSelectionChanged: (set) {
            if (set.isEmpty) return;
            setState(() => _mode = set.first);
          },
        ),
        Gap.h12,
        if (_mode == _StartSessionMode.duration) ...[
          Text(
            '${_minutes.toInt()} minutes',
            style: theme.textTheme.bodyMedium,
          ),
          Slider(
            value: _minutes,
            min: 5,
            max: 180,
            divisions: 35,
            label: '${_minutes.toInt()} min',
            onChanged: (v) => setState(() => _minutes = v),
          ),
        ] else ...[
          OutlinedButton.icon(
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
            icon: const Icon(Icons.schedule, size: 18),
            label: Text(
              _endTime == null ? 'Pick end time' : 'End at ${_endTime!.format(context)}',
            ),
          ),
          if (_endTime != null && !endAtIsValid) ...[
            Gap.h8,
            Text(
              'End time must be in the future',
              style: theme.textTheme.bodySmall?.copyWith(
                color: scheme.error,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
          if (_endTime != null && endAtIsValid && endAtDurationMinutes != null) ...[
            Gap.h8,
            Text(
              'Duration: $endAtDurationMinutes min',
              style: theme.textTheme.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
          ],
        ],
        Gap.h16,
        Text(
          'Tasks to complete before ending early',
          style: theme.textTheme.labelLarge?.copyWith(
            fontWeight: FontWeight.w600,
            color: scheme.onSurfaceVariant,
          ),
        ),
        Gap.h8,
        SegmentedButton<_SessionPreset>(
          segments: const [
            ButtonSegment(value: _SessionPreset.zero, label: Text('0')),
            ButtonSegment(value: _SessionPreset.one, label: Text('1')),
            ButtonSegment(value: _SessionPreset.two, label: Text('2')),
            ButtonSegment(value: _SessionPreset.three, label: Text('3')),
          ],
          selected: {_preset},
          onSelectionChanged: (set) {
            if (set.isEmpty) return;
            setState(() => _preset = set.first);
          },
        ),
        if (requiredUnlockCount > 0) ...[
          Gap.h4,
          Text(
            'Complete $requiredUnlockCount task${requiredUnlockCount == 1 ? '' : 's'} to unlock early exit',
            style: theme.textTheme.bodySmall?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
        ],
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
                        final ymd = DateFormat('yyyy-MM-dd').format(now);

                        final computedEndsAt = _mode == _StartSessionMode.duration
                            ? now.add(Duration(minutes: _minutes.toInt()))
                            : _endAtForToday(now: now)!;
                        final computedDuration = _mode == _StartSessionMode.duration
                            ? Duration(minutes: _minutes.toInt())
                            : computedEndsAt.difference(now);

                        final ok = await _confirmStart(
                          context: context,
                          policy: policy,
                          endsAt: computedEndsAt,
                          duration: computedDuration,
                          friction: presetFriction,
                          requiredUnlockTaskCount: requiredUnlockCount,
                          requireSelfieToEndEarly: requireSelfieToEndEarly,
                        );
                        if (!ok) return;
                        if (!context.mounted) return;

                        List<String> unlockTaskIds = const [];
                        if (requiredUnlockCount > 0) {
                          final picked = await TaskUnlockPickerSheet.show(
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

                        if (!context.mounted) return;
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
                        if (!context.mounted) return;

                        final session =
                            ref.read(activeFocusSessionProvider).valueOrNull;
                        if (session != null && session.isActive) {
                          final unlockController = ref.read(
                            activeSessionTaskUnlockControllerProvider.notifier,
                          );
                          if (requiredUnlockCount > 0) {
                            if (!context.mounted) return;
                            await unlockController.safeSetForActiveSession(
                              context: context,
                              session: session,
                              ymd: ymd,
                              requiredCount: requiredUnlockCount,
                              requiredTaskIds: unlockTaskIds,
                            );
                          } else {
                            await unlockController.clear();
                          }
                        }

                        if (!context.mounted) return;
                        await ref
                            .read(todayControllerProvider(ymd).notifier)
                            .enableFocusModeAndSelectDefaultTask();
                        if (settings.dumbPhoneAutoStart25mTimebox) {
                          await ref
                              .read(todayTimeboxControllerProvider(ymd).notifier)
                              .queuePendingAutoStart25m();
                        }
                        if (!context.mounted) return;
                        context.go('/today?ymd=$ymd');
                      },
                icon: const Icon(Icons.play_arrow, size: 18),
                label: Text(
                  policies.isEmpty ? 'Create a policy' : 'Start session',
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  static Future<bool> _confirmStart({
    required BuildContext context,
    required FocusPolicy policy,
    required DateTime endsAt,
    required Duration duration,
    required FocusFrictionSettings friction,
    required int requiredUnlockTaskCount,
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

class RemoteStartOnIPhoneCard extends ConsumerStatefulWidget {
  const RemoteStartOnIPhoneCard({super.key});

  @override
  ConsumerState<RemoteStartOnIPhoneCard> createState() =>
      _RemoteStartOnIPhoneCardState();
}

class _RemoteStartOnIPhoneCardState
    extends ConsumerState<RemoteStartOnIPhoneCard> {
  int _minutes = 25;
  String? _policyId;
  bool _sending = false;
  int? _iosDeviceCount;
  Object? _loadError;

  String? _lastCommandId;
  String? _lastCommandStatus; // pending|processing|completed|failed|expired
  String? _lastCommandError;
  String? _lastCommandType; // start|stop
  DateTime? _lastCommandCreatedAt;
  Timer? _commandPollTimer;

  @override
  void initState() {
    super.initState();
    unawaited(_loadDevices());
  }

  @override
  void dispose() {
    _commandPollTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadDevices() async {
    final client = ref.read(supabaseProvider).client;
    final auth = ref.read(authStateProvider).valueOrNull;
    if (client == null || auth == null || !auth.isSignedIn || auth.isDemo) {
      if (!mounted) return;
      setState(() {
        _iosDeviceCount = null;
        _loadError = null;
      });
      return;
    }

    try {
      final rows = await client
          .from('user_devices')
          .select('id')
          .eq('platform', 'ios')
          .eq('push_provider', 'apns');
      if (!mounted) return;
      setState(() {
        _iosDeviceCount = (rows as List).length;
        _loadError = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _iosDeviceCount = null;
        _loadError = e;
      });
    }
  }

  String? _requireUserId(SupabaseClient client) {
    final uid = client.auth.currentUser?.id;
    if (uid == null || uid.isEmpty) return null;
    return uid;
  }

  Future<void> _sendCommand({required String command}) async {
    final client = ref.read(supabaseProvider).client;
    final auth = ref.read(authStateProvider).valueOrNull;
    if (client == null || auth == null || !auth.isSignedIn || auth.isDemo) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              command == 'stop'
                  ? 'Sign in to stop Focus on your iPhone.'
                  : 'Sign in to start Focus on your iPhone.',
            ),
          ),
        );
      }
      return;
    }

    final uid = _requireUserId(client);
    if (uid == null) return;

    setState(() => _sending = true);
    try {
      final insertPayload = <String, Object?>{
        'user_id': uid,
        'command': command,
        'source_platform': 'macos',
        'target_platform': 'ios',
      };

      if (command == 'start') {
        insertPayload['duration_minutes'] = _minutes;
      }

      final effectivePolicyId = _policyId?.trim();
      if (effectivePolicyId != null && effectivePolicyId.isNotEmpty) {
        insertPayload['policy_id'] = effectivePolicyId;
      }

      final inserted = await client
          .from('remote_focus_commands')
          .insert(insertPayload)
          .select('id, status, command, error_message, created_at')
          .single();

      final id = (inserted['id'] as String?)?.trim();
      final status = (inserted['status'] as String?)?.trim();
      final cmd = (inserted['command'] as String?)?.trim();
      final err = inserted['error_message'] as String?;
      final createdAtRaw = inserted['created_at'] as String?;

      if (mounted) {
        setState(() {
          _lastCommandId = id;
          _lastCommandStatus = status;
          _lastCommandType = cmd;
          _lastCommandError = err;
          _lastCommandCreatedAt =
              createdAtRaw != null ? DateTime.tryParse(createdAtRaw)?.toLocal() : null;
        });
      }

      if (id != null && id.isNotEmpty) {
        _startPollingCommandStatus(id);
      }

      await _loadDevices();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              command == 'stop'
                  ? 'Sent “Stop Focus” to iPhone (waiting for device)…'
                  : 'Sent “Start Focus” to iPhone (waiting for device)…',
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to send remote command: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _sendStartCommand() async {
    await _sendCommand(command: 'start');
  }

  Future<void> _sendStopCommand() async {
    await _sendCommand(command: 'stop');
  }

  void _startPollingCommandStatus(String id) {
    _commandPollTimer?.cancel();
    // Poll fairly frequently so the macOS UI feels responsive after sending,
    // but stop automatically once the command is done.
    _commandPollTimer = Timer.periodic(const Duration(seconds: 2), (_) {
      unawaited(_pollCommandStatusOnce(id));
    });
    // Also run once immediately.
    unawaited(_pollCommandStatusOnce(id));
  }

  Future<void> _pollCommandStatusOnce(String id) async {
    if (!mounted) return;
    final client = ref.read(supabaseProvider).client;
    final auth = ref.read(authStateProvider).valueOrNull;
    if (client == null || auth == null || !auth.isSignedIn || auth.isDemo) {
      _commandPollTimer?.cancel();
      return;
    }

    try {
      final row = await client
          .from('remote_focus_commands')
          .select('status, command, error_message, created_at')
          .eq('id', id)
          .maybeSingle();
      if (row == null || !mounted) return;

      final nextStatus = (row['status'] as String?)?.trim();
      final nextCommand = (row['command'] as String?)?.trim();
      final nextError = row['error_message'] as String?;
      final createdAtRaw = row['created_at'] as String?;
      final nextCreatedAt =
          createdAtRaw != null ? DateTime.tryParse(createdAtRaw)?.toLocal() : null;

      final prevStatus = _lastCommandStatus;
      setState(() {
        _lastCommandId = id;
        _lastCommandStatus = nextStatus;
        _lastCommandType = nextCommand;
        _lastCommandError = nextError;
        _lastCommandCreatedAt = nextCreatedAt;
      });

      final done = nextStatus == 'completed' ||
          nextStatus == 'failed' ||
          nextStatus == 'expired';
      if (done) {
        _commandPollTimer?.cancel();

        // Only notify on terminal transitions to avoid snackbar spam.
        if (prevStatus != nextStatus && mounted) {
          final msg = switch (nextStatus) {
            'completed' => nextCommand == 'stop'
                ? 'iPhone stopped Focus.'
                : 'iPhone started Focus.',
            'failed' => 'iPhone failed: ${nextError ?? 'unknown error'}',
            'expired' => 'Remote command expired before iPhone processed it.',
            _ => null,
          };
          if (msg != null) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(msg)),
            );
          }
        }
      }
    } catch (_) {
      // Ignore polling errors; keep polling for a bit.
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final policies = ref.watch(focusPolicyListProvider);
    final policyItems = policies.valueOrNull ?? const <FocusPolicy>[];

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpace.s12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Start on iPhone',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            Gap.h8,
            Text(
              'Sends a silent push to your iPhone so it can start Dumb Phone Mode.\n'
              'Your iPhone must have completed Focus onboarding at least once.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
            Gap.h12,
            Row(
              children: [
                SizedBox(
                  width: 140,
                  child: DropdownButtonFormField<int>(
                    value: _minutes,
                    items: const [
                      DropdownMenuItem(value: 15, child: Text('15 min')),
                      DropdownMenuItem(value: 25, child: Text('25 min')),
                      DropdownMenuItem(value: 45, child: Text('45 min')),
                      DropdownMenuItem(value: 60, child: Text('60 min')),
                    ],
                    onChanged: _sending
                        ? null
                        : (v) => setState(() => _minutes = v ?? 25),
                    decoration: const InputDecoration(labelText: 'Duration'),
                  ),
                ),
                Gap.w12,
                FilledButton.icon(
                  onPressed: _sending ? null : _sendStartCommand,
                  icon: const Icon(Icons.send),
                  label: Text(_sending ? 'Sending…' : 'Start on iPhone'),
                ),
                Gap.w12,
                OutlinedButton.icon(
                  onPressed: _sending ? null : _sendStopCommand,
                  icon: const Icon(Icons.stop_circle_outlined),
                  label: const Text('Stop'),
                ),
              ],
            ),
            Gap.h8,
            DropdownButtonFormField<String?>(
              value: _policyId,
              items: [
                const DropdownMenuItem<String?>(
                  value: null,
                  child: Text('Auto (use iPhone default)'),
                ),
                ...policyItems.map(
                  (p) => DropdownMenuItem<String?>(
                    value: p.id,
                    child: Text(p.name),
                  ),
                ),
              ],
              onChanged: _sending
                  ? null
                  : (v) => setState(() {
                        _policyId = v;
                      }),
              decoration: const InputDecoration(
                labelText: 'Policy (optional)',
                helperText:
                    'Note: policies are currently stored per-device. If the ID does not exist on iPhone, it will fall back to the first policy.',
              ),
            ),
            Gap.h8,
            if (_lastCommandId != null && _lastCommandId!.isNotEmpty)
              Text(
                [
                  'Last: ${_lastCommandType ?? 'command'}',
                  if (_lastCommandStatus != null && _lastCommandStatus!.isNotEmpty)
                    'status=${_lastCommandStatus!}',
                  if (_lastCommandCreatedAt != null)
                    'at ${DateFormat.Hm().format(_lastCommandCreatedAt!)}',
                  if ((_lastCommandError ?? '').trim().isNotEmpty)
                    'error=${_lastCommandError!.trim()}',
                ].join(' • '),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            if (_loadError != null)
              Text(
                'Device check failed: $_loadError',
                style: theme.textTheme.bodySmall?.copyWith(color: scheme.error),
              )
            else if (_iosDeviceCount != null)
              Text(
                _iosDeviceCount == 0
                    ? 'No iOS devices registered yet (open the iPhone app once).'
                    : 'iOS devices registered: $_iosDeviceCount',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

enum _StartSessionMode {
  duration,
  endAt,
}

enum _SessionPreset {
  zero,
  one,
  two,
  three;

  static FocusFrictionSettings frictionFor(_SessionPreset preset) {
    // Use normal friction settings for all presets, with task count being the differentiator.
    return FocusFrictionSettings.defaults;
  }

  static int requiredUnlockTaskCount(_SessionPreset preset) {
    return switch (preset) {
      _SessionPreset.zero => 0,
      _SessionPreset.one => 1,
      _SessionPreset.two => 2,
      _SessionPreset.three => 3,
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
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final today = ref.watch(todayControllerProvider(ymd));
    final byId = <String, TodayTask>{for (final t in today.tasks) t.id: t};

    final remaining = (requiredCount - doneCount).clamp(0, requiredCount);
    final blocked = remaining > 0 || missingCount > 0 || requiredTaskIds.length != requiredCount;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Divider(),
        Gap.h8,
        Row(
          children: [
            Expanded(
              child: Text(
                'Tasks to unlock ($doneCount/$requiredCount)',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            TextButton(
              onPressed: onEdit,
              child: const Text('Edit'),
            ),
          ],
        ),
        if (missingCount > 0) ...[
          Gap.h4,
          Text(
            '$missingCount task${missingCount == 1 ? '' : 's'} missing',
            style: theme.textTheme.bodySmall?.copyWith(
              color: scheme.error,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
        Gap.h8,
        for (final id in requiredTaskIds)
          Builder(
            builder: (context) {
              final t = byId[id];
              if (t == null) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: AppSpace.s4),
                  child: Row(
                    children: [
                      Icon(Icons.error_outline, size: 20, color: scheme.error),
                      Gap.w8,
                      Text(
                        'Missing task',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: scheme.error,
                        ),
                      ),
                    ],
                  ),
                );
              }
              return InkWell(
                onTap: () => onToggleTask(t.id),
                borderRadius: BorderRadius.circular(kRadiusSmall),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    vertical: AppSpace.s8,
                    horizontal: AppSpace.s4,
                  ),
                  child: Row(
                    children: [
                      Icon(
                        t.completed
                            ? Icons.check_circle
                            : Icons.radio_button_unchecked,
                        size: 20,
                        color: t.completed ? scheme.primary : scheme.onSurfaceVariant,
                      ),
                      Gap.w8,
                      Expanded(
                        child: Text(
                          t.title,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            decoration: t.completed ? TextDecoration.lineThrough : null,
                            color: t.completed ? scheme.onSurfaceVariant : null,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        if (blocked) ...[
          Gap.h12,
          FilledButton(
            onPressed: onGoToToday,
            child: const Text('Go to Today'),
          ),
        ],
      ],
    );
  }
}

