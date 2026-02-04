import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/habits/habits_providers.dart';
import '../../../data/habits/habits_repository.dart';
import '../today_models.dart';

final todayHabitsControllerProvider = StateNotifierProvider.family<
    TodayHabitsController, TodayHabitsState, String>((ref, ymd) {
  final repo = ref.watch(habitsRepositoryProvider);
  return TodayHabitsController(habitsRepository: repo, ymd: ymd);
});

class TodayHabitsState {
  const TodayHabitsState({
    required this.habits,
    required this.updatingHabitIds,
    required this.isLoading,
  });

  final List<TodayHabit> habits;
  final Set<String> updatingHabitIds;
  final bool isLoading;

  bool isHabitUpdating(String habitId) => updatingHabitIds.contains(habitId);

  TodayHabitsState copyWith({
    List<TodayHabit>? habits,
    Set<String>? updatingHabitIds,
    bool? isLoading,
  }) {
    return TodayHabitsState(
      habits: habits ?? this.habits,
      updatingHabitIds: updatingHabitIds ?? this.updatingHabitIds,
      isLoading: isLoading ?? this.isLoading,
    );
  }

  static const initial =
      TodayHabitsState(habits: [], updatingHabitIds: {}, isLoading: false);
}

class TodayHabitsController extends StateNotifier<TodayHabitsState> {
  TodayHabitsController({
    required HabitsRepository habitsRepository,
    required String ymd,
  })  : _habitsRepository = habitsRepository,
        _ymd = ymd,
        super(TodayHabitsState.initial) {
    state = state.copyWith(isLoading: true);
    unawaited(_loadHabitsForDay());
  }

  final HabitsRepository _habitsRepository;
  final String _ymd;

  Future<void> _loadHabitsForDay() async {
    try {
      final habits = await _habitsRepository.listHabits();
      final completedIds =
          await _habitsRepository.getCompletedHabitIds(ymd: _ymd);
      state = state.copyWith(
        habits: [
          for (final h in habits)
            TodayHabit(
              id: h.id,
              name: h.name,
              completed: completedIds.contains(h.id),
              createdAtMs: h.createdAtMs,
            ),
        ],
        isLoading: false,
      );
    } catch (_) {
      state = state.copyWith(isLoading: false);
    }
  }

  Future<bool> addHabit({required String name}) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return false;
    try {
      final created = await _habitsRepository.create(name: trimmed);
      state = state.copyWith(
        habits: [
          ...state.habits,
          TodayHabit(
            id: created.id,
            name: created.name,
            completed: false,
            createdAtMs: created.createdAtMs,
          ),
        ],
      );
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> setHabitCompleted({
    required String habitId,
    required bool completed,
  }) async {
    if (state.isHabitUpdating(habitId)) return false;

    final optimisticHabits = [
      for (final h in state.habits)
        if (h.id == habitId) h.copyWith(completed: completed) else h,
    ];
    final previous = state;
    state = state.copyWith(
      habits: optimisticHabits,
      updatingHabitIds: {...state.updatingHabitIds, habitId},
    );

    try {
      await _habitsRepository.setCompleted(
        habitId: habitId,
        ymd: _ymd,
        completed: completed,
      );
      state = state.copyWith(
        updatingHabitIds: {...state.updatingHabitIds}..remove(habitId),
      );
      return true;
    } catch (_) {
      state = previous;
      return false;
    }
  }
}

