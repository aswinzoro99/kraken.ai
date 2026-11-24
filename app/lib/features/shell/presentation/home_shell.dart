import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/analytics/events.dart';
import '../../../app/kraken_app.dart';
import '../../../ui_kit/ui_kit.dart';

/// The signed-in app: five tabs, each keeping its own navigation stack.
class HomeShell extends StatelessWidget {
  const HomeShell({super.key, required this.shell});

  final StatefulNavigationShell shell;

  static const tabs = [
    (KNavItem(label: 'Home', icon: Icons.home_outlined, selectedIcon: Icons.home_rounded), 'home'),
    (KNavItem(label: 'Friends', icon: Icons.person_outline_rounded, selectedIcon: Icons.person_rounded), 'friends'),
    (KNavItem(label: 'Insights', icon: Icons.insights_outlined, selectedIcon: Icons.insights_rounded), 'insights'),
    (
      KNavItem(label: 'Activity', icon: Icons.receipt_long_outlined, selectedIcon: Icons.receipt_long_rounded),
      'activity',
    ),
    (
      KNavItem(label: 'Account', icon: Icons.account_circle_outlined, selectedIcon: Icons.account_circle_rounded),
      'account',
    ),
  ];

  @override
  Widget build(BuildContext context) => Scaffold(
    body: shell,
    bottomNavigationBar: KBottomNav(
      items: [for (final t in tabs) t.$1],
      selectedIndex: shell.currentIndex,
      onSelected: (i) {
        if (i != shell.currentIndex) context.analytics.log(TabSelected(tabs[i].$2));
        // Tapping the current tab again returns it to its first screen.
        shell.goBranch(i, initialLocation: i == shell.currentIndex);
      },
    ),
  );
}
