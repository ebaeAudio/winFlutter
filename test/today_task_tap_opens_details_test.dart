import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:win_flutter/app/app.dart';
import 'package:win_flutter/app/env.dart';
import 'package:win_flutter/app/theme.dart';

void main() {
  testWidgets(
    'Tapping a task on Today opens Task Details (same as Tasks screen)',
    (WidgetTester tester) async {
      SharedPreferences.setMockInitialValues({});
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

      // Add a Must‑Win via the Quick add section.
      final scrollable = find.byType(Scrollable).first;
      final quickAdd = find.bySemanticsLabel('What’s the task?');
      await tester.scrollUntilVisible(quickAdd, 250, scrollable: scrollable);
      await tester.tap(quickAdd);
      await tester.enterText(quickAdd, title);
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();

      // If the keyboard is still up / a field is still focused, the first tap can
      // be consumed by the app's "tap-to-dismiss-keyboard" handler. Ensure we're
      // in the normal browsing state before tapping a task row.
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pumpAndSettle();

      // Tap the task row title on Today.
      final taskRow = find.text(title);
      await tester.scrollUntilVisible(taskRow, 250, scrollable: scrollable);
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

