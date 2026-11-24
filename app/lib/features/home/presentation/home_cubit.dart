import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/time/clock.dart';
import '../../groups/domain/group_ledger.dart';
import '../domain/home_calculator.dart';
import '../domain/home_snapshot.dart';

sealed class HomeState {
  const HomeState();
}

final class HomeLoading extends HomeState {
  const HomeLoading();
}

final class HomeFailed extends HomeState {
  const HomeFailed();
}

final class HomeReady extends HomeState {
  const HomeReady(this.snapshot);
  final HomeSnapshot snapshot;

  /// The month shown in the spending section.
  DateTime get month => snapshot.spending.month;
}

/// Home: follows the person's groups and works out the dashboard.
class HomeCubit extends Cubit<HomeState> {
  HomeCubit({required GroupsRepository repository, required String uid, required this._clock})
    : _repository = repository,
      _uid = uid,
      super(const HomeLoading()) {
    _sub = repository.watchLedgers(uid).listen((ledgers) {
      _ledgers = ledgers;
      _emit();
    }, onError: (Object _) => emit(const HomeFailed()));
  }

  final Clock _clock;
  final GroupsRepository _repository;
  final String _uid;
  late final StreamSubscription<List<GroupLedger>> _sub;
  List<GroupLedger> _ledgers = const [];
  DateTime? _month;

  /// Shows spending for [month]; future months are ignored.
  void selectMonth(DateTime month) {
    final now = _clock();
    if (month.isAfter(DateTime(now.year, now.month))) return;
    _month = month;
    _emit();
  }

  /// Fetches the groups again (pull to refresh). False if that failed;
  /// what's on screen stays as it was.
  Future<bool> refresh() async {
    try {
      _ledgers = await _repository.watchLedgers(_uid).first;
      _emit();
      return true;
    } on Object {
      return false;
    }
  }

  void _emit() {
    if (isClosed) return;
    emit(HomeReady(HomeCalculator.build(ledgers: _ledgers, now: _clock(), month: _month)));
  }

  @override
  Future<void> close() async {
    await _sub.cancel();
    return super.close();
  }
}
