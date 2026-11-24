import 'package:flutter_test/flutter_test.dart';
import 'package:kraken/core/haptics/haptics.dart';
import 'package:kraken/core/storage/key_value_store.dart';
import 'package:kraken/ui_kit/ui_kit.dart';
import 'package:ledger/ledger.dart';
import 'package:material_ui/material_ui.dart';

Future<RecordingHapticsEngine> pumpKit(WidgetTester tester, Widget child) async {
  final engine = RecordingHapticsEngine();
  await tester.pumpWidget(
    MaterialApp(
      theme: KrakenTheme.light(),
      home: HapticsScope(
        haptics: Haptics(engine, MemoryStore()),
        child: Scaffold(body: Center(child: child)),
      ),
    ),
  );
  return engine;
}

void main() {
  testWidgets('KButton calls back and plays a tap', (tester) async {
    var taps = 0;
    final engine = await pumpKit(tester, KButton(label: 'Save', onPressed: () => taps++));
    await tester.tap(find.text('Save'));
    expect(taps, 1);
    expect(engine.played, [HapticKind.tap]);
  });

  testWidgets('a disabled or loading KButton does nothing', (tester) async {
    var taps = 0;
    final engine = await pumpKit(
      tester,
      Column(
        children: [
          const KButton(label: 'Off', onPressed: null),
          KButton(label: 'Busy', loading: true, onPressed: () => taps++),
        ],
      ),
    );
    await tester.tap(find.text('Off'));
    await tester.tap(find.byType(CircularProgressIndicator));
    expect(taps, 0);
    expect(engine.played, isEmpty);
  });

  testWidgets('KChip plays a selection haptic', (tester) async {
    var picked = false;
    final engine = await pumpKit(tester, KChip(label: 'Skip for now', onTap: () => picked = true));
    await tester.tap(find.text('Skip for now'));
    expect(picked, isTrue);
    expect(engine.played, [HapticKind.selection]);
  });

  testWidgets('ChatInputBar sends trimmed text only when there is some', (tester) async {
    final sent = <String>[];
    final engine = await pumpKit(
      tester,
      ChatInputBar(label: 'Email', placeholder: 'you@example.com', onSubmitted: sent.add),
    );
    await tester.tap(find.bySemanticsLabel('Send'));
    expect(sent, isEmpty);
    await tester.enterText(find.byType(TextField), 'a@b.com');
    await tester.pump();
    await tester.tap(find.bySemanticsLabel('Send'));
    expect(sent, ['a@b.com']);
    expect(engine.played, [HapticKind.tap]);
  });

  testWidgets('BalanceLabel reads naturally', (tester) async {
    await pumpKit(
      tester,
      const Column(
        children: [
          BalanceLabel(balance: Money.rupees(-150)),
          BalanceLabel(balance: Money.rupees(2180)),
          BalanceLabel(balance: Money.zero),
        ],
      ),
    );
    expect(find.text('you owe'), findsOneWidget);
    expect(find.text('₹150'), findsOneWidget);
    expect(find.text("you're owed"), findsOneWidget);
    expect(find.text('₹2,180'), findsOneWidget);
    expect(find.text('settled up'), findsOneWidget);
  });

  test('MoneyFormat uses Indian grouping and hides zero paise', () {
    expect(MoneyFormat.format(const Money.rupees(2870)), '₹2,870');
    expect(MoneyFormat.format(const Money.rupees(123456)), '₹1,23,456');
    expect(MoneyFormat.format(const Money(3334)), '₹33.34');
    expect(MoneyFormat.format(const Money(-15000)), '₹150');
  });

  test('KAvatar initials match the design', () {
    expect(KAvatar.initialsOf('Goa Trip'), 'GT');
    expect(KAvatar.initialsOf('Flat 302'), 'F3');
    expect(KAvatar.initialsOf('sreya'), 'S');
    expect(KAvatar.initialsOf('  '), '?');
    expect(KAvatar.toneFor('Goa Trip'), KAvatar.toneFor('Goa Trip'));
  });

  testWidgets('KSegmentedControl picks an option with a selection tick', (tester) async {
    final picked = <String>[];
    final engine = await pumpKit(
      tester,
      KSegmentedControl<String>(
        segments: const [KSegment('a', 'Alpha'), KSegment('b', 'Beta')],
        value: 'a',
        onChanged: picked.add,
      ),
    );
    expect(
      tester.getSemantics(find.bySemanticsLabel('Alpha')),
      isSemantics(label: 'Alpha', isButton: true, isSelected: true, isInMutuallyExclusiveGroup: true),
    );
    await tester.tap(find.bySemanticsLabel('Alpha')); // Already chosen: nothing happens.
    await tester.tap(find.bySemanticsLabel('Beta'));
    expect(picked, ['b']);
    expect(engine.played, [HapticKind.selection]);
  });
}
