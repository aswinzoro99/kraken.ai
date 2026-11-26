import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../domain/expense.dart';
import '../domain/group_ledger.dart';

sealed class GroupState {
  const GroupState();
}

final class GroupLoading extends GroupState {
  const GroupLoading();
}

/// The group is gone, or the person isn't in it.
final class GroupMissing extends GroupState {
  const GroupMissing();
}

final class GroupReady extends GroupState {
  const GroupReady(this.ledger, {this.tab = GroupTab.expenses});
  final GroupLedger ledger;
  final GroupTab tab;
}

enum GroupTab { expenses, activity }

/// One group, live: balances, expenses and its history.
class GroupCubit extends Cubit<GroupState> {
  GroupCubit({required GroupsRepository repository, required String uid, required this.groupId})
    : _repository = repository,
      _uid = uid,
      super(const GroupLoading()) {
    _sub = repository
        .watchLedgers(uid)
        .listen(
          (ledgers) {
            if (isClosed) return;
            final ledger = ledgers.where((l) => l.group.id == groupId).firstOrNull;
            emit(ledger == null ? const GroupMissing() : GroupReady(ledger, tab: _tab));
          },
          onError: (Object _) {
            if (!isClosed && state is GroupLoading) emit(const GroupMissing());
          },
        );
  }

  final String groupId;
  final GroupsRepository _repository;
  final String _uid;
  late final StreamSubscription<List<GroupLedger>> _sub;
  GroupTab _tab = GroupTab.expenses;

  void showTab(GroupTab tab) {
    _tab = tab;
    if (state case GroupReady(:final ledger)) emit(GroupReady(ledger, tab: tab));
  }

  /// Puts back an expense deleted a moment ago.
  Future<bool> undoDelete(Expense expense) async {
    try {
      await _repository.restoreExpense(_uid, expense);
      return true;
    } on Object {
      return false;
    }
  }

  @override
  Future<void> close() async {
    await _sub.cancel();
    return super.close();
  }
}
