/// Kraken's money maths. Pure Dart, shared by the app and the server:
/// [Money], splits (equal, exact, percent, shares), who owes whom, and
/// simplified debts.
///
/// Every amount is a whole number of paise. Nothing in this package uses
/// floating point for money.
library;

export 'src/balances.dart';
export 'src/money.dart';
export 'src/simplify.dart';
export 'src/splits.dart';
