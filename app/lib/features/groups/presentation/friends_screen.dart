import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:ledger/ledger.dart';
import 'package:material_ui/material_ui.dart';

import '../../../app/kraken_app.dart';
import '../../../app/routes.dart';
import '../../../app/session.dart';
import '../../../core/analytics/events.dart';
import '../../../ui_kit/ui_kit.dart';
import '../../home/domain/home_calculator.dart';
import '../domain/group_ledger.dart';
import 'create_group_sheet.dart';
import 'ledgers_cubit.dart';
import 'widgets/group_rows.dart';

/// Everyone you share a group with, and where you stand with each of them,
/// across all groups.
class FriendsScreen extends StatelessWidget {
  const FriendsScreen({super.key});

  @override
  Widget build(BuildContext context) => BlocProvider(
    create: (context) =>
        LedgersCubit(repository: context.read<GroupsRepository>(), uid: context.read<SessionCubit>().state.uid ?? ''),
    child: const _FriendsView(),
  );
}

class _FriendsView extends StatelessWidget {
  const _FriendsView();

  @override
  Widget build(BuildContext context) {
    final state = context.watch<LedgersCubit>().state;
    final List<Widget> body = switch (state) {
      LedgersLoading() => [
        const Padding(
          padding: EdgeInsets.all(KSpace.xxxl),
          child: Center(child: CircularProgressIndicator()),
        ),
      ],
      LedgersFailed() => [
        const KEmptyState(
          illustration: KIllustrations.emptyOffline,
          title: "Couldn't load your friends",
          message: 'Check your connection and try again.',
        ),
      ],
      LedgersReady(:final ledgers) => _friends(context, ledgers),
    };
    return CustomScrollView(
      slivers: [
        const SliverToBoxAdapter(child: KTopBar(title: 'Friends')),
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: KSpace.gutter),
          sliver: SliverList.list(children: body),
        ),
        SliverToBoxAdapter(child: SizedBox(height: MediaQuery.paddingOf(context).bottom + KSpace.xl)),
      ],
    );
  }

  List<Widget> _friends(BuildContext context, List<GroupLedger> ledgers) {
    final balances = HomeCalculator.balances(ledgers);
    final owing = {for (final p in balances.people) p.personId};
    // Everyone else you share a group with, square with you.
    final settled = <String, (String, Set<String>)>{};
    for (final l in ledgers) {
      for (final m in l.group.members) {
        if (m.id == l.myMemberId || owing.contains(m.id)) continue;
        final entry = settled.putIfAbsent(m.id, () => (m.name, <String>{}));
        entry.$2.add(l.group.name);
      }
    }
    if (balances.people.isEmpty && settled.isEmpty) {
      return [
        Padding(
          padding: const EdgeInsets.only(top: KSpace.xxxl),
          child: KEmptyState(
            illustration: KIllustrations.emptyFriends,
            title: 'Your friends show up here',
            message: 'Make a group and add friends to it, and you’ll see where you stand with each of them.',
            action: KButton(
              label: 'Create a group',
              size: KButtonSize.medium,
              icon: Icons.add_rounded,
              onPressed: () => showCreateGroupSheet(context),
            ),
          ),
        ),
      ];
    }
    void soon(String message) {
      context.analytics.log(const ComingSoonTapped('friend_settle'));
      KToast.show(context, message);
    }

    return [
      if (!balances.allSettled) ...[
        KBalanceCard(owedToYou: balances.owedToYou, youOwe: balances.youOwe),
        const SizedBox(height: KSpace.xl),
        const KSectionHeader(title: 'Balances'),
        KGroupedList(
          indent: 52,
          children: [
            for (final p in balances.people)
              KListRow(
                title: p.name,
                subtitle: p.groupNames.join(', '),
                leading: KAvatar(name: p.name, circle: true),
                trailing: PersonBalanceLabel(amount: p.amount),
                onTap: () =>
                    soon(p.amount.isNegative ? 'Paying by UPI arrives in Phase 6.' : 'Reminders arrive in Phase 6.'),
              ),
          ],
        ),
      ],
      if (settled.isNotEmpty) ...[
        const SizedBox(height: KSpace.xl),
        const KSectionHeader(title: 'Settled up'),
        KGroupedList(
          indent: 52,
          children: [
            for (final MapEntry(key: id, value: (name, groups)) in settled.entries)
              KListRow(
                key: ValueKey(id),
                title: name,
                subtitle: groups.join(', '),
                leading: KAvatar(name: name, circle: true),
                trailing: const PersonBalanceLabel(amount: Money.zero),
                onTap: () {
                  final ledger = ledgers.firstWhere((l) => l.group.members.any((m) => m.id == id));
                  context.go(Paths.group(ledger.group.id));
                },
              ),
          ],
        ),
      ],
    ];
  }
}
