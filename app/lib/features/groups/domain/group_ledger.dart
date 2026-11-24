import 'expense.dart';
import 'group.dart';

/// A group with everything recorded in it.
final class GroupLedger {
  const GroupLedger({
    required this.group,
    required this.myMemberId,
    this.expenses = const [],
    this.payments = const [],
  });

  final Group group;

  /// Which member is the signed-in person.
  final String myMemberId;
  final List<Expense> expenses;
  final List<Payment> payments;

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
}

/// Phase 2 replaces the mock with Firestore-backed groups.
abstract interface class GroupsRepository {
  Stream<List<GroupLedger>> watchLedgers(String uid);
}
