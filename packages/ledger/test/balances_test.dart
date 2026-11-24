import 'package:ledger/ledger.dart';
import 'package:test/test.dart';

void main() {
  group('splitEqually', () {
    test('gives leftover paise to the first people', () {
      final shares = splitEqually(const Money.rupees(100), ['a', 'b', 'c']);
      expect(shares.values, [const Money(3334), const Money(3333), const Money(3333)]);
      expect(Money.sum(shares.values), const Money.rupees(100));
    });

    test('splits evenly when it can', () {
      expect(splitEqually(const Money.rupees(2100), ['me', 'sreya']).values,
          [const Money.rupees(1050), const Money.rupees(1050)]);
    });

    test('rejects empty, duplicate and negative input', () {
      expect(() => splitEqually(Money.zero, []), throwsArgumentError);
      expect(() => splitEqually(Money.zero, ['a', 'a']), throwsArgumentError);
      expect(() => splitEqually(const Money(-1), ['a']), throwsArgumentError);
    });
  });

  group('SplitExpense', () {
    test('rejects shares that do not add up', () {
      expect(
        () => SplitExpense(paidBy: 'a', total: const Money(100), shares: {'a': const Money(50), 'b': const Money(49)}),
        throwsArgumentError,
      );
    });
  });

  group('balancesWith', () {
    // The Goa Trip from the design canvas: four people, four expenses.
    const people = ['me', 'sreya', 'arjun', 'meera'];
    SplitExpense even(String payer, int rupees) =>
        SplitExpense(paidBy: payer, total: Money.rupees(rupees), shares: splitEqually(Money.rupees(rupees), people));
    final goa = [even('arjun', 2400), even('me', 2800), even('meera', 12000), even('me', 1800)];

    test('matches the design: Sreya +1,150, Arjun +550, Meera −1,850', () {
      final b = balancesWith('me', goa);
      expect(b, {
        'sreya': const Money.rupees(1150),
        'arjun': const Money.rupees(550),
        'meera': const Money.rupees(-1850),
      });
      expect(Money.sum(b.values), const Money.rupees(-150));
    });

    test('transfers settle debts in either direction and square people drop out', () {
      final b = balancesWith('me', goa, const [
        Transfer(from: 'me', to: 'meera', amount: Money.rupees(1850)),
        Transfer(from: 'sreya', to: 'me', amount: Money.rupees(1000)),
      ]);
      expect(b, {'sreya': const Money.rupees(150), 'arjun': const Money.rupees(550)});
    });

    test('debts between other people do not touch mine', () {
      final b = balancesWith('me', [
        SplitExpense(
          paidBy: 'sreya',
          total: const Money.rupees(300),
          shares: {'sreya': const Money.rupees(150), 'arjun': const Money.rupees(150)},
        ),
      ], const [
        Transfer(from: 'arjun', to: 'sreya', amount: Money.rupees(150)),
      ]);
      expect(b, isEmpty);
    });
  });

  test('Money.sum adds exactly', () {
    expect(Money.sum([const Money(1), const Money(2), const Money(-3)]), Money.zero);
    expect(Money.sum(const []), Money.zero);
  });
}
