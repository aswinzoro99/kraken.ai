import 'package:flutter_test/flutter_test.dart';
import 'package:kraken/features/groups/domain/expense.dart';
import 'package:kraken/features/groups/domain/group.dart';
import 'package:kraken/features/groups/domain/split_draft.dart';
import 'package:ledger/ledger.dart';

const members = [Member('y', 'You'), Member('s', 'Sreya'), Member('a', 'Arjun'), Member('m', 'Meera')];

SplitDraft design() => SplitDraft.forMembers(members).copyWith(total: const Money.rupees(3300));

void main() {
  group('reading what was typed', () {
    test('rupees', () {
      expect(parseRupees('450'), const Money.rupees(450));
      expect(parseRupees('₹ 1,234.5'), const Money(123450));
      expect(parseRupees('33.34'), const Money(3334));
      expect(parseRupees('12.345'), isNull);
      expect(parseRupees('abc'), isNull);
      expect(parseRupees(''), isNull);
    });

    test('percent', () {
      expect(parsePercent('25'), 2500);
      expect(parsePercent('33.33'), 3333);
      expect(parsePercent('100'), 10000);
      expect(parsePercent('101'), isNull);
    });

    test('and back', () {
      expect(rupeesText(const Money(90000)), '900');
      expect(rupeesText(const Money(3334)), '33.34');
      expect(percentText(2500), '25');
      expect(percentText(3333), '33.33');
      expect(percentText(1250), '12.5');
    });
  });

  group('the four splits, with the design\'s numbers', () {
    test('equally: ₹825 each · 4 people, and leaving someone out', () {
      var draft = design();
      expect(draft.summary(), '₹825 each · 4 people');
      draft = draft.toggle('m');
      expect(draft.summary(), '₹1,100 each · 3 people');
      expect((draft.check() as SplitReady).shares.keys, ['y', 's', 'a']);
      expect(draft.toggle('y').toggle('s').toggle('a').summary(), 'Pick at least one person');
    });

    test('exact: says what is left, then adds up', () {
      var draft = design().copyWith(method: SplitMethod.exact);
      draft = draft.setExact('y', '900').setExact('s', '700').setExact('a', '1000');
      expect(draft.summary(), '₹700 left to assign');
      draft = draft.setExact('m', '800');
      expect(draft.summary(), '₹100 more than the total');
      draft = draft.setExact('m', '700');
      expect(draft.summary(), 'Adds up to ₹3,300');
      expect((draft.check() as SplitReady).shares['a'], const Money.rupees(1000));
    });

    test('percent: 25 / 25 / 30 / 20', () {
      var draft = design().copyWith(method: SplitMethod.percent);
      draft = draft.setPercent('y', '25').setPercent('s', '25').setPercent('a', '30');
      expect(draft.summary(), '20% left to assign');
      draft = draft.setPercent('m', '20');
      expect(draft.summary(), 'Adds up to 100%');
      expect((draft.check() as SplitReady).shares['a'], const Money.rupees(990));
    });

    test('shares: 1 / 1 / 2 / 1', () {
      final draft = design().copyWith(method: SplitMethod.shares).stepShares('a', 1);
      expect(draft.summary(), '5 shares · ₹660 per share');
      expect((draft.check() as SplitReady).shares['a'], const Money.rupees(1320));
      expect(draft.stepShares('a', 50).shares['a'], SplitDraft.maxShares);
    });

    test('switching tabs keeps what was typed in each', () {
      final draft = design()
          .copyWith(method: SplitMethod.exact)
          .setExact('y', '900')
          .copyWith(method: SplitMethod.equal);
      expect(draft.copyWith(method: SplitMethod.exact).exact['y'], '900');
    });

    test('needs an amount first', () {
      expect(SplitDraft.forMembers(members).summary(), 'Enter the amount');
    });
  });

  test('a saved expense opens as it was entered', () {
    var draft = design().copyWith(method: SplitMethod.percent);
    for (final (id, p) in [('y', '25'), ('s', '25'), ('a', '30'), ('m', '20')]) {
      draft = draft.setPercent(id, p);
    }
    final shares = (draft.check() as SplitReady).shares;
    final expense = Expense(
      id: 'e1',
      groupId: 'g',
      description: 'Dinner',
      date: DateTime(2026, 11, 20),
      paidBy: 'y',
      total: draft.total!,
      shares: shares,
      split: SplitMethod.percent,
      weights: draft.weightsFor(shares),
    );
    final reopened = SplitDraft.fromExpense(expense, members);
    expect(reopened.method, SplitMethod.percent);
    expect(reopened.percent, {'y': '25', 's': '25', 'a': '30', 'm': '20'});
    expect((reopened.check() as SplitReady).shares, shares);
  });
}
