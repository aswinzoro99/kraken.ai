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
  return {
    for (var i = 0; i < people.length; i++) people[i]: Money(base + (i < leftover ? 1 : 0)),
  };
}
