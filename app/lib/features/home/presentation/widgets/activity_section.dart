import 'package:material_ui/material_ui.dart';

import '../../../../ui_kit/ui_kit.dart';
import '../../../groups/domain/expense.dart';
import '../../domain/home_snapshot.dart';

/// The last few things that happened across your groups, so nothing
/// involving you goes unnoticed.
class ActivitySection extends StatelessWidget {
  const ActivitySection({super.key, required this.items, required this.onSeeAll});

  final List<ActivityItem> items;
  final VoidCallback onSeeAll;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      KSectionHeader(title: 'Recent activity', actionLabel: 'See all', onAction: onSeeAll),
      KGroupedList(indent: 52, children: [for (final item in items) _ActivityRow(item)]),
    ],
  );
}

class _ActivityRow extends StatelessWidget {
  const _ActivityRow(this.item);
  final ActivityItem item;

  @override
  Widget build(BuildContext context) {
    final k = context.k;
    final (String title, String subtitle, ExpenseSource? source) = switch (item) {
      ExpenseActivity(:final expense, :final payerName, :final groupName) => (
        expense.description,
        '$payerName paid ${MoneyFormat.format(expense.total)} · $groupName',
        expense.source,
      ),
      PaymentActivity(:final fromName, :final toName, :final groupName) => (
        '$fromName paid ${toName == 'You' ? 'you' : toName}',
        'Settled up · $groupName',
        null,
      ),
    };
    final (String effectWords, String effectAmount, Color effectColor) = switch (item) {
      ExpenseActivity(:final yourEffect) when yourEffect.isPositive => (
        'you lent',
        MoneyFormat.format(yourEffect),
        k.owed,
      ),
      ExpenseActivity(:final yourEffect) when yourEffect.isNegative => (
        'you borrowed',
        MoneyFormat.format(yourEffect),
        k.owe,
      ),
      ExpenseActivity() => ('not involved', '', k.muted),
      PaymentActivity(:final amount) => ('', MoneyFormat.format(amount), k.ink),
    };
    final tag = switch (source) {
      ExpenseSource.voice => (Icons.mic_none_rounded, 'Added by voice'),
      ExpenseSource.scan => (Icons.document_scanner_outlined, 'Scanned'),
      ExpenseSource.agent => (Icons.auto_awesome_outlined, 'Added by Kraken'),
      ExpenseSource.gmail => (Icons.mail_outline_rounded, 'From Gmail'),
      _ => null,
    };

    return MergeSemantics(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: KSpace.sm),
        child: Row(
          children: [
            KDateBlock(item.date),
            const SizedBox(width: KSpace.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          title,
                          style: KText.bodyStrong.copyWith(color: k.ink),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (tag != null) ...[
                        const SizedBox(width: 6),
                        Semantics(
                          label: tag.$2,
                          child: Icon(tag.$1, size: 14, color: k.muted),
                        ),
                      ],
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
                if (effectWords.isNotEmpty) Text(effectWords, style: KText.small.copyWith(color: effectColor)),
                if (effectAmount.isNotEmpty) Text(effectAmount, style: KText.amount.copyWith(color: effectColor)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
