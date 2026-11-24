# ledger

Pure Dart money maths shared by the Kraken app and server. Every amount is
whole paise (`Money(paise)`); no floating point is used for money.

Today it holds the `Money` value type. Splits (equal, exact, percent, shares),
balances, simplified debts and amount parsing ("2.5k", "1 lakh", "₹2,100")
land here in Phase 0, day 4.

```sh
dart test
```
