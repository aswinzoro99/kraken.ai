import 'balances.dart';
import 'money.dart';

/// Where each person stands in a group overall: positive means the group
/// owes them, negative means they owe the group. Always sums to zero.
Map<String, Money> netBalances(Iterable<SplitExpense> expenses, [Iterable<Transfer> transfers = const []]) {
  final net = <String, int>{};
  void add(String person, int paise) => net[person] = (net[person] ?? 0) + paise;
  for (final e in expenses) {
    add(e.paidBy, e.total.paise);
    for (final MapEntry(key: person, value: share) in e.shares.entries) {
      add(person, -share.paise);
    }
  }
  for (final t in transfers) {
    add(t.from, t.amount.paise);
    add(t.to, -t.amount.paise);
  }
  return {
    for (final MapEntry(key: person, value: paise) in net.entries)
      if (paise != 0) person: Money(paise),
  };
}

/// The fewest payments that settle [net] (from [netBalances]), roughly:
/// the person owing most pays the person owed most, until everyone is
/// square. Ties go by id, so the answer is the same on every phone.
List<Transfer> simplifyDebts(Map<String, Money> net) {
  final sum = Money.sum(net.values);
  if (!sum.isZero) throw ArgumentError('Balances add up to $sum, not zero');
  final owed = [
    for (final MapEntry(:key, :value) in net.entries)
      if (value.isPositive) _Side(key, value.paise),
  ];
  final owing = [
    for (final MapEntry(:key, :value) in net.entries)
      if (value.isNegative) _Side(key, -value.paise),
  ];
  final transfers = <Transfer>[];
  while (owed.isNotEmpty && owing.isNotEmpty) {
    owed.sort(_Side.largestFirst);
    owing.sort(_Side.largestFirst);
    final to = owed.first;
    final from = owing.first;
    final paise = to.paise < from.paise ? to.paise : from.paise;
    transfers.add(Transfer(from: from.person, to: to.person, amount: Money(paise)));
    to.paise -= paise;
    from.paise -= paise;
    if (to.paise == 0) owed.removeAt(0);
    if (from.paise == 0) owing.removeAt(0);
  }
  return transfers;
}

final class _Side {
  _Side(this.person, this.paise);
  final String person;
  int paise;

  static int largestFirst(_Side a, _Side b) {
    final byAmount = b.paise.compareTo(a.paise);
    return byAmount != 0 ? byAmount : a.person.compareTo(b.person);
  }
}
