import 'package:flutter_test/flutter_test.dart';
import 'package:kraken/features/groups/data/mock_groups_repository.dart';
import 'package:kraken/ui_kit/ui_kit.dart';
import 'package:material_ui/material_ui.dart';

import '../helpers/test_app.dart';
import 'login_flow_test.dart' show finishSignUp, openLogin, tapText;

Future<void> signUpWithGoogle(WidgetTester tester) async {
  await openLogin(tester);
  await tester.tap(find.bySemanticsLabel('Continue with Google'));
  await tester.pumpAndSettle();
  await finishSignUp(tester);
}

void main() {
  testWidgets('make a group, add an expense split by shares, then delete it and Undo', (tester) async {
    await pumpKraken(tester, emptyGroups: true);
    await signUpWithGoogle(tester);
    expect(find.text('No groups yet'), findsOneWidget);

    // New group: a name and one friend.
    await tester.tap(find.text('Create a group'));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(KTextField, 'Group name'), 'Pondy');
    await tester.enterText(find.widgetWithText(KTextField, 'Friends'), 'Kiran');
    await tester.tap(find.widgetWithText(KButton, 'Add'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(KButton, 'Create group'));
    await tester.pumpAndSettle();
    expect(find.text('Pondy'), findsOneWidget);
    expect(find.text('Nothing added yet'), findsOneWidget);

    // Add ₹900 for dinner; Kiran has two shares.
    await tester.tap(find.widgetWithText(KButton, 'Add expense').first);
    await tester.pumpAndSettle();
    expect(find.text('Add expense'), findsOneWidget);
    expect(find.text('Enter the amount'), findsOneWidget);
    await tester.enterText(find.byType(TextField).first, '900');
    await tester.enterText(find.widgetWithText(KTextField, 'Description'), 'Dinner');
    await tester.pump();
    expect(find.text('₹450 each · 2 people'), findsOneWidget);
    await tester.tap(find.text('Shares'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.bySemanticsLabel('One more share for Kiran'));
    await tester.pumpAndSettle();
    await tester.tap(find.bySemanticsLabel('One more share for Kiran'));
    await tester.pumpAndSettle();
    expect(find.text('3 shares · ₹300 per share'), findsOneWidget);
    await tester.tap(find.text('Save to Pondy'));
    await tester.pumpAndSettle();

    expect(find.text('Expense added'), findsOneWidget);
    expect(find.text('Dinner'), findsOneWidget);
    expect(find.text('Overall, you’re owed ₹600'), findsOneWidget);
    expect(find.text('owes you'), findsOneWidget);
    expect(find.text('Kiran pays you'), findsOneWidget, reason: 'who owes whom');
    // Let the message go; it sits over the newest row.
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();

    // Open it (scrolled clear of the tab bar): it comes back as entered.
    await tester.drag(find.byType(CustomScrollView), const Offset(0, -300));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Dinner'));
    await tester.pumpAndSettle();
    expect(find.text('Edit expense'), findsOneWidget);
    expect(find.text('3 shares · ₹300 per share'), findsOneWidget);

    // Delete, then Undo.
    await tester.ensureVisible(find.text('Delete expense'));
    await tester.tap(find.text('Delete expense'));
    await tester.pumpAndSettle();
    expect(find.text('Deleted “Dinner”'), findsOneWidget);
    expect(find.text('Dinner'), findsNothing);
    await tester.tap(find.text('Undo'));
    await tester.pumpAndSettle();
    expect(find.text('Dinner'), findsOneWidget);
    expect(find.text('Overall, you’re owed ₹600'), findsOneWidget);

    // The group's history, newest first.
    await tapText(tester, 'Activity');
    expect(find.text('You restored “Dinner”'), findsOneWidget);
    expect(find.text('You deleted “Dinner”'), findsOneWidget);
    expect(find.text('You added “Dinner”'), findsOneWidget);
    await tester.pump(const Duration(seconds: 6));
    await tester.pumpAndSettle();
  });

  testWidgets('the form waits until the split adds up', (tester) async {
    await pumpKraken(tester);
    await signUpWithGoogle(tester);
    // The group row, below the balances that also name the group.
    await tester.ensureVisible(find.text('Goa Trip').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Goa Trip').last);
    await tester.pumpAndSettle();
    expect(find.text('Overall, you owe ₹150'), findsOneWidget);
    expect(find.text('Who owes whom'), findsOneWidget);

    await tester.tap(find.widgetWithText(KButton, 'Add expense'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, '3300');
    await tester.enterText(find.widgetWithText(KTextField, 'Description'), 'Dinner at Coastal Kitchen');
    await tester.tap(find.text('Exact'));
    await tester.pumpAndSettle();
    await tester.enterText(find.bySemanticsLabel('Amount for You'), '900');
    await tester.pump();
    expect(find.text('₹2,400 left to assign'), findsOneWidget);

    // Saving now does nothing.
    await tester.tap(find.text('Save to Goa Trip'));
    await tester.pumpAndSettle();
    expect(find.text('Add expense'), findsOneWidget);

    await tester.enterText(find.bySemanticsLabel('Amount for Sreya'), '700');
    await tester.enterText(find.bySemanticsLabel('Amount for Arjun'), '1000');
    await tester.enterText(find.bySemanticsLabel('Amount for Meera'), '700');
    await tester.pump();
    expect(find.text('Adds up to ₹3,300'), findsOneWidget);
    await tester.tap(find.text('Save to Goa Trip'));
    await tester.pumpAndSettle();
    // You paid 3,300 and owe 900 of it: owed 2,400 more than before.
    expect(find.text('Overall, you’re owed ₹2,250'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Dinner at Coastal Kitchen'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Dinner at Coastal Kitchen'), findsOneWidget);
  });

  testWidgets('a friend joins with an invite code and picks their name', (tester) async {
    final app = await pumpKraken(tester, emptyGroups: true);
    final repo = app.services.groups as MockGroupsRepository;
    // Someone else's group, with an open name.
    final g = await repo.createGroup(uid: 'friend', yourName: 'Meera', name: 'Book club', friendNames: ['Tester']);
    final invite = await repo.createInvite('friend', g.id);

    await signUpWithGoogle(tester);
    await tester.tap(find.text('Create a group'));
    await tester.pumpAndSettle();
    await tapText(tester, 'Have an invite? Join a group');
    await tester.enterText(find.widgetWithText(KTextField, 'Invite code'), invite.code.toLowerCase());
    await tester.tap(find.text('Find group'));
    await tester.pumpAndSettle();
    expect(find.text('Join Book club'), findsWidgets);
    expect(find.text('Which name is yours?'), findsOneWidget);
    // The only open name is already picked.
    await tester.tap(find.widgetWithText(KButton, 'Join Book club'));
    await tester.pumpAndSettle();
    expect(find.text('Book club'), findsOneWidget);
    expect(find.text('You, Meera'), findsOneWidget);
  });

  testWidgets('Friends and Activity tabs show who owes what and what happened', (tester) async {
    await pumpKraken(tester);
    await signUpWithGoogle(tester);
    await tester.tap(find.bySemanticsLabel('Friends'));
    await tester.pumpAndSettle();
    expect(find.text('Meera'), findsOneWidget);
    expect(find.text('Balances'), findsOneWidget);

    await tester.tap(find.bySemanticsLabel('Activity'));
    await tester.pumpAndSettle();
    expect(find.textContaining('added “'), findsWidgets);
  });
}
