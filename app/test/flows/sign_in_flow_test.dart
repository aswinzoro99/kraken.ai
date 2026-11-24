import 'package:flutter_test/flutter_test.dart';
import 'package:kraken/ui_kit/ui_kit.dart';
import 'package:material_ui/material_ui.dart';

import '../helpers/test_app.dart';

/// A rolling figure showing [value] (its digits are separate wheels).
Finder rolling(String value) => find.byWidgetPredicate((w) => w is KRollingNumber && w.text == value);

Future<void> say(WidgetTester tester, String text) async {
  await tester.enterText(find.byType(TextField), text);
  await tester.pump();
  await tester.tap(find.bySemanticsLabel('Send'));
  await tester.pumpAndSettle();
}

Future<void> chip(WidgetTester tester, String label) async {
  await tester.tap(find.widgetWithText(KChip, label));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('a new person signs up by chat and lands on Home', (tester) async {
    final app = await pumpKraken(tester);

    expect(find.text('Get started'), findsOneWidget);
    await tester.tap(find.text('Get started'));
    await tester.pumpAndSettle();
    expect(find.textContaining("What's your email address?"), findsOneWidget);

    await say(tester, 'not an email');
    expect(find.textContaining("doesn't look like an email"), findsOneWidget);
    expect(app.haptics.played, contains(HapticKind.error));

    await say(tester, 'Aarav@Example.com');
    expect(find.textContaining('sent a 6-digit code to aarav@example.com'), findsOneWidget);
    expect(find.textContaining('Mock inbox'), findsOneWidget);

    await say(tester, app.inbox.value!.code);
    expect(find.text("You're verified."), findsOneWidget);

    await say(tester, 'Aarav');
    await chip(tester, "Yes, I'm 18 or older");
    await chip(tester, 'I agree');
    await chip(tester, 'Yes, share usage stats');
    await chip(tester, 'Skip for now');
    await chip(tester, 'Skip for now');
    expect(find.text('All set. Tap below to see your groups.'), findsOneWidget);

    await tester.tap(find.text('Open your groups'));
    await tester.pumpAndSettle();
    expect(find.text('Spent so far in November'), findsOneWidget);
    expect(rolling('₹21,500'), findsOneWidget);
    expect(find.text('35% more than 1–24 Oct'), findsOneWidget);
    expect(find.text('Meera'), findsOneWidget);
    expect(app.haptics.played, containsAll([HapticKind.success, HapticKind.selection, HapticKind.tap]));

    final names = app.services.recorder.names.toList();
    expect(
      names,
      containsAllInOrder([
        'welcome_start_tapped',
        'sign_in_email_submitted',
        'sign_in_code_requested',
        'sign_in_completed',
        'consent_recorded',
        'onboarding_completed',
      ]),
    );
    expect(names, contains('screen_view'));
  });

  testWidgets('a returning person goes straight to Home, and can sign out', (tester) async {
    final first = await pumpKraken(tester);
    await tester.tap(find.text('Get started'));
    await tester.pumpAndSettle();
    await say(tester, 'meera@example.com');
    await say(tester, first.inbox.value!.code);
    await say(tester, 'Meera');
    await chip(tester, "Yes, I'm 18 or older");
    await chip(tester, 'I agree');
    await chip(tester, 'No thanks');
    await chip(tester, 'Skip for now');
    await chip(tester, 'Create a new group');
    await tester.tap(find.text('Open your groups'));
    await tester.pumpAndSettle();

    // Restart the app on the same storage: the session is restored.
    await tester.pumpWidget(const SizedBox());
    await pumpKraken(tester, store: first.store);
    expect(find.text('Spent so far in November'), findsOneWidget);

    expect(first.services.recorder.events, isEmpty, reason: 'usage stats were refused, so nothing is sent');

    await tester.tap(find.bySemanticsLabel('Account'));
    await tester.pumpAndSettle();
    expect(find.text('Meera'), findsOneWidget);
    await tester.ensureVisible(find.widgetWithText(KNavRow, 'Sign out'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(KNavRow, 'Sign out'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(KButton, 'Sign out'));
    await tester.pumpAndSettle();
    expect(find.text('Get started'), findsOneWidget);
  });

  testWidgets('an empty account shows the empty state', (tester) async {
    final app = await pumpKraken(tester, emptyGroups: true);
    await tester.tap(find.text('Get started'));
    await tester.pumpAndSettle();
    await say(tester, 'new@example.com');
    await say(tester, app.inbox.value!.code);
    await say(tester, 'Sreya');
    await chip(tester, "Yes, I'm 18 or older");
    await chip(tester, 'I agree');
    await chip(tester, 'No thanks');
    await chip(tester, 'Skip for now');
    await chip(tester, 'Skip for now');
    await tester.tap(find.text('Open your groups'));
    await tester.pumpAndSettle();
    expect(find.text('No groups yet'), findsOneWidget);
  });

  testWidgets('quick actions open from any tab, and scrolling shrinks the tab bar', (tester) async {
    final app = await pumpKraken(tester);
    await tester.tap(find.text('Get started'));
    await tester.pumpAndSettle();
    await say(tester, 'kavya@example.com');
    await say(tester, app.inbox.value!.code);
    await say(tester, 'Kavya');
    await chip(tester, "Yes, I'm 18 or older");
    await chip(tester, 'I agree');
    await chip(tester, 'Yes, share usage stats');
    await chip(tester, 'Skip for now');
    await chip(tester, 'Skip for now');
    await tester.tap(find.text('Open your groups'));
    await tester.pumpAndSettle();

    await tester.tap(find.bySemanticsLabel('Quick actions'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Scan a bill'));
    await tester.pumpAndSettle();
    expect(find.text('Bill scanning arrives in Phase 5.'), findsOneWidget);
    expect(app.services.recorder.names, containsAllInOrder(['quick_actions_opened', 'quick_action_used']));

    // Scrolling down shrinks the bar (every tab stays); back up restores it.
    double barHeight() => tester.getSize(find.byKey(KBottomNav.capsuleKey)).height;
    expect(barHeight(), KBottomNav.height);
    await tester.drag(find.byType(Scrollable).first, const Offset(0, -300));
    await tester.pumpAndSettle();
    expect(barHeight(), KBottomNav.minimizedHeight);
    for (final tab in ['Home', 'Friends', 'Insights', 'Activity', 'Account']) {
      expect(find.bySemanticsLabel(tab).hitTestable(), findsOneWidget, reason: tab);
    }
    await tester.drag(find.byType(Scrollable).first, const Offset(0, 300));
    await tester.pumpAndSettle();
    expect(barHeight(), KBottomNav.height);
  });

  testWidgets('Appearance in Account switches the theme and is kept after a restart', (tester) async {
    final first = await pumpKraken(tester);
    await tester.tap(find.text('Get started'));
    await tester.pumpAndSettle();
    await say(tester, 'aarav@example.com');
    await say(tester, first.inbox.value!.code);
    await say(tester, 'Aarav');
    await chip(tester, "Yes, I'm 18 or older");
    await chip(tester, 'I agree');
    await chip(tester, 'Yes, share usage stats');
    await chip(tester, 'Skip for now');
    await chip(tester, 'Skip for now');
    await tester.tap(find.text('Open your groups'));
    await tester.pumpAndSettle();

    ThemeMode? mode() => tester.widget<MaterialApp>(find.byType(MaterialApp)).themeMode;
    expect(mode(), ThemeMode.system);

    await tester.tap(find.bySemanticsLabel('Account'));
    await tester.pumpAndSettle();
    await tester.tap(find.bySemanticsLabel('Dark'));
    await tester.pumpAndSettle();
    expect(mode(), ThemeMode.dark);
    expect(Theme.of(tester.element(find.text('Appearance'))).brightness, Brightness.dark);
    final event = first.services.recorder.events.lastWhere((e) => e.name == 'appearance_changed');
    expect(event.params, {'appearance': 'dark'});

    // Restart on the same storage: still dark.
    await tester.pumpWidget(const SizedBox());
    await pumpKraken(tester, store: first.store);
    expect(mode(), ThemeMode.dark);
  });

  testWidgets('Home: a welcome, a chart toggle that is remembered, and pull to refresh', (tester) async {
    final first = await pumpKraken(tester);
    await tester.tap(find.text('Get started'));
    await tester.pumpAndSettle();
    await say(tester, 'aarav@example.com');
    await say(tester, first.inbox.value!.code);
    await say(tester, 'Aarav');
    await chip(tester, "Yes, I'm 18 or older");
    await chip(tester, 'I agree');
    await chip(tester, 'Yes, share usage stats');
    await chip(tester, 'Skip for now');
    await chip(tester, 'Skip for now');
    await tester.tap(find.text('Open your groups'));
    await tester.pumpAndSettle();

    expect(find.text('Welcome, Aarav'), findsOneWidget);
    expect(find.byType(KTrendBars), findsOneWidget);
    await tester.tap(find.bySemanticsLabel('Line chart'));
    await tester.pumpAndSettle();
    expect(find.byType(KTrendLine), findsOneWidget);
    expect(find.byType(KTrendBars), findsNothing);

    // Pull down past the line: the kraken arms, refreshes, then says so.
    final pull = await tester.startGesture(tester.getCenter(find.text('Welcome, Aarav')));
    for (var i = 0; i < 20; i++) {
      await pull.moveBy(const Offset(0, 15));
      await tester.pump(const Duration(milliseconds: 16));
    }
    expect(find.text('Release to refresh'), findsOneWidget);
    await pull.up();
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.text('Refreshing…'), findsOneWidget);
    // Step through the refresh, noting each label as it changes.
    final seen = <String>[];
    for (var i = 0; i < 30; i++) {
      await tester.pump(const Duration(milliseconds: 100));
      for (final label in ['Refreshing…', 'Up to date', 'Pull down to refresh']) {
        if (find.text(label).evaluate().isNotEmpty && (seen.isEmpty || seen.last != label)) seen.add(label);
      }
    }
    expect(seen, containsAllInOrder(['Refreshing…', 'Up to date']));
    await tester.pumpAndSettle();
    expect(find.text('Up to date'), findsNothing);
    expect(find.text('Spent so far in November'), findsOneWidget);

    final actions = [
      for (final e in first.services.recorder.events)
        if (e.name == 'home_action') e.params['action'],
    ];
    expect(actions, containsAllInOrder(['chart_line', 'refresh']));
    expect(first.haptics.played, containsAllInOrder([HapticKind.selection, HapticKind.success]));

    // Restart on the same storage: still the line chart.
    await tester.pumpWidget(const SizedBox());
    await pumpKraken(tester, store: first.store);
    expect(find.byType(KTrendLine), findsOneWidget);
  });
}
