import 'package:flutter_test/flutter_test.dart';
import 'package:kraken/core/haptics/haptics.dart';
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

    // The dots are buttons that jump to their slide.
    await tester.tap(find.bySemanticsLabel('Slide 4 of 4'));
    await tester.pumpAndSettle();
    expect(find.text('Settle up in a tap'), findsOneWidget);

    // Get started works from any slide.
    await tester.tap(find.text('Get started'));
    await tester.pumpAndSettle();
    expect(find.text('Get started'), findsNothing);
  });
}
