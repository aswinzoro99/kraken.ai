import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../app/routes.dart';
import '../../../app/session.dart';
import '../../../core/time/clock.dart';
import '../../../ui_kit/ui_kit.dart';
import '../../home/presentation/widgets/formatting.dart';
import '../domain/group_ledger.dart';
import 'create_group_sheet.dart';
import 'ledgers_cubit.dart';
import 'widgets/group_rows.dart';

/// Every group, and a search across groups and expenses.
class GroupsListScreen extends StatelessWidget {
  const GroupsListScreen({super.key, this.searching = false});

  /// Opened from the search button: the search box starts focused.
  final bool searching;

  @override
  Widget build(BuildContext context) => BlocProvider(
    create: (context) =>
        LedgersCubit(repository: context.read<GroupsRepository>(), uid: context.read<SessionCubit>().state.uid ?? ''),
    child: _GroupsListView(searching: searching),
  );
}

class _GroupsListView extends StatefulWidget {
  const _GroupsListView({required this.searching});
  final bool searching;

  @override
  State<_GroupsListView> createState() => _GroupsListViewState();
}

class _GroupsListViewState extends State<_GroupsListView> {
  final _query = TextEditingController();

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final k = context.k;
    final now = context.read<Clock>()();
    final state = context.watch<LedgersCubit>().state;
    final q = _query.text.trim().toLowerCase();

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
          title: "Couldn't load your groups",
          message: 'Check your connection and try again.',
        ),
      ],
      LedgersReady(:final ledgers) when ledgers.isEmpty => [
        Padding(
          padding: const EdgeInsets.only(top: KSpace.xxxl),
          child: KEmptyState(
            illustration: KIllustrations.emptyGroups,
            title: 'No groups yet',
            message: 'Make one for a trip, your flat or office lunches.',
            action: KButton(
              label: 'Create a group',
              size: KButtonSize.medium,
              icon: Icons.add_rounded,
              onPressed: () => showCreateGroupSheet(context),
            ),
          ),
        ),
      ],
      LedgersReady(:final ledgers) => _results(context, ledgers, q, now),
    };

    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: KTopBar(
            title: 'Your groups',
            onBack: () => context.canPop() ? context.pop() : context.go(Paths.home),
            actions: [
              KIconButton(
                icon: Icons.group_add_outlined,
                label: 'New group',
                onPressed: () => showCreateGroupSheet(context),
              ),
            ],
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: KSpace.gutter),
          sliver: SliverList.list(
            children: [
              TextField(
                controller: _query,
                autofocus: widget.searching,
                textInputAction: TextInputAction.search,
                onChanged: (_) => setState(() {}),
                style: KText.body.copyWith(color: k.ink),
                decoration: InputDecoration(
                  hintText: 'Search groups and expenses',
                  prefixIcon: Icon(Icons.search_rounded, color: k.muted),
                  suffixIcon: _query.text.isEmpty
                      ? null
                      : IconButton(
                          tooltip: 'Clear search',
                          icon: Icon(Icons.close_rounded, color: k.muted),
                          onPressed: () => setState(_query.clear),
                        ),
                  filled: true,
                  fillColor: k.surfaceMuted,
                  border: const OutlineInputBorder(
                    borderRadius: BorderRadius.all(KRadius.lg),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: KSpace.md),
              ...body,
            ],
          ),
        ),
        SliverToBoxAdapter(child: SizedBox(height: MediaQuery.paddingOf(context).bottom + KSpace.xl)),
      ],
    );
  }

  List<Widget> _results(BuildContext context, List<GroupLedger> ledgers, String q, DateTime now) {
    final k = context.k;
    final sorted = [...ledgers]
      ..sort(
        (a, b) => (b.lastActivity ?? b.group.createdAt ?? DateTime(0)).compareTo(
          a.lastActivity ?? a.group.createdAt ?? DateTime(0),
        ),
      );
    final groups = q.isEmpty
        ? sorted
        : sorted
              .where(
                (l) =>
                    l.group.name.toLowerCase().contains(q) ||
                    l.group.members.any((m) => m.name.toLowerCase().contains(q)),
              )
              .toList();
    final expenses = q.isEmpty
        ? const <(GroupLedger, int)>[]
        : [
            for (final l in sorted)
              for (var i = 0; i < l.expenses.length; i++)
                if (l.expenses[i].description.toLowerCase().contains(q)) (l, i),
          ];
    return [
      if (groups.isNotEmpty)
        KGroupedList(
          indent: 52,
          children: [
            for (final l in groups)
              KListRow(
                title: l.group.name,
                subtitle: [
                  people(l.group.members.length),
                  if (l.lastActivity != null)
                    relativeDay(l.lastActivity!, now)
                  else if (l.group.detail.isNotEmpty)
                    l.group.detail,
                ].join(' · '),
                leading: KAvatar(name: l.group.name, tone: KTone.neutral),
                trailing: BalanceLabel(balance: l.myNet),
                onTap: () => context.push(Paths.group(l.group.id)),
              ),
          ],
        ),
      if (expenses.isNotEmpty) ...[
        const SizedBox(height: KSpace.lg),
        const KSectionHeader(title: 'Expenses'),
        for (final (l, i) in expenses.take(50))
          ExpenseRow(expense: l.expenses[i], ledger: l, onTap: () => context.push(Paths.group(l.group.id))),
      ],
      if (q.isNotEmpty && groups.isEmpty && expenses.isEmpty)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: KSpace.xxxl),
          child: Text(
            'Nothing matches “${_query.text.trim()}”',
            textAlign: TextAlign.center,
            style: KText.body.copyWith(color: k.muted),
          ),
        ),
    ];
  }
}
