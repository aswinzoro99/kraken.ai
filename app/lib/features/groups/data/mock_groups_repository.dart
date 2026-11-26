import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:ledger/ledger.dart';

import '../../../core/storage/key_value_store.dart';
import '../../../core/time/clock.dart';
import '../domain/expense.dart';
import '../domain/group.dart';
import '../domain/group_ledger.dart';

/// Groups, expenses and invites kept on this phone: the stand-in until the
/// groups server exists. Everything a server would do (ids, activity
/// entries, invite checks, "two people can't take the same name") happens
/// here, so screens behave as they will for real.
///
/// With [seed], everyone signed in sees the design canvas's groups as "me"
/// (rebuilt relative to today on each launch, never saved). Without it,
/// groups start empty and, given a [store], are saved on the phone.
///
/// Invites only reach people signed in on this same phone, since nothing
/// leaves it.
final class MockGroupsRepository implements GroupsRepository {
  MockGroupsRepository({this.clock = systemClock, this.seed = true, this.empty = false, KeyValueStore? store})
    : _store = seed ? null : store {
    if (seed && !empty) {
      _load(buildMockLedgers(clock()));
    } else {
      _restore();
    }
  }

  final Clock clock;

  /// Start with the sample groups.
  final bool seed;

  /// Start with no groups, to see the empty state.
  final bool empty;
  final KeyValueStore? _store;

  static const storeKey = 'groups.mock_state.v1';
  static const inviteLifetime = Duration(days: 7);

  final _groups = <String, Group>{};
  final _expenses = <String, List<Expense>>{};
  final _payments = <String, List<Payment>>{};
  final _activity = <String, List<ActivityEntry>>{};
  final _invites = <String, Invite>{};
  final _changes = StreamController<void>.broadcast(sync: true);
  int _seq = 0;
  final _random = Random();

  // ---- Reading ----------------------------------------------------------

  @override
  Stream<List<GroupLedger>> watchLedgers(String uid) {
    late final StreamController<List<GroupLedger>> out;
    StreamSubscription<void>? sub;
    out = StreamController<List<GroupLedger>>(
      onListen: () {
        // Listen for changes before the first answer, so none is missed.
        sub = _changes.stream.listen((_) => out.add(ledgersFor(uid)));
        out.add(ledgersFor(uid));
      },
      // Not awaited: `.first` waits for whatever this returns.
      onCancel: () => unawaited(sub?.cancel()),
    );
    return out.stream;
  }

  /// The person's groups now, most recently active first.
  List<GroupLedger> ledgersFor(String uid) {
    final ledgers = <GroupLedger>[];
    for (final group in _groups.values) {
      final me = _memberFor(group, uid);
      if (me == null) continue;
      ledgers.add(
        GroupLedger(
          group: group,
          myMemberId: me.id,
          expenses: _newestFirst(_expenses[group.id], (e) => e.date),
          payments: _newestFirst(_payments[group.id], (p) => p.date),
          activity: _newestFirst(_activity[group.id], (a) => a.date),
        ),
      );
    }
    return ledgers;
  }

  /// Sorted by date, newest first; things recorded in the same instant keep
  /// the later one first.
  static List<T> _newestFirst<T>(List<T>? items, DateTime Function(T) dateOf) {
    final indexed = [for (final (i, item) in (items ?? <T>[]).indexed) (i, item)];
    indexed.sort((a, b) {
      final byDate = dateOf(b.$2).compareTo(dateOf(a.$2));
      return byDate != 0 ? byDate : b.$1.compareTo(a.$1);
    });
    return [for (final (_, item) in indexed) item];
  }

  /// The member that is [uid] in [group]. In sample data, an unclaimed
  /// "me" stands for whoever is signed in.
  Member? _memberFor(Group group, String uid) {
    for (final m in group.members) {
      if (m.userId == uid) return m;
    }
    if (seed) return group.memberById('me');
    return null;
  }

  Member _requireMember(String uid, String groupId) {
    final group = _groups[groupId];
    final me = group == null ? null : _memberFor(group, uid);
    if (me == null) throw StateError('Not a member of $groupId');
    return me;
  }

  // ---- Groups -------------------------------------------------------------

  @override
  Future<Group> createGroup({
    required String uid,
    required String yourName,
    required String name,
    List<String> friendNames = const [],
    String detail = '',
  }) async {
    final id = _newId('g');
    final now = clock();
    final members = <Member>[Member(_newId('m'), yourName.trim(), userId: uid)];
    final seen = {yourName.trim().toLowerCase()};
    for (final raw in friendNames) {
      final friend = raw.trim();
      if (friend.isEmpty || !seen.add(friend.toLowerCase())) continue;
      members.add(Member(_newId('m'), friend));
    }
    final group = Group(id: id, name: name.trim(), members: members, detail: detail.trim(), createdAt: now);
    _groups[id] = group;
    _log(id, ActivityKind.groupCreated, members.first.id, subject: group.name);
    await _changed();
    return group;
  }

  // ---- Expenses ---------------------------------------------------------

  @override
  Future<Expense> addExpense(String uid, Expense draft) async {
    final me = _requireMember(uid, draft.groupId);
    _check(draft);
    final saved = Expense(
      id: _newId('e'),
      groupId: draft.groupId,
      description: draft.description,
      date: draft.date,
      paidBy: draft.paidBy,
      total: draft.total,
      shares: draft.shares,
      category: draft.category,
      source: draft.source,
      split: draft.split,
      weights: draft.weights,
      addedBy: me.id,
    );
    (_expenses[draft.groupId] ??= []).add(saved);
    _log(
      draft.groupId,
      ActivityKind.expenseAdded,
      me.id,
      subject: saved.description,
      amount: saved.total,
      expenseId: saved.id,
    );
    await _changed();
    return saved;
  }

  @override
  Future<void> updateExpense(String uid, Expense expense) async {
    final me = _requireMember(uid, expense.groupId);
    _check(expense);
    final list = _expenses[expense.groupId] ?? [];
    final i = list.indexWhere((e) => e.id == expense.id);
    if (i < 0) throw StateError('No expense ${expense.id}');
    list[i] = expense;
    _log(
      expense.groupId,
      ActivityKind.expenseEdited,
      me.id,
      subject: expense.description,
      amount: expense.total,
      expenseId: expense.id,
    );
    await _changed();
  }

  @override
  Future<Expense> deleteExpense(String uid, String groupId, String expenseId) async {
    final me = _requireMember(uid, groupId);
    final list = _expenses[groupId] ?? [];
    final i = list.indexWhere((e) => e.id == expenseId);
    if (i < 0) throw StateError('No expense $expenseId');
    final removed = list.removeAt(i);
    _log(
      groupId,
      ActivityKind.expenseDeleted,
      me.id,
      subject: removed.description,
      amount: removed.total,
      expenseId: removed.id,
    );
    await _changed();
    return removed;
  }

  @override
  Future<void> restoreExpense(String uid, Expense expense) async {
    final me = _requireMember(uid, expense.groupId);
    final list = _expenses[expense.groupId] ??= [];
    if (list.any((e) => e.id == expense.id)) return;
    list.add(expense);
    _log(
      expense.groupId,
      ActivityKind.expenseRestored,
      me.id,
      subject: expense.description,
      amount: expense.total,
      expenseId: expense.id,
    );
    await _changed();
  }

  /// What a server would refuse: shares that don't add up, or people who
  /// aren't in the group.
  void _check(Expense e) {
    final group = _groups[e.groupId]!;
    if (Money.sum(e.shares.values) != e.total) throw ArgumentError('Shares do not add up to the total');
    final ids = {for (final m in group.members) m.id};
    if (!ids.contains(e.paidBy) || !e.shares.keys.every(ids.contains)) {
      throw ArgumentError('Someone in the expense is not in the group');
    }
  }

  // ---- Invites ----------------------------------------------------------

  @override
  Future<Invite> createInvite(String uid, String groupId) async {
    _requireMember(uid, groupId);
    final now = clock();
    for (final invite in _invites.values) {
      if (invite.groupId == groupId && invite.expiresAt.isAfter(now.add(const Duration(days: 1)))) return invite;
    }
    var code = _newCode();
    while (_invites.containsKey(code)) {
      code = _newCode();
    }
    final invite = Invite(code: code, groupId: groupId, expiresAt: now.add(inviteLifetime));
    _invites[code] = invite;
    await _changed();
    return invite;
  }

  @override
  Future<InvitePreview> openInvite(String code) async {
    final (invite, group) = _validInvite(code);
    return InvitePreview(
      code: invite.code,
      groupName: group.name,
      openNames: [
        for (final m in group.members)
          if (!m.claimed && !(seed && m.id == 'me')) m,
      ],
      memberCount: group.members.length,
    );
  }

  @override
  Future<String> claimInvite({required String uid, required String code, String? memberId, String? newName}) async {
    final (_, group) = _validInvite(code);
    if (_memberFor(group, uid) != null) throw AlreadyInGroup(group.id);
    final Member joined;
    final List<Member> members;
    if (memberId != null) {
      final target = group.memberById(memberId);
      if (target == null || target.claimed) throw const NameTaken();
      joined = target.claimedBy(uid);
      members = [for (final m in group.members) m.id == memberId ? joined : m];
    } else {
      final name = newName?.trim() ?? '';
      if (name.isEmpty) throw ArgumentError('A name is needed');
      joined = Member(_newId('m'), name, userId: uid);
      members = [...group.members, joined];
    }
    _groups[group.id] = group.copyWith(members: members);
    _log(group.id, ActivityKind.memberJoined, joined.id, subject: joined.name);
    await _changed();
    return group.id;
  }

  (Invite, Group) _validInvite(String code) {
    final invite = _invites[code.trim().toUpperCase()];
    final group = invite == null ? null : _groups[invite.groupId];
    if (invite == null || group == null) throw const InviteNotFound();
    if (!invite.expiresAt.isAfter(clock())) throw const InviteExpired();
    return (invite, group);
  }

  /// 8 letters and digits, leaving out ones that are easy to misread
  /// (0/O, 1/I/L).
  String _newCode() {
    const alphabet = 'ABCDEFGHJKMNPQRSTUVWXYZ23456789';
    return String.fromCharCodes([for (var i = 0; i < 8; i++) alphabet.codeUnitAt(_random.nextInt(alphabet.length))]);
  }

  // ---- Bookkeeping --------------------------------------------------------

  String _newId(String prefix) =>
      '$prefix${clock().microsecondsSinceEpoch.toRadixString(36)}${(_seq++).toRadixString(36)}';

  void _log(
    String groupId,
    ActivityKind kind,
    String authorId, {
    String subject = '',
    Money? amount,
    String? expenseId,
  }) {
    (_activity[groupId] ??= []).add(
      ActivityEntry(
        id: _newId('a'),
        groupId: groupId,
        kind: kind,
        authorId: authorId,
        date: clock(),
        subject: subject,
        amount: amount,
        expenseId: expenseId,
      ),
    );
  }

  Future<void> _changed() async {
    _changes.add(null);
    final store = _store;
    if (store != null) await store.setString(storeKey, jsonEncode(_toJson()));
  }

  void _load(List<GroupLedger> ledgers) {
    for (final l in ledgers) {
      _groups[l.group.id] = l.group;
      _expenses[l.group.id] = [...l.expenses];
      _payments[l.group.id] = [...l.payments];
      _activity[l.group.id] = [...l.activity];
    }
  }

  Map<String, Object?> _toJson() => {
    'groups': [for (final g in _groups.values) g.toJson()],
    'expenses': [
      for (final list in _expenses.values)
        for (final e in list) e.toJson(),
    ],
    'payments': [
      for (final list in _payments.values)
        for (final p in list) p.toJson(),
    ],
    'activity': [
      for (final list in _activity.values)
        for (final a in list) a.toJson(),
    ],
    'invites': [for (final i in _invites.values) i.toJson()],
  };

  void _restore() {
    final raw = _store?.getString(storeKey);
    if (raw == null) return;
    try {
      final json = (jsonDecode(raw) as Map).cast<String, Object?>();
      Iterable<Map<String, Object?>> rows(String key) => [
        for (final r in (json[key] as List?) ?? const []) (r as Map).cast<String, Object?>(),
      ];
      for (final g in rows('groups').map(Group.fromJson)) {
        _groups[g.id] = g;
      }
      for (final e in rows('expenses').map(Expense.fromJson)) {
        (_expenses[e.groupId] ??= []).add(e);
      }
      for (final p in rows('payments').map(Payment.fromJson)) {
        (_payments[p.groupId] ??= []).add(p);
      }
      for (final a in rows('activity').map(ActivityEntry.fromJson)) {
        (_activity[a.groupId] ??= []).add(a);
      }
      for (final i in rows('invites').map(Invite.fromJson)) {
        _invites[i.code] = i;
      }
    } on Object {
      // A saved state from an older build that can't be read: start over.
      _groups.clear();
      _expenses.clear();
      _payments.clear();
      _activity.clear();
      _invites.clear();
    }
  }

  Future<void> dispose() => _changes.close();
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
const weekendTrek = Group(
  id: 'trek',
  name: 'Weekend trek',
  members: [_me, _sreya, _arjun, _dev, _nisha],
  detail: 'Lonavala',
);
const officeLunch = Group(
  id: 'lunch',
  name: 'Office lunch',
  members: [
    _me,
    _priya,
    Member('rahul', 'Rahul'),
    Member('anjali', 'Anjali'),
    Member('vikram', 'Vikram'),
    Member('zoya', 'Zoya'),
  ],
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
        // Each expense added by whoever paid, each payment by who paid it.
        activity: [
          for (final e in b.expenses.where((e) => e.groupId == g.id))
            ActivityEntry(
              id: 'a${e.id}',
              groupId: g.id,
              kind: ActivityKind.expenseAdded,
              authorId: e.paidBy,
              date: e.date,
              subject: e.description,
              amount: e.total,
              expenseId: e.id,
            ),
          for (final p in b.payments.where((p) => p.groupId == g.id))
            ActivityEntry(
              id: 'a${p.id}',
              groupId: g.id,
              kind: ActivityKind.paymentRecorded,
              authorId: p.from,
              date: p.date,
              amount: p.amount,
            ),
        ],
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
    expenses.add(
      Expense(
        id: 'e${_id++}',
        groupId: g.id,
        description: what,
        date: date,
        paidBy: payer,
        total: total,
        shares: splitEqually(total, [for (final m in g.members) m.id]),
        category: category,
        source: source,
        weights: {for (final m in g.members) m.id: 1},
        addedBy: payer,
      ),
    );
  }

  void pay(Group g, String from, String to, int rupees, DateTime date) => payments.add(
    Payment(id: 'p${_id++}', groupId: g.id, from: from, to: to, amount: Money.rupees(rupees), date: date),
  );

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
        payments.add(
          Payment(
            id: 'p${_id++}',
            groupId: groupId,
            from: amount.isPositive ? person : 'me',
            to: amount.isPositive ? 'me' : person,
            amount: amount.abs(),
            date: date,
          ),
        );
      });
    }
  }
}
