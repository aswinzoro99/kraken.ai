import 'package:ledger/ledger.dart';

import '../../../core/time/clock.dart';
import '../domain/expense.dart';
import '../domain/group.dart';
import '../domain/group_ledger.dart';

/// The groups from the design canvas, with six months of history built
/// relative to today, so Home always has a current month to show.
///
/// Balances match the design exactly: Goa Trip −₹150, Flat 302 +₹2,180,
/// Weekend trek +₹840, Office lunch settled. Past months are settled.
final class MockGroupsRepository implements GroupsRepository {
  const MockGroupsRepository({this.clock = systemClock, this.empty = false});

  final Clock clock;

  /// Start with no groups, to see the empty state.
  final bool empty;

  @override
  Stream<List<GroupLedger>> watchLedgers(String uid) => Stream.value(empty ? const [] : buildMockLedgers(clock()));
}

const _me = Member('me', 'You');
const _sreya = Member('sreya', 'Sreya');
const _arjun = Member('arjun', 'Arjun');
const _meera = Member('meera', 'Meera');
const _rohan = Member('rohan', 'Rohan');
const _kavya = Member('kavya', 'Kavya');
const _dev = Member('dev', 'Dev');
const _nisha = Member('nisha', 'Nisha');
const _priya = Member('priya', 'Priya');

const goaTrip = Group(id: 'goa', name: 'Goa Trip', members: [_me, _sreya, _arjun, _meera]);
const flat302 = Group(id: 'flat', name: 'Flat 302', members: [_me, _rohan, _kavya], detail: 'rent, wifi, groceries');
const weekendTrek =
    Group(id: 'trek', name: 'Weekend trek', members: [_me, _sreya, _arjun, _dev, _nisha], detail: 'Lonavala');
const officeLunch = Group(
  id: 'lunch',
  name: 'Office lunch',
  members: [_me, _priya, Member('rahul', 'Rahul'), Member('anjali', 'Anjali'), Member('vikram', 'Vikram'), Member('zoya', 'Zoya')],
);

List<GroupLedger> buildMockLedgers(DateTime now) {
  final b = _Builder(now);

  // ---- This month ----------------------------------------------------
  // Goa Trip, exactly as on the Group screen design (₹19,000, your share ₹4,750).
  b.spend(goaTrip, 'Airport cab', 'me', 1800, b.daysAgo(5, 9), ExpenseCategory.travel, ExpenseSource.voice);
  b.spend(goaTrip, 'Villa stay · 2 nights', 'meera', 12000, b.daysAgo(5, 15), ExpenseCategory.stays);
  b.spend(goaTrip, 'Scooter rentals', 'arjun', 2400, b.daysAgo(4, 10), ExpenseCategory.travel);
  b.spend(goaTrip, 'Beach shack lunch', 'me', 2800, b.daysAgo(4, 14), ExpenseCategory.foodDrinks, ExpenseSource.scan);

  // Flat 302: rent paid by you and paid back; bills and groceries still open.
  b.spend(flat302, 'Rent', 'me', 36000, b.thisMonth(1), ExpenseCategory.rentBills);
  b.pay(flat302, 'rohan', 'me', 12000, b.thisMonth(2));
  b.pay(flat302, 'kavya', 'me', 12000, b.thisMonth(2));
  b.spend(flat302, 'Wifi', 'kavya', 1200, b.thisMonth(3), ExpenseCategory.rentBills);
  b.spend(flat302, 'Electricity', 'rohan', 2400, b.thisMonth(5), ExpenseCategory.rentBills);
  b.spend(flat302, 'Groceries', 'me', 5070, b.thisMonth(9), ExpenseCategory.groceries, ExpenseSource.agent);

  // Weekend trek to Lonavala.
  b.spend(weekendTrek, 'Fuel and tolls', 'me', 2100, b.daysAgo(17, 7), ExpenseCategory.travel);
  b.spend(weekendTrek, 'Dinner at the dhaba', 'arjun', 2100, b.daysAgo(17, 21), ExpenseCategory.foodDrinks);
  b.spend(weekendTrek, 'Breakfast', 'nisha', 2100, b.daysAgo(16, 9), ExpenseCategory.foodDrinks);

  // Office lunch: Priya paid, you paid her back.
  b.spend(officeLunch, 'Team lunch', 'priya', 3600, b.daysAgo(2, 13), ExpenseCategory.foodDrinks);
  b.pay(officeLunch, 'me', 'priya', 600, b.daysAgo(1, 19));

  // ---- Earlier months, each settled at month end ------------------------
  const electricity = [2310, 2460, 2880, 2640, 2190];
  const groceries = [5040, 5520, 4590, 5310, 4860];
  const lunches = [3600, 4200, 3300, 3900, 3000];
  for (var k = 1; k <= 5; k++) {
    final month = b.monthStart(k);
    b.beginMonth();
    b.spend(flat302, 'Rent', 'me', 36000, b.on(month, 1), ExpenseCategory.rentBills);
    b.spend(flat302, 'Wifi', 'kavya', 1200, b.on(month, 3), ExpenseCategory.rentBills);
    b.spend(flat302, 'Electricity', 'rohan', electricity[k - 1], b.on(month, 5), ExpenseCategory.rentBills);
    b.spend(flat302, 'Groceries', 'me', groceries[k - 1], b.on(month, 12), ExpenseCategory.groceries);
    b.spend(officeLunch, 'Team lunch', 'priya', lunches[k - 1], b.on(month, 14), ExpenseCategory.foodDrinks);
    switch (k) {
      case 1:
        b.spend(flat302, 'Movie night', 'kavya', 1260, b.on(month, 20), ExpenseCategory.other);
        b.spend(flat302, 'Dinner out', 'rohan', 3450, b.on(month, 26), ExpenseCategory.foodDrinks);
      case 2:
        b.spend(flat302, 'Sofa for the hall', 'me', 9000, b.on(month, 18), ExpenseCategory.other);
      case 3:
        b.spend(weekendTrek, 'Bus to Rajmachi', 'me', 1750, b.on(month, 9), ExpenseCategory.travel);
        b.spend(weekendTrek, 'Homestay', 'dev', 6000, b.on(month, 9), ExpenseCategory.stays);
        b.spend(weekendTrek, 'Trail food', 'sreya', 2500, b.on(month, 10), ExpenseCategory.foodDrinks);
      case 4:
        b.spend(officeLunch, 'Farewell cake', 'me', 1800, b.on(month, 22), ExpenseCategory.foodDrinks);
    }
    b.settleMonth(b.on(month, 28));
  }

  return [
    for (final g in [goaTrip, flat302, weekendTrek, officeLunch])
      GroupLedger(
        group: g,
        myMemberId: 'me',
        expenses: b.expenses.where((e) => e.groupId == g.id).toList(),
        payments: b.payments.where((p) => p.groupId == g.id).toList(),
      ),
  ];
}

class _Builder {
  _Builder(this.now);
  final DateTime now;
  final expenses = <Expense>[];
  final payments = <Payment>[];
  int _id = 0;
  int _monthStart = 0;
  int _paymentStart = 0;

  DateTime daysAgo(int days, int hour) {
    final d = now.subtract(Duration(days: days));
    return DateTime(d.year, d.month, d.day, hour);
  }

  /// A day of the current month, never later than today.
  DateTime thisMonth(int day) => DateTime(now.year, now.month, day > now.day ? now.day : day, 10);

  DateTime monthStart(int monthsAgo) => DateTime(now.year, now.month - monthsAgo);

  DateTime on(DateTime month, int day) {
    final last = DateTime(month.year, month.month + 1, 0).day;
    return DateTime(month.year, month.month, day > last ? last : day, 12);
  }

  void spend(
    Group g,
    String what,
    String payer,
    int rupees,
    DateTime date,
    ExpenseCategory category, [
    ExpenseSource source = ExpenseSource.manual,
  ]) {
    final total = Money.rupees(rupees);
    expenses.add(Expense(
      id: 'e${_id++}',
      groupId: g.id,
      description: what,
      date: date,
      paidBy: payer,
      total: total,
      shares: splitEqually(total, [for (final m in g.members) m.id]),
      category: category,
      source: source,
    ));
  }

  void pay(Group g, String from, String to, int rupees, DateTime date) => payments.add(
      Payment(id: 'p${_id++}', groupId: g.id, from: from, to: to, amount: Money.rupees(rupees), date: date));

  void beginMonth() {
    _monthStart = expenses.length;
    _paymentStart = payments.length;
  }

  /// Adds payments so that, within each group, everything since
  /// [beginMonth] is square with "me".
  void settleMonth(DateTime date) {
    final monthExpenses = expenses.sublist(_monthStart);
    final monthPayments = payments.sublist(_paymentStart);
    for (final groupId in monthExpenses.map((e) => e.groupId).toSet()) {
      final owed = balancesWith(
        'me',
        monthExpenses.where((e) => e.groupId == groupId).map((e) => e.toSplit()),
        monthPayments.where((p) => p.groupId == groupId).map((p) => p.toTransfer()),
      );
      owed.forEach((person, amount) {
        payments.add(Payment(
          id: 'p${_id++}',
          groupId: groupId,
          from: amount.isPositive ? person : 'me',
          to: amount.isPositive ? 'me' : person,
          amount: amount.abs(),
          date: date,
        ));
      });
    }
  }
}
