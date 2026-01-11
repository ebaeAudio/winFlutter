import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:speech_to_text/speech_to_text.dart';

import '../../app/env.dart';
import '../../app/supabase.dart';
import '../../assistant/assistant_client.dart';
import '../../assistant/assistant_executor.dart';
import '../../data/trackers/tracker_models.dart';
import '../../ui/app_scaffold.dart';
import '../../ui/components/empty_state_card.dart';
import '../../ui/components/section_header.dart';
import '../../ui/components/task_details_sheet.dart';
import '../../ui/spacing.dart';
import 'today_controller.dart';
import 'today_models.dart';
import 'today_trackers_controller.dart';

class TodayScreen extends ConsumerStatefulWidget {
  const TodayScreen({super.key});

  @override
  ConsumerState<TodayScreen> createState() => _TodayScreenState();
}

class _TodayScreenState extends ConsumerState<TodayScreen> {
  DateTime _date = _dateOnly(DateTime.now());
  String? _loadedReflectionForYmd;
  final Set<String> _expandedTaskIds = {};
  final _quickAddController = TextEditingController();
  final _quickAddFocus = FocusNode();
  var _quickAddType = TodayTaskType.mustWin;
  final _reflectionController = TextEditingController();
  final _reflectionFocus = FocusNode();
  final _habitAddController = TextEditingController();
  final _assistantController = TextEditingController();
  bool _assistantLoading = false;
  String? _assistantSay;

  final _assistantRingKey = GlobalKey();
  final SpeechToText _speech = SpeechToText();
  bool _speechReady = false;
  bool _assistantListening = false;
  String? _assistantSpeechError;

  static DateTime _dateOnly(DateTime dt) => DateTime(dt.year, dt.month, dt.day);
  static bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  @override
  void initState() {
    super.initState();
    _reflectionFocus.addListener(() {
      if (_reflectionFocus.hasFocus) return;
      final ymd = DateFormat('yyyy-MM-dd').format(_date);
      final today = ref.read(todayControllerProvider(ymd));
      final draft = _reflectionController.text;
      if (draft != today.reflection) {
        ref.read(todayControllerProvider(ymd).notifier).setReflection(draft);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Reflection saved')),
          );
        }
      }
    });
  }

  @override
  void dispose() {
    _quickAddController.dispose();
    _quickAddFocus.dispose();
    _reflectionController.dispose();
    _reflectionFocus.dispose();
    _habitAddController.dispose();
    _assistantController.dispose();
    try {
      _speech.cancel();
    } catch (_) {
      // Ignore.
    }
    super.dispose();
  }

  Future<bool> _ensureSpeechReady() async {
    if (_speechReady) return true;
    try {
      final ok = await _speech.initialize(
        onError: (e) {
          if (!mounted) return;
          setState(() => _assistantSpeechError = e.errorMsg);
        },
      );
      final hasPerm = await _speech.hasPermission;
      if (!mounted) return false;
      setState(() {
        _speechReady = ok;
        if (ok) {
          _assistantSpeechError = null;
        } else if (hasPerm == false) {
          _assistantSpeechError =
              'Microphone / Speech permission denied. Enable it in Settings and try again.';
        } else if (_speech.isAvailable == false) {
          _assistantSpeechError =
              'Speech recognition is not available on this device.'
              '${(defaultTargetPlatform == TargetPlatform.iOS || defaultTargetPlatform == TargetPlatform.android) ? ' (Tip: simulators sometimes don’t support this; try a physical device.)' : ''}';
        } else {
          _assistantSpeechError = _assistantSpeechError ?? 'Speech unavailable';
        }
      });
      return ok;
    } catch (_) {
      if (!mounted) return false;
      setState(() {
        _assistantSpeechError = kIsWeb
            ? 'Speech unavailable in this environment.'
            : 'Speech unavailable';
      });
      return false;
    }
  }

  void _setAssistantTranscript(String text) {
    _assistantController.value = TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }

  Future<void> _startAssistantListening() async {
    if (_assistantLoading) return;
    if (_assistantListening) return;

    final ok = await _ensureSpeechReady();
    if (!ok) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_assistantSpeechError ?? 'Speech unavailable')),
      );
      return;
    }

    final hasPerm = await _speech.hasPermission;
    if (hasPerm == false) {
      if (!mounted) return;
      setState(() {
        _assistantSpeechError =
            'Microphone / Speech permission denied. Enable it in Settings and try again.';
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_assistantSpeechError!)),
      );
      return;
    }

    HapticFeedback.selectionClick();
    setState(() {
      _assistantListening = true;
      _assistantSpeechError = null;
    });

    await _speech.listen(
      listenOptions: SpeechListenOptions(
        listenMode: ListenMode.confirmation,
        partialResults: true,
      ),
      onResult: (result) {
        final words = result.recognizedWords.trim();
        if (words.isEmpty) return;
        _setAssistantTranscript(words);
      },
    );
  }

  Future<void> _stopAssistantListening() async {
    if (!_assistantListening) return;
    try {
      await _speech.stop();
    } catch (_) {
      // Ignore stop errors; we'll still reset UI state.
    }
    if (!mounted) return;
    HapticFeedback.selectionClick();
    setState(() => _assistantListening = false);
  }

  Size? _assistantRingSize() {
    final ctx = _assistantRingKey.currentContext;
    final renderObject = ctx?.findRenderObject();
    if (renderObject is! RenderBox) return null;
    return renderObject.size;
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked == null) return;
    setState(() => _date = _dateOnly(picked));
  }

  @override
  Widget build(BuildContext context) {
    final now = _dateOnly(DateTime.now());
    final ymd = DateFormat('yyyy-MM-dd').format(_date);
    final friendly = DateFormat('EEE, MMM d').format(_date);
    final isToday = _isSameDay(_date, now);

    final today = ref.watch(todayControllerProvider(ymd));
    final controller = ref.read(todayControllerProvider(ymd).notifier);
    final trackersData = ref.watch(todayTrackersControllerProvider(ymd));
    final trackersController =
        ref.read(todayTrackersControllerProvider(ymd).notifier);
    final env = ref.watch(envProvider);
    final supabaseState = ref.watch(supabaseProvider);
    final assistantClient = AssistantClient(
      supabase: supabaseState.client,
      enableRemote: !env.demoMode && supabaseState.isInitialized,
    );

    // Keep reflection controller in sync when switching dates.
    if (_loadedReflectionForYmd != ymd) {
      _loadedReflectionForYmd = ymd;
      _reflectionController.text = today.reflection;
      _expandedTaskIds.clear();
    }

    final mustWins =
        today.tasks.where((t) => t.type == TodayTaskType.mustWin).toList();
    final niceTodos =
        today.tasks.where((t) => t.type == TodayTaskType.niceToDo).toList();
    final habits = today.habits;
    final habitDoneCount = habits.where((h) => h.completed).length;

    TodayTask? focusTask;
    if (today.focusTaskId != null) {
      for (final t in today.tasks) {
        if (t.id == today.focusTaskId) {
          focusTask = t;
          break;
        }
      }
    }
    if (focusTask == null) {
      for (final t in mustWins) {
        if (!t.completed) {
          focusTask = t;
          break;
        }
      }
    }

    return AppScaffold(
      title: 'Today',
      actions: [
        IconButton(
          tooltip: 'All tasks',
          onPressed: () => context.go('/tasks'),
          icon: const Icon(Icons.view_list),
        ),
        IconButton(
          tooltip: 'Pick date',
          onPressed: _pickDate,
          icon: const Icon(Icons.calendar_month),
        ),
      ],
      children: [
        const SectionHeader(title: 'Date'),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(AppSpace.s16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(friendly, style: Theme.of(context).textTheme.titleLarge),
                Gap.h4,
                Text(ymd, style: Theme.of(context).textTheme.bodySmall),
                Gap.h16,
                Wrap(
                  spacing: AppSpace.s8,
                  runSpacing: AppSpace.s8,
                  children: [
                    OutlinedButton.icon(
                      onPressed: () => setState(() =>
                          _date = _date.subtract(const Duration(days: 1))),
                      icon: const Icon(Icons.chevron_left),
                      label: const Text('Prev'),
                    ),
                    OutlinedButton.icon(
                      onPressed: () => setState(
                          () => _date = _date.add(const Duration(days: 1))),
                      icon: const Icon(Icons.chevron_right),
                      label: const Text('Next'),
                    ),
                    if (!isToday)
                      FilledButton.icon(
                        onPressed: () => setState(() => _date = now),
                        icon: const Icon(Icons.today),
                        label: const Text('Go to Today'),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
        Gap.h16,
        const SectionHeader(title: 'Assistant'),
        Stack(
          key: _assistantRingKey,
          children: [
            // Outline ring + content.
            Container(
              decoration: ShapeDecoration(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                  side: BorderSide(
                    width: 2.5,
                    color: _assistantListening
                        ? Theme.of(context).colorScheme.primary
                        : Theme.of(context).dividerColor.withOpacity(0.9),
                  ),
                ),
              ),
              child: Card(
                margin: EdgeInsets.zero,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(AppSpace.s16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _assistantController,
                              textInputAction: TextInputAction.send,
                              onSubmitted: (_) => _runAssistant(
                                assistantClient: assistantClient,
                                baseDate: _date,
                              ),
                              decoration: InputDecoration(
                                labelText: 'Tell me what to do',
                                hintText:
                                    'Ex: tomorrow add must win task: renew passport',
                                helperText: _assistantListening
                                    ? 'Listening… keep holding the outline'
                                    : 'Hold the outline to talk',
                              ),
                              enabled: !_assistantLoading,
                            ),
                          ),
                          Gap.w8,
                          Container(
                            padding: const EdgeInsets.all(AppSpace.s8),
                            decoration: BoxDecoration(
                              color: _assistantListening
                                  ? Theme.of(context)
                                      .colorScheme
                                      .primaryContainer
                                      .withOpacity(0.65)
                                  : Theme.of(context)
                                      .colorScheme
                                      .surfaceContainerHighest
                                      .withOpacity(0.55),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(
                              _assistantListening ? Icons.mic : Icons.mic_none,
                              size: 18,
                            ),
                          ),
                        ],
                      ),
                      Gap.h12,
                      FilledButton.icon(
                        onPressed: _assistantLoading
                            ? null
                            : () => _runAssistant(
                                  assistantClient: assistantClient,
                                  baseDate: _date,
                                ),
                        icon: _assistantLoading
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.send),
                        label: Text(_assistantLoading ? 'Working…' : 'Run'),
                      ),
                      if ((_assistantSay ?? '').trim().isNotEmpty) ...[
                        Gap.h12,
                        Text(
                          _assistantSay!,
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ],
                      if ((_assistantSpeechError ?? '').trim().isNotEmpty) ...[
                        Gap.h8,
                        Text(
                          _assistantSpeechError!,
                          style: Theme.of(context)
                              .textTheme
                              .bodySmall
                              ?.copyWith(
                                  color: Theme.of(context).colorScheme.error),
                        ),
                      ],
                      Gap.h8,
                      Text(
                        'Tip: “note: …”, “complete task …”, “add habit …”',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // Press-and-hold handler: only starts if the long-press begins on the outline ring.
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.translucent,
                onLongPressStart: (details) async {
                  // Require the long-press to start on the outline ring.
                  const ring = 14.0;
                  final size = _assistantRingSize();
                  if (size != null) {
                    final pos = details.localPosition;
                    final inRing = pos.dx <= ring ||
                        pos.dy <= ring ||
                        pos.dx >= (size.width - ring) ||
                        pos.dy >= (size.height - ring);
                    if (!inRing) {
                      if (!mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                            content: Text('Hold the outline to talk')),
                      );
                      return;
                    }
                  }

                  await _startAssistantListening();
                },
                onLongPressEnd: (_) => _stopAssistantListening(),
                onLongPressCancel: _stopAssistantListening,
              ),
            ),
          ],
        ),
        Gap.h16,
        SectionHeader(
          title: 'Focus',
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(today.focusModeEnabled ? 'On' : 'Off'),
              Gap.w8,
              Switch.adaptive(
                value: today.focusModeEnabled,
                onChanged: (v) => controller.setFocusModeEnabled(v),
              ),
            ],
          ),
        ),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(AppSpace.s16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'One thing now',
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontWeight: FontWeight.w800),
                ),
                Gap.h8,
                Text(
                  today.focusModeEnabled
                      ? 'Hide the noise. Just do the next tiny step.'
                      : 'Turn this on when you’re feeling stuck or scattered.',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                Gap.h12,
                if (!today.focusModeEnabled)
                  Wrap(
                    spacing: AppSpace.s8,
                    runSpacing: AppSpace.s8,
                    children: [
                      FilledButton.icon(
                        onPressed: mustWins.isEmpty
                            ? null
                            : () {
                                controller.setFocusModeEnabled(true);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                      content: Text('Focus mode on')),
                                );
                              },
                        icon: const Icon(Icons.center_focus_strong),
                        label: const Text('Start focus'),
                      ),
                      OutlinedButton.icon(
                        onPressed: () => _scrollToQuickAdd(context),
                        icon: const Icon(Icons.add),
                        label: const Text('Add a Must‑Win'),
                      ),
                    ],
                  )
                else ...[
                  if (focusTask == null)
                    Text(
                      mustWins.isEmpty
                          ? 'Add a Must‑Win, then focus on it.'
                          : 'No Must‑Wins left. Nice work.',
                      style: Theme.of(context)
                          .textTheme
                          .titleSmall
                          ?.copyWith(fontWeight: FontWeight.w700),
                    )
                  else ...[
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(AppSpace.s12),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        color: Theme.of(context)
                            .colorScheme
                            .primaryContainer
                            .withOpacity(0.35),
                        border: Border.all(
                            color: Theme.of(context)
                                .dividerColor
                                .withOpacity(0.4)),
                      ),
                      child: Text(
                        focusTask.title,
                        style: Theme.of(context)
                            .textTheme
                            .titleLarge
                            ?.copyWith(fontWeight: FontWeight.w900),
                      ),
                    ),
                    Gap.h12,
                    Wrap(
                      spacing: AppSpace.s8,
                      runSpacing: AppSpace.s8,
                      children: [
                        FilledButton.icon(
                          onPressed: () async {
                            await controller.toggleTaskCompleted(focusTask!.id);
                            if (!context.mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Marked done')),
                            );
                          },
                          icon: const Icon(Icons.check),
                          label: const Text('Done'),
                        ),
                        OutlinedButton.icon(
                          onPressed: mustWins.isEmpty
                              ? null
                              : () async {
                                  final picked =
                                      await _pickFocusTask(context, mustWins);
                                  if (!context.mounted) return;
                                  if (picked == null) return;
                                  await controller.setFocusTaskId(picked);
                                },
                          icon: const Icon(Icons.swap_horiz),
                          label: const Text('Pick different'),
                        ),
                        OutlinedButton.icon(
                          onPressed: () async {
                            await controller.setFocusTaskId(null);
                            await controller.setFocusModeEnabled(false);
                          },
                          icon: const Icon(Icons.close),
                          label: const Text('Exit'),
                        ),
                      ],
                    ),
                  ],
                ],
              ],
            ),
          ),
        ),
        Gap.h16,
        const SectionHeader(title: 'Quick add'),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(AppSpace.s16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: _quickAddController,
                  focusNode: _quickAddFocus,
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => _submitQuickAdd(controller),
                  decoration: const InputDecoration(
                    labelText: 'What’s the task?',
                    hintText: 'Ex: Send the email',
                  ),
                ),
                Gap.h12,
                SegmentedButton<TodayTaskType>(
                  segments: const [
                    ButtonSegment(
                        value: TodayTaskType.mustWin, label: Text('Must‑Win')),
                    ButtonSegment(
                        value: TodayTaskType.niceToDo,
                        label: Text('Nice‑to‑Do')),
                  ],
                  selected: {_quickAddType},
                  onSelectionChanged: (s) =>
                      setState(() => _quickAddType = s.first),
                ),
                Gap.h12,
                FilledButton.icon(
                  onPressed: () => _submitQuickAdd(controller),
                  icon: const Icon(Icons.add),
                  label: const Text('Add'),
                ),
              ],
            ),
          ),
        ),
        Gap.h16,
        SectionHeader(
          title: 'Habits',
          trailing: Text('$habitDoneCount/${habits.length}'),
        ),
        if (habits.isEmpty)
          EmptyStateCard(
            icon: Icons.repeat,
            title: 'Add a habit to track',
            description:
                'Habits are recurring. You can mark them complete for the selected day.',
            ctaLabel: 'Add a habit',
            onCtaPressed: () {
              _habitAddController.clear();
              showDialog<void>(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('New habit'),
                  content: TextField(
                    controller: _habitAddController,
                    autofocus: true,
                    decoration: const InputDecoration(labelText: 'Habit name'),
                    textInputAction: TextInputAction.done,
                    onSubmitted: (_) => Navigator.of(context).pop(),
                  ),
                  actions: [
                    TextButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: const Text('Cancel')),
                    FilledButton(
                        onPressed: () async {
                          final ok = await controller.addHabit(
                              name: _habitAddController.text);
                          if (!context.mounted) return;
                          Navigator.of(context).pop();
                          if (ok) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Habit added')),
                            );
                          }
                        },
                        child: const Text('Add')),
                  ],
                ),
              );
            },
          )
        else
          Card(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpace.s8),
              child: Column(
                children: [
                  for (final h in habits)
                    CheckboxListTile(
                      value: h.completed,
                      onChanged: (v) => controller.setHabitCompleted(
                        habitId: h.id,
                        completed: v == true,
                      ),
                      title: Text(h.name),
                    ),
                  Padding(
                    padding: const EdgeInsets.all(AppSpace.s12),
                    child: Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _habitAddController,
                            decoration: const InputDecoration(
                              labelText: 'Add habit',
                              hintText: 'Ex: Walk 20 minutes',
                            ),
                            textInputAction: TextInputAction.done,
                            onSubmitted: (_) async {
                              final ok = await controller.addHabit(
                                  name: _habitAddController.text);
                              if (!ok) return;
                              _habitAddController.clear();
                              if (!context.mounted) return;
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Habit added')),
                              );
                            },
                          ),
                        ),
                        Gap.w8,
                        FilledButton(
                          onPressed: () async {
                            final ok = await controller.addHabit(
                                name: _habitAddController.text);
                            if (!ok) return;
                            _habitAddController.clear();
                            if (!context.mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Habit added')),
                            );
                          },
                          child: const Text('Add'),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        Gap.h16,
        const SectionHeader(title: 'Trackers'),
        if (trackersData.isLoading)
          const Center(child: CircularProgressIndicator())
        else if (trackersData.trackers.isEmpty)
          EmptyStateCard(
            icon: Icons.emoji_objects_outlined,
            title: 'Add a tracker',
            description:
                'Create a custom tracker (3 items) and tap here to tally quickly.',
            ctaLabel: 'Add tracker',
            onCtaPressed: () => context.go('/settings/trackers'),
          )
        else
          Column(
            children: [
              if ((trackersData.error ?? '').trim().isNotEmpty) ...[
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpace.s12),
                    child: Text('Tracker error: ${trackersData.error}'),
                  ),
                ),
                Gap.h12,
              ],
              for (final t in trackersData.trackers) ...[
                Card(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: AppSpace.s8),
                    child: Column(
                      children: [
                        ListTile(
                          title: Text(
                            t.tracker.name,
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.copyWith(fontWeight: FontWeight.w800),
                          ),
                          subtitle:
                              const Text('Tap to add. Long-press to undo.'),
                        ),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(
                              AppSpace.s12, 0, AppSpace.s12, AppSpace.s12),
                          child: LayoutBuilder(
                            builder: (context, constraints) {
                              final isNarrow = constraints.maxWidth < 420;
                              final tileWidth = isNarrow
                                  ? constraints.maxWidth
                                  : ((constraints.maxWidth - AppSpace.s12) / 2);
                              return Wrap(
                                spacing: AppSpace.s12,
                                runSpacing: AppSpace.s12,
                                children: [
                                  for (final it in t.items)
                                    SizedBox(
                                      width: tileWidth,
                                      child: _TrackerTallyTile(
                                        emoji: it.item.emoji,
                                        title: it.item.description,
                                        subtitle: it.item.hasTarget
                                            ? _targetLabel(
                                                it.item.targetCadence,
                                              )
                                            : null,
                                        count: it.todayCount,
                                        progress: it.item.hasTarget
                                            ? '${it.progressCount}/${it.item.targetValue}'
                                            : null,
                                        onIncrement: () =>
                                            trackersController.increment(
                                          trackerId: t.tracker.id,
                                          itemKey: it.item.key,
                                        ),
                                        onDecrement: () =>
                                            trackersController.decrement(
                                          trackerId: t.tracker.id,
                                          itemKey: it.item.key,
                                        ),
                                      ),
                                    ),
                                ],
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Gap.h12,
              ],
            ],
          ),
        Gap.h16,
        SectionHeader(
          title: 'Must‑Wins',
          trailing: Text(
              '${mustWins.where((t) => t.completed).length}/${mustWins.length}'),
        ),
        if (mustWins.isEmpty)
          EmptyStateCard(
            icon: Icons.flag_outlined,
            title: 'Pick 1–3 Must‑Wins',
            description:
                'Must‑Wins are the few things that make today a win. Keep it small.',
            ctaLabel: 'Add a Must‑Win',
            onCtaPressed: () {
              setState(() => _quickAddType = TodayTaskType.mustWin);
              _scrollToQuickAdd(context);
            },
          )
        else
          _TasksCard(
            tasks: mustWins,
            onToggle: controller.toggleTaskCompleted,
            onEdit: (id, current) => _editTask(context,
                id: id, current: current, onSave: controller.updateTaskTitle),
            onDelete: (id) => controller.deleteTask(id),
            onMove: (id) => controller.moveTaskType(id, TodayTaskType.niceToDo),
            expandedTaskIds: _expandedTaskIds,
            onToggleExpanded: _toggleExpandedTask,
            onEditDetails: (t) => _openTaskDetailsSheet(
              context,
              controller: controller,
              task: t,
            ),
          ),
        Gap.h16,
        SectionHeader(
          title: 'Nice‑to‑Do',
          trailing: Text(
              '${niceTodos.where((t) => t.completed).length}/${niceTodos.length}'),
        ),
        if (niceTodos.isEmpty)
          EmptyStateCard(
            icon: Icons.playlist_add_check_circle_outlined,
            title: 'Optional wins live here',
            description:
                'If you have extra energy, add a few “nice-to-dos”. No guilt if they wait.',
            ctaLabel: 'Add a Nice‑to‑Do',
            onCtaPressed: () {
              setState(() => _quickAddType = TodayTaskType.niceToDo);
              _scrollToQuickAdd(context);
            },
          )
        else
          _TasksCard(
            tasks: niceTodos,
            onToggle: controller.toggleTaskCompleted,
            onEdit: (id, current) => _editTask(context,
                id: id, current: current, onSave: controller.updateTaskTitle),
            onDelete: (id) => controller.deleteTask(id),
            onMove: (id) => controller.moveTaskType(id, TodayTaskType.mustWin),
            expandedTaskIds: _expandedTaskIds,
            onToggleExpanded: _toggleExpandedTask,
            onEditDetails: (t) => _openTaskDetailsSheet(
              context,
              controller: controller,
              task: t,
            ),
          ),
        Gap.h16,
        const SectionHeader(title: 'Reflection'),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(AppSpace.s16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: _reflectionController,
                  focusNode: _reflectionFocus,
                  maxLines: 6,
                  decoration: const InputDecoration(
                    labelText: 'Brain dump (optional)',
                    hintText:
                        'What happened today? What’s one small improvement for tomorrow?',
                  ),
                ),
                Gap.h8,
                Text(
                  'Auto-saves when you leave the field.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  static String _targetLabel(TargetCadence? cadence) {
    return switch (cadence) {
      TargetCadence.weekly => 'Weekly target',
      TargetCadence.yearly => 'Yearly target',
      _ => 'Daily target',
    };
  }

  Future<void> _runAssistant({
    required AssistantClient assistantClient,
    required DateTime baseDate,
  }) async {
    if (_assistantListening) {
      await _stopAssistantListening();
    }
    final transcript = _assistantController.text.trim();
    if (transcript.isEmpty) return;
    if (_assistantLoading) return;

    setState(() {
      _assistantLoading = true;
      _assistantSay = null;
    });

    final baseYmd = DateFormat('yyyy-MM-dd').format(baseDate);

    try {
      final translation = await assistantClient.translate(
        transcript: transcript,
        baseDateYmd: baseYmd,
      );

      if (!mounted) return;
      setState(() => _assistantSay = translation.say);

      const executor = AssistantExecutor();
      final result = await executor.execute(
        context: context,
        ref: ref,
        baseDate: baseDate,
        onSelectDate: (next) => setState(() => _date = _dateOnly(next)),
        commands: translation.commands,
        confirm: (title, message) => showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(title),
            content: Text(message),
            actions: [
              TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: const Text('Cancel')),
              FilledButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  child: const Text('Run')),
            ],
          ),
        ).then((v) => v == true),
      );

      if (!mounted) return;

      if (result.executedCount > 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Done (${result.executedCount})')),
        );
      }
      if (result.errors.isNotEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(result.errors.first)),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _assistantLoading = false);
      }
    }
  }

  void _scrollToQuickAdd(BuildContext context) {
    // AppScaffold uses a ListView; focusing the input is the lowest-friction
    // “take me there” behavior for now.
    FocusScope.of(context).requestFocus(_quickAddFocus);
  }

  Future<void> _submitQuickAdd(TodayController controller) async {
    final title = _quickAddController.text;
    final ok = await controller.addTask(title: title, type: _quickAddType);
    if (!ok) return;
    _quickAddController.clear();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(_quickAddType == TodayTaskType.mustWin
            ? 'Added to Must‑Wins'
            : 'Added to Nice‑to‑Do'),
      ),
    );
  }

  Future<String?> _pickFocusTask(
      BuildContext context, List<TodayTask> mustWins) async {
    return showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        return SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(AppSpace.s16),
            children: [
              Text(
                'Pick a focus task',
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.w800),
              ),
              Gap.h12,
              for (final t in mustWins)
                ListTile(
                  leading: Icon(t.completed
                      ? Icons.check_circle
                      : Icons.radio_button_unchecked),
                  title: Text(t.title),
                  onTap: () => Navigator.of(context).pop(t.id),
                ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _editTask(
    BuildContext context, {
    required String id,
    required String current,
    required Future<void> Function(String taskId, String title) onSave,
  }) async {
    final controller = TextEditingController(text: current);
    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit task'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'Title'),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Save')),
        ],
      ),
    );
    if (saved != true) return;
    await onSave(id, controller.text);
  }

  void _toggleExpandedTask(String taskId) {
    setState(() {
      if (_expandedTaskIds.contains(taskId)) {
        _expandedTaskIds.remove(taskId);
      } else {
        _expandedTaskIds.add(taskId);
      }
    });
  }

  Future<void> _openTaskDetailsSheet(
    BuildContext context, {
    required TodayController controller,
    required TodayTask task,
  }) async {
    final saved = await showModalBottomSheet<bool>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) => TaskDetailsSheet(
        title: task.title,
        initialDetails: task.details ?? '',
        maxLength: TodayController.maxTaskDetailsChars,
        onSave: (next) => controller.updateTaskDetailsText(
          taskId: task.id,
          details: next,
        ),
      ),
    );
    if (saved == true && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Saved')),
      );
    }
  }
}

class _TasksCard extends StatelessWidget {
  const _TasksCard({
    required this.tasks,
    required this.onToggle,
    required this.onEdit,
    required this.onDelete,
    required this.onMove,
    required this.expandedTaskIds,
    required this.onToggleExpanded,
    required this.onEditDetails,
  });

  final List<TodayTask> tasks;
  final Future<void> Function(String taskId) onToggle;
  final Future<void> Function(String taskId, String currentTitle) onEdit;
  final Future<void> Function(String taskId) onDelete;
  final Future<void> Function(String taskId) onMove;
  final Set<String> expandedTaskIds;
  final void Function(String taskId) onToggleExpanded;
  final void Function(TodayTask task) onEditDetails;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpace.s8),
        child: Column(
          children: [
            for (final t in tasks)
              _TaskRow(
                task: t,
                expanded: expandedTaskIds.contains(t.id),
                onToggle: onToggle,
                onEdit: onEdit,
                onDelete: onDelete,
                onMove: onMove,
                onToggleExpanded: onToggleExpanded,
                onEditDetails: onEditDetails,
              ),
          ],
        ),
      ),
    );
  }
}

class _TaskRow extends StatelessWidget {
  const _TaskRow({
    required this.task,
    required this.expanded,
    required this.onToggle,
    required this.onEdit,
    required this.onDelete,
    required this.onMove,
    required this.onToggleExpanded,
    required this.onEditDetails,
  });

  final TodayTask task;
  final bool expanded;
  final Future<void> Function(String taskId) onToggle;
  final Future<void> Function(String taskId, String currentTitle) onEdit;
  final Future<void> Function(String taskId) onDelete;
  final Future<void> Function(String taskId) onMove;
  final void Function(String taskId) onToggleExpanded;
  final void Function(TodayTask task) onEditDetails;

  bool get _hasDetails => (task.details ?? '').trim().isNotEmpty;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final noteColor = _hasDetails
        ? theme.colorScheme.primary
        : theme.colorScheme.onSurfaceVariant;

    return Column(
      children: [
        GestureDetector(
          onDoubleTap: () => onEditDetails(task),
          behavior: HitTestBehavior.opaque,
          child: ListTile(
            leading: Checkbox(
              value: task.completed,
              onChanged: (_) => onToggle(task.id),
            ),
            title: Text(
              task.title,
              style: task.completed
                  ? theme.textTheme.bodyLarge?.copyWith(
                      decoration: TextDecoration.lineThrough,
                      color: theme.colorScheme.onSurface.withOpacity(0.6),
                    )
                  : theme.textTheme.bodyLarge,
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                GestureDetector(
                  onLongPress: () => onEditDetails(task),
                  child: IconButton(
                    tooltip: _hasDetails ? 'Show note' : 'Add note',
                    icon: Icon(
                      _hasDetails
                          ? Icons.sticky_note_2
                          : Icons.sticky_note_2_outlined,
                      color: noteColor,
                    ),
                    onPressed: _hasDetails
                        ? () => onToggleExpanded(task.id)
                        : () => onEditDetails(task),
                  ),
                ),
                PopupMenuButton<String>(
                  onSelected: (value) async {
                    switch (value) {
                      case 'details':
                        onEditDetails(task);
                        break;
                      case 'edit':
                        await onEdit(task.id, task.title);
                        break;
                      case 'move':
                        await onMove(task.id);
                        break;
                      case 'delete':
                        await onDelete(task.id);
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Deleted')),
                          );
                        }
                        break;
                    }
                  },
                  itemBuilder: (context) => const [
                    PopupMenuItem(value: 'details', child: Text('Details')),
                    PopupMenuDivider(),
                    PopupMenuItem(value: 'edit', child: Text('Edit')),
                    PopupMenuItem(
                        value: 'move', child: Text('Move to other list')),
                    PopupMenuDivider(),
                    PopupMenuItem(value: 'delete', child: Text('Delete')),
                  ],
                ),
              ],
            ),
          ),
        ),
        if (expanded && _hasDetails)
          Padding(
            padding: const EdgeInsets.fromLTRB(
                AppSpace.s16, 0, AppSpace.s16, AppSpace.s12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  task.details!.trim(),
                  maxLines: 6,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                Gap.h8,
                Row(
                  children: [
                    TextButton(
                      onPressed: () => onEditDetails(task),
                      child: const Text('Edit note'),
                    ),
                    const Spacer(),
                    TextButton(
                      onPressed: () => onToggleExpanded(task.id),
                      child: const Text('Hide'),
                    ),
                  ],
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _TrackerTallyTile extends StatelessWidget {
  const _TrackerTallyTile({
    required this.emoji,
    required this.title,
    required this.count,
    required this.onIncrement,
    required this.onDecrement,
    this.subtitle,
    this.progress,
  });

  final String emoji;
  final String title;
  final String? subtitle;
  final int count;
  final String? progress;
  final VoidCallback onIncrement;
  final VoidCallback onDecrement;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onIncrement,
      onLongPress: onDecrement,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(AppSpace.s12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: theme.dividerColor.withOpacity(0.5)),
          color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.18),
        ),
        child: Row(
          children: [
            Text(emoji, style: theme.textTheme.headlineSmall),
            Gap.w12,
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: theme.textTheme.titleSmall
                        ?.copyWith(fontWeight: FontWeight.w800),
                  ),
                  if ((subtitle ?? '').trim().isNotEmpty ||
                      (progress ?? '').trim().isNotEmpty) ...[
                    Gap.h4,
                    Text(
                      [
                        if ((subtitle ?? '').trim().isNotEmpty) subtitle!,
                        if ((progress ?? '').trim().isNotEmpty) progress!,
                      ].join(' • '),
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                ],
              ),
            ),
            Gap.w12,
            Text(
              '$count',
              style: theme.textTheme.titleLarge
                  ?.copyWith(fontWeight: FontWeight.w900),
            ),
          ],
        ),
      ),
    );
  }
}
