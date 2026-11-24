import 'package:ledger/ledger.dart';
import 'package:test/test.dart';

void main() {
  group('Money', () {
    test('stores whole paise and converts from rupees', () {
      expect(const Money.rupees(2100).paise, 210000);
      expect(const Money(3334).wholeRupees, 33);
      expect(const Money(3334).remainderPaise, 34);
    });

    test('adds, subtracts and negates exactly', () {
      const a = Money(3334);
      const b = Money(3333);
      expect(a + b + b, const Money.rupees(100));
      expect(a - b, const Money(1));
      expect(-a, const Money(-3334));
      expect((-a).abs(), a);
    });

    test('compares by value', () {
      expect(const Money(5), const Money(5));
      expect(const Money(5).hashCode, const Money(5).hashCode);
      expect(const Money(4) < const Money(5), isTrue);
      expect([const Money(9), const Money(-1), Money.zero]..sort(),
          [const Money(-1), Money.zero, const Money(9)]);
    });

    test('reports sign', () {
      expect(Money.zero.isZero, isTrue);
      expect(const Money(-1).isNegative, isTrue);
      expect(const Money(1).isPositive, isTrue);
      expect(const Money(-150).remainderPaise, 50);
    });

    test('toString shows rupees and paise', () {
      expect(const Money(-15050).toString(), 'Money(-₹150.50)');
    });
  });
}
