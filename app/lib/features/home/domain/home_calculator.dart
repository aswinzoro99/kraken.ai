import 'package:intl/intl.dart';
import 'package:ledger/ledger.dart';

import '../../groups/domain/expense.dart';
import '../../groups/domain/group_ledger.dart';
import 'home_snapshot.dart';

/// Builds [HomeSnapshot] from the person's groups. Pure: give it the same
/// ledgers, month and time and it returns the same answer.
abstract final class HomeCalculator {
  static const trendMonths = 6;
  static const recentCount = 4;

  static HomeSnapshot build({required List<GroupLedger> ledgers, required DateTime now, DateTime? month}) {
    final selected = _monthOf(month ?? now);
    return HomeSnapshot(
      spending: spending(ledgers, selected, now),
      balances: balances(ledgers),
      recent: recent(ledgers, recentCount),
      groups: groups(ledgers),
    );
  }

  // ---- Spending ----

  /// Your share of everything in [month]. Payments are settling up, not
  /// spending, so they never count.
  static SpendingSummary spending(List<GroupLedger> ledgers, DateTime month, DateTime now) {
    final current = _monthOf(now);
    final inProgress = month == current;
    final shares = [
      for (final l in ledgers)
        for (final e in l.expenses) (date: e.date, category: e.category, amount: e.shareOf(l.myMemberId)),
    ].where((s) => !s.amount.isZero).toList();

    Money totalBetween(DateTime from, DateTime until) =>
        Money.sum(shares.where((s) => !s.date.isBefore(from) && s.date.isBefore(until)).map((s) => s.amount));

    final next = DateTime(month.year, month.month + 1);
    final total = totalBetween(month, next);

    final byCategory = <ExpenseCategory, Money>{};
    for (final s in shares.where((s) => !s.date.isBefore(month) && s.date.isBefore(next))) {
      byCategory[s.category] = (byCategory[s.category] ?? Money.zero) + s.amount;
    }
    final categories = [
      for (final MapEntry(key: c, value: amount) in byCategory.entries)
        CategoryTotal(c, amount, total.isZero ? 0 : amount.paise / total.paise),
    ]..sort((a, b) => b.amount.compareTo(a.amount));

    final previous = DateTime(month.year, month.month - 1);
    Money? comparison;
    String? label;
    final hasEarlier = shares.any((s) => s.date.isBefore(month));
    if (hasEarlier) {
      if (inProgress) {
        // Same days of last month: 1st up to today's date.
        final lastDay = DateTime(previous.year, previous.month + 1, 0).day;
        final day = now.day > lastDay ? lastDay : now.day;
        comparison = totalBetween(previous, DateTime(previous.year, previous.month, day + 1));
        label = '1–$day ${DateFormat.MMM().format(previous)}';
      } else {
        comparison = totalBetween(previous, month);
        label = DateFormat.MMMM().format(previous);
      }
    }

    final months = [
      for (var i = trendMonths - 1; i >= 0; i--)
        () {
          final start = DateTime(current.year, current.month - i);
          return MonthTotal(start, totalBetween(start, DateTime(start.year, start.month + 1)));
        }(),
    ];

    return SpendingSummary(
      month: month,
      total: total,
      categories: categories,
      months: months,
      comparison: comparison,
      comparisonLabel: label,
      inProgress: inProgress,
    );
  }

  // ---- Balances ----

  static BalanceSummary balances(List<GroupLedger> ledgers) {
    final totals = <String, Money>{};
    final names = <String, String>{};
    final groupsOf = <String, List<String>>{};
    for (final l in ledgers) {
      final owed = balancesWith(
        l.myMemberId,
        l.expenses.map((e) => e.toSplit()),
        l.payments.map((p) => p.toTransfer()),
      );
      owed.forEach((person, amount) {
        totals[person] = (totals[person] ?? Money.zero) + amount;
        names[person] = l.nameOf(person);
        (groupsOf[person] ??= []).add(l.group.name);
      });
    }
    final people =
        [
          for (final MapEntry(key: id, value: amount) in totals.entries)
            if (!amount.isZero)
              PersonBalance(personId: id, name: names[id]!, amount: amount, groupNames: groupsOf[id]!),
        ]..sort((a, b) {
          // You owe first (they need action from you), then largest first.
          if (a.amount.isNegative != b.amount.isNegative) return a.amount.isNegative ? -1 : 1;
          return b.amount.abs().compareTo(a.amount.abs());
        });
    return BalanceSummary(people);
  }

  // ---- Activity ----

  static List<ActivityItem> recent(List<GroupLedger> ledgers, int count) {
    final items = <ActivityItem>[
      for (final l in ledgers) ...[
        for (final e in l.expenses)
          ExpenseActivity(
            date: e.date,
            groupName: l.group.name,
            expense: e,
            payerName: l.nameOf(e.paidBy),
            paidByYou: e.paidBy == l.myMemberId,
            yourEffect: (e.paidBy == l.myMemberId ? e.total : Money.zero) - e.shareOf(l.myMemberId),
          ),
        for (final p in l.payments)
          PaymentActivity(
            date: p.date,
            groupName: l.group.name,
            fromName: l.nameOf(p.from),
            toName: l.nameOf(p.to),
            amount: p.amount,
          ),
      ],
    ]..sort((a, b) => b.date.compareTo(a.date));
    return items.take(count).toList();
  }

  // ---- Groups ----

  static List<GroupSummary> groups(List<GroupLedger> ledgers) {
    final summaries = [
      for (final l in ledgers)
        GroupSummary(
          id: l.group.id,
          name: l.group.name,
          memberCount: l.group.members.length,
          detail: l.group.detail,
          myBalance: Money.sum(
            balancesWith(
              l.myMemberId,
              l.expenses.map((e) => e.toSplit()),
              l.payments.map((p) => p.toTransfer()),
            ).values,
          ),
          lastActivity: l.lastActivity,
        ),
    ];
    // Most recently active first.
    summaries.sort((a, b) => (b.lastActivity ?? DateTime(0)).compareTo(a.lastActivity ?? DateTime(0)));
    return summaries;
  }

  static DateTime _monthOf(DateTime d) => DateTime(d.year, d.month);
}
