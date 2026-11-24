import 'package:flutter_test/flutter_test.dart';
import 'package:kraken/features/groups/data/mock_groups_repository.dart';
import 'package:kraken/features/groups/domain/expense.dart';
import 'package:kraken/features/home/domain/home_calculator.dart';
import 'package:kraken/features/home/domain/home_snapshot.dart';
import 'package:ledger/ledger.dart';

void main() {
  final now = DateTime(2026, 11, 24, 18);
  final ledgers = buildMockLedgers(now);
  final home = HomeCalculator.build(ledgers: ledgers, now: now);

  group('spending', () {
    test('this month is your share only, payments excluded', () {
      expect(home.spending.month, DateTime(2026, 11));
      expect(home.spending.total, const Money.rupees(21500));
      expect(home.spending.inProgress, isTrue);
    });

    test('categories are largest first and add up to the total', () {
      final c = home.spending.categories;
      expect([for (final x in c) x.category], [
        ExpenseCategory.rentBills,
        ExpenseCategory.stays,
        ExpenseCategory.foodDrinks,
        ExpenseCategory.groceries,
        ExpenseCategory.travel,
      ]);
      expect([for (final x in c) x.amount.wholeRupees], [13200, 3000, 2140, 1690, 1470]);
      expect(Money.sum(c.map((x) => x.amount)), home.spending.total);
    });

    test('a running month is compared with the same days of last month', () {
      expect(home.spending.comparisonLabel, '1–24 Oct');
      expect(home.spending.comparison, const Money.rupees(15870));
      expect(home.spending.changePercent, 35);
    });

    test('a finished month is compared with the whole month before', () {
      final october = HomeCalculator.spending(ledgers, DateTime(2026, 10), now);
      expect(october.total, const Money.rupees(17020));
      expect(october.inProgress, isFalse);
      expect(october.comparisonLabel, 'September');
      expect(october.comparison, const Money.rupees(18760));
      expect(october.changePercent, -9);
    });

    test('six months of trend, oldest first', () {
      expect([for (final m in home.spending.months) m.month.month], [6, 7, 8, 9, 10, 11]);
      expect([for (final m in home.spending.months) m.total.wholeRupees], [15250, 16000, 17490, 18760, 17020, 21500]);
    });

    test('no earlier spending means no comparison', () {
      final s = HomeCalculator.spending(ledgers, DateTime(2026, 6), now);
      expect(s.comparison, isNull);
      expect(s.changePercent, isNull);
    });
  });

  group('balances', () {
    test('are per person across groups, people you owe first', () {
      final people = home.balances.people;
      expect([for (final p in people) (p.name, p.amount.wholeRupees)], [
        ('Meera', -1850),
        ('Sreya', 1570),
        ('Kavya', 1290),
        ('Rohan', 890),
        ('Arjun', 550),
        ('Dev', 420),
      ]);
      expect(people[1].groupNames, ['Goa Trip', 'Weekend trek']);
    });

    test('totals: owed ₹4,720, you owe ₹1,850, net matches the group view', () {
      final b = home.balances;
      expect(b.owedToYou, const Money.rupees(4720));
      expect(b.youOwe, const Money.rupees(1850));
      expect(b.net, const Money.rupees(2870));
      expect(b.net, Money.sum(home.groups.map((g) => g.myBalance)));
      expect((b.owingYouCount, b.youOweCount), (5, 1));
    });
  });

  test('groups match the design balances, most recent first', () {
    expect([for (final g in home.groups) (g.name, g.myBalance.wholeRupees)], [
      ('Office lunch', 0),
      ('Goa Trip', -150),
      ('Flat 302', 2180),
      ('Weekend trek', 840),
    ]);
  });

  test('recent activity mixes expenses and payments, newest first', () {
    final r = home.recent;
    expect(r.first, isA<PaymentActivity>().having((p) => p.toName, 'to', 'Priya'));
    final lunch = r[1] as ExpenseActivity;
    expect((lunch.expense.description, lunch.yourEffect), ('Team lunch', const Money.rupees(-600)));
    final beach = r[2] as ExpenseActivity;
    expect((beach.paidByYou, beach.yourEffect, beach.expense.source), (true, const Money.rupees(2100), ExpenseSource.scan));
  });

  test('no groups gives an empty, zeroed snapshot', () {
    final empty = HomeCalculator.build(ledgers: const [], now: now);
    expect(empty.isEmpty, isTrue);
    expect(empty.spending.total, Money.zero);
    expect(empty.balances.allSettled, isTrue);
    expect(empty.recent, isEmpty);
  });
}
