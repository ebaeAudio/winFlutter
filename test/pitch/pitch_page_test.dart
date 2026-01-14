import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:win_flutter/app/theme.dart';
import 'package:win_flutter/features/pitch/pitch_content.dart';
import 'package:win_flutter/features/pitch/pitch_page.dart';
import 'package:win_flutter/features/pitch/ui/hero.dart';

void main() {
  Future<void> setDesktopSurface(WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(1000, 900));
    addTearDown(() async => tester.binding.setSurfaceSize(null));
  }

  testWidgets('PitchPage renders hero copy', (WidgetTester tester) async {
    await setDesktopSurface(tester);
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
        child: const MaterialApp(home: PitchPage()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text(pitchContent.hero.headline), findsOneWidget);
    final hero = find.byType(HeroSection);
    expect(
      find.descendant(
        of: hero,
        matching: find.widgetWithText(FilledButton, pitchContent.hero.primaryCtaLabel),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: hero,
        matching:
            find.widgetWithText(OutlinedButton, pitchContent.hero.secondaryCtaLabel),
      ),
      findsOneWidget,
    );
  });

  testWidgets('Primary CTA triggers provided callback',
      (WidgetTester tester) async {
    await setDesktopSurface(tester);
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();

    var called = false;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
        child: MaterialApp(
          home: PitchPage(
            onPrimaryCta: () => called = true,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final hero = find.byType(HeroSection);
    await tester.tap(
      find.descendant(
        of: hero,
        matching: find.widgetWithText(FilledButton, pitchContent.hero.primaryCtaLabel),
      ),
    );
    await tester.pump();

    expect(called, isTrue);
  });

  testWidgets('FAQ accordion expands and collapses',
      (WidgetTester tester) async {
    await setDesktopSurface(tester);
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
        child: const MaterialApp(home: PitchPage()),
      ),
    );
    await tester.pumpAndSettle();

    final first = pitchContent.faq.items.first;
    final question = find.widgetWithText(ListTile, first.question).at(0);
    final answer = find.text(first.answer);

    await tester.scrollUntilVisible(question, 200);
    expect(answer, findsNothing);

    await tester.tap(question);
    await tester.pumpAndSettle();
    expect(answer, findsOneWidget);

    await tester.tap(question);
    await tester.pumpAndSettle();
    expect(answer, findsNothing);
  });
}

