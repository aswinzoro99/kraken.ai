import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../app/kraken_app.dart';
import '../../../app/session.dart';
import '../../../core/analytics/events.dart';
import '../../../ui_kit/ui_kit.dart';

/// The signed-in app: five tabs, each keeping its own navigation stack,
/// under a floating Liquid Glass tab bar (icons only, Instagram-style) with
/// the quick-actions + beside it.
///
/// Content runs under the glass (`extendBody`). Scrolling down shrinks the
/// bar and the + together, with every tab still there; scrolling back up,
/// or switching tabs, restores the full size.
class HomeShell extends StatefulWidget {
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

  /// What the + offers, most used first. Holding the + is the fast way to
  /// talk; the Talk row teaches that.
  static const quickActions = [
    KQuickAction(
      id: 'talk',
      label: 'Talk',
      description: 'Say “Cab 450 with Arjun”. Or press and hold +',
      icon: Icons.mic_none_rounded,
    ),
    KQuickAction(
      id: 'scan',
      label: 'Scan a bill',
      description: 'Take a photo or pick a screenshot',
      icon: Icons.document_scanner_outlined,
    ),
    KQuickAction(
      id: 'add',
      label: 'Add expense',
      description: 'Type the amount and who was in',
      icon: Icons.edit_note_rounded,
    ),
    KQuickAction(
      id: 'settle',
      label: 'Settle up',
      description: 'Pay back by UPI or record cash',
      icon: Icons.payments_outlined,
    ),
  ];

  static const _comingSoon = {
    'talk': 'Talking to Kraken arrives in Phase 4.',
    'scan': 'Bill scanning arrives in Phase 5.',
    'add': 'Adding expenses arrives in Phase 2.',
    'settle': 'Settle up arrives in Phase 6.',
  };

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  bool _minimized = false;

  void _setMinimized(bool value) {
    if (value != _minimized) setState(() => _minimized = value);
  }

  bool _onScroll(ScrollUpdateNotification n) {
    if (n.metrics.axis != Axis.vertical) return false;
    final delta = n.scrollDelta ?? 0;
    if (n.metrics.pixels <= 24) {
      _setMinimized(false);
    } else if (delta > 4) {
      _setMinimized(true);
    } else if (delta < -4) {
      _setMinimized(false);
    }
    return false;
  }

  void _onAction(KQuickAction action) {
    context.analytics.log(QuickActionUsed(action.id, via: 'menu'));
    KToast.show(context, HomeShell._comingSoon[action.id] ?? 'Coming soon.');
  }

  void _onTalk(bool completed) {
    context.analytics.log(QuickActionUsed('talk', via: 'hold', completed: completed));
    if (completed) KToast.show(context, 'Talking to Kraken arrives in Phase 4. Nothing was recorded.');
  }

  @override
  Widget build(BuildContext context) {
    final shell = widget.shell;
    final session = context.watch<SessionCubit>().state;
    final name = switch (session) {
      ReadySession(:final profile) => profile.displayName,
      OnboardingSession(:final profile) => profile?.displayName,
      _ => null,
    };
    final items = [
      for (final (item, key) in HomeShell.tabs)
        // The profile tab shows the person's avatar, as on Instagram.
        key == 'account' && name != null
            ? KNavItem(label: item.label, icon: item.icon, selectedIcon: item.selectedIcon, avatarName: name)
            : item,
    ];
    return Scaffold(
      extendBody: true,
      body: NotificationListener<ScrollUpdateNotification>(onNotification: _onScroll, child: shell),
      bottomNavigationBar: KBottomNav(
        items: items,
        selectedIndex: shell.currentIndex,
        minimized: _minimized,
        onSelected: (i) {
          if (i != shell.currentIndex) context.analytics.log(TabSelected(HomeShell.tabs[i].$2));
          _setMinimized(false);
          // Tapping the current tab again returns it to its first screen.
          shell.goBranch(i, initialLocation: i == shell.currentIndex);
        },
        trailing: KQuickActionButton(
          actions: HomeShell.quickActions,
          onAction: _onAction,
          onTalk: _onTalk,
          onOpened: () => context.analytics.log(const QuickActionsOpened()),
        ),
      ),
    );
  }
}
