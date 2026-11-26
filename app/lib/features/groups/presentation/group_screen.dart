import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:ledger/ledger.dart';
import 'package:material_ui/material_ui.dart';

import '../../../app/kraken_app.dart';
import '../../../app/routes.dart';
import '../../../app/session.dart';
import '../../../core/analytics/events.dart';
import '../../../core/time/clock.dart';
import '../../../ui_kit/ui_kit.dart';
import '../../home/presentation/widgets/formatting.dart';
import '../domain/expense.dart';
import '../domain/group_ledger.dart';
import 'expense_form_cubit.dart';
import 'group_cubit.dart';
import 'invite_sheet.dart';
import 'widgets/group_rows.dart';

/// A group, as on the Group design: where you stand with each person, who
/// owes whom once debts are simplified, then the expenses (or the group's
/// history), newest first.
class GroupScreen extends StatelessWidget {
  const GroupScreen({super.key, required this.groupId});

  final String groupId;

  @override
  Widget build(BuildContext context) => BlocProvider(
    create: (context) => GroupCubit(
      repository: context.read<GroupsRepository>(),
      uid: context.read<SessionCubit>().state.uid ?? '',
      groupId: groupId,
    ),
    child: const _GroupView(),
  );
}

class _GroupView extends StatelessWidget {
  const _GroupView();

  void _back(BuildContext context) => context.canPop() ? context.pop() : context.go(Paths.home);

  @override
  Widget build(BuildContext context) {
    final state = context.watch<GroupCubit>().state;
    return switch (state) {
      GroupLoading() => Column(
        children: [
          KTopBar(onBack: () => _back(context)),
          const Expanded(child: Center(child: CircularProgressIndicator())),
        ],
      ),
      GroupMissing() => Column(
        children: [
          KTopBar(onBack: () => _back(context)),
          const Expanded(
            child: Center(
              child: KEmptyState(
                illustration: KIllustrations.emptyGroups,
                title: 'This group isn’t here',
                message: 'It may have been removed, or you’re not in it any more.',
              ),
            ),
          ),
        ],
      ),
      GroupReady(:final ledger, :final tab) => _Ready(ledger: ledger, tab: tab, onBack: () => _back(context)),
    };
  }
}

class _Ready extends StatelessWidget {
  const _Ready({required this.ledger, required this.tab, required this.onBack});

  final GroupLedger ledger;
  final GroupTab tab;
  final VoidCallback onBack;

  Future<void> _addExpense(BuildContext context) async {
    context.analytics.log(const GroupAction('add_expense'));
    final result = await context.push<ExpenseFormResult>(Paths.expense(ledger.group.id));
    if (context.mounted) _announce(context, result);
  }

  Future<void> _openExpense(BuildContext context, Expense e) async {
    context.analytics.log(const GroupAction('open_expense'));
    final result = await context.push<ExpenseFormResult>(Paths.expense(ledger.group.id, expenseId: e.id));
    if (context.mounted) _announce(context, result);
  }

  /// Says what the form did; a delete can be undone from here.
  void _announce(BuildContext context, ExpenseFormResult? result) {
    switch (result) {
      case ExpenseWasSaved(:final edited):
        KToast.show(context, edited ? 'Expense updated' : 'Expense added', kind: KToastKind.success);
      case ExpenseWasDeleted(:final expense):
        final cubit = context.read<GroupCubit>();
        final analytics = context.analytics;
        var undone = false;
        KToast.show(
          context,
          'Deleted “${expense.description}”',
          actionLabel: 'Undo',
          onAction: () async {
            undone = true;
            analytics.log(const ExpenseDeleted(undone: true));
            final ok = await cubit.undoDelete(expense);
            if (!ok && context.mounted) KToast.show(context, "Couldn't put it back.", kind: KToastKind.error);
          },
        );
        // Logged once the chance to undo has passed.
        Future<void>.delayed(const Duration(seconds: 5), () {
          if (!undone) analytics.log(const ExpenseDeleted(undone: false));
        });
      case null:
        break;
    }
  }

  void _soon(BuildContext context, String action, String message) {
    context.analytics.log(GroupAction(action));
    KToast.show(context, message);
  }

  @override
  Widget build(BuildContext context) {
    final k = context.k;
    final now = context.read<Clock>()();
    final group = ledger.group;
    final myNet = ledger.myNet;
    final balances = ledger.myBalances.entries.toList()..sort((a, b) => b.value.paise.abs() - a.value.paise.abs());
    final simplified = ledger.simplified;

    // You first, as on the design.
    final names = [
      'You',
      for (final m in group.members)
        if (m.id != ledger.myMemberId) m.name,
    ];
    final subtitle = [names.join(', '), ?_dateRange(ledger.expenses)].join(' · ');

    final (String overall, Color overallColor) = myNet.isNegative
        ? ('Overall, you owe ${MoneyFormat.format(myNet)}', k.owe)
        : myNet.isPositive
        ? ('Overall, you’re owed ${MoneyFormat.format(myNet)}', k.owed)
        : (ledger.expenses.isEmpty ? 'No expenses yet' : 'You’re all settled up', k.muted);

    final items = <Widget>[];
    if (tab == GroupTab.expenses) {
      final entries = <(DateTime, Widget)>[
        for (final e in ledger.expenses)
          (e.date, ExpenseRow(expense: e, ledger: ledger, onTap: () => _openExpense(context, e))),
        for (final p in ledger.payments) (p.date, PaymentRow(payment: p, ledger: ledger)),
      ]..sort((a, b) => b.$1.compareTo(a.$1));
      DateTime? month;
      for (final (date, row) in entries) {
        final m = DateTime(date.year, date.month);
        if (month != m) {
          month = m;
          items.add(
            Padding(
              padding: const EdgeInsets.only(top: KSpace.lg),
              child: KSectionHeader(title: DateFormat('MMMM y').format(m)),
            ),
          );
        }
        items.add(row);
      }
      if (entries.isEmpty) {
        items.add(
          Padding(
            padding: const EdgeInsets.symmetric(vertical: KSpace.xxxl),
            child: KEmptyState(
              illustration: KIllustrations.emptyActivity,
              title: 'Nothing added yet',
              message: 'Add the first expense, or invite friends so they can add theirs.',
              action: KButton(
                label: 'Add expense',
                size: KButtonSize.medium,
                icon: Icons.add_rounded,
                onPressed: () => _addExpense(context),
              ),
            ),
          ),
        );
      }
    } else {
      for (final a in ledger.activity) {
        items.add(
          ActivityRow(
            entry: a,
            ledger: ledger,
            when: relativeDay(a.date, now),
            onTap: switch ((a.expenseId, a.kind)) {
              (final String id, final kind)
                  when kind != ActivityKind.expenseDeleted && ledger.expenseById(id) != null =>
                () => _openExpense(context, ledger.expenseById(id)!),
              _ => null,
            },
          ),
        );
      }
      if (ledger.activity.isEmpty) {
        items.add(
          Padding(
            padding: const EdgeInsets.symmetric(vertical: KSpace.xxxl),
            child: Text(
              'Changes to this group show up here.',
              textAlign: TextAlign.center,
              style: KText.body.copyWith(color: k.muted),
            ),
          ),
        );
      }
    }

    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: KTopBar(
            onBack: onBack,
            actions: [
              KIconButton(
                icon: Icons.person_add_alt_1_outlined,
                label: 'Invite friends',
                onPressed: () {
                  context.analytics.log(const GroupAction('invite'));
                  showInviteSheet(context, ledger);
                },
              ),
            ],
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: KSpace.gutter),
          sliver: SliverList.list(
            children: [
              KAvatarStack(names: names),
              const SizedBox(height: KSpace.md),
              Semantics(
                header: true,
                child: Text(group.name, style: KText.title.copyWith(color: k.ink)),
              ),
              const SizedBox(height: KSpace.xxs),
              Text(subtitle, style: KText.caption.copyWith(color: k.muted)),
              const SizedBox(height: KSpace.lg),
              Text(overall, style: KText.heading.copyWith(color: overallColor)),
              if (balances.isNotEmpty) ...[
                const SizedBox(height: KSpace.xs),
                KGroupedList(
                  indent: 52,
                  children: [
                    for (final MapEntry(key: id, value: amount) in balances)
                      KListRow(
                        title: ledger.nameOf(id),
                        leading: KAvatar(name: ledger.nameOf(id), circle: true),
                        trailing: PersonBalanceLabel(amount: amount),
                      ),
                  ],
                ),
              ],
              const SizedBox(height: KSpace.md),
              KChipRow(
                children: [
                  KChip(
                    label: 'Settle up',
                    icon: Icons.payments_outlined,
                    onTap: () => _soon(context, 'settle_up', 'Settle up arrives in Phase 6.'),
                  ),
                  KChip(
                    label: 'Invite',
                    icon: Icons.link_rounded,
                    onTap: () {
                      context.analytics.log(const GroupAction('invite'));
                      showInviteSheet(context, ledger);
                    },
                  ),
                  KChip(
                    label: 'Totals',
                    icon: Icons.pie_chart_outline_rounded,
                    onTap: () => _soon(context, 'totals', 'Group totals arrive with Insights in Phase 7.'),
                  ),
                ],
              ),
              const SizedBox(height: KSpace.lg),
              KButton(
                label: 'Add expense',
                icon: Icons.add_rounded,
                expand: true,
                onPressed: () => _addExpense(context),
              ),
              if (simplified.isNotEmpty) ...[
                const SizedBox(height: KSpace.xxl),
                const KSectionHeader(title: 'Who owes whom'),
                for (final t in simplified) _TransferRow(transfer: t, ledger: ledger),
              ],
              const SizedBox(height: KSpace.xxl),
              KSegmentedControl<GroupTab>(
                segments: const [KSegment(GroupTab.expenses, 'Expenses'), KSegment(GroupTab.activity, 'Activity')],
                value: tab,
                onChanged: (t) {
                  context.analytics.log(GroupAction('tab_${t.name}'));
                  context.read<GroupCubit>().showTab(t);
                },
              ),
              ...items,
            ],
          ),
        ),
        // Room to scroll clear of the floating tab bar.
        SliverToBoxAdapter(child: SizedBox(height: MediaQuery.paddingOf(context).bottom + KSpace.xl)),
      ],
    );
  }

  /// "19–23 Nov" for a trip; null for a group that spans months.
  static String? _dateRange(List<Expense> expenses) {
    if (expenses.isEmpty) return null;
    final dates = expenses.map((e) => e.date).toList()..sort();
    final first = dates.first;
    final last = dates.last;
    if (first.year != last.year || first.month != last.month) return null;
    final month = DateFormat.MMM().format(first);
    return first.day == last.day ? '${first.day} $month' : '${first.day}–${last.day} $month';
  }
}

/// "Sreya pays Meera ₹1,150".
class _TransferRow extends StatelessWidget {
  const _TransferRow({required this.transfer, required this.ledger});

  final Transfer transfer;
  final GroupLedger ledger;

  @override
  Widget build(BuildContext context) {
    final k = context.k;
    final from = ledger.nameOf(transfer.from);
    final to = ledger.nameOf(transfer.to);
    final involvesMe = transfer.from == ledger.myMemberId || transfer.to == ledger.myMemberId;
    return MergeSemantics(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: KSpace.xs),
        child: Row(
          children: [
            KAvatar(name: from, circle: true, size: 28),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: KSpace.xs),
              child: Icon(Icons.arrow_forward_rounded, size: 16, color: k.muted),
            ),
            KAvatar(name: to, circle: true, size: 28),
            const SizedBox(width: KSpace.md),
            Expanded(
              child: Text(
                '$from ${from == 'You' ? 'pay' : 'pays'} ${to == 'You' ? 'you' : to}',
                style: (involvesMe ? KText.bodyStrong : KText.body).copyWith(color: k.ink),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Text(MoneyFormat.format(transfer.amount), style: KText.amount.copyWith(color: k.ink)),
          ],
        ),
      ),
    );
  }
}
