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
import '../../ui/app_scaffold.dart';
import '../../ui/components/empty_state_card.dart';
import '../../ui/components/section_header.dart';
import '../../ui/spacing.dart';
import 'today_controller.dart';
import 'today_models.dart';

class TodayScreen extends ConsumerStatefulWidget {
  const TodayScreen({super.key});

  @override
  ConsumerState<TodayScreen> createState() => _TodayScreenState();
}

class _TodayScreenState extends ConsumerState<TodayScreen> {
  DateTime _date = _dateOnly(DateTime.now());
  String? _loadedReflectionForYmd;
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
          _assistantSpeechError = 'Speech recognition is not available on this device.'
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
                                child: CircularProgressIndicator(strokeWidth: 2),
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
                              ?.copyWith(color: Theme.of(context).colorScheme.error),
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
                        const SnackBar(content: Text('Hold the outline to talk')),
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
                          final ok =
                              await controller.addHabit(name: _habitAddController.text);
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
            onDetails: (id) => context.push('/home/today/task/$id?ymd=$ymd'),
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
            onDetails: (id) => context.push('/home/today/task/$id?ymd=$ymd'),
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
}

class _TasksCard extends StatelessWidget {
  const _TasksCard({
    required this.tasks,
    required this.onToggle,
    required this.onEdit,
    required this.onDelete,
    required this.onMove,
    required this.onDetails,
  });

  final List<TodayTask> tasks;
  final Future<void> Function(String taskId) onToggle;
  final Future<void> Function(String taskId, String currentTitle) onEdit;
  final Future<void> Function(String taskId) onDelete;
  final Future<void> Function(String taskId) onMove;
  final void Function(String taskId) onDetails;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpace.s8),
        child: Column(
          children: [
            for (final t in tasks)
              GestureDetector(
                onDoubleTap: () => onDetails(t.id),
                behavior: HitTestBehavior.opaque,
                child: ListTile(
                  leading: Checkbox(
                    value: t.completed,
                    onChanged: (_) => onToggle(t.id),
                  ),
                  title: Text(
                    t.title,
                    style: t.completed
                        ? Theme.of(context).textTheme.bodyLarge?.copyWith(
                              decoration: TextDecoration.lineThrough,
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurface
                                  .withOpacity(0.6),
                            )
                        : Theme.of(context).textTheme.bodyLarge,
                  ),
                  trailing: PopupMenuButton<String>(
                    onSelected: (value) async {
                      switch (value) {
                        case 'details':
                          onDetails(t.id);
                          break;
                        case 'edit':
                          await onEdit(t.id, t.title);
                          break;
                        case 'move':
                          await onMove(t.id);
                          break;
                        case 'delete':
                          await onDelete(t.id);
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
                ),
              ),
          ],
        ),
      ),
    );
  }
}
