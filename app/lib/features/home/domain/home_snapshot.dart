import 'package:ledger/ledger.dart';

import '../../groups/domain/expense.dart';

/// Everything Home shows, computed from the ledgers. Pure data.
final class HomeSnapshot {
  const HomeSnapshot({required this.spending, required this.balances, required this.recent, required this.groups});

  final SpendingSummary spending;
  final BalanceSummary balances;

  /// Newest first.
  final List<ActivityItem> recent;
  final List<GroupSummary> groups;

  bool get isEmpty => groups.isEmpty;
}

// ---- What you spent ----------------------------------------------------

final class MonthTotal {
  const MonthTotal(this.month, this.total);

  /// First day of the month.
  final DateTime month;
  final Money total;
}

final class CategoryTotal {
  const CategoryTotal(this.category, this.amount, this.share);
  final ExpenseCategory category;
  final Money amount;

  /// 0–1 of the month's total.
  final double share;
}

/// Your share of spending in one month, and how it compares.
final class SpendingSummary {
  const SpendingSummary({
    required this.month,
    required this.total,
    required this.categories,
    required this.months,
    this.comparison,
    this.comparisonLabel,
    this.inProgress = false,
  });

  /// First day of the selected month.
  final DateTime month;
  final Money total;

  /// Largest first; categories with nothing spent are left out.
  final List<CategoryTotal> categories;

  /// The last six months, oldest first, for the trend bars.
  final List<MonthTotal> months;

  /// The previous month, cut to the same days when [month] is the current
  /// one, so a half-finished month isn't compared with a whole one.
  final Money? comparison;

  /// What [comparison] covers, e.g. "1–24 Oct" or "October".
  final String? comparisonLabel;

  /// The selected month is the current one and still running.
  final bool inProgress;

  /// Change against [comparison] in whole percent; null when there is
  /// nothing to compare with.
  int? get changePercent {
    final base = comparison;
    if (base == null || base.isZero) return null;
    return ((total.paise - base.paise) * 100 / base.paise).round();
  }
}

// ---- Who owes whom -----------------------------------------------------

final class PersonBalance {
  const PersonBalance({required this.personId, required this.name, required this.amount, required this.groupNames});

  final String personId;
  final String name;

  /// Positive: they owe you. Negative: you owe them.
  final Money amount;

  /// Groups where the debt comes from.
  final List<String> groupNames;
}

/// Balances per person across all groups. Netting per group would hide real
/// debts (in Goa Trip you owe Meera ₹1,850 even though the group nets to
/// ₹150), so Home works per person.
final class BalanceSummary {
  const BalanceSummary(this.people);

  /// People you owe first, then people who owe you; largest first.
  final List<PersonBalance> people;

  Money get owedToYou => Money.sum(people.where((p) => p.amount.isPositive).map((p) => p.amount));
  Money get youOwe => Money.sum(people.where((p) => p.amount.isNegative).map((p) => p.amount.abs()));
  Money get net => owedToYou - youOwe;
  int get owingYouCount => people.where((p) => p.amount.isPositive).length;
  int get youOweCount => people.where((p) => p.amount.isNegative).length;
  bool get allSettled => people.isEmpty;
}

// ---- What happened -----------------------------------------------------

sealed class ActivityItem {
  const ActivityItem({required this.date, required this.groupName});
  final DateTime date;
  final String groupName;
}

final class ExpenseActivity extends ActivityItem {
  const ExpenseActivity({
    required super.date,
    required super.groupName,
    required this.expense,
    required this.payerName,
    required this.paidByYou,
    required this.yourEffect,
  });

  final Expense expense;
  final String payerName;
  final bool paidByYou;

  /// What it did to your balance: positive you lent, negative you borrowed,
  /// zero you weren't part of it.
  final Money yourEffect;
}

final class PaymentActivity extends ActivityItem {
  const PaymentActivity({
    required super.date,
    required super.groupName,
    required this.fromName,
    required this.toName,
    required this.amount,
  });

  final String fromName;
  final String toName;
  final Money amount;
}

// ---- Groups --------------------------------------------------------------

final class GroupSummary {
  const GroupSummary({
    required this.id,
    required this.name,
    required this.memberCount,
    required this.detail,
    required this.myBalance,
    this.lastActivity,
  });

  final String id;
  final String name;
  final int memberCount;
  final String detail;

  /// Positive: you're owed. Negative: you owe. Zero: settled up.
  final Money myBalance;
  final DateTime? lastActivity;
}
