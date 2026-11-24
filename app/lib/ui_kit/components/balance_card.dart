import 'package:ledger/ledger.dart';
import 'package:material_ui/material_ui.dart';

import '../theme/kraken_theme.dart';
import '../tokens/layout.dart';
import '../tokens/typography.dart';
import 'money_text.dart';

/// The balance summary at the top of Home: one big number in plain type,
/// with what you're owed and what you owe on one line beneath it.
class KBalanceCard extends StatelessWidget {
  const KBalanceCard({super.key, required this.owedToYou, required this.youOwe});

  final Money owedToYou;
  final Money youOwe;

  @override
  Widget build(BuildContext context) {
    final k = context.k;
    final net = owedToYou - youOwe;
    final (headline, color) = switch (net.tone) {
      BalanceTone.owed => ('Overall, you are owed', k.ink),
      BalanceTone.owe => ('Overall, you owe', k.owe),
      BalanceTone.settled => ("You're all settled up", k.ink),
    };
    Widget part(String label, Money value, Color dot) => Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 6,
          height: 6,
          decoration: BoxDecoration(color: dot, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text('$label ', style: KText.caption.copyWith(color: k.muted)),
        Text(
          MoneyFormat.format(value),
          style: KText.caption.copyWith(color: k.ink, fontWeight: FontWeight.w500),
        ),
      ],
    );
    return Semantics(
      container: true,
      label: 'Your balance',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(headline, style: KText.caption.copyWith(color: k.muted)),
          const SizedBox(height: KSpace.xxs),
          Text(net.isZero ? '₹0' : MoneyFormat.format(net), style: KText.amountHero.copyWith(color: color)),
          const SizedBox(height: KSpace.sm),
          Wrap(
            spacing: KSpace.lg,
            runSpacing: KSpace.xxs,
            children: [part('Owed to you', owedToYou, k.owed), part('You owe', youOwe, k.owe)],
          ),
        ],
      ),
    );
  }
}
