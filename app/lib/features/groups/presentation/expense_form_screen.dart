import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:ledger/ledger.dart';
import 'package:material_ui/material_ui.dart';

import '../../../app/kraken_app.dart';
import '../../../app/session.dart';
import '../../../core/time/clock.dart';
import '../../../ui_kit/ui_kit.dart';
import '../domain/expense.dart';
import '../domain/group.dart';
import '../domain/group_ledger.dart';
import '../domain/split_draft.dart';
import 'expense_form_cubit.dart';

/// Adding or editing an expense: the amount, what it was for, who paid, and
/// the split tabs from the "Split the total" design. Pops with an
/// [ExpenseFormResult].
class ExpenseFormScreen extends StatelessWidget {
  const ExpenseFormScreen({super.key, required this.groupId, this.expenseId});

  final String groupId;

  /// Set when editing.
  final String? expenseId;

  @override
  Widget build(BuildContext context) {
    final uid = context.read<SessionCubit>().state.uid ?? '';
    return StreamBuilder<List<GroupLedger>>(
      stream: context.read<GroupsRepository>().watchLedgers(uid),
      builder: (context, snap) {
        final ledgers = snap.data;
        if (ledgers == null) return const Scaffold(body: Center(child: CircularProgressIndicator()));
        final ledger = ledgers.where((l) => l.group.id == groupId).firstOrNull;
        final editing = expenseId == null ? null : ledger?.expenseById(expenseId!);
        if (ledger == null || (expenseId != null && editing == null)) {
          return Scaffold(
            body: Column(
              children: [
                KTopBar(onBack: () => context.pop()),
                const Expanded(
                  child: Center(
                    child: KEmptyState(
                      illustration: KIllustrations.emptyActivity,
                      title: 'This expense isn’t here',
                      message: 'Someone may have deleted it.',
                    ),
                  ),
                ),
              ],
            ),
          );
        }
        return BlocProvider(
          // Keyed so a later update to the group doesn't reset what's typed.
          key: ValueKey('$groupId/$expenseId'),
          create: (context) => ExpenseFormCubit(
            repository: context.read<GroupsRepository>(),
            analytics: context.analytics,
            clock: context.read<Clock>(),
            uid: uid,
            ledger: ledger,
            editing: editing,
          ),
          child: const _FormView(),
        );
      },
    );
  }
}

class _FormView extends StatefulWidget {
  const _FormView();

  @override
  State<_FormView> createState() => _FormViewState();
}

class _FormViewState extends State<_FormView> {
  late final ExpenseFormCubit _cubit = context.read<ExpenseFormCubit>();
  late final _amount = TextEditingController(
    text: switch (_cubit.state.draft.total) {
      final Money t => rupeesText(t),
      null => '',
    },
  );
  late final _description = TextEditingController(text: _cubit.state.description);
  final _exact = <String, TextEditingController>{};
  final _percent = <String, TextEditingController>{};

  TextEditingController _controllerFor(Map<String, TextEditingController> map, String id, String? text) =>
      map.putIfAbsent(id, () => TextEditingController(text: text ?? ''));

  @override
  void dispose() {
    _amount.dispose();
    _description.dispose();
    for (final c in [..._exact.values, ..._percent.values]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    final router = GoRouter.of(context);
    final result = await _cubit.save();
    if (result != null) router.pop(result);
  }

  Future<void> _delete() async {
    final router = GoRouter.of(context);
    final result = await _cubit.delete();
    if (result != null) router.pop(result);
  }

  @override
  Widget build(BuildContext context) {
    final k = context.k;
    final state = context.watch<ExpenseFormCubit>().state;
    final ledger = _cubit.ledger;
    final editing = _cubit.editing;
    final check = state.draft.check();
    final preview = _cubit.preview;

    return BlocListener<ExpenseFormCubit, ExpenseFormState>(
      listenWhen: (a, b) => b.error != null && a.error != b.error,
      listener: (context, s) => KToast.show(context, s.error!, kind: KToastKind.error),
      child: Scaffold(
        body: Column(
          children: [
            KTopBar(
              title: editing == null ? 'Add expense' : 'Edit expense',
              subtitle: ledger.group.name,
              onBack: () => context.pop(),
            ),
            Expanded(
              // Not lazy: the form is short, and the summary under the rows
              // must always be there for screen readers.
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(KSpace.gutter, KSpace.xs, KSpace.gutter, KSpace.xl),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _AmountField(controller: _amount, error: state.amountError, onChanged: _cubit.setAmount),
                    const SizedBox(height: KSpace.lg),
                    KTextField(
                      label: 'Description',
                      hint: 'Dinner at Coastal Kitchen',
                      controller: _description,
                      error: state.descriptionError,
                      maxLength: 60,
                      textCapitalization: TextCapitalization.sentences,
                      onChanged: _cubit.setDescription,
                    ),
                    const SizedBox(height: KSpace.md),
                    _Label('Category'),
                    KChipRow(
                      children: [
                        for (final c in ExpenseCategory.values)
                          KChip(label: c.label, selected: state.category == c, onTap: () => _cubit.setCategory(c)),
                      ],
                    ),
                    const SizedBox(height: KSpace.lg),
                    _Label('Paid by'),
                    KChipRow(
                      children: [
                        for (final m in ledger.group.members)
                          KChip(
                            label: ledger.nameOf(m.id),
                            selected: state.paidBy == m.id,
                            onTap: () => _cubit.setPaidBy(m.id),
                          ),
                      ],
                    ),
                    const SizedBox(height: KSpace.xl),
                    _Label('Split'),
                    KSegmentedControl<SplitMethod>(
                      segments: [for (final m in SplitMethod.values) KSegment(m, m.label)],
                      value: state.draft.method,
                      onChanged: _cubit.setMethod,
                    ),
                    const SizedBox(height: KSpace.xs),
                    for (final m in ledger.group.members) _row(context, state, m, ledger, preview[m.id]),
                    const SizedBox(height: KSpace.md),
                    Semantics(
                      liveRegion: true,
                      child: Text(
                        state.draft.summary(),
                        textAlign: TextAlign.center,
                        style: KText.label.copyWith(color: check is SplitReady ? k.muted : k.warning),
                      ),
                    ),
                    if (editing != null) ...[
                      const SizedBox(height: KSpace.xxl),
                      KButton(
                        label: 'Delete expense',
                        variant: KButtonVariant.danger,
                        haptic: HapticKind.heavy,
                        icon: Icons.delete_outline_rounded,
                        expand: true,
                        onPressed: state.saving ? null : _delete,
                      ),
                    ],
                  ],
                ),
              ),
            ),
            SafeArea(
              top: false,
              minimum: const EdgeInsets.fromLTRB(KSpace.gutter, KSpace.xs, KSpace.gutter, KSpace.lg),
              child: KButton(
                label: editing == null ? 'Save to ${ledger.group.name}' : 'Save changes',
                expand: true,
                loading: state.saving,
                onPressed: _save,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _row(BuildContext context, ExpenseFormState state, Member m, GroupLedger ledger, Money? share) {
    final name = ledger.nameOf(m.id);
    final draft = state.draft;
    final amount = share == null ? null : MoneyFormat.format(share);
    return switch (draft.method) {
      SplitMethod.equal => KCheckRow(
        title: name,
        subtitle: draft.included.contains(m.id) ? (amount ?? '—') : 'Not in this one',
        value: draft.included.contains(m.id),
        onChanged: (_) => _cubit.toggle(m.id),
      ),
      SplitMethod.exact => _InputRow(
        name: name,
        controller: _controllerFor(_exact, m.id, draft.exact[m.id]),
        prefix: '₹',
        semanticLabel: 'Amount for $name',
        onChanged: (t) => _cubit.setExact(m.id, t),
      ),
      SplitMethod.percent => _InputRow(
        name: name,
        sub: amount,
        controller: _controllerFor(_percent, m.id, draft.percent[m.id]),
        suffix: '%',
        semanticLabel: 'Percent for $name',
        onChanged: (t) => _cubit.setPercent(m.id, t),
      ),
      SplitMethod.shares => _SharesRow(
        name: name,
        sub: amount ?? '₹0',
        count: draft.shares[m.id] ?? 0,
        onStep: (by) => _cubit.stepShares(m.id, by),
      ),
    };
  }
}

class _Label extends StatelessWidget {
  const _Label(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: KSpace.xs),
    child: Text(text, style: KText.label.copyWith(color: context.k.ink)),
  );
}

/// The total, big, as on the design.
class _AmountField extends StatelessWidget {
  const _AmountField({required this.controller, required this.onChanged, this.error});

  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final String? error;

  @override
  Widget build(BuildContext context) {
    final k = context.k;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Total', style: KText.label.copyWith(color: k.ink)),
        TextField(
          controller: controller,
          autofocus: controller.text.isEmpty,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))],
          style: KText.amountHero.copyWith(color: k.ink),
          onChanged: onChanged,
          decoration: InputDecoration(
            prefixText: '₹ ',
            prefixStyle: KText.amountHero.copyWith(color: k.muted),
            hintText: '0',
            hintStyle: KText.amountHero.copyWith(color: k.placeholder),
            border: InputBorder.none,
            errorText: error,
            semanticCounterText: '',
          ),
        ),
      ],
    );
  }
}

/// A person with a small box for an amount or a percentage.
class _InputRow extends StatelessWidget {
  const _InputRow({
    required this.name,
    required this.controller,
    required this.semanticLabel,
    required this.onChanged,
    this.sub,
    this.prefix,
    this.suffix,
  });

  final String name;
  final String? sub;
  final TextEditingController controller;
  final String semanticLabel;
  final ValueChanged<String> onChanged;
  final String? prefix;
  final String? suffix;

  @override
  Widget build(BuildContext context) {
    final k = context.k;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: KSpace.xs),
      child: Row(
        children: [
          KAvatar(name: name, circle: true, size: 36),
          const SizedBox(width: KSpace.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: KText.bodyStrong.copyWith(color: k.ink)),
                if (sub != null) Text(sub!, style: KText.small.copyWith(color: k.muted)),
              ],
            ),
          ),
          SizedBox(
            width: 112,
            child: Semantics(
              label: semanticLabel,
              textField: true,
              child: TextField(
                controller: controller,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))],
                textAlign: TextAlign.end,
                style: KText.bodyStrong.copyWith(color: k.ink),
                onChanged: onChanged,
                decoration: InputDecoration(
                  isDense: true,
                  // Always shown, not only while typing.
                  prefixIcon: prefix == null ? null : _Affix(prefix!),
                  prefixIconConstraints: const BoxConstraints(minWidth: 28),
                  suffixIcon: suffix == null ? null : _Affix(suffix!),
                  suffixIconConstraints: const BoxConstraints(minWidth: 28),
                  hintText: '0',
                  filled: true,
                  fillColor: k.surfaceMuted,
                  contentPadding: const EdgeInsets.symmetric(horizontal: KSpace.md, vertical: KSpace.sm),
                  border: const OutlineInputBorder(
                    borderRadius: BorderRadius.all(KRadius.md),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The ₹ or % beside a small box.
class _Affix extends StatelessWidget {
  const _Affix(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: Center(
      widthFactor: 1,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: KSpace.xs),
        child: Text(text, style: KText.bodyStrong.copyWith(color: context.k.muted)),
      ),
    ),
  );
}

/// A person with − and + for their shares.
class _SharesRow extends StatelessWidget {
  const _SharesRow({required this.name, required this.sub, required this.count, required this.onStep});

  final String name;
  final String sub;
  final int count;
  final ValueChanged<int> onStep;

  @override
  Widget build(BuildContext context) {
    final k = context.k;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: KSpace.xxs),
      child: Row(
        children: [
          KAvatar(name: name, circle: true, size: 36),
          const SizedBox(width: KSpace.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: KText.bodyStrong.copyWith(color: k.ink)),
                Text(sub, style: KText.small.copyWith(color: k.muted)),
              ],
            ),
          ),
          KIconButton(
            icon: Icons.remove_rounded,
            label: 'One less share for $name',
            onPressed: count > 0 ? () => onStep(-1) : null,
          ),
          SizedBox(
            width: 28,
            child: Semantics(
              label: '$count ${count == 1 ? 'share' : 'shares'} for $name',
              excludeSemantics: true,
              child: Text(
                '$count',
                textAlign: TextAlign.center,
                style: KText.heading.copyWith(color: k.ink),
              ),
            ),
          ),
          KIconButton(
            icon: Icons.add_rounded,
            label: 'One more share for $name',
            onPressed: count < SplitDraft.maxShares ? () => onStep(1) : null,
          ),
        ],
      ),
    );
  }
}
