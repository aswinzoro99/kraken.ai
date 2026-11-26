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

/// How the total was divided, as on the "Split the total" design.
enum SplitMethod {
  equal('Equally'),
  exact('Exact'),
  percent('Percent'),
  shares('Shares');

  const SplitMethod(this.label);
  final String label;
}

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
    this.split = SplitMethod.equal,
    this.weights = const {},
    this.addedBy,
  });

  final String id;
  final String groupId;
  final String description;
  final DateTime date;
  final String paidBy;
  final Money total;

  /// Each member's part, in paise. Always adds up to [total].
  final Map<String, Money> shares;
  final ExpenseCategory category;
  final ExpenseSource source;
  final SplitMethod split;

  /// What was typed for [split], so an edit opens as it was saved: 1 per
  /// person for equal, paise for exact, basis points (25% = 2500) for
  /// percent, and share counts for shares. Empty for older expenses.
  final Map<String, int> weights;

  /// The member who added it; null for sample data.
  final String? addedBy;

  Money shareOf(String member) => shares[member] ?? Money.zero;

  SplitExpense toSplit() => SplitExpense(paidBy: paidBy, total: total, shares: shares);

  Expense copyWith({String? id, DateTime? date}) => Expense(
    id: id ?? this.id,
    groupId: groupId,
    description: description,
    date: date ?? this.date,
    paidBy: paidBy,
    total: total,
    shares: shares,
    category: category,
    source: source,
    split: split,
    weights: weights,
    addedBy: addedBy,
  );

  Map<String, Object?> toJson() => {
    'id': id,
    'groupId': groupId,
    'description': description,
    'date': date.toIso8601String(),
    'paidBy': paidBy,
    'total': total.paise,
    'shares': {for (final e in shares.entries) e.key: e.value.paise},
    'category': category.name,
    'source': source.name,
    'split': split.name,
    'weights': weights,
    'addedBy': addedBy,
  };

  static Expense fromJson(Map<String, Object?> json) => Expense(
    id: json['id']! as String,
    groupId: json['groupId']! as String,
    description: json['description']! as String,
    date: DateTime.parse(json['date']! as String),
    paidBy: json['paidBy']! as String,
    total: Money(json['total']! as int),
    shares: {for (final e in (json['shares']! as Map).entries) e.key as String: Money(e.value as int)},
    category: ExpenseCategory.values.byName(json['category']! as String),
    source: ExpenseSource.values.byName(json['source']! as String),
    split: SplitMethod.values.byName(json['split'] as String? ?? 'equal'),
    weights: {for (final e in ((json['weights'] as Map?) ?? const {}).entries) e.key as String: e.value as int},
    addedBy: json['addedBy'] as String?,
  );
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

  Map<String, Object?> toJson() => {
    'id': id,
    'groupId': groupId,
    'from': from,
    'to': to,
    'amount': amount.paise,
    'date': date.toIso8601String(),
  };

  static Payment fromJson(Map<String, Object?> json) => Payment(
    id: json['id']! as String,
    groupId: json['groupId']! as String,
    from: json['from']! as String,
    to: json['to']! as String,
    amount: Money(json['amount']! as int),
    date: DateTime.parse(json['date']! as String),
  );
}

/// One line of a group's history: who did what, and when.
enum ActivityKind {
  groupCreated,
  memberJoined,
  expenseAdded,
  expenseEdited,
  expenseDeleted,
  expenseRestored,
  paymentRecorded,
}

final class ActivityEntry {
  const ActivityEntry({
    required this.id,
    required this.groupId,
    required this.kind,
    required this.authorId,
    required this.date,
    this.subject = '',
    this.amount,
    this.expenseId,
  });

  final String id;
  final String groupId;
  final ActivityKind kind;

  /// The member who did it.
  final String authorId;
  final DateTime date;

  /// The expense's description, or the name that joined.
  final String subject;
  final Money? amount;
  final String? expenseId;

  Map<String, Object?> toJson() => {
    'id': id,
    'groupId': groupId,
    'kind': kind.name,
    'authorId': authorId,
    'date': date.toIso8601String(),
    'subject': subject,
    'amount': amount?.paise,
    'expenseId': expenseId,
  };

  static ActivityEntry fromJson(Map<String, Object?> json) => ActivityEntry(
    id: json['id']! as String,
    groupId: json['groupId']! as String,
    kind: ActivityKind.values.byName(json['kind']! as String),
    authorId: json['authorId']! as String,
    date: DateTime.parse(json['date']! as String),
    subject: json['subject'] as String? ?? '',
    amount: switch (json['amount']) {
      final int p => Money(p),
      _ => null,
    },
    expenseId: json['expenseId'] as String?,
  );
}
