import 'package:ledger/ledger.dart';

/// Spending categories, in the order the Insights design lists them.
enum ExpenseCategory {
  rentBills('Rent & bills'),
  foodDrinks('Food & drinks'),
  travel('Travel'),
  stays('Stays'),
  groceries('Groceries'),
  other('Other');

  const ExpenseCategory(this.label);
  final String label;
}

/// How an expense got into Kraken; shown as a small tag.
enum ExpenseSource { manual, agent, voice, scan, gmail }

final class Expense {
  const Expense({
    required this.id,
    required this.groupId,
    required this.description,
    required this.date,
    required this.paidBy,
    required this.total,
    required this.shares,
    this.category = ExpenseCategory.other,
    this.source = ExpenseSource.manual,
  });

  final String id;
  final String groupId;
  final String description;
  final DateTime date;
  final String paidBy;
  final Money total;
  final Map<String, Money> shares;
  final ExpenseCategory category;
  final ExpenseSource source;

  Money shareOf(String member) => shares[member] ?? Money.zero;

  SplitExpense toSplit() => SplitExpense(paidBy: paidBy, total: total, shares: shares);
}

/// Money handed over to settle up.
final class Payment {
  const Payment({
    required this.id,
    required this.groupId,
    required this.from,
    required this.to,
    required this.amount,
    required this.date,
  });

  final String id;
  final String groupId;
  final String from;
  final String to;
  final Money amount;
  final DateTime date;

  Transfer toTransfer() => Transfer(from: from, to: to, amount: amount);
}
