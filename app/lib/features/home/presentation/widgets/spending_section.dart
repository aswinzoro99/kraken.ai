import 'package:intl/intl.dart';
import 'package:ledger/ledger.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../ui_kit/ui_kit.dart';
import '../../domain/home_snapshot.dart';

/// What you spent: the month's total (your share), how it compares, six
/// months of trend you can tap through, and where the money went.
class SpendingSection extends StatelessWidget {
  const SpendingSection({super.key, required this.spending, required this.onSelectMonth, required this.onOpenInsights});

  final SpendingSummary spending;
  final ValueChanged<DateTime> onSelectMonth;
  final VoidCallback onOpenInsights;

  static const _topCategories = 3;

  @override
  Widget build(BuildContext context) {
    final k = context.k;
    final monthName = DateFormat.MMMM().format(spending.month);
    final title = spending.inProgress ? 'Spent so far in $monthName' : 'Spent in $monthName';
    final selected = spending.months.indexWhere((m) => m.month == spending.month);
    final hasTrend = spending.months.any((m) => !m.total.isZero);
    final change = spending.changePercent;
    final shown = spending.categories.take(_topCategories).toList();
    final hidden = spending.categories.length - shown.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(title, style: KText.caption.copyWith(color: k.muted)),
            ),
            KPressable(
              onTap: onOpenInsights,
              semanticLabel: 'Open insights',
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: KSpace.xs),
                child: Text('Insights', style: KText.overline.copyWith(color: k.primaryText)),
              ),
            ),
          ],
        ),
        Semantics(
          label: '$title: ${MoneyFormat.format(spending.total)}, your share',
          excludeSemantics: true,
          child: KRollingNumber(MoneyFormat.format(spending.total), style: KText.amountHero.copyWith(color: k.ink)),
        ),
        const SizedBox(height: 6),
        if (change != null && spending.comparisonLabel != null)
          KDelta(percent: change, against: spending.comparisonLabel!)
        else
          Text(
            spending.total.isZero ? 'Nothing spent in $monthName' : 'Your share of shared expenses',
            style: KText.caption.copyWith(color: k.muted),
          ),
        if (hasTrend) ...[
          const SizedBox(height: KSpace.lg),
          KTrendBars(
            height: 52,
            selected: selected,
            onSelect: (i) => onSelectMonth(spending.months[i].month),
            bars: [
              for (final m in spending.months)
                KBarDatum(
                  label: DateFormat.MMM().format(m.month),
                  value: m.total.paise.toDouble(),
                  semanticLabel: '${DateFormat.MMMM().format(m.month)}, ${MoneyFormat.format(m.total)}',
                ),
            ],
          ),
        ],
        if (shown.isNotEmpty) ...[
          const SizedBox(height: KSpace.md),
          for (final c in shown)
            KShareRow(label: c.category.label, value: MoneyFormat.format(c.amount), share: c.share),
          if (hidden > 0) _Rest(spending.categories.skip(_topCategories).toList()),
        ],
      ],
    );
  }
}

/// "Also Groceries and Travel: ₹3,160" for the categories not drawn.
class _Rest extends StatelessWidget {
  const _Rest(this.rest);
  final List<CategoryTotal> rest;

  @override
  Widget build(BuildContext context) {
    final names = [for (final c in rest) c.category.label];
    final joined = names.length == 1 ? names.single : '${names.take(names.length - 1).join(', ')} and ${names.last}';
    return Padding(
      padding: const EdgeInsets.only(top: KSpace.xxs),
      child: Text(
        'Also $joined: ${MoneyFormat.format(Money.sum(rest.map((c) => c.amount)))}',
        style: KText.small.copyWith(color: context.k.muted),
      ),
    );
  }
}
