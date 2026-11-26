import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../domain/group_ledger.dart';

sealed class LedgersState {
  const LedgersState();
}

final class LedgersLoading extends LedgersState {
  const LedgersLoading();
}

final class LedgersFailed extends LedgersState {
  const LedgersFailed();
}

final class LedgersReady extends LedgersState {
  const LedgersReady(this.ledgers);
  final List<GroupLedger> ledgers;
}

/// Follows every group the person is in (Friends, Activity, the groups list).
class LedgersCubit extends Cubit<LedgersState> {
  LedgersCubit({required GroupsRepository repository, required String uid}) : super(const LedgersLoading()) {
    _sub = repository
        .watchLedgers(uid)
        .listen(
          (ledgers) {
            if (!isClosed) emit(LedgersReady(ledgers));
          },
          onError: (Object _) {
            if (!isClosed) emit(const LedgersFailed());
          },
        );
  }

  late final StreamSubscription<List<GroupLedger>> _sub;

  @override
  Future<void> close() async {
    await _sub.cancel();
    return super.close();
  }
}
