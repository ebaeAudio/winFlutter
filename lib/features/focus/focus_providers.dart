import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme.dart' show sharedPreferencesProvider;
import '../../data/focus/focus_policy_repository.dart';
import '../../data/focus/focus_session_repository.dart';
import '../../data/focus/local_focus_policy_repository.dart';
import '../../data/focus/local_focus_session_repository.dart';
import '../../platform/restriction_engine/restriction_engine.dart';
import '../../platform/restriction_engine/restriction_engine_channel.dart';

final focusPolicyRepositoryProvider = Provider<FocusPolicyRepository>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return LocalFocusPolicyRepository(prefs);
});

final focusSessionRepositoryProvider = Provider<FocusSessionRepository>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return LocalFocusSessionRepository(prefs);
});

final restrictionEngineProvider = Provider<RestrictionEngine>((ref) {
  return const MethodChannelRestrictionEngine();
});
