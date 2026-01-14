import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/auth/auth_screen.dart';
import '../features/auth/password_recovery_screen.dart';
import '../features/focus/ui/focus_entry_screen.dart';
import '../features/focus/ui/focus_history_screen.dart';
import '../features/focus/ui/focus_policies_screen.dart';
import '../features/focus/ui/focus_policy_editor_screen.dart';
import '../features/projects/projects_screen.dart';
import '../features/rollups/rollups_screen.dart';
import '../features/settings/settings_screen.dart';
import '../features/settings/trackers/tracker_editor_screen.dart';
import '../features/settings/trackers/trackers_screen.dart';
import '../features/setup/setup_screen.dart';
import '../features/feedback/feedback_screen.dart';
import '../features/pitch/pitch_page.dart';
import '../features/tasks/all_tasks_screen.dart';
import '../features/today/today_screen.dart';
import '../features/tasks/task_details_screen.dart';
import '../ui/nav_shell.dart';
import 'auth.dart';

String? _safeRelativeLocationFromNextParam(String? nextParam) {
  if (nextParam == null || nextParam.trim().isEmpty) return null;
  final decoded = Uri.decodeComponent(nextParam.trim());

  // Only allow safe, app-internal relative paths.
  if (!decoded.startsWith('/')) return null;
  final uri = Uri.tryParse(decoded);
  if (uri == null) return null;
  if (uri.hasScheme || uri.hasAuthority) return null;

  return uri.toString();
}

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
    initialLocation: '/today',
    refreshListenable: refreshNotifier,
    redirect: (context, state) {
      final isSignedIn = auth?.isSignedIn == true;
      final needsSetup = auth?.needsSetup == true;
      final needsPasswordReset = auth?.needsPasswordReset == true;

      final goingToAuth = state.matchedLocation == '/auth';
      final goingToSetup = state.matchedLocation == '/setup';
      final goingToPasswordRecovery = state.matchedLocation == '/auth/recovery';

      if (needsSetup) {
        return goingToSetup ? null : '/setup';
      }

      if (needsPasswordReset) {
        return goingToPasswordRecovery ? null : '/auth/recovery';
      }

      if (!isSignedIn) {
        // Allow the recovery route to show a helpful "invalid/expired link"
        // state even if a session couldn't be established.
        if (goingToPasswordRecovery) return null;
        if (goingToAuth) return null;
        final next = Uri.encodeComponent(state.uri.toString());
        return '/auth?next=$next';
      }

      if (isSignedIn && (goingToAuth || goingToSetup)) {
        final safeNext = _safeRelativeLocationFromNextParam(
            state.uri.queryParameters['next']);
        return safeNext ?? '/today';
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
        builder: (context, state) => AuthScreen(
          next: state.uri.queryParameters['next'],
        ),
      ),
      GoRoute(
        path: '/auth/recovery',
        builder: (context, state) => const PasswordRecoveryScreen(),
      ),
      GoRoute(
        // Legacy URLs (keep for safety): redirect /home/* -> /* while preserving query params.
        path: '/home',
        redirect: (context, state) => '/today',
        routes: [
          GoRoute(
            path: ':rest(.*)',
            redirect: (context, state) {
              final rest = state.pathParameters['rest'] ?? '';
              final query = state.uri.hasQuery ? '?${state.uri.query}' : '';
              return '/$rest$query';
            },
          ),
        ],
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) =>
            NavShell(navigationShell: navigationShell),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/projects',
                builder: (context, state) => const ProjectsScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/tasks',
                builder: (context, state) => const AllTasksScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/today',
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
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/focus',
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
                              (state.uri.queryParameters['closeOnSave'] ??
                                      '') ==
                                  '1',
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
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/settings',
                builder: (context, state) => const SettingsScreen(),
                routes: [
                  GoRoute(
                    path: 'rollups',
                    builder: (context, state) => const RollupsScreen(),
                  ),
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
                  GoRoute(
                    path: 'feedback',
                    builder: (context, state) => FeedbackScreen(
                      entryPoint: state.uri.queryParameters['entryPoint'],
                    ),
                  ),
                  GoRoute(
                    path: 'pitch',
                    builder: (context, state) => const PitchPage(),
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
