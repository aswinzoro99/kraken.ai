import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:ledger/ledger.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../core/storage/key_value_store.dart';
import '../../../../ui_kit/ui_kit.dart';
import '../../domain/home_snapshot.dart';

enum _Chart { bars, line }

/// What you spent: the month's total (your share), how it compares, six
/// months of trend you can tap through, as bars or a line (the toggle by
/// the title, remembered on the device), and where the money went.
class SpendingSection extends StatefulWidget {
  const SpendingSection({
    super.key,
    required this.spending,
    required this.onSelectMonth,
    required this.onOpenInsights,
    this.onChartChanged,
  });

  final SpendingSummary spending;
  final ValueChanged<DateTime> onSelectMonth;
  final VoidCallback onOpenInsights;

  /// `bars` or `line`.
  final ValueChanged<String>? onChartChanged;

  @override
  State<SpendingSection> createState() => _SpendingSectionState();
}

class _SpendingSectionState extends State<SpendingSection> {
  static const _topCategories = 3;

  late _Chart _chart = context.read<KeyValueStore>().getString(StoreKeys.homeChart) == _Chart.line.name
      ? _Chart.line
      : _Chart.bars;

  void _setChart(_Chart chart) {
    setState(() => _chart = chart);
    context.read<KeyValueStore>().setString(StoreKeys.homeChart, chart.name);
    widget.onChartChanged?.call(chart.name);
  }

  @override
  Widget build(BuildContext context) {
    final k = context.k;
    final spending = widget.spending;
    final monthName = DateFormat.MMMM().format(spending.month);
    final title = spending.inProgress ? 'Spent so far in $monthName' : 'Spent in $monthName';
    final selected = spending.months.indexWhere((m) => m.month == spending.month);
    final hasTrend = spending.months.any((m) => !m.total.isZero);
    final change = spending.changePercent;
    final shown = spending.categories.take(_topCategories).toList();
    final hidden = spending.categories.length - shown.length;
    final months = [
      for (final m in spending.months)
        KBarDatum(
          label: DateFormat.MMM().format(m.month),
          value: m.total.paise.toDouble(),
          semanticLabel: '${DateFormat.MMMM().format(m.month)}, ${MoneyFormat.format(m.total)}',
        ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(title, style: KText.caption.copyWith(color: k.muted)),
            ),
            if (hasTrend) ...[
              KSegmentedControl<_Chart>(
                compact: true,
                segments: const [
                  KSegment(_Chart.bars, 'Bar chart', icon: Icons.bar_chart_rounded),
                  KSegment(_Chart.line, 'Line chart', icon: Icons.show_chart_rounded),
                ],
                value: _chart,
                onChanged: _setChart,
              ),
              const SizedBox(width: KSpace.md),
            ],
            KPressable(
              onTap: widget.onOpenInsights,
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
          AnimatedSwitcher(
            duration: KMotion.of(context, KMotion.base),
            child: switch (_chart) {
              _Chart.bars => KTrendBars(
                key: const ValueKey(_Chart.bars),
                height: 52,
                selected: selected,
                onSelect: (i) => widget.onSelectMonth(spending.months[i].month),
                bars: months,
              ),
              _Chart.line => KTrendLine(
                key: const ValueKey(_Chart.line),
                height: 52,
                selected: selected,
                onSelect: (i) => widget.onSelectMonth(spending.months[i].month),
                points: months,
              ),
            },
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
