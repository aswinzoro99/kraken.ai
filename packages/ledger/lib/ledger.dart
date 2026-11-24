/// Kraken's money maths. Pure Dart, shared by the app and the server:
/// [Money], equal splits, and who owes whom.
///
/// Every amount is a whole number of paise. Nothing in this package uses
/// floating point for money.
library;

export 'src/balances.dart';
export 'src/money.dart';
export 'src/splits.dart';
