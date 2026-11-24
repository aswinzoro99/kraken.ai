import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../app/kraken_app.dart';
import '../../../app/routes.dart';
import '../../../app/session.dart';
import '../../../core/analytics/events.dart';
import '../../../core/time/clock.dart';
import '../../../ui_kit/ui_kit.dart';
import '../../groups/domain/group_ledger.dart';
import '../domain/home_snapshot.dart';
import 'home_cubit.dart';
import 'widgets/activity_section.dart';
import 'widgets/balances_section.dart';
import 'widgets/groups_section.dart';
import 'widgets/spending_section.dart';

/// Home, in the order people need it (see docs/ux/home-study.md):
/// what you spent, who owes whom, what just happened, then your groups.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final uid = switch (context.read<SessionCubit>().state) {
      ReadySession(:final user) || OnboardingSession(:final user) => user.uid,
      _ => '',
    };
    return BlocProvider(
      create: (context) =>
          HomeCubit(repository: context.read<GroupsRepository>(), uid: uid, clock: context.read<Clock>()),
      child: const _HomeView(),
    );
  }
}

class _HomeView extends StatelessWidget {
  const _HomeView();

  @override
  Widget build(BuildContext context) {
    final state = context.watch<HomeCubit>().state;
    final now = context.read<Clock>()();

    void track(String action, {int? monthsAgo}) => context.analytics.log(HomeAction(action, monthsAgo: monthsAgo));
    void soon(String feature, String message) {
      context.analytics.log(ComingSoonTapped(feature));
      KToast.show(context, message);
    }

    final content = switch (state) {
      HomeLoading() => <Widget>[const SliverFillRemaining(child: Center(child: CircularProgressIndicator()))],
      HomeFailed() => [
        const SliverFillRemaining(
          hasScrollBody: false,
          child: Center(
            child: KEmptyState(
              icon: Icons.cloud_off_rounded,
              title: "Couldn't load your groups",
              message: 'Check your connection. Kraken will try again when you are back online.',
            ),
          ),
        ),
      ],
      HomeReady(:final snapshot) when snapshot.isEmpty => [
        SliverFillRemaining(
          hasScrollBody: false,
          child: Center(
            child: KEmptyState(
              icon: Icons.groups_outlined,
              title: 'No groups yet',
              message:
                  'Create a group for a trip, your flat or office lunches. Your spending and balances show up here.',
              action: KButton(
                label: 'Create a group',
                size: KButtonSize.medium,
                icon: Icons.add_rounded,
                onPressed: () => soon('new_group', 'Creating groups arrives in Phase 2.'),
              ),
            ),
          ),
        ),
      ],
      HomeReady(:final snapshot) => [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(KSpace.gutter, KSpace.sm, KSpace.gutter, 0),
          sliver: SliverList.list(
            children: [
              SpendingSection(
                spending: snapshot.spending,
                onSelectMonth: (month) {
                  track('month_selected', monthsAgo: (now.year - month.year) * 12 + now.month - month.month);
                  context.read<HomeCubit>().selectMonth(month);
                },
                onOpenInsights: () {
                  track('open_insights');
                  context.go(Paths.insights);
                },
              ),
              const SizedBox(height: KSpace.xxxl),
              BalancesSection(
                balances: snapshot.balances,
                onSeeAll: () {
                  track('see_balances');
                  context.go(Paths.friends);
                },
                onSettle: (p) {
                  track(p.amount.isNegative ? 'pay' : 'remind');
                  KToast.show(
                    context,
                    p.amount.isNegative ? 'Paying by UPI arrives in Phase 6.' : 'Reminders arrive in Phase 6.',
                  );
                },
              ),
              if (snapshot.recent.isNotEmpty) ...[
                const SizedBox(height: KSpace.xxxl),
                ActivitySection(
                  items: snapshot.recent,
                  onSeeAll: () {
                    track('see_activity');
                    context.go(Paths.activity);
                  },
                ),
              ],
              const SizedBox(height: KSpace.xxxl),
              GroupsSection(
                groups: snapshot.groups,
                now: now,
                onOpen: (GroupSummary g) {
                  track('open_group');
                  KToast.show(context, 'The group screen arrives in Phase 2.');
                },
                onSeeAll: () => soon('all_groups', 'The full list of groups arrives in Phase 2.'),
              ),
              const SizedBox(height: KSpace.xl),
              KBanner(
                icon: Icons.mail_outline_rounded,
                onTap: () => soon('gmail', 'Gmail suggestions arrive in Phase 9.'),
                child: const Text('Connect Gmail to get split suggestions from receipts'),
              ),
            ],
          ),
        ),
      ],
    };

    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: KTopBar(
            leading: const KrakenLogo(fontSize: 20),
            actions: [
              KIconButton(
                icon: Icons.search_rounded,
                label: 'Search',
                onPressed: () => soon('search', 'Search arrives in Phase 2.'),
              ),
              KIconButton(
                icon: Icons.group_add_outlined,
                label: 'New group',
                onPressed: () => soon('new_group', 'Creating groups arrives in Phase 2.'),
              ),
            ],
          ),
        ),
        ...content,
        // Room to scroll the last row clear of the floating glass tab bar
        // (its height is in the bottom padding, since the shell extends the
        // body under it).
        SliverToBoxAdapter(child: SizedBox(height: MediaQuery.paddingOf(context).bottom + KSpace.xl)),
      ],
    );
  }
}
