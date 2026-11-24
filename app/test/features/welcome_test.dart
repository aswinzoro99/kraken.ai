import 'package:flutter_test/flutter_test.dart';
import 'package:kraken/app/composition.dart';
import 'package:kraken/ui_kit/ui_kit.dart';
import 'package:material_ui/material_ui.dart';

import '../helpers/test_app.dart';

void main() {
  testWidgets('the welcome slider swipes through what Kraken does', (tester) async {
    final app = await pumpKraken(tester);
    expect(find.text('Split bills, not friendships'), findsOneWidget);
    expect(find.bySemanticsLabel('Slide 1 of 4'), findsOneWidget);

    await tester.fling(find.byType(PageView), const Offset(-400, 0), 1000);
    await tester.pumpAndSettle();
    expect(find.text('Just say it'), findsOneWidget);
    expect(app.haptics.played, contains(HapticKind.selection));
    // Its demo plays through: you talk, then the chat and the expense.
    expect(find.text('Touch and hold to talk'), findsOneWidget);
    expect(find.text('Cab 450 with Arjun, split equally'), findsOneWidget);
  });

  testWidgets('Back, Next and swiping move together; Get started only on the last slide', (tester) async {
    final app = await pumpKraken(tester);
    final back = find.widgetWithText(KButton, 'Back');
    bool backShown() => tester.widget<KButton>(back).onPressed != null;

    // First slide: no Back, no Get started, no Skip on a first visit.
    expect(backShown(), isFalse);
    expect(find.text('Get started'), findsNothing);
    expect(find.text('Skip'), findsNothing);

    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();
    expect(find.text('Just say it'), findsOneWidget);
    expect(find.bySemanticsLabel('Slide 2 of 4'), findsOneWidget);
    expect(backShown(), isTrue);

    await tester.tap(back);
    await tester.pumpAndSettle();
    expect(find.text('Split bills, not friendships'), findsOneWidget);
    expect(backShown(), isFalse);

    // A swipe moves one slide too, and the buttons follow it.
    await tester.fling(find.byType(PageView), const Offset(-400, 0), 1000);
    await tester.pumpAndSettle();
    expect(find.text('Just say it'), findsOneWidget);
    expect(backShown(), isTrue);

    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();
    expect(find.text('Snap the bill'), findsOneWidget);
    expect(find.text('Get started'), findsNothing);
    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();
    expect(find.text('Settle up in a tap'), findsOneWidget);
    expect(find.text('Next'), findsNothing);

    await tester.tap(find.text('Get started'));
    await tester.pumpAndSettle();
    expect(find.text('Welcome back'), findsOneWidget);

    // Seen them all: next time there's a Skip.
    await tester.pumpWidget(const SizedBox());
    await startSignedOut(app.store);
    await pumpKraken(tester, store: app.store);
    await tester.tap(find.text('Skip'));
    await tester.pumpAndSettle();
    expect(find.text('Welcome back'), findsOneWidget);
  });
}
