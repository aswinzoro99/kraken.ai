import 'money.dart';

/// Splits [total] equally between [people], in order. Leftover paise go to
/// the first people, one each, so the shares always add up exactly:
/// ₹100 between three is ₹33.34, ₹33.33, ₹33.33.
Map<String, Money> splitEqually(Money total, List<String> people) {
  if (people.isEmpty) throw ArgumentError.value(people, 'people', 'needs at least one person');
  if (people.toSet().length != people.length) throw ArgumentError.value(people, 'people', 'has duplicates');
  if (total.isNegative) throw ArgumentError.value(total, 'total', 'must not be negative');
  final base = total.paise ~/ people.length;
  final leftover = total.paise % people.length;
  return {for (var i = 0; i < people.length; i++) people[i]: Money(base + (i < leftover ? 1 : 0))};
}

/// Checks hand-typed amounts: each person's exact share. They must add up to
/// [total] to the paisa; people with nothing are left out.
Map<String, Money> splitExactly(Money total, Map<String, Money> amounts) {
  if (total.isNegative) throw ArgumentError.value(total, 'total', 'must not be negative');
  if (amounts.values.any((m) => m.isNegative)) throw ArgumentError.value(amounts, 'amounts', 'has a negative amount');
  final sum = Money.sum(amounts.values);
  if (sum != total) throw ArgumentError('Amounts add up to $sum, not $total');
  return {
    for (final MapEntry(:key, :value) in amounts.entries)
      if (!value.isZero) key: value,
  };
}

/// Splits [total] by percentages given in basis points (25% is 2500), which
/// must add up to 100%. See [splitByWeights] for how paise are rounded.
Map<String, Money> splitByPercent(Money total, Map<String, int> basisPoints) {
  final sum = basisPoints.values.fold(0, (a, b) => a + b);
  if (sum != 10000) throw ArgumentError('Percentages add up to ${sum / 100}%, not 100%');
  return splitByWeights(total, basisPoints);
}

/// Splits [total] by shares: someone with 2 shares pays twice as much as
/// someone with 1.
Map<String, Money> splitByShares(Money total, Map<String, int> shares) => splitByWeights(total, shares);

/// Splits [total] in proportion to whole-number [weights], in their order.
/// Everyone gets the rounded-down amount first; the paise left over go one
/// each to the first people with a weight, as with [splitEqually], so the
/// shares always add up exactly. People with weight 0 are left out.
Map<String, Money> splitByWeights(Money total, Map<String, int> weights) {
  if (total.isNegative) throw ArgumentError.value(total, 'total', 'must not be negative');
  if (weights.values.any((w) => w < 0)) throw ArgumentError.value(weights, 'weights', 'has a negative weight');
  final people = [
    for (final MapEntry(:key, :value) in weights.entries)
      if (value > 0) key,
  ];
  if (people.isEmpty) throw ArgumentError.value(weights, 'weights', 'needs at least one positive weight');
  final sum = people.fold(0, (a, p) => a + weights[p]!);
  final base = {for (final p in people) p: total.paise * weights[p]! ~/ sum};
  var leftover = total.paise - base.values.fold(0, (a, b) => a + b);
  // The leftover is always fewer paise than there are people.
  for (final p in people) {
    if (leftover == 0) break;
    base[p] = base[p]! + 1;
    leftover--;
  }
  return {for (final p in people) p: Money(base[p]!)};
}
