import 'package:intl/intl.dart';
import 'package:ledger/ledger.dart';
import 'package:material_ui/material_ui.dart';

import '../theme/kraken_theme.dart';
import '../tokens/typography.dart';

/// Formats [Money] the Indian way: ₹2,870, ₹1,23,456, ₹33.34.
abstract final class MoneyFormat {
  static final _whole = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);
  static final _exact = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 2);

  /// Hides paise when there are none. Always positive; say "owe" or
  /// "owed" in words rather than with a minus sign.
  static String format(Money m) {
    final abs = m.abs();
    return abs.remainderPaise == 0 ? _whole.format(abs.wholeRupees) : _exact.format(abs.paise / 100);
  }
}

enum BalanceTone { owe, owed, settled }

extension BalanceToneOf on Money {
  BalanceTone get tone => isNegative ? BalanceTone.owe : (isPositive ? BalanceTone.owed : BalanceTone.settled);
}

/// The right-hand column on group rows: "you owe ₹150", "you're owed ₹840"
/// or "settled up".
class BalanceLabel extends StatelessWidget {
  const BalanceLabel({super.key, required this.balance, this.align = CrossAxisAlignment.end});

  final Money balance;
  final CrossAxisAlignment align;

  @override
  Widget build(BuildContext context) {
    final k = context.k;
    final tone = balance.tone;
    if (tone == BalanceTone.settled) {
      return Text('settled up', style: KText.caption.copyWith(color: k.muted));
    }
    final color = tone == BalanceTone.owe ? k.owe : k.owed;
    final words = tone == BalanceTone.owe ? 'you owe' : "you're owed";
    final amount = MoneyFormat.format(balance);
    return Semantics(
      label: '$words $amount',
      excludeSemantics: true,
      child: Column(
        crossAxisAlignment: align,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(words, style: KText.small.copyWith(color: color)),
          Text(amount, style: KText.amount.copyWith(color: color)),
        ],
      ),
    );
  }
}
