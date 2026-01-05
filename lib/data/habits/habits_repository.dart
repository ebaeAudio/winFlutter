import 'habit.dart';

abstract class HabitsRepository {
  Future<List<Habit>> listHabits();

  Future<Habit> create({required String name});

  /// Returns habit IDs completed for the given day.
  Future<Set<String>> getCompletedHabitIds({required String ymd});

  Future<void> setCompleted({
    required String habitId,
    required String ymd,
    required bool completed,
  });
}


