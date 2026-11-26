import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:ledger/ledger.dart';

import '../../../core/analytics/consent_gated_analytics.dart';
import '../../../core/analytics/events.dart';
import '../../../core/time/clock.dart';
import '../domain/expense.dart';
import '../domain/group_ledger.dart';
import '../domain/split_draft.dart';

final class ExpenseFormState {
  const ExpenseFormState({
    required this.draft,
    required this.paidBy,
    this.description = '',
    this.category = ExpenseCategory.other,
    this.saving = false,
    this.error,
    this.showErrors = false,
  });

  final SplitDraft draft;
  final String paidBy;
  final String description;
  final ExpenseCategory category;
  final bool saving;

  /// Saving didn't work; shown once.
  final String? error;

  /// Set after a save attempt, so empty fields only complain then.
  final bool showErrors;

  String? get descriptionError => showErrors && description.trim().isEmpty ? 'Say what it was for' : null;
  String? get amountError => showErrors && (draft.total == null || draft.total!.isZero) ? 'Enter the amount' : null;

  bool get canSave => !saving && description.trim().isNotEmpty && draft.check() is SplitReady;

  ExpenseFormState copyWith({
    SplitDraft? draft,
    String? paidBy,
    String? description,
    ExpenseCategory? category,
    bool? saving,
    String? error,
    bool clearError = false,
    bool? showErrors,
  }) => ExpenseFormState(
    draft: draft ?? this.draft,
    paidBy: paidBy ?? this.paidBy,
    description: description ?? this.description,
    category: category ?? this.category,
    saving: saving ?? this.saving,
    error: clearError ? null : (error ?? this.error),
    showErrors: showErrors ?? this.showErrors,
  );
}

/// What the form ended with, for the group screen.
sealed class ExpenseFormResult {
  const ExpenseFormResult();
}

final class ExpenseWasSaved extends ExpenseFormResult {
  const ExpenseWasSaved(this.expense, {required this.edited});
  final Expense expense;
  final bool edited;
}

final class ExpenseWasDeleted extends ExpenseFormResult {
  const ExpenseWasDeleted(this.expense);
  final Expense expense;
}

/// Adding or editing one expense: amount, what for, who paid, and how it's
/// split, Equally, Exact, Percent or Shares.
class ExpenseFormCubit extends Cubit<ExpenseFormState> {
  ExpenseFormCubit({
    required this._repository,
    required this._analytics,
    required this._clock,
    required this._uid,
    required this.ledger,
    this.editing,
  }) : super(
         editing == null
             ? ExpenseFormState(draft: SplitDraft.forMembers(ledger.group.members), paidBy: ledger.myMemberId)
             : ExpenseFormState(
                 draft: SplitDraft.fromExpense(editing, ledger.group.members),
                 paidBy: editing.paidBy,
                 description: editing.description,
                 category: editing.category,
               ),
       );

  final GroupLedger ledger;

  /// The expense being edited; null when adding.
  final Expense? editing;
  final GroupsRepository _repository;
  final ConsentGatedAnalytics _analytics;
  final Clock _clock;
  final String _uid;

  void setAmount(String text) {
    final total = parseRupees(text);
    emit(
      state.copyWith(
        draft: total == null ? state.draft.copyWith(clearTotal: true) : state.draft.copyWith(total: total),
      ),
    );
  }

  void setDescription(String text) => emit(state.copyWith(description: text));
  void setCategory(ExpenseCategory c) => emit(state.copyWith(category: c));
  void setPaidBy(String memberId) => emit(state.copyWith(paidBy: memberId));
  void setMethod(SplitMethod m) => emit(state.copyWith(draft: state.draft.copyWith(method: m)));
  void toggle(String memberId) => emit(state.copyWith(draft: state.draft.toggle(memberId)));
  void setExact(String memberId, String text) => emit(state.copyWith(draft: state.draft.setExact(memberId, text)));
  void setPercent(String memberId, String text) => emit(state.copyWith(draft: state.draft.setPercent(memberId, text)));
  void stepShares(String memberId, int by) => emit(state.copyWith(draft: state.draft.stepShares(memberId, by)));

  /// Saves, and returns what happened; null if there's something to fix.
  Future<ExpenseFormResult?> save() async {
    if (state.saving) return null;
    final check = state.draft.check();
    if (state.description.trim().isEmpty || check is! SplitReady) {
      emit(state.copyWith(showErrors: true));
      return null;
    }
    emit(state.copyWith(saving: true, clearError: true));
    final editing = this.editing;
    final expense = Expense(
      id: editing?.id ?? '',
      groupId: ledger.group.id,
      description: state.description.trim(),
      date: editing?.date ?? _clock(),
      paidBy: state.paidBy,
      total: state.draft.total!,
      shares: check.shares,
      category: state.category,
      source: editing?.source ?? ExpenseSource.manual,
      split: state.draft.method,
      weights: state.draft.weightsFor(check.shares),
      addedBy: editing?.addedBy,
    );
    try {
      final saved = editing == null ? await _repository.addExpense(_uid, expense) : expense;
      if (editing != null) await _repository.updateExpense(_uid, expense);
      _analytics.log(ExpenseSaved(split: expense.split.name, edited: editing != null, people: check.shares.length));
      if (!isClosed) emit(state.copyWith(saving: false));
      return ExpenseWasSaved(saved, edited: editing != null);
    } on Object {
      if (!isClosed) emit(state.copyWith(saving: false, error: "Couldn't save. Try again."));
      return null;
    }
  }

  /// Deletes the expense being edited; it can be put back with Undo.
  Future<ExpenseFormResult?> delete() async {
    final editing = this.editing;
    if (editing == null || state.saving) return null;
    emit(state.copyWith(saving: true, clearError: true));
    try {
      final removed = await _repository.deleteExpense(_uid, editing.groupId, editing.id);
      if (!isClosed) emit(state.copyWith(saving: false));
      return ExpenseWasDeleted(removed);
    } on Object {
      if (!isClosed) emit(state.copyWith(saving: false, error: "Couldn't delete. Try again."));
      return null;
    }
  }

  /// Each member's part right now, for the rows (zero when not in it).
  Map<String, Money> get preview => switch (state.draft.check()) {
    SplitReady(:final shares) => shares,
    _ => const {},
  };
}
