import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:speech_to_text/speech_to_text.dart';

import '../../app/env.dart';
import '../../app/errors.dart';
import '../../app/supabase.dart';
import '../../assistant/assistant_client.dart';
import '../../assistant/assistant_executor.dart';
import '../../data/tasks/task_details_providers.dart';
import '../../data/tasks/task_realtime_provider.dart';
import '../../ui/app_scaffold.dart';
import '../../ui/components/assistant_preview_sheet.dart';
import '../../ui/components/empty_state_card.dart';
import '../../ui/components/conversation_border.dart';
import '../../ui/components/primary_cta.dart';
import '../../ui/components/section_header.dart';
import '../../ui/components/task_details_sheet.dart';
import '../../ui/spacing.dart';
import '../focus/focus_session_controller.dart';
import '../focus/focus_ticker_provider.dart';
import '../tasks/task_details_screen.dart';
import 'dashboard/dashboard_layout_controller.dart';
import 'dashboard/dashboard_section_id.dart';
import 'today_controller.dart';
import 'today_models.dart';
import 'today_timebox_controller.dart';
import 'widgets/starter_step_editor_sheet.dart';

enum _TodayOverflowAction {
  customizeDashboard,
  resetDashboard,
}

class TodayScreen extends ConsumerStatefulWidget {
  const TodayScreen({
    super.key,
    this.initialYmd,
  });

  /// Optional deep-link override (e.g., Focus wants to open the session’s start-day).
  ///
  /// Format: yyyy-MM-dd
  final String? initialYmd;

  @override
  ConsumerState<TodayScreen> createState() => _TodayScreenState();
}

class _TodayScreenState extends ConsumerState<TodayScreen> {
  DateTime _date = _dateOnly(DateTime.now());
  String? _loadedReflectionForYmd;
  final Set<String> _expandedTaskIds = {};
  String? _rolloverCheckForYmd;
  Future<List<TodayTask>>? _rolloverYesterdayIncompleteFuture;
  bool _rolloverInFlight = false;
  final _quickAddController = TextEditingController();
  final _quickAddFocus = FocusNode();
  var _quickAddType = TodayTaskType.mustWin;
  bool _quickAddInFlight = false;
  final _reflectionController = TextEditingController();
  final _reflectionFocus = FocusNode();
  final _habitAddController = TextEditingController();
  final _assistantController = TextEditingController();
  final _assistantFocus = FocusNode();
  bool _assistantLoading = false;
  bool _isCustomizingDashboard = false;

  final SpeechToText _speech = SpeechToText();
  bool _speechReady = false;
  bool _assistantListening = false;
  String? _assistantSpeechError;
  int _assistantListenSession = 0;
  double _assistantSoundLevel01 = 0.0;
  Future<void> Function()? _assistantFinishListeningAndRun;

  static DateTime _dateOnly(DateTime dt) => DateTime(dt.year, dt.month, dt.day);
  static bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  @override
  void initState() {
    super.initState();
    final raw = widget.initialYmd;
    if (raw != null && raw.trim().isNotEmpty) {
      final parsed = DateTime.tryParse(raw.trim());
      if (parsed != null) {
        _date = _dateOnly(parsed);
      }
    }
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
    _assistantFocus.dispose();
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
        onStatus: (status) {
          // speech_to_text v7 reports listen lifecycle statuses here.
          // For the auto-run interaction, treat "done"/"notListening" as the end
          // of speech and finish the session.
          if (!mounted) return;
          final finish = _assistantFinishListeningAndRun;
          if (finish == null) return;
          if (!_assistantListening) return;
          if (status == SpeechToText.doneStatus ||
              status == SpeechToText.notListeningStatus) {
            unawaited(finish());
          }
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


  Future<void> _stopAssistantListening() async {
    if (!_assistantListening) return;
    _assistantFinishListeningAndRun = null;
    try {
      await _speech.stop();
    } catch (_) {
      // Ignore stop errors; we'll still reset UI state.
    }
    if (!mounted) return;
    // Safely handle haptic feedback (may not be supported on all platforms)
    try {
      await HapticFeedback.selectionClick();
    } catch (_) {
      // Ignore haptic feedback errors
    }
    setState(() {
      _assistantListening = false;
      _assistantSoundLevel01 = 0.0;
    });
  }

  Future<void> _startAssistantListeningAndAutoRun({
    required AssistantClient assistantClient,
    required DateTime baseDate,
  }) async {
    // Wrap entire function in try-catch to prevent crashes on macOS
    try {
      if (_assistantLoading) return;

      // If already listening, interpret a second tap as "stop + run now".
      if (_assistantListening) {
        await _stopAssistantListening();
        if (!mounted) return;
        await _runAssistant(assistantClient: assistantClient, baseDate: baseDate);
        return;
      }

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

      // End customize mode if active; voice input should feel immediate.
      if (_isCustomizingDashboard) {
        setState(() => _isCustomizingDashboard = false);
      }

      // Session token prevents double-run if callbacks race.
      final session = ++_assistantListenSession;
      var didAutoRun = false;

      Future<void> finishListeningAndRun() async {
        // Guard against duplicate stop+run from multiple callbacks (finalResult,
        // status changes, safety timeout).
        if (didAutoRun) return;
        if (!_assistantListening) return;
        didAutoRun = true;
        _assistantFinishListeningAndRun = null;

        await _stopAssistantListening();

        // Give the speech plugin a beat to deliver any final transcript update.
        await Future<void>.delayed(const Duration(milliseconds: 120));

        if (!mounted) return;
        if (session != _assistantListenSession) return;
        await _runAssistant(assistantClient: assistantClient, baseDate: baseDate);
      }

      // Safely handle haptic feedback (may not be supported on all platforms)
      try {
        await HapticFeedback.selectionClick();
      } catch (_) {
        // Ignore haptic feedback errors
      }

      if (!mounted) return;
      setState(() {
        _assistantListening = true;
        _assistantSpeechError = null;
        _assistantSoundLevel01 = 0.0;
      });

      try {
        await _speech.listen(
          pauseFor: const Duration(seconds: 2),
          onSoundLevelChange: (level) {
            if (!mounted) return;
            if (session != _assistantListenSession) return;
            final next = ((level + 2) / 12).clamp(0.0, 1.0);
            final smooth = _assistantSoundLevel01 * 0.65 + next * 0.35;
            setState(() => _assistantSoundLevel01 = smooth);
          },
          listenOptions: SpeechListenOptions(
            listenMode: ListenMode.confirmation,
            partialResults: true,
          ),
          onResult: (result) async {
            if (!mounted) return;
            if (session != _assistantListenSession) return;

            final words = result.recognizedWords.trim();
            if (words.isNotEmpty) {
              _setAssistantTranscript(words);
            }

            // When the engine considers the result final, stop listening and run.
            if (result.finalResult) {
              await finishListeningAndRun();
            }
          },
        );
      } catch (e) {
        if (!mounted) return;
        setState(() {
          _assistantListening = false;
          _assistantSoundLevel01 = 0.0;
          _assistantSpeechError = kIsWeb
              ? 'Speech unavailable in this environment.'
              : 'Speech recognition error. Please try again.';
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_assistantSpeechError!)),
        );
        return;
      }

      // Safety net: if we never get a finalResult/status, stop + run eventually.
      // This should not normally trigger because `pauseFor` ends listening on silence.
      Future<void>.delayed(const Duration(seconds: 60), () async {
        if (!mounted) return;
        if (session != _assistantListenSession) return;
        if (!_assistantListening) return;
        await finishListeningAndRun();
      });
    } catch (e, stackTrace) {
      // Catch any unhandled exceptions to prevent crashes
      if (!mounted) return;
      setState(() {
        _assistantListening = false;
        _assistantSoundLevel01 = 0.0;
        _assistantSpeechError = 'Speech recognition unavailable. Please try again.';
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_assistantSpeechError!),
          duration: const Duration(seconds: 4),
        ),
      );
      // Log the error for debugging
      debugPrint('AI button error: $e');
      debugPrint('Stack trace: $stackTrace');
    }
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

    // Listen for realtime task changes from other devices.
    // When a change is detected for this date, refresh the task list.
    ref.listen<AsyncValue<TaskChangeEvent?>>(
      taskRealtimeChangesProvider,
      (previous, next) {
        final event = next.valueOrNull;
        if (event != null && taskChangeAffectsDate(event, ymd)) {
          debugPrint('[TodayScreen] Refreshing tasks due to realtime event: $event');
          ref.read(todayControllerProvider(ymd).notifier).refreshTasks();
        }
      },
    );

    final today = ref.watch(todayControllerProvider(ymd));
    final controller = ref.read(todayControllerProvider(ymd).notifier);
    final activeSession = ref.watch(activeFocusSessionProvider).valueOrNull;
    final activeTimebox = ref.watch(todayTimeboxControllerProvider(ymd));
    final env = ref.watch(envProvider);
    final supabaseState = ref.watch(supabaseProvider);
    final assistantClient = AssistantClient(
      supabase: supabaseState.client,
      enableRemote: !env.demoMode && supabaseState.isInitialized,
    );
    final taskDetailsRepo = ref.watch(taskDetailsRepositoryProvider);

    // Keep reflection controller in sync when switching dates.
    if (_loadedReflectionForYmd != ymd) {
      _loadedReflectionForYmd = ymd;
      _reflectionController.text = today.reflection;
      _expandedTaskIds.clear();
      _rolloverCheckForYmd = null;
      _rolloverYesterdayIncompleteFuture = null;
      _rolloverInFlight = false;
    }

    final mustWins =
        today.tasks.where((t) => t.type == TodayTaskType.mustWin).toList();
    final niceTodos =
        today.tasks.where((t) => t.type == TodayTaskType.niceToDo).toList();
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

    TodayTask? timeboxTask;
    if (activeTimebox?.taskId != null) {
      for (final t in today.tasks) {
        if (t.id == activeTimebox!.taskId) {
          timeboxTask = t;
          break;
        }
      }
    }
    final showActiveFocusTimer = activeTimebox != null &&
        activeTimebox.kind == TodayTimerKind.focus &&
        activeSession?.isActive == true;

    final dashboardOrder = ref.watch(dashboardLayoutControllerProvider);
    final dashboardController =
        ref.read(dashboardLayoutControllerProvider.notifier);

    final shouldOfferRollover =
        isToday && mustWins.isEmpty && niceTodos.isEmpty && !_rolloverInFlight;
    if (shouldOfferRollover && _rolloverCheckForYmd != ymd) {
      _rolloverCheckForYmd = ymd;
      _rolloverYesterdayIncompleteFuture =
          controller.getYesterdayIncompleteTasks();
    }

    Widget buildHeader(
      String title, {
      required bool editing,
      required int index,
      Widget? trailing,
    }) {
      Widget? nextTrailing = trailing;
      if (editing) {
        final handle = _DashboardDragHandle(index: index);
        nextTrailing = nextTrailing == null
            ? handle
            : Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  nextTrailing,
                  Gap.w12,
                  handle,
                ],
              );
      }
      return SectionHeader(title: title, trailing: nextTrailing);
    }

    Widget buildSection(
      DashboardSectionId id, {
      required bool editing,
      required int index,
    }) {
      final sectionKey = ValueKey(id.name);

      Widget wrap(Widget child) {
        return RepaintBoundary(
          key: sectionKey,
          child: Padding(
            // 12px vertical rhythm between sections
            padding: const EdgeInsets.only(bottom: AppSpace.s12),
            child: child,
          ),
        );
      }

      switch (id) {
        case DashboardSectionId.date:
          // Compact date header: "Thu, Jan 29 • 2026-01-29" with small nav
          final compactDateLabel = '$friendly • $ymd';
          return wrap(
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Compact date row with icon buttons
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: AppSpace.s4),
                  child: Row(
                    children: [
                      // Prev day button
                      IconButton(
                        onPressed: () => setState(
                            () => _date = _date.subtract(const Duration(days: 1)),),
                        icon: const Icon(Icons.chevron_left),
                        tooltip: 'Previous day',
                        style: IconButton.styleFrom(
                          minimumSize: const Size(44, 44),
                        ),
                      ),
                      // Date label (tappable to open picker)
                      Expanded(
                        child: GestureDetector(
                          onTap: _pickDate,
                          child: Text(
                            compactDateLabel,
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                      // Next day button
                      IconButton(
                        onPressed: () => setState(
                            () => _date = _date.add(const Duration(days: 1)),),
                        icon: const Icon(Icons.chevron_right),
                        tooltip: 'Next day',
                        style: IconButton.styleFrom(
                          minimumSize: const Size(44, 44),
                        ),
                      ),
                      // Go to today (only shown when not viewing today)
                      if (!isToday)
                        IconButton(
                          onPressed: () => setState(() => _date = now),
                          icon: const Icon(Icons.today),
                          tooltip: 'Go to today',
                          style: IconButton.styleFrom(
                            minimumSize: const Size(44, 44),
                          ),
                        ),
                      // Drag handle when editing
                      if (editing) ...[
                        Gap.w8,
                        _DashboardDragHandle(index: index),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          );

        case DashboardSectionId.focus:
          return wrap(
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header with compact switch
                SectionHeader(
                  title: 'Focus',
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Transform.scale(
                        scale: 0.85,
                        child: Switch.adaptive(
                          value: today.focusModeEnabled,
                          onChanged: (v) => controller.setFocusModeEnabled(v),
                        ),
                      ),
                      if (editing) ...[
                        Gap.w8,
                        _DashboardDragHandle(index: index),
                      ],
                    ],
                  ),
                ),
                // Active timer (when running)
                if (showActiveFocusTimer) ...[
                  _ActiveFocusTimerCard(
                    ymd: ymd,
                    timer: activeTimebox,
                    taskTitle: timeboxTask?.title,
                  ),
                  Gap.h12,
                ],
                // Content based on focus mode state
                if (!today.focusModeEnabled) ...[
                  // Helper text (muted)
                  Text(
                    'Turn this on when feeling stuck or scattered.',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                  ),
                  Gap.h12,
                  // Primary CTA: Start focus
                  PrimaryCTA(
                    label: 'Start focus',
                    icon: Icons.center_focus_strong,
                    onPressed: mustWins.isEmpty
                        ? null
                        : () {
                            controller.setFocusModeEnabled(true);
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Focus mode on')),
                            );
                          },
                  ),
                  Gap.h8,
                  // Secondary: Add a Must-Win
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () => _scrollToQuickAdd(context),
                      icon: const Icon(Icons.add),
                      label: const Text('Add a Must-Win'),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(double.infinity, 48),
                      ),
                    ),
                  ),
                ] else
                  _FocusActionLane(
                            focusTask: focusTask,
                            taskDetailsRepoPresent: taskDetailsRepo != null,
                            ymd: ymd,
                            mustWins: mustWins,
                            onSwitchTask: mustWins.isEmpty
                                ? null
                                : () async {
                                    final picked =
                                        await _pickFocusTask(context, mustWins);
                                    if (!context.mounted) return;
                                    if (picked == null) return;
                                    await controller.setFocusTaskId(picked);
                                  },
                            onExitFocus: () async {
                              await controller.setFocusTaskId(null);
                              await controller.setFocusModeEnabled(false);
                            },
                            onEditStarterStep: (taskId, taskTitle) async {
                              final saved = await showModalBottomSheet<bool>(
                                context: context,
                                showDragHandle: true,
                                isScrollControlled: true,
                                builder: (context) => StarterStepEditorSheet(
                                  taskId: taskId,
                                  ymd: ymd,
                                  taskTitle: taskTitle,
                                ),
                              );
                              if (saved == true && context.mounted) return;
                            },
                            onStartTimeboxMinutes: (minutes) async {
                              final task = focusTask;
                              if (task == null) return;
                              final timeboxController = ref.read(
                                todayTimeboxControllerProvider(ymd).notifier,
                              );
                              final ok = await timeboxController.startFocus(
                                taskId: task.id,
                                minutes: minutes,
                              );
                              if (!context.mounted) return;
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(ok
                                      ? 'Focus timer started ($minutes min)'
                                      : 'Timer already running',),
                                ),
                              );
                            },
                            onImStuck: focusTask == null
                                ? null
                                : () {
                                    final ft = focusTask;
                                    if (ft == null) return;
                                    _showImStuckSheet(
                                      context,
                                      taskId: ft.id,
                                      taskTitle: ft.title,
                                      onMakeItSmaller: () async {
                                        Navigator.of(context).pop();
                                        final saved =
                                            await showModalBottomSheet<bool>(
                                          context: context,
                                          showDragHandle: true,
                                          isScrollControlled: true,
                                          builder: (context) =>
                                              StarterStepEditorSheet(
                                            taskId: ft.id,
                                            ymd: ymd,
                                            taskTitle: ft.title,
                                          ),
                                        );
                                        if (saved == true && context.mounted) {
                                          return;
                                        }
                                      },
                                      onSwitchTask: mustWins.isEmpty
                                          ? null
                                          : () async {
                                              Navigator.of(context).pop();
                                              final picked =
                                                  await _pickFocusTask(
                                                      context, mustWins,);
                                              if (!context.mounted) return;
                                              if (picked == null) return;
                                              await controller
                                                  .setFocusTaskId(picked);
                                            },
                                      onExitFocus: () async {
                                        Navigator.of(context).pop();
                                        await controller.setFocusTaskId(null);
                                        await controller
                                            .setFocusModeEnabled(false);
                                      },
                                    );
                                  },
                  ),
              ],
            ),
          );

        case DashboardSectionId.quickAdd:
          return wrap(
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                buildHeader('Quick add', editing: editing, index: index),
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
                          enabled: !_quickAddInFlight,
                          decoration: const InputDecoration(
                            labelText: 'What’s the task?',
                            hintText: 'Ex: Send the email',
                          ),
                        ),
                        Gap.h12,
                        SegmentedButton<TodayTaskType>(
                          segments: const [
                            ButtonSegment(
                                value: TodayTaskType.mustWin,
                                label: Text('Must‑Win'),),
                            ButtonSegment(
                                value: TodayTaskType.niceToDo,
                                label: Text('Nice‑to‑Do'),),
                          ],
                          selected: {_quickAddType},
                          onSelectionChanged: _quickAddInFlight
                              ? null
                              : (s) => setState(() => _quickAddType = s.first),
                        ),
                        Gap.h12,
                        FilledButton.icon(
                          onPressed: _quickAddInFlight
                              ? null
                              : () => _submitQuickAdd(controller),
                          icon: _quickAddInFlight
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.add),
                          label: Text(_quickAddInFlight ? 'Adding…' : 'Add'),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );

        case DashboardSectionId.assistant:
        case DashboardSectionId.habits:
        case DashboardSectionId.trackers:
          return const SizedBox.shrink();

        case DashboardSectionId.mustWins:
          return wrap(
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                buildHeader(
                  'Must‑Wins',
                  editing: editing,
                  index: index,
                  trailing: Text(
                      '${mustWins.where((t) => t.completed).length}/${mustWins.length}',),
                ),
                if (mustWins.isEmpty)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (isToday && mustWins.isEmpty && niceTodos.isEmpty)
                        FutureBuilder<List<TodayTask>>(
                          future: _rolloverYesterdayIncompleteFuture,
                          builder: (context, snap) {
                            final tasks = snap.data ?? const [];
                            if (snap.connectionState != ConnectionState.done) {
                              return const SizedBox.shrink();
                            }
                            if (tasks.isEmpty) return const SizedBox.shrink();

                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                _RolloverYesterdayCard(
                                  count: tasks.length,
                                  loading: _rolloverInFlight,
                                  onPressed: _rolloverInFlight
                                      ? null
                                      : () async {
                                          setState(
                                              () => _rolloverInFlight = true,);
                                          try {
                                            final moved = await controller
                                                .rolloverYesterdayTasks();
                                            if (!context.mounted) return;
                                            ScaffoldMessenger.of(context)
                                                .showSnackBar(
                                              SnackBar(
                                                content: Text(moved == 0
                                                    ? 'No tasks to roll over'
                                                    : 'Rolled over $moved task${moved == 1 ? '' : 's'}',),
                                              ),
                                            );
                                          } catch (e) {
                                            if (!context.mounted) return;
                                            ScaffoldMessenger.of(context)
                                                .showSnackBar(
                                              SnackBar(
                                                  content:
                                                      Text(friendlyError(e)),),
                                            );
                                          } finally {
                                            if (mounted) {
                                              setState(() {
                                                _rolloverInFlight = false;
                                                _rolloverCheckForYmd = null;
                                                _rolloverYesterdayIncompleteFuture =
                                                    null;
                                              });
                                            }
                                          }
                                        },
                                ),
                                Gap.h12,
                              ],
                            );
                          },
                        ),
                      EmptyStateCard(
                        icon: Icons.flag_outlined,
                        title: 'Pick 1–3 Must‑Wins',
                        description:
                            'Must‑Wins are the few things that make now a win. Keep it small.',
                        ctaLabel: 'Add a Must‑Win',
                        onCtaPressed: () {
                          setState(() => _quickAddType = TodayTaskType.mustWin);
                          _scrollToQuickAdd(context);
                        },
                      ),
                    ],
                  )
                else
                  _TasksCard(
                    tasks: mustWins,
                    ymd: ymd,
                    onToggle: (taskId) async {
                      final beforeDay = ref.read(todayControllerProvider(ymd));
                      bool wasCompleted = false;
                      for (final t in beforeDay.tasks) {
                        if (t.id == taskId) {
                          wasCompleted = t.completed;
                          break;
                        }
                      }

                      await controller.toggleTaskCompleted(taskId);

                      final afterDay = ref.read(todayControllerProvider(ymd));
                      bool isCompleted = false;
                      TodayTaskType? afterType;
                      for (final t in afterDay.tasks) {
                        if (t.id == taskId) {
                          isCompleted = t.completed;
                          afterType = t.type;
                          break;
                        }
                      }

                      if (!wasCompleted && isCompleted) {
                        if (afterType == TodayTaskType.mustWin) {
                          final mustWinsAfter = afterDay.tasks
                              .where((t) => t.type == TodayTaskType.mustWin)
                              .toList();
                          final allMustWinsDone = mustWinsAfter.isNotEmpty &&
                              mustWinsAfter.every((t) => t.completed);
                          if (allMustWinsDone) {} else {}
                        } else {
                        }
                      }
                    },
                    onSetInProgress: controller.setTaskInProgress,
                    onEdit: (id, current) => _editTask(
                      context,
                      id: id,
                      current: current,
                      onSave: controller.updateTaskTitle,
                    ),
                    onDelete: (id) => controller.deleteTask(id),
                    onMove: (id) =>
                        controller.moveTaskType(id, TodayTaskType.niceToDo),
                    onEditStarterStep: (t) async {
                      final saved = await showModalBottomSheet<bool>(
                        context: context,
                        showDragHandle: true,
                        isScrollControlled: true,
                        builder: (context) => StarterStepEditorSheet(
                          taskId: t.id,
                          ymd: ymd,
                          taskTitle: t.title,
                        ),
                      );
                      if (saved == true && context.mounted) return;
                    },
                    expandedTaskIds: _expandedTaskIds,
                    onToggleExpanded: _toggleExpandedTask,
                    onEditDetails: (t) => _openTaskDetailsSheet(
                      context,
                      controller: controller,
                      task: t,
                    ),
                  ),
              ],
            ),
          );

        case DashboardSectionId.niceToDo:
          return wrap(
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                buildHeader(
                  'Nice‑to‑Do',
                  editing: editing,
                  index: index,
                  trailing: Text(
                      '${niceTodos.where((t) => t.completed).length}/${niceTodos.length}',),
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
                    ymd: ymd,
                    onToggle: (taskId) async {
                      final beforeDay = ref.read(todayControllerProvider(ymd));
                      bool wasCompleted = false;
                      for (final t in beforeDay.tasks) {
                        if (t.id == taskId) {
                          wasCompleted = t.completed;
                          break;
                        }
                      }

                      await controller.toggleTaskCompleted(taskId);

                      final afterDay = ref.read(todayControllerProvider(ymd));
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
                    onSetInProgress: controller.setTaskInProgress,
                    onEdit: (id, current) => _editTask(
                      context,
                      id: id,
                      current: current,
                      onSave: controller.updateTaskTitle,
                    ),
                    onDelete: (id) => controller.deleteTask(id),
                    onMove: (id) =>
                        controller.moveTaskType(id, TodayTaskType.mustWin),
                    onEditStarterStep: (t) async {
                      final saved = await showModalBottomSheet<bool>(
                        context: context,
                        showDragHandle: true,
                        isScrollControlled: true,
                        builder: (context) => StarterStepEditorSheet(
                          taskId: t.id,
                          ymd: ymd,
                          taskTitle: t.title,
                        ),
                      );
                      if (saved == true && context.mounted) return;
                    },
                    expandedTaskIds: _expandedTaskIds,
                    onToggleExpanded: _toggleExpandedTask,
                    onEditDetails: (t) => _openTaskDetailsSheet(
                      context,
                      controller: controller,
                      task: t,
                    ),
                  ),
              ],
            ),
          );

        case DashboardSectionId.reflection:
          return wrap(
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                buildHeader('Reflection', editing: editing, index: index),
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
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton(
                            onPressed: () =>
                                FocusManager.instance.primaryFocus?.unfocus(),
                            child: const Text('Done'),
                          ),
                        ),
                        Text(
                          'Auto-saves when you leave the field.',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
      }
    }

    return AppScaffold(
      title: 'Now',
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
        if (_isCustomizingDashboard)
          TextButton(
            onPressed: () => setState(() => _isCustomizingDashboard = false),
            child: const Text('Done'),
          ),
        PopupMenuButton<_TodayOverflowAction>(
          tooltip: 'More',
          onSelected: (action) {
            switch (action) {
              case _TodayOverflowAction.customizeDashboard:
                setState(() => _isCustomizingDashboard = true);
                break;
              case _TodayOverflowAction.resetDashboard:
                dashboardController.resetToDefault();
                break;
            }
          },
          itemBuilder: (context) => [
            if (!_isCustomizingDashboard)
              const PopupMenuItem(
                value: _TodayOverflowAction.customizeDashboard,
                child: Text('Customize dashboard'),
              ),
            if (_isCustomizingDashboard)
              const PopupMenuItem(
                value: _TodayOverflowAction.resetDashboard,
                child: Text('Reset to default order'),
              ),
          ],
        ),
      ],
      floatingActionButton: ConversationBorder(
        active: _assistantListening,
        level: _assistantSoundLevel01,
        child: FloatingActionButton.extended(
          onPressed: () => _startAssistantListeningAndAutoRun(
            assistantClient: assistantClient,
            baseDate: _date,
          ),
          icon: Icon(_assistantListening ? Icons.mic : Icons.auto_awesome),
          label: const Text('AI'),
          tooltip: _assistantListening ? 'Listening… tap to run now' : 'AI',
        ),
      ),
      body: _isCustomizingDashboard
          ? ReorderableListView.builder(
              padding: const EdgeInsets.all(AppSpace.s16),
              buildDefaultDragHandles: false,
              itemCount: dashboardOrder.length,
              onReorder: dashboardController.onReorder,
              itemBuilder: (context, index) => buildSection(
                dashboardOrder[index],
                editing: true,
                index: index,
              ),
            )
          : null,
      children: _isCustomizingDashboard
          ? const []
          : [
              for (var i = 0; i < dashboardOrder.length; i++)
                buildSection(dashboardOrder[i], editing: false, index: i),
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
    });

    final baseYmd = DateFormat('yyyy-MM-dd').format(baseDate);

    try {
      final translation = await assistantClient.translate(
        transcript: transcript,
        baseDateYmd: baseYmd,
      );

      if (!mounted) return;
      setState(() {});

      final hasAction = translation.commands.any(
        (c) => c.kind != 'date.shift' && c.kind != 'date.set',
      );

      // Preview before executing (builds trust and avoids surprises).
      if (translation.commands.isNotEmpty && hasAction) {
        final run = await showModalBottomSheet<bool>(
          context: context,
          showDragHandle: true,
          isScrollControlled: true,
          builder: (context) => AssistantPreviewSheet(
            baseDate: baseDate,
            say: translation.say,
            commands: translation.commands,
          ),
        ).then((v) => v == true);
        if (!run) return;
      }

      if (!mounted) return;

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
                  child: const Text('Cancel'),),
              FilledButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  child: const Text('Run'),),
            ],
          ),
        ).then((v) => v == true),
        alreadyPreviewed: translation.commands.isNotEmpty && hasAction,
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
    // Guard against double-submission (e.g. user presses Enter + taps Add button,
    // or double-taps the button before the first addTask completes).
    if (_quickAddInFlight) return;

    final title = _quickAddController.text;
    if (title.trim().isEmpty) return;

    setState(() => _quickAddInFlight = true);
    try {
      final ok = await controller.addTask(title: title, type: _quickAddType);
      if (!ok) return;
      _quickAddController.clear();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_quickAddType == TodayTaskType.mustWin
              ? 'Added to Must‑Wins'
              : 'Added to Nice‑to‑Do',),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _quickAddInFlight = false);
      }
    }
  }

  Future<String?> _pickFocusTask(
      BuildContext context, List<TodayTask> mustWins,) async {
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
                      : Icons.radio_button_unchecked,),
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
              child: const Text('Cancel'),),
          FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Save'),),
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

  void _showImStuckSheet(
    BuildContext context, {
    required String taskId,
    required String taskTitle,
    required VoidCallback onMakeItSmaller,
    required VoidCallback? onSwitchTask,
    required VoidCallback onExitFocus,
  }) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(AppSpace.s16),
          children: [
            Text(
              'I’m stuck',
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.w800),
            ),
            Gap.h4,
            Text(
              taskTitle,
              style: Theme.of(context).textTheme.bodySmall,
            ),
            Gap.h12,
            ListTile(
              leading: const Icon(Icons.compress),
              title: const Text('Make it smaller'),
              subtitle: const Text('Set a “next 2 minutes” starter step.'),
              onTap: onMakeItSmaller,
            ),
            ListTile(
              leading: const Icon(Icons.swap_horiz),
              title: const Text('Switch focus'),
              subtitle: const Text('Pick a different Must‑Win.'),
              onTap: onSwitchTask,
            ),
            ListTile(
              leading: const Icon(Icons.exit_to_app),
              title: const Text('Exit focus'),
              onTap: onExitFocus,
            ),
            Gap.h8,
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
          ],
        ),
      ),
    );
  }
}

class _TasksCard extends StatelessWidget {
  const _TasksCard({
    required this.tasks,
    required this.ymd,
    required this.onToggle,
    required this.onSetInProgress,
    required this.onEdit,
    required this.onDelete,
    required this.onMove,
    required this.onEditStarterStep,
    required this.expandedTaskIds,
    required this.onToggleExpanded,
    required this.onEditDetails,
  });

  final List<TodayTask> tasks;
  final String ymd;
  final Future<void> Function(String taskId) onToggle;
  final Future<void> Function(String taskId, bool inProgress) onSetInProgress;
  final Future<void> Function(String taskId, String currentTitle) onEdit;
  final Future<void> Function(String taskId) onDelete;
  final Future<void> Function(String taskId) onMove;
  final void Function(TodayTask task) onEditStarterStep;
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
                ymd: ymd,
                expanded: expandedTaskIds.contains(t.id),
                onToggle: onToggle,
                onSetInProgress: onSetInProgress,
                onEdit: onEdit,
                onDelete: onDelete,
                onMove: onMove,
                onEditStarterStep: onEditStarterStep,
                onToggleExpanded: onToggleExpanded,
                onEditDetails: onEditDetails,
              ),
          ],
        ),
      ),
    );
  }
}

class _RolloverYesterdayCard extends StatelessWidget {
  const _RolloverYesterdayCard({
    required this.count,
    required this.loading,
    required this.onPressed,
  });

  final int count;
  final bool loading;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final label = count == 1 ? '1 unfinished task' : '$count unfinished tasks';

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpace.s16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.replay, size: 28, color: theme.colorScheme.primary),
            Gap.h12,
            Text(
              'Pick up where you left off?',
              style: theme.textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
            Gap.h8,
            Text(
              'You have $label from yesterday.',
              style: theme.textTheme.bodyMedium,
            ),
            Gap.h16,
            FilledButton.icon(
              onPressed: onPressed,
              icon: loading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.call_made),
              label: Text(loading ? 'Bringing…' : 'Bring to now'),
            ),
          ],
        ),
      ),
    );
  }
}

class _DashboardDragHandle extends StatelessWidget {
  const _DashboardDragHandle({required this.index});

  final int index;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ReorderableDragStartListener(
      index: index,
      child: Semantics(
        button: true,
        label: 'Drag to reorder section',
        child: Container(
          width: 44,
          height: 44,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            color: scheme.surfaceContainerHighest.withOpacity(0.25),
            border: Border.all(color: Theme.of(context).dividerColor),
          ),
          child: Icon(
            Icons.drag_handle,
            color: scheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}

class _TaskRow extends StatelessWidget {
  const _TaskRow({
    required this.task,
    required this.ymd,
    required this.expanded,
    required this.onToggle,
    required this.onSetInProgress,
    required this.onEdit,
    required this.onDelete,
    required this.onMove,
    required this.onEditStarterStep,
    required this.onToggleExpanded,
    required this.onEditDetails,
  });

  final TodayTask task;
  final String ymd;
  final bool expanded;
  final Future<void> Function(String taskId) onToggle;
  final Future<void> Function(String taskId, bool inProgress) onSetInProgress;
  final Future<void> Function(String taskId, String currentTitle) onEdit;
  final Future<void> Function(String taskId) onDelete;
  final Future<void> Function(String taskId) onMove;
  final void Function(TodayTask task) onEditStarterStep;
  final void Function(String taskId) onToggleExpanded;
  final void Function(TodayTask task) onEditDetails;

  bool get _hasDetails => (task.details ?? '').trim().isNotEmpty;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final noteColor = _hasDetails
        ? theme.colorScheme.primary
        : theme.colorScheme.onSurfaceVariant;
    final showInProgress = task.inProgress && !task.completed;
    final goalYmd = (task.goalYmd ?? '').trim();
    final hasGoal = goalYmd.isNotEmpty;

    String goalLabel() {
      try {
        final dt = DateTime.parse(goalYmd);
        return DateFormat('MMM d').format(dt);
      } catch (_) {
        return goalYmd;
      }
    }

    bool isOverdue() {
      if (!hasGoal || task.completed) return false;
      try {
        final goal = DateTime.parse(goalYmd);
        final day = DateTime.parse(ymd);
        final goalDate = DateTime(goal.year, goal.month, goal.day);
        final dayDate = DateTime(day.year, day.month, day.day);
        return goalDate.isBefore(dayDate);
      } catch (_) {
        return false;
      }
    }

    final overdue = isOverdue();
    final dueColor =
        overdue ? theme.colorScheme.error : theme.colorScheme.onSurfaceVariant;

    return Column(
      children: [
        ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: AppSpace.s8),
          leading: Checkbox(
            value: task.completed,
            onChanged: (_) => onToggle(task.id),
          ),
          title: SelectionArea(
            child: Text(
              task.title,
              style: task.completed
                  ? theme.textTheme.bodyLarge?.copyWith(
                      decoration: TextDecoration.lineThrough,
                      color: theme.colorScheme.onSurface.withOpacity(0.6),
                    )
                  : theme.textTheme.bodyLarge,
            ),
          ),
          subtitle: (showInProgress || hasGoal)
              ? Wrap(
                  spacing: AppSpace.s12,
                  runSpacing: AppSpace.s4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    if (showInProgress)
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.timelapse,
                            size: 16,
                            color: theme.colorScheme.primary,
                          ),
                          Gap.w8,
                          Text(
                            'In progress',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.primary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    if (hasGoal)
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.event, size: 16, color: dueColor),
                          Gap.w8,
                          Text(
                            'Due ${goalLabel()}',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: dueColor,
                              fontWeight:
                                  overdue ? FontWeight.w700 : FontWeight.w400,
                            ),
                          ),
                        ],
                      ),
                  ],
                )
              : null,
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (context) => TaskDetailsScreen(
                taskId: task.id,
                ymd: ymd,
              ),
            ),
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
                    case 'progress':
                      final next = !task.inProgress;
                      try {
                        await onSetInProgress(task.id, next);
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                next
                                    ? 'Marked in progress'
                                    : 'Cleared in progress',
                              ),
                            ),
                          );
                        }
                      } catch (e) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text(friendlyError(e))),
                          );
                        }
                      }
                      break;
                    case 'starterStep':
                      onEditStarterStep(task);
                      break;
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
                itemBuilder: (context) => [
                  PopupMenuItem(
                    value: 'progress',
                    child: Text(
                      task.inProgress
                          ? 'Clear in progress'
                          : 'Mark in progress',
                    ),
                  ),
                  const PopupMenuDivider(),
                  const PopupMenuItem(
                      value: 'starterStep', child: Text('Starter step'),),
                  const PopupMenuDivider(),
                  const PopupMenuItem(value: 'details', child: Text('Details')),
                  const PopupMenuDivider(),
                  const PopupMenuItem(value: 'edit', child: Text('Edit')),
                  const PopupMenuItem(
                      value: 'move', child: Text('Move to other list'),),
                  const PopupMenuDivider(),
                  const PopupMenuItem(value: 'delete', child: Text('Delete')),
                ],
              ),
            ],
          ),
        ),
        if (expanded && _hasDetails)
          Padding(
            padding: const EdgeInsets.fromLTRB(
                AppSpace.s16, 0, AppSpace.s16, AppSpace.s12,),
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

class _FocusActionLane extends ConsumerWidget {
  const _FocusActionLane({
    required this.focusTask,
    required this.taskDetailsRepoPresent,
    required this.ymd,
    required this.mustWins,
    required this.onSwitchTask,
    required this.onExitFocus,
    required this.onEditStarterStep,
    required this.onStartTimeboxMinutes,
    required this.onImStuck,
  });

  final TodayTask? focusTask;
  final bool taskDetailsRepoPresent;
  final String ymd;
  final List<TodayTask> mustWins;

  final VoidCallback? onSwitchTask;
  final Future<void> Function() onExitFocus;
  final Future<void> Function(String taskId, String taskTitle)
      onEditStarterStep;
  final void Function(int minutes) onStartTimeboxMinutes;
  final VoidCallback? onImStuck;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final task = focusTask;
    final theme = Theme.of(context);

    if (task == null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            mustWins.isEmpty
                ? 'Add a Must‑Win, then focus on it.'
                : 'No Must‑Wins left. Nice work.',
            style: theme.textTheme.titleSmall
                ?.copyWith(fontWeight: FontWeight.w700),
          ),
          Gap.h12,
          Wrap(
            spacing: AppSpace.s8,
            runSpacing: AppSpace.s8,
            children: [
              OutlinedButton.icon(
                onPressed: onSwitchTask,
                icon: const Icon(Icons.swap_horiz),
                label: const Text('Switch task'),
              ),
              OutlinedButton.icon(
                onPressed: () => onExitFocus(),
                icon: const Icon(Icons.close),
                label: const Text('Exit focus'),
              ),
            ],
          ),
        ],
      );
    }

    String starterStep = task.starterStep ?? '';
    if (taskDetailsRepoPresent) {
      final detailsAsync = ref.watch(taskDetailsProvider(task.id));
      starterStep = detailsAsync.valueOrNull?.nextStep ?? '';
    }
    final hasStarterStep = starterStep.trim().isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(AppSpace.s12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            color: theme.colorScheme.primaryContainer.withOpacity(0.35),
            border: Border.all(color: theme.dividerColor.withOpacity(0.4)),
          ),
          child: SelectionArea(
            child: Text(
              task.title,
              style: theme.textTheme.titleLarge
                  ?.copyWith(fontWeight: FontWeight.w900),
            ),
          ),
        ),
        Gap.h12,
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(AppSpace.s12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: theme.dividerColor.withOpacity(0.5)),
            color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.18),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Starter step (next 2 minutes)',
                style: theme.textTheme.titleSmall
                    ?.copyWith(fontWeight: FontWeight.w800),
              ),
              Gap.h8,
              if (hasStarterStep)
                Text(
                  starterStep.trim(),
                  style: theme.textTheme.bodyMedium,
                )
              else
                Text(
                  'Add a tiny next step so it’s obvious what to do.',
                  style: theme.textTheme.bodyMedium
                      ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                ),
              Gap.h8,
              Align(
                alignment: Alignment.centerLeft,
                child: OutlinedButton.icon(
                  onPressed: () => onEditStarterStep(task.id, task.title),
                  icon: Icon(hasStarterStep ? Icons.edit : Icons.add),
                  label: Text(hasStarterStep
                      ? 'Edit starter step'
                      : 'Add starter step',),
                ),
              ),
            ],
          ),
        ),
        Gap.h12,
        // Action lane (v2): ONE primary CTA + quick timeboxes + secondary actions.
        FilledButton.icon(
          onPressed: () => onStartTimeboxMinutes(2),
          icon: const Icon(Icons.play_arrow),
          label: const Text('Start (2 min)'),
        ),
        Gap.h12,
        Wrap(
          spacing: AppSpace.s8,
          runSpacing: AppSpace.s8,
          children: [
            OutlinedButton(
              onPressed: () => onStartTimeboxMinutes(10),
              child: const Text('10 min'),
            ),
            OutlinedButton(
              onPressed: () => onStartTimeboxMinutes(15),
              child: const Text('15 min'),
            ),
            OutlinedButton(
              onPressed: () => onStartTimeboxMinutes(25),
              child: const Text('25 min'),
            ),
            OutlinedButton(
              onPressed: () => onStartTimeboxMinutes(45),
              child: const Text('45 min'),
            ),
          ],
        ),
        Gap.h12,
        Wrap(
          spacing: AppSpace.s8,
          runSpacing: AppSpace.s8,
          children: [
            OutlinedButton.icon(
              onPressed: onImStuck,
              icon: const Icon(Icons.help_outline),
              label: const Text('I’m stuck'),
            ),
            OutlinedButton.icon(
              onPressed: onSwitchTask,
              icon: const Icon(Icons.swap_horiz),
              label: const Text('Switch task'),
            ),
            OutlinedButton.icon(
              onPressed: () => onExitFocus(),
              icon: const Icon(Icons.close),
              label: const Text('Exit focus'),
            ),
          ],
        ),
      ],
    );
  }
}

class _ActiveFocusTimerCard extends ConsumerStatefulWidget {
  const _ActiveFocusTimerCard({
    required this.ymd,
    required this.timer,
    this.taskTitle,
  });

  final String ymd;
  final ActiveTodayTimer timer;
  final String? taskTitle;

  @override
  ConsumerState<_ActiveFocusTimerCard> createState() =>
      _ActiveFocusTimerCardState();
}

class _ActiveFocusTimerCardState
    extends ConsumerState<_ActiveFocusTimerCard> {
  int? _didScheduleReconcileForStartedAtMs;

  @override
  Widget build(BuildContext context) {
    final now = ref.watch(nowTickerProvider).valueOrNull ?? DateTime.now();
    final remainingRaw = widget.timer.endsAt.difference(now);
    final remaining = remainingRaw.isNegative ? Duration.zero : remainingRaw;
    final totalSeconds = widget.timer.durationMinutes * 60;
    final elapsedSeconds = now.difference(widget.timer.startedAt).inSeconds;
    final progress = totalSeconds > 0
        ? (elapsedSeconds / totalSeconds).clamp(0.0, 1.0)
        : 0.0;

    if (remaining == Duration.zero &&
        _didScheduleReconcileForStartedAtMs != widget.timer.startedAtMs) {
      _didScheduleReconcileForStartedAtMs = widget.timer.startedAtMs;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref
            .read(todayTimeboxControllerProvider(widget.ymd).notifier)
            .reconcileExpiredNow();
      });
    }

    final theme = Theme.of(context);
    final title = (widget.taskTitle ?? '').trim();
    final mmss = _formatMmss(remaining);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpace.s12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: theme.colorScheme.primaryContainer.withOpacity(0.35),
        border: Border.all(color: theme.dividerColor.withOpacity(0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.timer, color: theme.colorScheme.primary),
              Gap.w8,
              Expanded(
                child: Text(
                  'Focus timer',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              Text(
                '${widget.timer.durationMinutes} min',
                style: theme.textTheme.bodySmall,
              ),
            ],
          ),
          Gap.h8,
          Center(
            child: Text(
              mmss,
              style: theme.textTheme.displayMedium?.copyWith(
                fontWeight: FontWeight.w800,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ),
          if (title.isNotEmpty) ...[
            Gap.h4,
            Center(
              child: Text(
                title,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium,
              ),
            ),
          ],
          Gap.h8,
          LinearProgressIndicator(value: progress),
          Gap.h8,
          Text(
            'Ends at ${DateFormat.Hm().format(widget.timer.endsAt)}',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  static String _formatMmss(Duration d) {
    final total = d.inSeconds.clamp(0, 24 * 60 * 60);
    final m = total ~/ 60;
    final s = total % 60;
    return '$m:${s.toString().padLeft(2, '0')}';
  }
}
