import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/auth/auth_screen.dart';
import '../features/home/home_screen.dart';
import '../features/focus/ui/focus_entry_screen.dart';
import '../features/focus/ui/focus_history_screen.dart';
import '../features/focus/ui/focus_policies_screen.dart';
import '../features/focus/ui/focus_policy_editor_screen.dart';
import '../features/rollups/rollups_screen.dart';
import '../features/settings/settings_screen.dart';
import '../features/settings/trackers/tracker_editor_screen.dart';
import '../features/settings/trackers/trackers_screen.dart';
import '../features/setup/setup_screen.dart';
import '../features/today/today_screen.dart';
import '../features/tasks/task_details_screen.dart';
import 'auth.dart';

final _routerRefreshNotifierProvider = Provider<_RouterRefreshNotifier>((ref) {
  final notifier = _RouterRefreshNotifier();
  // Any auth state change should refresh the router so redirects apply.
  ref.listen(authStateProvider, (_, __) => notifier.refresh());
  ref.onDispose(notifier.dispose);
  return notifier;
});

final routerProvider = Provider<GoRouter>((ref) {
  final auth = ref.watch(authStateProvider).valueOrNull;
  final refreshNotifier = ref.watch(_routerRefreshNotifierProvider);

  return GoRouter(
    initialLocation: '/home',
    refreshListenable: refreshNotifier,
    redirect: (context, state) {
      final isSignedIn = auth?.isSignedIn == true;
      final needsSetup = auth?.needsSetup == true;

      final goingToAuth = state.matchedLocation == '/auth';
      final goingToSetup = state.matchedLocation == '/setup';

      if (needsSetup) {
        return goingToSetup ? null : '/setup';
      }

      if (!isSignedIn) {
        return goingToAuth ? null : '/auth';
      }

      if (isSignedIn && (goingToAuth || goingToSetup)) {
        return '/home';
      }

      return null;
    },
    routes: [
      GoRoute(
        path: '/setup',
        builder: (context, state) => const SetupScreen(),
      ),
      GoRoute(
        path: '/auth',
        builder: (context, state) => const AuthScreen(),
      ),
      GoRoute(
        path: '/home',
        builder: (context, state) => const HomeScreen(),
        routes: [
          GoRoute(
            path: 'today',
            builder: (context, state) => const TodayScreen(),
            routes: [
              GoRoute(
                path: 'task/:id',
                builder: (context, state) => TaskDetailsScreen(
                  taskId: state.pathParameters['id'] ?? '',
                  ymd: state.uri.queryParameters['ymd'] ?? '',
                ),
              ),
            ],
          ),
          GoRoute(
            path: 'focus',
            builder: (context, state) => const FocusEntryScreen(),
            routes: [
              GoRoute(
                path: 'policies',
                builder: (context, state) => const FocusPoliciesScreen(),
                routes: [
                  GoRoute(
                    path: 'edit/:id',
                    builder: (context, state) => FocusPolicyEditorScreen(
                      policyId: state.pathParameters['id'] ?? '',
                      closeOnSave:
                          (state.uri.queryParameters['closeOnSave'] ?? '') == '1',
                    ),
                  ),
                ],
              ),
              GoRoute(
                path: 'history',
                builder: (context, state) => const FocusHistoryScreen(),
              ),
            ],
          ),
          GoRoute(
            path: 'rollups',
            builder: (context, state) => const RollupsScreen(),
          ),
          GoRoute(
            path: 'settings',
            builder: (context, state) => const SettingsScreen(),
            routes: [
              GoRoute(
                path: 'trackers',
                builder: (context, state) => const TrackersScreen(),
                routes: [
                  GoRoute(
                    path: 'new',
                    builder: (context, state) =>
                        const TrackerEditorScreen(trackerId: null),
                  ),
                  GoRoute(
                    path: 'edit/:id',
                    builder: (context, state) => TrackerEditorScreen(
                      trackerId: state.pathParameters['id'],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    ],
  );
});

class _RouterRefreshNotifier extends ChangeNotifier {
  void refresh() => notifyListeners();
}
