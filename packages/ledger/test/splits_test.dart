import 'dart:math';

import 'package:ledger/ledger.dart';
import 'package:test/test.dart';

void main() {
  group('splitExactly', () {
    test('keeps the typed amounts and drops zeros', () {
      final shares = splitExactly(const Money.rupees(3300), {
        'y': const Money.rupees(900),
        's': const Money.rupees(700),
        'a': const Money.rupees(1700),
        'm': Money.zero,
      });
      expect(shares, {'y': const Money.rupees(900), 's': const Money.rupees(700), 'a': const Money.rupees(1700)});
    });

    test('refuses amounts that are a paisa off', () {
      expect(
        () => splitExactly(const Money.rupees(100), {'a': const Money(5000), 'b': const Money(4999)}),
        throwsArgumentError,
      );
    });
  });

  group('splitByPercent', () {
    test('matches the Split the total design: 25 / 25 / 30 / 20 of ₹3,300', () {
      final shares = splitByPercent(const Money.rupees(3300), {'y': 2500, 's': 2500, 'a': 3000, 'm': 2000});
      expect(shares, {
        'y': const Money.rupees(825),
        's': const Money.rupees(825),
        'a': const Money.rupees(990),
        'm': const Money.rupees(660),
      });
    });

    test('uneven paise go to the first people', () {
      final shares = splitByPercent(const Money(100), {'a': 3333, 'b': 3333, 'c': 3334});
      expect(shares.values, [const Money(34), const Money(33), const Money(33)]);
    });

    test('must add up to 100%', () {
      expect(() => splitByPercent(const Money.rupees(10), {'a': 5000, 'b': 4000}), throwsArgumentError);
    });
  });

  group('splitByShares', () {
    test('matches the design: 1 / 1 / 2 / 1 of ₹3,300', () {
      final shares = splitByShares(const Money.rupees(3300), {'y': 1, 's': 1, 'a': 2, 'm': 1});
      expect(shares, {
        'y': const Money.rupees(660),
        's': const Money.rupees(660),
        'a': const Money.rupees(1320),
        'm': const Money.rupees(660),
      });
    });

    test('leaves out people with no shares', () {
      final shares = splitByShares(const Money.rupees(100), {'a': 1, 'b': 0, 'c': 1});
      expect(shares.keys, ['a', 'c']);
    });

    test('needs someone with a share', () {
      expect(() => splitByShares(const Money.rupees(100), {'a': 0}), throwsArgumentError);
    });

    test('always adds up to the total, for any amount and shares', () {
      final random = Random(7);
      for (var i = 0; i < 2000; i++) {
        final total = Money(random.nextInt(10000000));
        final weights = {for (var p = 0; p < 1 + random.nextInt(8); p++) 'p$p': random.nextInt(5)};
        if (weights.values.every((w) => w == 0)) weights['p0'] = 1;
        final shares = splitByWeights(total, weights);
        expect(Money.sum(shares.values), total);
        // No one is more than a paisa away from their exact part.
        final sum = weights.values.fold(0, (a, b) => a + b);
        shares.forEach((p, m) {
          final exact = total.paise * weights[p]! / sum;
          expect((m.paise - exact).abs(), lessThanOrEqualTo(1));
        });
      }
    });
  });
}
