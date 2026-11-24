import 'package:flutter_test/flutter_test.dart';
import 'package:kraken/ui_kit/ui_kit.dart';
import 'package:material_ui/material_ui.dart';

import '../helpers/test_app.dart';

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
    expect(find.text('₹21,500'), findsOneWidget);
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

    await tester.tap(find.text('Account'));
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
}
