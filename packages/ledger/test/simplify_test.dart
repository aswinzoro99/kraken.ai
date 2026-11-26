import 'dart:math';

import 'package:ledger/ledger.dart';
import 'package:test/test.dart';

SplitExpense spend(String payer, int rupees, List<String> people) {
  final total = Money.rupees(rupees);
  return SplitExpense(paidBy: payer, total: total, shares: splitEqually(total, people));
}

void main() {
  const goa = ['me', 'sreya', 'arjun', 'meera'];

  test('netBalances: the Goa Trip design', () {
    final net = netBalances([
      spend('me', 1800, goa),
      spend('meera', 12000, goa),
      spend('arjun', 2400, goa),
      spend('me', 2800, goa),
    ]);
    expect(
      net,
      {
        'me':
            const Money.rupees(-150 + 0) +
            const Money.rupees(0) +
            const Money.rupees(150 + 0) -
            const Money.rupees(150),
        'meera': const Money.rupees(7250),
        'arjun': const Money.rupees(-2350),
        'sreya': const Money.rupees(-4750),
      }..removeWhere((_, m) => m.isZero),
    );
    expect(Money.sum(net.values), Money.zero);
  });

  test('simplifyDebts settles everyone in as few payments as it can', () {
    final net = {'a': const Money.rupees(-30), 'b': const Money.rupees(-20), 'c': const Money.rupees(50)};
    final transfers = simplifyDebts(net);
    expect(transfers.map((t) => '${t.from}>${t.to}:${t.amount.paise}'), ['a>c:3000', 'b>c:2000']);
  });

  test('payments that over-settle flip who owes whom', () {
    final net = netBalances(
      [
        spend('a', 100, ['a', 'b']),
      ],
      [const Transfer(from: 'b', to: 'a', amount: Money.rupees(80))],
    );
    expect(net, {'a': const Money.rupees(-30), 'b': const Money.rupees(30)});
    final t = simplifyDebts(net).single;
    expect((t.from, t.to, t.amount), ('a', 'b', const Money.rupees(30)));
  });

  test('everyone square: nothing to pay', () {
    expect(
      simplifyDebts(
        netBalances([
          spend('a', 100, ['a']),
        ]),
      ),
      isEmpty,
    );
  });

  test('random groups: simplified payments settle every balance exactly', () {
    final random = Random(42);
    for (var i = 0; i < 500; i++) {
      final people = [for (var p = 0; p < 2 + random.nextInt(7); p++) 'p$p'];
      final expenses = [
        for (var e = 0; e < random.nextInt(15); e++)
          spend(
            people[random.nextInt(people.length)],
            1 + random.nextInt(5000),
            people.sublist(random.nextInt(people.length - 1)),
          ),
      ];
      final net = netBalances(expenses);
      final transfers = simplifyDebts(net);
      expect(netBalances(expenses, transfers), isEmpty);
      expect(transfers.length, lessThan(people.length));
    }
  });

  test('refuses balances that do not add up', () {
    expect(() => simplifyDebts({'a': const Money(1)}), throwsArgumentError);
  });
}
