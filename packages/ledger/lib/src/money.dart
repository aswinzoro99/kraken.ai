/// An amount of Indian rupees, stored as whole paise.
///
/// `Money` is immutable and compares by value. Use [Money.paise] for storage
/// and maths; formatting for display lives in the app's UI layer.
final class Money implements Comparable<Money> {
  /// Creates an amount from whole paise (₹1 = 100 paise).
  const Money(this.paise);

  /// Creates an amount from whole rupees.
  const Money.rupees(int rupees) : paise = rupees * 100;

  /// Zero rupees.
  static const zero = Money(0);

  /// Adds up [amounts] exactly.
  static Money sum(Iterable<Money> amounts) => Money(amounts.fold(0, (total, m) => total + m.paise));

  /// The amount in paise. Negative means money owed.
  final int paise;

  /// Whole rupees, rounded toward zero.
  int get wholeRupees => paise ~/ 100;

  /// The paise left over after [wholeRupees], always 0–99.
  int get remainderPaise => paise.abs() % 100;

  bool get isZero => paise == 0;
  bool get isNegative => paise < 0;
  bool get isPositive => paise > 0;

  Money abs() => Money(paise.abs());

  Money operator +(Money other) => Money(paise + other.paise);
  Money operator -(Money other) => Money(paise - other.paise);
  Money operator -() => Money(-paise);
  bool operator <(Money other) => paise < other.paise;
  bool operator >(Money other) => paise > other.paise;
  bool operator <=(Money other) => paise <= other.paise;
  bool operator >=(Money other) => paise >= other.paise;

  @override
  int compareTo(Money other) => paise.compareTo(other.paise);

  @override
  bool operator ==(Object other) => other is Money && other.paise == paise;

  @override
  int get hashCode => paise.hashCode;

  @override
  String toString() {
    final sign = isNegative ? '-' : '';
    final rupees = paise.abs() ~/ 100;
    final rest = (paise.abs() % 100).toString().padLeft(2, '0');
    return 'Money($sign₹$rupees.$rest)';
  }
}
