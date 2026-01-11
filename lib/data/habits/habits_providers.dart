import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme.dart';
import 'habits_repository.dart';
import 'local_habits_repository.dart';

final habitsRepositoryProvider = Provider<HabitsRepository>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return LocalHabitsRepository(prefs);
});
