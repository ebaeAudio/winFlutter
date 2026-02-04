import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../ui/components/accent_card.dart';
import '../../../ui/spacing.dart';
import '../today_controller.dart';
import '../today_models.dart';
import 'morning_wizard_data.dart';

class MorningLaunchWizardResult {
  const MorningLaunchWizardResult({
    required this.completed,
    required this.carriedForwardCount,
    required this.createdMustWin,
  });

  final bool completed;
  final int carriedForwardCount;
  final bool createdMustWin;
}

Future<MorningLaunchWizardResult?> showMorningLaunchWizard(
  BuildContext context, {
  required String ymd,
  required TodayController todayController,
}) {
  return showModalBottomSheet<MorningLaunchWizardResult>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (ctx) => MorningLaunchWizardSheet(
      ymd: ymd,
      todayController: todayController,
    ),
  );
}

class MorningLaunchWizardSheet extends ConsumerStatefulWidget {
  const MorningLaunchWizardSheet({
    super.key,
    required this.ymd,
    required this.todayController,
  });

  final String ymd;
  final TodayController todayController;

  @override
  ConsumerState<MorningLaunchWizardSheet> createState() =>
      _MorningLaunchWizardSheetState();
}

class _MorningLaunchWizardSheetState
    extends ConsumerState<MorningLaunchWizardSheet> {
  late final PageController _pageController;
  int _step = 0;

  YesterdayRecap? _recap;
  bool _loadingRecap = true;

  final _selectedCarryIds = <String>{};
  bool _carryInFlight = false;
  int _carriedForwardCount = 0;

  final TextEditingController _oneThingController = TextEditingController();
  bool _creating = false;
  bool _createdMustWin = false;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    unawaited(_loadRecap());
  }

  @override
  void dispose() {
    _pageController.dispose();
    _oneThingController.dispose();
    super.dispose();
  }

  Future<void> _loadRecap() async {
    try {
      final recap = await widget.todayController.getYesterdayRecap();
      if (!mounted) return;
      setState(() {
        _recap = recap;
        _loadingRecap = false;
        _selectedCarryIds
          ..clear()
          ..addAll(recap.incompleteMustWins.map((t) => t.id));
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _recap = null;
        _loadingRecap = false;
      });
    }
  }

  Future<void> _goTo(int index) async {
    if (!mounted) return;
    setState(() => _step = index);
    await _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOut,
    );
  }

  Future<void> _carryForwardSelected() async {
    if (_carryInFlight) return;
    setState(() => _carryInFlight = true);
    try {
      final count =
          await widget.todayController.rolloverYesterdayTasksById(_selectedCarryIds);
      if (!mounted) return;
      setState(() {
        _carriedForwardCount = count;
      });
      if (count > 0) {
        // Gentle confirmation; avoids "shame" framing.
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Brought $count Must‑Win${count == 1 ? '' : 's'} to today.')),
          );
        }
      }
      await _goTo(1);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not bring tasks right now.')),
      );
    } finally {
      if (mounted) setState(() => _carryInFlight = false);
    }
  }

  Future<void> _createMustWinAndFinish() async {
    if (_creating) return;
    final text = _oneThingController.text.trim();
    setState(() => _creating = true);
    try {
      if (text.isNotEmpty) {
        final ok = await widget.todayController.addTask(
          title: text,
          type: TodayTaskType.mustWin,
        );
        if (!mounted) return;
        _createdMustWin = ok;
        if (!ok) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Could not add that Must‑Win.')),
          );
          setState(() => _creating = false);
          return;
        }
      }

      if (!mounted) return;
      Navigator.of(context).pop(
        MorningLaunchWizardResult(
          completed: true,
          carriedForwardCount: _carriedForwardCount,
          createdMustWin: text.isNotEmpty,
        ),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not save right now.')),
      );
      setState(() => _creating = false);
    }
  }

  void _dismiss({required bool completed}) {
    Navigator.of(context).pop(
      MorningLaunchWizardResult(
        completed: completed,
        carriedForwardCount: _carriedForwardCount,
        createdMustWin: _createdMustWin,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final recap = _recap;

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: AppSpace.s16,
          right: AppSpace.s16,
          bottom: MediaQuery.viewInsetsOf(context).bottom + AppSpace.s16,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _WizardProgress(currentStep: _step, totalSteps: 2),
            SizedBox(
              height: 420,
              child: PageView(
                controller: _pageController,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  _StepYesterday(
                    loading: _loadingRecap,
                    recap: recap,
                    selectedCarryIds: _selectedCarryIds,
                    onToggleCarry: (id, selected) {
                      setState(() {
                        if (selected) {
                          _selectedCarryIds.add(id);
                        } else {
                          _selectedCarryIds.remove(id);
                        }
                      });
                    },
                  ),
                  _StepOneThing(controller: _oneThingController),
                ],
              ),
            ),
            Gap.h12,
            Row(
              children: [
                TextButton(
                  onPressed: () => _dismiss(completed: false),
                  child: const Text('Skip'),
                ),
                const Spacer(),
                if (_step == 0) ...[
                  FilledButton(
                    onPressed: _carryInFlight
                        ? null
                        : () async {
                            // If there’s nothing to carry, go straight to the ONE thing.
                            if ((_selectedCarryIds.isEmpty) &&
                                (recap?.incompleteMustWins.isNotEmpty ?? false)) {
                              await _goTo(1);
                              return;
                            }
                            if (recap?.incompleteMustWins.isEmpty ?? true) {
                              await _goTo(1);
                              return;
                            }
                            await _carryForwardSelected();
                          },
                    child: _carryInFlight
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text(
                            (recap?.incompleteMustWins.isNotEmpty ?? false)
                                ? 'Continue'
                                : 'Next',
                          ),
                  ),
                ] else ...[
                  FilledButton(
                    onPressed: _creating ? null : _createMustWinAndFinish,
                    child: _creating
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Start day'),
                  ),
                ],
              ],
            ),
            Gap.h4,
            Text(
              '2‑Minute setup. Small commitments beat perfect plans.',
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _WizardProgress extends StatelessWidget {
  const _WizardProgress({
    required this.currentStep,
    required this.totalSteps,
  });

  final int currentStep;
  final int totalSteps;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpace.s8),
      child: Row(
        children: [
          Text(
            'Morning setup',
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w700,
              color: theme.colorScheme.primary,
            ),
          ),
          const Spacer(),
          Text(
            '${currentStep + 1} of $totalSteps',
            style: theme.textTheme.bodySmall
                ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}

class _StepYesterday extends StatelessWidget {
  const _StepYesterday({
    required this.loading,
    required this.recap,
    required this.selectedCarryIds,
    required this.onToggleCarry,
  });

  final bool loading;
  final YesterdayRecap? recap;
  final Set<String> selectedCarryIds;
  final void Function(String taskId, bool selected) onToggleCarry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    if (loading) {
      return const Center(child: CircularProgressIndicator());
    }

    final r = recap ??
        const YesterdayRecap(
          percent: 0,
          label: 'Fresh start',
          mustWinTotal: 0,
          mustWinDone: 0,
          niceToDoTotal: 0,
          niceToDoDone: 0,
          habitsTotal: 0,
          habitsDone: 0,
          incompleteMustWins: [],
        );

    return ListView(
      padding: EdgeInsets.zero,
      children: [
        AccentCard(
          accentColor: scheme.primary,
          child: Padding(
            padding: const EdgeInsets.all(AppSpace.s16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.wb_sunny_outlined,
                        color: scheme.primary, size: 28,),
                    Gap.w12,
                    Expanded(
                      child: Text(
                        'Good morning',
                        style: theme.textTheme.titleLarge
                            ?.copyWith(fontWeight: FontWeight.w800),
                      ),
                    ),
                  ],
                ),
                Gap.h12,
                Text(
                  'Yesterday was ${r.percent}% (${r.label}).',
                  style: theme.textTheme.bodyMedium,
                ),
                Gap.h8,
                Text(
                  'That’s just context — not a grade.',
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: scheme.onSurfaceVariant),
                ),
                Gap.h16,
                Wrap(
                  spacing: AppSpace.s8,
                  runSpacing: AppSpace.s8,
                  children: [
                    _StatChip(
                      label: 'Must‑Wins',
                      value: '${r.mustWinDone}/${r.mustWinTotal}',
                    ),
                    _StatChip(
                      label: 'Nice‑to‑Dos',
                      value: '${r.niceToDoDone}/${r.niceToDoTotal}',
                    ),
                    _StatChip(
                      label: 'Habits',
                      value: '${r.habitsDone}/${r.habitsTotal}',
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        Gap.h12,
        if (r.incompleteMustWins.isEmpty)
          AccentCard(
            accentColor: scheme.tertiary,
            child: Padding(
              padding: const EdgeInsets.all(AppSpace.s16),
              child: Text(
                'No unfinished Must‑Wins from yesterday. Let’s pick today’s ONE thing.',
                style: theme.textTheme.bodyMedium,
              ),
            ),
          )
        else
          AccentCard(
            accentColor: scheme.tertiary,
            child: Padding(
              padding: const EdgeInsets.all(AppSpace.s16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Pick up where you left off?',
                    style: theme.textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.w700),
                  ),
                  Gap.h8,
                  Text(
                    'Select what you want to carry forward (you can also start fresh).',
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: scheme.onSurfaceVariant),
                  ),
                  Gap.h12,
                  for (final t in r.incompleteMustWins)
                    CheckboxListTile(
                      value: selectedCarryIds.contains(t.id),
                      onChanged: (v) =>
                          onToggleCarry(t.id, (v ?? false) == true),
                      contentPadding: EdgeInsets.zero,
                      dense: false,
                      controlAffinity: ListTileControlAffinity.leading,
                      title: Text(t.title),
                    ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class _StepOneThing extends StatelessWidget {
  const _StepOneThing({required this.controller});

  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return ListView(
      padding: EdgeInsets.zero,
      children: [
        AccentCard(
          accentColor: scheme.secondary,
          child: Padding(
            padding: const EdgeInsets.all(AppSpace.s16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'What’s the ONE thing that would make today a win?',
                  style: theme.textTheme.titleLarge
                      ?.copyWith(fontWeight: FontWeight.w800),
                ),
                Gap.h12,
                TextField(
                  controller: controller,
                  autofocus: true,
                  textInputAction: TextInputAction.done,
                  minLines: 1,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: 'Today’s Must‑Win',
                    hintText: 'Ex: Send the proposal',
                  ),
                ),
                Gap.h12,
                Text(
                  'Make it small enough to start.',
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: scheme.onSurfaceVariant),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _StatChip extends StatelessWidget {
  const _StatChip({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpace.s12, vertical: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        color: scheme.surfaceContainerHighest.withOpacity(0.35),
        border: Border.all(color: theme.dividerColor),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: theme.textTheme.bodySmall
                ?.copyWith(color: scheme.onSurfaceVariant),
          ),
          Gap.w8,
          Text(
            value,
            style: theme.textTheme.bodySmall
                ?.copyWith(fontWeight: FontWeight.w800),
          ),
        ],
      ),
    );
  }
}

