import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:win_flutter/app/app.dart';
import 'package:win_flutter/app/env.dart';
import 'package:win_flutter/app/theme.dart';
import 'package:win_flutter/features/today/today_models.dart';

void main() {
  testWidgets(
    'Tapping a task on Today opens Task Details (same as Tasks screen)',
    (WidgetTester tester) async {
      // Seed a local/demo-mode task so the test doesn't rely on Quick add UI.
      final now = DateTime.now();
      final ymd =
          '${now.year.toString().padLeft(4, '0')}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
      final day = TodayDayData(
        ymd: ymd,
        tasks: [
          TodayTask(
            id: 't1',
            title: 'Tap to open details',
            type: TodayTaskType.mustWin,
            date: ymd,
            completed: false,
            inProgress: false,
            createdAt: DateTime.fromMillisecondsSinceEpoch(1),
          ),
        ],
        habits: const [],
        reflection: '',
        focusModeEnabled: false,
        focusTaskId: null,
        activeTimebox: null,
      );
      SharedPreferences.setMockInitialValues({
        'today_day_$ymd': day.toJsonString(),
      });
      final prefs = await SharedPreferences.getInstance();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            // Demo mode avoids auth/setup redirects; Today will use local-only tasks.
            envProvider.overrideWithValue(
              Env(supabaseUrl: '', supabaseAnonKey: '', demoMode: true),
            ),
          ],
          child: const AppRoot(),
        ),
      );
      await tester.pumpAndSettle();

      const title = 'Tap to open details';

      Finder scrollable() => find.byType(Scrollable).first;

      // Scroll to the Must‑Wins section and then to the task row title.
      final mustWinsHeader = find.text('Must‑Wins');
      await tester.scrollUntilVisible(mustWinsHeader, 250, scrollable: scrollable());

      final taskRow = find.text(title);
      await tester.scrollUntilVisible(taskRow, 250, scrollable: scrollable());
      final rowTile =
          find.ancestor(of: taskRow, matching: find.byType(ListTile)).first;

      // Trigger the same callback path as a user tap. (Using the callback
      // directly avoids flakiness around gesture disambiguation in widget tests
      // when multiple detectors are present.)
      final tile = tester.widget<ListTile>(rowTile);
      expect(tile.onTap, isNotNull);
      tile.onTap!();
      await tester.pumpAndSettle();

      // AppScaffold title for the details screen.
      expect(find.text('Task Details'), findsWidgets);
    },
  );
}

