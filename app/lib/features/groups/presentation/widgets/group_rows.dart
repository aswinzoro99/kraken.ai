import 'package:ledger/ledger.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../ui_kit/ui_kit.dart';
import '../../domain/expense.dart';
import '../../domain/group_ledger.dart';

/// One expense in a group's list: what, who paid, and what it did to you.
class ExpenseRow extends StatelessWidget {
  const ExpenseRow({super.key, required this.expense, required this.ledger, this.onTap});

  final Expense expense;
  final GroupLedger ledger;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final k = context.k;
    final me = ledger.myMemberId;
    final paidByMe = expense.paidBy == me;
    final effect = paidByMe ? expense.total - expense.shareOf(me) : -expense.shareOf(me);
    final addedBy = expense.addedBy;
    final subtitle = [
      '${ledger.nameOf(expense.paidBy)} paid ${MoneyFormat.format(expense.total)}',
      if (addedBy != null && addedBy != expense.paidBy) 'added by ${ledger.nameOf(addedBy).replaceFirst('You', 'you')}',
    ].join(' · ');
    final (String words, Color color) = effect.isPositive
        ? ('you lent', k.owed)
        : effect.isNegative
        ? ('you borrowed', k.owe)
        : ('not involved', k.muted);
    final tag = sourceTag(expense.source);
    return KPressable(
      onTap: onTap,
      pressedScale: 0.99,
      semanticLabel:
          '${expense.description}. $subtitle. ${effect.isZero ? words : '$words ${MoneyFormat.format(effect)}'}',
      excludeChildSemantics: true,
      child: ColoredBox(
        color: k.background,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: KSpace.sm),
          child: Row(
            children: [
              KDateBlock(expense.date),
              const SizedBox(width: KSpace.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            expense.description,
                            style: KText.bodyStrong.copyWith(color: k.ink),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (tag != null) ...[const SizedBox(width: 6), Icon(tag.$1, size: 14, color: k.muted)],
                      ],
                    ),
                    Text(
                      subtitle,
                      style: KText.small.copyWith(color: k.muted),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: KSpace.sm),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(words, style: KText.small.copyWith(color: color)),
                  if (!effect.isZero) Text(MoneyFormat.format(effect), style: KText.amount.copyWith(color: color)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A payment in a group's list.
class PaymentRow extends StatelessWidget {
  const PaymentRow({super.key, required this.payment, required this.ledger});

  final Payment payment;
  final GroupLedger ledger;

  @override
  Widget build(BuildContext context) {
    final k = context.k;
    final to = ledger.nameOf(payment.to);
    return MergeSemantics(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: KSpace.sm),
        child: Row(
          children: [
            KDateBlock(payment.date),
            const SizedBox(width: KSpace.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${ledger.nameOf(payment.from)} paid ${to == 'You' ? 'you' : to}',
                    style: KText.bodyStrong.copyWith(color: k.ink),
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text('Settled up', style: KText.small.copyWith(color: k.muted)),
                ],
              ),
            ),
            Text(MoneyFormat.format(payment.amount), style: KText.amount.copyWith(color: k.ink)),
          ],
        ),
      ),
    );
  }
}

/// The icon and words for how an expense got in, or null when typed.
(IconData, String)? sourceTag(ExpenseSource source) => switch (source) {
  ExpenseSource.voice => (Icons.mic_none_rounded, 'Added by voice'),
  ExpenseSource.scan => (Icons.document_scanner_outlined, 'Scanned'),
  ExpenseSource.agent => (Icons.auto_awesome_outlined, 'Added by Kraken'),
  ExpenseSource.gmail => (Icons.mail_outline_rounded, 'From Gmail'),
  ExpenseSource.manual => null,
};

/// "Sreya added Scooter rentals", "You deleted Wifi".
String describeActivity(ActivityEntry a, GroupLedger ledger) {
  final who = ledger.nameOf(a.authorId);
  final what = a.subject.isEmpty ? '' : ' “${a.subject}”';
  return switch (a.kind) {
    ActivityKind.groupCreated => '$who made the group',
    ActivityKind.memberJoined => a.authorId == ledger.myMemberId ? 'You joined' : '${a.subject} joined',
    ActivityKind.expenseAdded => '$who added$what',
    ActivityKind.expenseEdited => '$who edited$what',
    ActivityKind.expenseDeleted => '$who deleted$what',
    ActivityKind.expenseRestored => '$who restored$what',
    ActivityKind.paymentRecorded => '$who recorded a payment',
  };
}

/// One line of a group's history.
class ActivityRow extends StatelessWidget {
  const ActivityRow({
    super.key,
    required this.entry,
    required this.ledger,
    required this.when,
    this.showGroup = false,
    this.onTap,
  });

  final ActivityEntry entry;
  final GroupLedger ledger;

  /// "2 days ago".
  final String when;

  /// Name the group too (on the Activity tab).
  final bool showGroup;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final k = context.k;
    final amount = entry.amount;
    final deleted = entry.kind == ActivityKind.expenseDeleted;
    return KListRow(
      title: describeActivity(entry, ledger),
      subtitle: [if (showGroup) ledger.group.name, if (when.isNotEmpty) when].join(' · '),
      leading: KAvatar(name: ledger.nameOf(entry.authorId), circle: true, size: 36),
      trailing: amount == null
          ? null
          : Text(
              MoneyFormat.format(amount),
              style: KText.amount.copyWith(
                color: deleted ? k.muted : k.ink,
                decoration: deleted ? TextDecoration.lineThrough : null,
              ),
            ),
      onTap: onTap,
    );
  }
}

/// "owes you ₹1,150" / "you owe ₹1,850" in a person's row.
class PersonBalanceLabel extends StatelessWidget {
  const PersonBalanceLabel({super.key, required this.amount});

  /// Positive: they owe you.
  final Money amount;

  @override
  Widget build(BuildContext context) {
    final k = context.k;
    if (amount.isZero) return Text('settled up', style: KText.caption.copyWith(color: k.muted));
    final color = amount.isPositive ? k.owed : k.owe;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(amount.isPositive ? 'owes you' : 'you owe', style: KText.small.copyWith(color: color)),
        Text(MoneyFormat.format(amount), style: KText.amount.copyWith(color: color)),
      ],
    );
  }
}
