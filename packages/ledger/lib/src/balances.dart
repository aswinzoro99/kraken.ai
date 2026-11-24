import 'money.dart';

/// One shared expense as the ledger sees it: who paid, and each person's
/// share. Shares must add up to the total exactly.
final class SplitExpense {
  SplitExpense({required this.paidBy, required this.total, required this.shares}) {
    final sum = Money.sum(shares.values);
    if (sum != total) {
      throw ArgumentError('Shares add up to $sum, not $total');
    }
  }

  final String paidBy;
  final Money total;
  final Map<String, Money> shares;

  /// [person]'s part of the cost (zero if they weren't in the split).
  Money shareOf(String person) => shares[person] ?? Money.zero;
}

/// Money handed from one person to another to settle up.
final class Transfer {
  const Transfer({required this.from, required this.to, required this.amount});
  final String from;
  final String to;
  final Money amount;
}

/// What each other person owes [me], from direct debts only: positive means
/// they owe [me], negative means [me] owes them. People who are square are
/// left out.
///
/// Only expenses and transfers involving [me] count. Debts between two other
/// people never change what [me] owes.
Map<String, Money> balancesWith(
  String me,
  Iterable<SplitExpense> expenses, [
  Iterable<Transfer> transfers = const [],
]) {
  final owed = <String, int>{};
  void add(String person, int paise) => owed[person] = (owed[person] ?? 0) + paise;

  for (final e in expenses) {
    if (e.paidBy == me) {
      for (final MapEntry(key: person, value: share) in e.shares.entries) {
        if (person != me) add(person, share.paise);
      }
    } else {
      final mine = e.shareOf(me);
      if (!mine.isZero) add(e.paidBy, -mine.paise);
    }
  }
  for (final t in transfers) {
    if (t.from == me && t.to != me) add(t.to, t.amount.paise);
    if (t.to == me && t.from != me) add(t.from, -t.amount.paise);
  }
  return {
    for (final MapEntry(key: person, value: paise) in owed.entries)
      if (paise != 0) person: Money(paise),
  };
}
