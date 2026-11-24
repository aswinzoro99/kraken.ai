import 'package:flutter_test/flutter_test.dart';
import 'package:kraken/core/haptics/haptics.dart';
import 'package:kraken/core/storage/key_value_store.dart';
import 'package:kraken/ui_kit/ui_kit.dart';
import 'package:material_ui/material_ui.dart';

const items = [
  KNavItem(label: 'Home', icon: Icons.home_outlined, selectedIcon: Icons.home_rounded),
  KNavItem(label: 'Friends', icon: Icons.person_outline, selectedIcon: Icons.person),
  KNavItem(label: 'Insights', icon: Icons.insights_outlined, selectedIcon: Icons.insights),
  KNavItem(label: 'Activity', icon: Icons.receipt_long_outlined, selectedIcon: Icons.receipt_long),
  KNavItem(label: 'Account', icon: Icons.account_circle_outlined, selectedIcon: Icons.account_circle),
];

/// The + sits in a square, as the tab bar gives it.
Widget button(Widget child) => Align(
  alignment: Alignment.centerRight,
  child: Padding(
    padding: const EdgeInsets.all(16),
    child: SizedBox.square(dimension: 58, child: child),
  ),
);

Future<RecordingHapticsEngine> host(WidgetTester tester, Widget child, {Widget? body}) async {
  final engine = RecordingHapticsEngine();
  await tester.pumpWidget(
    MaterialApp(
      theme: KrakenTheme.light(),
      home: HapticsScope(
        haptics: Haptics(engine, MemoryStore()),
        child: Scaffold(extendBody: true, body: body ?? const SizedBox.expand(), bottomNavigationBar: child),
      ),
    ),
  );
  return engine;
}

/// A tab bar that remembers its selection, like the shell.
class _Bar extends StatefulWidget {
  const _Bar({this.minimized = false, this.onChanged});
  final bool minimized;
  final ValueChanged<int>? onChanged;
  @override
  State<_Bar> createState() => _BarState();
}

class _BarState extends State<_Bar> {
  int selected = 0;
  late bool minimized = widget.minimized;
  @override
  Widget build(BuildContext context) => KBottomNav(
    items: items,
    selectedIndex: selected,
    minimized: minimized,
    onSelected: (i) {
      setState(() => selected = i);
      widget.onChanged?.call(i);
    },
  );
}

void main() {
  group('Liquid Glass tab bar', () {
    testWidgets('tapping a tab selects it with a selection tick', (tester) async {
      final picked = <int>[];
      final haptics = await host(tester, _Bar(onChanged: picked.add));
      expect(find.byType(KLiquidGlass), findsOneWidget);
      await tester.tap(find.bySemanticsLabel('Insights'));
      await tester.pumpAndSettle();
      expect(picked, [2]);
      expect(haptics.played, [HapticKind.selection]);
    });

    testWidgets('dragging the lens across the bar scrubs through tabs', (tester) async {
      final picked = <int>[];
      final haptics = await host(tester, _Bar(onChanged: picked.add));
      final from = tester.getCenter(find.bySemanticsLabel('Home'));
      final to = tester.getCenter(find.bySemanticsLabel('Activity'));
      final gesture = await tester.startGesture(from);
      for (var i = 1; i <= 10; i++) {
        await gesture.moveTo(Offset.lerp(from, to, i / 10)!);
        await tester.pump(const Duration(milliseconds: 16));
      }
      await gesture.up();
      await tester.pumpAndSettle();
      expect(picked, [3]);
      // A tick for each tab the lens crossed: Friends, Insights, Activity.
      expect(haptics.played.where((h) => h == HapticKind.selection), hasLength(3));
    });

    testWidgets('icons only: no labels on screen, names for screen readers', (tester) async {
      await host(tester, const _Bar());
      expect(find.text('Friends'), findsNothing);
      expect(find.bySemanticsLabel('Friends'), findsOneWidget);
    });

    testWidgets('minimised, it shrinks but keeps every tab tappable', (tester) async {
      final picked = <int>[];
      await host(tester, _Bar(minimized: true, onChanged: picked.add));
      expect(tester.getSize(find.byKey(KBottomNav.capsuleKey)).height, KBottomNav.minimizedHeight);
      for (final item in items) {
        expect(find.bySemanticsLabel(item.label).hitTestable(), findsOneWidget);
      }
      await tester.tap(find.bySemanticsLabel('Account'));
      await tester.pumpAndSettle();
      expect(picked, [4]);
    });

    testWidgets('the profile tab can show the person’s avatar', (tester) async {
      await host(
        tester,
        KBottomNav(
          items: [
            ...items.take(4),
            const KNavItem(
              label: 'Account',
              icon: Icons.account_circle_outlined,
              selectedIcon: Icons.account_circle,
              avatarName: 'Aarav',
            ),
          ],
          selectedIndex: 0,
          onSelected: (_) {},
        ),
      );
      expect(find.text('A'), findsOneWidget);
    });
  });

  group('quick actions', () {
    const actions = [
      KQuickAction(id: 'scan', label: 'Scan a bill', description: 'Photo', icon: Icons.document_scanner_outlined),
      KQuickAction(id: 'add', label: 'Add expense', description: 'Type it', icon: Icons.edit_note_rounded),
    ];

    testWidgets('tap opens the menu; picking an action closes it and reports it', (tester) async {
      KQuickAction? picked;
      await host(tester, button(KQuickActionButton(actions: actions, onAction: (a) => picked = a, onTalk: (_) {})));
      await tester.tap(find.bySemanticsLabel('Quick actions'));
      await tester.pumpAndSettle();
      expect(find.text('Scan a bill'), findsOneWidget);
      await tester.tap(find.text('Scan a bill'));
      await tester.pumpAndSettle();
      expect(picked?.id, 'scan');
      expect(find.text('Scan a bill'), findsNothing);
    });

    testWidgets('the × or the backdrop closes the menu without an action', (tester) async {
      KQuickAction? picked;
      await host(tester, button(KQuickActionButton(actions: actions, onAction: (a) => picked = a, onTalk: (_) {})));
      await tester.tap(find.bySemanticsLabel('Quick actions'));
      await tester.pumpAndSettle();
      await tester.tap(find.bySemanticsLabel('Close quick actions').last);
      await tester.pumpAndSettle();
      expect(find.text('Add expense'), findsNothing);
      expect(picked, isNull);
    });

    testWidgets('press and hold talks; release adds', (tester) async {
      final results = <bool>[];
      final haptics = await host(
        tester,
        button(KQuickActionButton(actions: actions, onAction: (_) {}, onTalk: results.add)),
      );
      final gesture = await tester.startGesture(tester.getCenter(find.byType(KQuickActionButton)));
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pump();
      expect(find.text('Listening…'), findsOneWidget);
      expect(haptics.played.first, HapticKind.heavy);
      await gesture.up();
      await tester.pumpAndSettle();
      expect(results, [true]);
      expect(find.text('Listening…'), findsNothing);
    });

    testWidgets('sliding away while holding cancels', (tester) async {
      final results = <bool>[];
      final haptics = await host(
        tester,
        button(KQuickActionButton(actions: actions, onAction: (_) {}, onTalk: results.add)),
      );
      final start = tester.getCenter(find.byType(KQuickActionButton));
      final gesture = await tester.startGesture(start);
      await tester.pump(const Duration(milliseconds: 400));
      await gesture.moveTo(start + const Offset(-120, -40));
      await tester.pump();
      expect(find.text('Release to cancel'), findsOneWidget);
      expect(haptics.played, contains(HapticKind.warning));
      await gesture.up();
      await tester.pumpAndSettle();
      expect(results, [false]);
    });
  });

  group('rolling numbers', () {
    Future<void> pumpNumber(WidgetTester tester, String text, {bool reduceMotion = false}) => tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(disableAnimations: reduceMotion),
          child: Scaffold(
            body: Center(child: KRollingNumber(text, style: KText.amountHero)),
          ),
        ),
      ),
    );

    testWidgets('digits roll up from 0 and settle on the value', (tester) async {
      await pumpNumber(tester, '₹21,500');
      // Mid-roll the wheels are moving.
      await tester.pump(const Duration(milliseconds: 120));
      final moving = tester.widgetList<Transform>(
        find.descendant(of: find.byType(KRollingNumber), matching: find.byType(Transform)),
      );
      expect(moving, isNotEmpty);
      await tester.pumpAndSettle();
      expect(find.bySemanticsLabel('₹21,500'), findsOneWidget);
    });

    testWidgets('a new value rolls each digit from where it is', (tester) async {
      await pumpNumber(tester, '₹21,500');
      await tester.pumpAndSettle();
      await pumpNumber(tester, '₹17,020');
      await tester.pump(const Duration(milliseconds: 50));
      expect(tester.hasRunningAnimations, isTrue);
      await tester.pumpAndSettle();
      expect(find.bySemanticsLabel('₹17,020'), findsOneWidget);
    });

    testWidgets('under Reduce Motion it is plain text', (tester) async {
      await pumpNumber(tester, '₹4,720', reduceMotion: true);
      expect(find.text('₹4,720'), findsOneWidget);
      expect(tester.hasRunningAnimations, isFalse);
    });
  });
}
