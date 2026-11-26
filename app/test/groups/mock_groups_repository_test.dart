import 'package:flutter_test/flutter_test.dart';
import 'package:kraken/core/storage/key_value_store.dart';
import 'package:kraken/features/groups/data/mock_groups_repository.dart';
import 'package:kraken/features/groups/domain/expense.dart';
import 'package:kraken/features/groups/domain/group_ledger.dart';
import 'package:ledger/ledger.dart';

DateTime now = DateTime(2026, 11, 24, 18);

Expense draft(String groupId, String paidBy, int rupees, List<String> people, {String what = 'Dinner'}) {
  final total = Money.rupees(rupees);
  return Expense(
    id: '',
    groupId: groupId,
    description: what,
    date: now,
    paidBy: paidBy,
    total: total,
    shares: splitEqually(total, people),
    weights: {for (final p in people) p: 1},
  );
}

void main() {
  late MemoryStore store;
  late MockGroupsRepository repo;

  setUp(() {
    now = DateTime(2026, 11, 24, 18);
    store = MemoryStore();
    repo = MockGroupsRepository(seed: false, store: store, clock: () => now);
  });

  Future<GroupLedger> ledgerOf(String uid, String groupId) async =>
      (await repo.watchLedgers(uid).first).firstWhere((l) => l.group.id == groupId);

  test('sample data: the design canvas\'s four groups, with Goa Trip at −₹150', () async {
    final seeded = MockGroupsRepository(clock: () => now);
    final ledgers = await seeded.watchLedgers('anyone').first;
    expect(ledgers.map((l) => l.group.name), containsAll(['Goa Trip', 'Flat 302', 'Weekend trek', 'Office lunch']));
    final goa = ledgers.firstWhere((l) => l.group.id == 'goa');
    expect(goa.myNet, const Money.rupees(-150));
    expect(goa.myBalances, {
      'sreya': const Money.rupees(1150),
      'arjun': const Money.rupees(550),
      'meera': const Money.rupees(-1850),
    });
    // Simplified: three payments settle the whole trip.
    expect(Money.sum(goa.simplified.map((t) => t.amount)), const Money.rupees(7250));
    expect(goa.expenses.first.description, 'Beach shack lunch', reason: 'newest first');
  });

  test('a new group shows at once, with you and your friends', () async {
    final seen = <int>[];
    final sub = repo.watchLedgers('u1').listen((l) => seen.add(l.length));
    addTearDown(sub.cancel);
    await pumpEventQueue();
    final g = await repo.createGroup(
      uid: 'u1',
      yourName: 'Aswin',
      name: ' Goa Trip ',
      friendNames: ['Sreya', 'sreya', ' ', 'Arjun'],
    );
    await pumpEventQueue();
    expect(seen, [0, 1]);
    expect(g.name, 'Goa Trip');
    expect(g.members.map((m) => m.name), ['Aswin', 'Sreya', 'Arjun'], reason: 'no blanks or repeats');
    final ledger = await ledgerOf('u1', g.id);
    expect(ledger.nameOf(ledger.myMemberId), 'You');
    expect(ledger.activity.single.kind, ActivityKind.groupCreated);
    expect(await repo.watchLedgers('someone-else').first, isEmpty);
  });

  test('add, edit, delete and Undo, with an activity line for each', () async {
    final g = await repo.createGroup(uid: 'u1', yourName: 'Aswin', name: 'Flat', friendNames: ['Rohan']);
    final [me, rohan] = [for (final m in g.members) m.id];
    final added = await repo.addExpense('u1', draft(g.id, me, 900, [me, rohan]));
    expect(added.id, isNotEmpty);
    expect(added.addedBy, me);
    expect((await ledgerOf('u1', g.id)).myBalances, {rohan: const Money.rupees(450)});

    final total = const Money.rupees(1200);
    await repo.updateExpense(
      'u1',
      Expense(
        id: added.id,
        groupId: g.id,
        description: 'Groceries',
        date: added.date,
        paidBy: rohan,
        total: total,
        shares: splitEqually(total, [me, rohan]),
        addedBy: added.addedBy,
      ),
    );
    expect((await ledgerOf('u1', g.id)).myBalances, {rohan: const Money.rupees(-600)});

    final removed = await repo.deleteExpense('u1', g.id, added.id);
    expect((await ledgerOf('u1', g.id)).expenses, isEmpty);
    await repo.restoreExpense('u1', removed);
    final back = (await ledgerOf('u1', g.id)).expenses.single;
    expect(back.toJson(), removed.toJson(), reason: 'Undo restores it exactly');

    final kinds = (await ledgerOf('u1', g.id)).activity.map((a) => a.kind).toList().reversed;
    expect(kinds, [
      ActivityKind.groupCreated,
      ActivityKind.expenseAdded,
      ActivityKind.expenseEdited,
      ActivityKind.expenseDeleted,
      ActivityKind.expenseRestored,
    ]);
  });

  test('refuses shares that don\'t add up, or people outside the group', () async {
    final g = await repo.createGroup(uid: 'u1', yourName: 'Aswin', name: 'Flat');
    final me = g.members.single.id;
    final bad = Expense(
      id: '',
      groupId: g.id,
      description: 'x',
      date: now,
      paidBy: me,
      total: const Money.rupees(100),
      shares: {me: const Money.rupees(99)},
    );
    expect(() => repo.addExpense('u1', bad), throwsArgumentError);
    expect(() => repo.addExpense('u1', draft(g.id, me, 100, [me, 'stranger'])), throwsArgumentError);
    expect(() => repo.addExpense('not-a-member', draft(g.id, me, 100, [me])), throwsStateError);
  });

  group('invites', () {
    test('a friend takes their name, then sees the group and its balances', () async {
      final g = await repo.createGroup(uid: 'u1', yourName: 'Aswin', name: 'Goa', friendNames: ['Sreya', 'Arjun']);
      final [me, sreya, _] = [for (final m in g.members) m.id];
      await repo.addExpense('u1', draft(g.id, me, 300, [me, sreya]));
      final invite = await repo.createInvite('u1', g.id);
      expect(invite.code, matches(RegExp(r'^[A-HJ-NP-Z2-9]{8}$')));
      expect(await repo.createInvite('u1', g.id), same(invite), reason: 'one live invite per group');

      final preview = await repo.openInvite(invite.code.toLowerCase());
      expect(preview.groupName, 'Goa');
      expect(preview.openNames.map((m) => m.name), ['Sreya', 'Arjun']);

      expect(await repo.claimInvite(uid: 'u2', code: invite.code, memberId: sreya), g.id);
      final theirs = await ledgerOf('u2', g.id);
      expect(theirs.myMemberId, sreya);
      expect(theirs.myBalances, {me: const Money.rupees(-150)});
      expect(theirs.nameOf(me), 'Aswin');
      expect((await repo.openInvite(invite.code)).openNames.map((m) => m.name), ['Arjun']);
    });

    test('two people can\'t take the same name', () async {
      final g = await repo.createGroup(uid: 'u1', yourName: 'Aswin', name: 'Goa', friendNames: ['Sreya']);
      final invite = await repo.createInvite('u1', g.id);
      final sreya = g.members[1].id;
      await repo.claimInvite(uid: 'u2', code: invite.code, memberId: sreya);
      expect(() => repo.claimInvite(uid: 'u3', code: invite.code, memberId: sreya), throwsA(isA<NameTaken>()));
    });

    test('joining with a new name, already in, unknown and expired codes', () async {
      final g = await repo.createGroup(uid: 'u1', yourName: 'Aswin', name: 'Goa');
      final invite = await repo.createInvite('u1', g.id);
      await repo.claimInvite(uid: 'u2', code: invite.code, newName: 'Dev');
      expect((await ledgerOf('u2', g.id)).group.members.map((m) => m.name), ['Aswin', 'Dev']);
      expect(
        () => repo.claimInvite(uid: 'u2', code: invite.code, newName: 'Dev again'),
        throwsA(isA<AlreadyInGroup>()),
      );
      expect(() => repo.openInvite('ZZZZZZZZ'), throwsA(isA<InviteNotFound>()));
      now = now.add(MockGroupsRepository.inviteLifetime);
      expect(() => repo.openInvite(invite.code), throwsA(isA<InviteExpired>()));
    });
  });

  test('everything is kept on the phone and comes back on the next launch', () async {
    final g = await repo.createGroup(uid: 'u1', yourName: 'Aswin', name: 'Flat', friendNames: ['Rohan']);
    final [me, rohan] = [for (final m in g.members) m.id];
    await repo.addExpense('u1', draft(g.id, me, 900, [me, rohan]));
    final invite = await repo.createInvite('u1', g.id);

    final relaunched = MockGroupsRepository(seed: false, store: store, clock: () => now);
    final ledger = (await relaunched.watchLedgers('u1').first).single;
    expect(ledger.group.name, 'Flat');
    expect(ledger.myBalances, {rohan: const Money.rupees(450)});
    expect(ledger.activity, hasLength(2));
    expect((await relaunched.openInvite(invite.code)).groupName, 'Flat');
  });

  test('a saved state it can\'t read starts over instead of crashing', () async {
    await store.setString(MockGroupsRepository.storeKey, '{"groups": [{"oops": 1}]}');
    final relaunched = MockGroupsRepository(seed: false, store: store);
    expect(await relaunched.watchLedgers('u1').first, isEmpty);
  });
}
