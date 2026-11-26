import 'package:ledger/ledger.dart';

import 'expense.dart';
import 'group.dart';

/// A group with everything recorded in it, as one member sees it.
final class GroupLedger {
  const GroupLedger({
    required this.group,
    required this.myMemberId,
    this.expenses = const [],
    this.payments = const [],
    this.activity = const [],
  });

  final Group group;

  /// Which member is the signed-in person.
  final String myMemberId;

  /// Newest first.
  final List<Expense> expenses;
  final List<Payment> payments;

  /// Newest first.
  final List<ActivityEntry> activity;

  String nameOf(String memberId) => memberId == myMemberId
      ? 'You'
      : group.members.firstWhere((m) => m.id == memberId, orElse: () => Member(memberId, 'Someone')).name;

  DateTime? get lastActivity {
    DateTime? latest;
    for (final d in [...expenses.map((e) => e.date), ...payments.map((p) => p.date)]) {
      if (latest == null || d.isAfter(latest)) latest = d;
    }
    return latest;
  }

  /// Where each member stands in the group (positive: the group owes them).
  Map<String, Money> get net => netBalances(expenses.map((e) => e.toSplit()), payments.map((p) => p.toTransfer()));

  /// The fewest payments that would settle the whole group.
  List<Transfer> get simplified => simplifyDebts(net);

  /// What each other member owes you directly (negative: you owe them).
  Map<String, Money> get myBalances =>
      balancesWith(myMemberId, expenses.map((e) => e.toSplit()), payments.map((p) => p.toTransfer()));

  /// Your overall position in the group.
  Money get myNet => net[myMemberId] ?? Money.zero;

  Expense? expenseById(String id) {
    for (final e in expenses) {
      if (e.id == id) return e;
    }
    return null;
  }
}

/// Why a groups call didn't work.
sealed class GroupsException implements Exception {
  const GroupsException();
}

/// No invite has that code.
final class InviteNotFound extends GroupsException {
  const InviteNotFound();
}

final class InviteExpired extends GroupsException {
  const InviteExpired();
}

/// Someone else took that name first.
final class NameTaken extends GroupsException {
  const NameTaken();
}

/// The person is in the group already.
final class AlreadyInGroup extends GroupsException {
  const AlreadyInGroup(this.groupId);
  final String groupId;
}

/// An invite to a group, shared as a code or a link.
final class Invite {
  const Invite({required this.code, required this.groupId, required this.expiresAt});
  final String code;
  final String groupId;
  final DateTime expiresAt;

  // No link yet: there's no invite site to host one. The code is what's
  // shared; a pasted `…/i/<code>` link also works once one exists.

  Map<String, Object?> toJson() => {'code': code, 'groupId': groupId, 'expiresAt': expiresAt.toIso8601String()};

  static Invite fromJson(Map<String, Object?> json) => Invite(
    code: json['code']! as String,
    groupId: json['groupId']! as String,
    expiresAt: DateTime.parse(json['expiresAt']! as String),
  );
}

/// What someone opening an invite sees before joining.
final class InvitePreview {
  const InvitePreview({
    required this.code,
    required this.groupName,
    required this.openNames,
    required this.memberCount,
  });
  final String code;
  final String groupName;

  /// Names nobody has claimed yet: "Which name is yours?"
  final List<Member> openNames;
  final int memberCount;
}

/// Groups, expenses and invites. The mock keeps them on this phone; a
/// server-backed version replaces it without changing callers.
abstract interface class GroupsRepository {
  /// Every group the person is in, then again after each change.
  Stream<List<GroupLedger>> watchLedgers(String uid);

  /// Makes a group with the person (as [yourName]) and [friendNames].
  Future<Group> createGroup({
    required String uid,
    required String yourName,
    required String name,
    List<String> friendNames = const [],
    String detail = '',
  });

  /// Adds [draft] (its id is ignored) and returns it as saved.
  Future<Expense> addExpense(String uid, Expense draft);

  /// Replaces the expense with the same id.
  Future<void> updateExpense(String uid, Expense expense);

  /// Removes it and returns it, so it can be restored with Undo.
  Future<Expense> deleteExpense(String uid, String groupId, String expenseId);

  /// Puts a deleted expense back exactly as it was.
  Future<void> restoreExpense(String uid, Expense expense);

  /// A code friends use to join; lasts 7 days.
  Future<Invite> createInvite(String uid, String groupId);

  /// What the invite is for. Throws [InviteNotFound] or [InviteExpired].
  Future<InvitePreview> openInvite(String code);

  /// Joins as [memberId], or as a new member called [newName] when
  /// [memberId] is null. Returns the group id. Throws a [GroupsException].
  Future<String> claimInvite({required String uid, required String code, String? memberId, String? newName});
}
