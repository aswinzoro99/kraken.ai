import 'package:flutter_test/flutter_test.dart';
import 'package:kraken/app/composition.dart';
import 'package:kraken/ui_kit/ui_kit.dart';
import 'package:material_ui/material_ui.dart';

import '../helpers/test_app.dart';

Future<void> openLogin(WidgetTester tester) async {
  await getStarted(tester);
}

Future<void> tapText(WidgetTester tester, String text) async {
  await tester.ensureVisible(find.text(text));
  await tester.pumpAndSettle();
  await tester.tap(find.text(text));
  await tester.pumpAndSettle();
}

Future<void> finishSignUp(WidgetTester tester) async {
  expect(find.text('Almost done'), findsOneWidget);
  await tester.tap(find.text("I'm 18 or older"));
  await tester.tap(find.text('I agree to the Terms and Privacy Policy'));
  await tester.pump();
  await tester.ensureVisible(find.text('Start using Kraken'));
  await tester.tap(find.text('Start using Kraken'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('sign up with an email code, then finish and land on Home', (tester) async {
    final app = await pumpKraken(tester);
    await openLogin(tester);
    expect(find.text('Welcome back'), findsOneWidget);

    await tester.tap(find.bySemanticsLabel('Sign up'));
    await tester.pumpAndSettle();
    expect(find.text('Create your account'), findsOneWidget);

    // Both fields are checked before anything is sent.
    await tapText(tester, 'Email me a code');
    expect(find.text('Enter the name your friends will see.'), findsOneWidget);
    expect(find.text('Enter an email address like name@example.com.'), findsOneWidget);

    await tester.enterText(find.widgetWithText(KTextField, 'Your name'), 'Priya');
    await tester.enterText(find.widgetWithText(KTextField, 'Email'), 'priya@example.com');
    await tapText(tester, 'Email me a code');
    expect(find.text('Check your email'), findsOneWidget);

    // A wrong code says so and how many tries are left.
    await tester.enterText(
      find.widgetWithText(KTextField, 'Code'),
      app.inbox.value!.code == '000000' ? '111111' : '000000',
    );
    await tester.pumpAndSettle();
    expect(find.textContaining("That code isn't right"), findsOneWidget);

    await tester.tap(find.text('Use code'));
    await tester.pumpAndSettle();

    // The name from sign-up is already filled in; the button waits for both boxes.
    expect(find.widgetWithText(TextField, 'Priya'), findsOneWidget);
    expect(tester.widget<KButton>(find.widgetWithText(KButton, 'Start using Kraken')).onPressed, isNull);
    await finishSignUp(tester);
    expect(find.text('Welcome, Priya'), findsOneWidget);
    expect(find.text('Spent so far in November'), findsOneWidget);
  });

  testWidgets('Google signs up with the shared name, and logs straight in next time', (tester) async {
    final first = await pumpKraken(tester);
    await openLogin(tester);
    await tester.tap(find.bySemanticsLabel('Continue with Google'));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(TextField, 'Kraken Tester'), findsOneWidget);
    await finishSignUp(tester);
    expect(find.text('Welcome, Kraken Tester'), findsOneWidget);

    // Relaunch (signed out), then Google again: a returning account goes home.
    await tester.pumpWidget(const SizedBox());
    await startSignedOut(first.store);
    await pumpKraken(tester, store: first.store);
    await openLogin(tester);
    await tester.tap(find.bySemanticsLabel('Continue with Apple'));
    await tester.pumpAndSettle();
    expect(find.text('Almost done'), findsOneWidget, reason: 'Apple is a different account');
    await tapText(tester, 'Not you?');
    await tester.tap(find.bySemanticsLabel('Continue with Google'));
    await tester.pumpAndSettle();
    expect(find.text('Welcome, Kraken Tester'), findsOneWidget);
  });

  testWidgets('a returning email account logs straight in', (tester) async {
    final first = await pumpKraken(tester);
    await openLogin(tester);
    await tester.tap(find.bySemanticsLabel('Continue with Google'));
    await tester.pumpAndSettle();
    await finishSignUp(tester);

    await tester.pumpWidget(const SizedBox());
    await startSignedOut(first.store);
    final second = await pumpKraken(tester, store: first.store);
    await openLogin(tester);
    await tester.enterText(find.widgetWithText(KTextField, 'Email'), 'kraken.tester@gmail.com');
    await tapText(tester, 'Email me a code');
    await tester.enterText(find.widgetWithText(KTextField, 'Code'), second.inbox.value!.code);
    await tester.pumpAndSettle();
    expect(find.text('Welcome, Kraken Tester'), findsOneWidget);
  });

  testWidgets('the Kraken logo opens the agent sign-up, and back returns here', (tester) async {
    await pumpKraken(tester);
    await openLogin(tester);
    await tester.tap(find.bySemanticsLabel('Chat with Kraken'));
    await tester.pumpAndSettle();
    expect(find.byType(ChatBubble), findsWidgets);
    await tester.tap(find.bySemanticsLabel('Back'));
    await tester.pumpAndSettle();
    expect(find.text('Welcome back'), findsOneWidget);
  });
}
