import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../domain/focus/focus_session.dart';
import '../../../domain/focus/focus_policy.dart';
import '../../../ui/app_scaffold.dart';
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
          onPressed: () => context.go('/home/focus/history'),
          icon: const Icon(Icons.history),
        ),
        IconButton(
          tooltip: 'Policies',
          onPressed: () => context.go('/home/focus/policies'),
          icon: const Icon(Icons.tune),
        ),
      ],
      children: [
        active.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Text('Session error: $e'),
            ),
          ),
          data: (session) => _ActiveSessionCard(session: session),
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

class _ActiveSessionCard extends ConsumerWidget {
  const _ActiveSessionCard({required this.session});

  final FocusSession? session;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
    final remaining = session!.plannedEndAt.difference(now);
    final mmss = _formatRemaining(remaining);

    // Ensure we auto-complete once the timer elapses.
    ref.read(activeFocusSessionProvider.notifier).reconcileIfExpired();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Session active', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 6),
            Text('Ends at: ${DateFormat.Hm().format(session!.plannedEndAt)}'),
            Text('Remaining: $mmss'),
            const SizedBox(height: 12),
            HoldToConfirmButton(
              holdDuration: const Duration(seconds: 3),
              label: 'Hold to end session early',
              icon: Icons.stop_circle,
              onConfirmed: () async {
                // NOTE: early-exit delay/friction is applied by the platform blocking UI.
                // Here we apply a small delay as a baseline fallback.
                await Future<void>.delayed(const Duration(seconds: 2));
                await ref
                    .read(activeFocusSessionProvider.notifier)
                    .endSession(reason: FocusSessionEndReason.userEarlyExit);
              },
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

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Start a session', style: Theme.of(context).textTheme.titleMedium),
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
              onPressed: policies.isEmpty || _policyId == null
                  ? () => context.go('/home/focus/policies')
                  : () async {
                      await ref.read(activeFocusSessionProvider.notifier).startSession(
                            policyId: _policyId!,
                            duration: Duration(minutes: _minutes.toInt()),
                          );
                    },
              icon: const Icon(Icons.play_arrow),
              label: Text(policies.isEmpty ? 'Create a policy' : 'Start session'),
            ),
          ],
        ),
      ),
    );
  }
}


