import 'package:ledger/ledger.dart';

import 'expense.dart';
import 'group.dart';

/// Reads an amount typed in rupees ("1,234.5", "₹ 450") as paise. Null if
/// it isn't one, has more than two decimals, or is too big.
Money? parseRupees(String raw) {
  final text = raw.replaceAll(RegExp(r'[₹,\s]'), '');
  final match = RegExp(r'^(\d{1,9})(?:\.(\d{0,2}))?$').firstMatch(text);
  if (match == null) return null;
  final rupees = int.parse(match.group(1)!);
  final decimals = (match.group(2) ?? '').padRight(2, '0');
  return Money(rupees * 100 + int.parse(decimals));
}

/// Reads a percentage ("25", "33.33") as basis points (25% = 2500).
int? parsePercent(String raw) {
  final text = raw.replaceAll(RegExp(r'[%\s]'), '');
  final match = RegExp(r'^(\d{1,3})(?:\.(\d{0,2}))?$').firstMatch(text);
  if (match == null) return null;
  final bp = int.parse(match.group(1)!) * 100 + int.parse((match.group(2) ?? '').padRight(2, '0'));
  return bp > 10000 ? null : bp;
}

/// Writes paise back as rupees for a text field: 90000 → "900", 3334 →
/// "33.34".
String rupeesText(Money m) {
  final whole = m.paise ~/ 100;
  final rest = m.paise % 100;
  return rest == 0 ? '$whole' : '$whole.${rest.toString().padLeft(2, '0')}';
}

/// Writes basis points as a percentage: 2500 → "25", 3333 → "33.33".
String percentText(int bp) {
  final whole = bp ~/ 100;
  final rest = bp % 100;
  if (rest == 0) return '$whole';
  return '$whole.${rest.toString().padLeft(2, '0').replaceFirst(RegExp(r'0$'), '')}';
}

/// What the split adds up to so far, for the line under the rows.
sealed class SplitCheck {
  const SplitCheck();
}

/// It adds up; [shares] are the paise each person pays.
final class SplitReady extends SplitCheck {
  const SplitReady(this.shares);
  final Map<String, Money> shares;
}

/// Not yet: [message] says what's missing ("₹300 left to assign").
final class SplitIncomplete extends SplitCheck {
  const SplitIncomplete(this.message);
  final String message;
}

/// An expense being typed: the total and how it's divided, in each of the
/// four ways. Switching tabs keeps what was typed in the others, as on the
/// "Split the total" design.
final class SplitDraft {
  const SplitDraft({
    required this.members,
    this.total,
    this.method = SplitMethod.equal,
    this.included = const {},
    this.exact = const {},
    this.percent = const {},
    this.shares = const {},
  });

  /// Everyone starts in, with one share each.
  factory SplitDraft.forMembers(List<Member> members) => SplitDraft(
    members: members,
    included: {for (final m in members) m.id},
    shares: {for (final m in members) m.id: 1},
  );

  /// Opens a saved expense as it was entered.
  factory SplitDraft.fromExpense(Expense e, List<Member> members) {
    final draft = SplitDraft.forMembers(members).copyWith(total: e.total, method: e.split);
    final w = e.weights;
    return switch (e.split) {
      SplitMethod.equal => draft.copyWith(included: {for (final id in e.shares.keys) id}),
      SplitMethod.exact => draft.copyWith(
        exact: {for (final MapEntry(:key, :value) in e.shares.entries) key: rupeesText(value)},
      ),
      SplitMethod.percent => draft.copyWith(
        percent: {for (final MapEntry(:key, :value) in w.entries) key: percentText(value)},
      ),
      SplitMethod.shares => draft.copyWith(shares: {for (final m in members) m.id: w[m.id] ?? 0}),
    };
  }

  final List<Member> members;
  final Money? total;
  final SplitMethod method;

  /// Equally: who is in.
  final Set<String> included;

  /// Exact: rupees typed per person.
  final Map<String, String> exact;

  /// Percent: percentages typed per person.
  final Map<String, String> percent;

  /// Shares: whole shares per person (0–20).
  final Map<String, int> shares;

  static const maxShares = 20;

  SplitDraft copyWith({
    Money? total,
    bool clearTotal = false,
    SplitMethod? method,
    Set<String>? included,
    Map<String, String>? exact,
    Map<String, String>? percent,
    Map<String, int>? shares,
  }) => SplitDraft(
    members: members,
    total: clearTotal ? null : (total ?? this.total),
    method: method ?? this.method,
    included: included ?? this.included,
    exact: exact ?? this.exact,
    percent: percent ?? this.percent,
    shares: shares ?? this.shares,
  );

  SplitDraft toggle(String id) =>
      copyWith(included: included.contains(id) ? ({...included}..remove(id)) : {...included, id});

  SplitDraft setExact(String id, String text) => copyWith(exact: {...exact, id: text});

  SplitDraft setPercent(String id, String text) => copyWith(percent: {...percent, id: text});

  SplitDraft stepShares(String id, int by) =>
      copyWith(shares: {...shares, id: ((shares[id] ?? 0) + by).clamp(0, maxShares)});

  /// In member order, so leftover paise always go to the same people.
  List<String> get _order => [for (final m in members) m.id];

  /// What each person pays, or what's still missing.
  SplitCheck check() {
    final total = this.total;
    if (total == null || total.isZero) return const SplitIncomplete('Enter the amount');
    switch (method) {
      case SplitMethod.equal:
        final people = [
          for (final id in _order)
            if (included.contains(id)) id,
        ];
        if (people.isEmpty) return const SplitIncomplete('Pick at least one person');
        return SplitReady(splitEqually(total, people));
      case SplitMethod.exact:
        final amounts = <String, Money>{};
        for (final id in _order) {
          final text = exact[id]?.trim() ?? '';
          if (text.isEmpty) continue;
          final m = parseRupees(text);
          if (m == null) return const SplitIncomplete('Check the amounts');
          amounts[id] = m;
        }
        final left = total - Money.sum(amounts.values);
        if (left.isPositive) return SplitIncomplete('${_format(left)} left to assign');
        if (left.isNegative) return SplitIncomplete('${_format(left)} more than the total');
        return SplitReady(splitExactly(total, amounts));
      case SplitMethod.percent:
        final bp = <String, int>{};
        for (final id in _order) {
          final text = percent[id]?.trim() ?? '';
          if (text.isEmpty) continue;
          final p = parsePercent(text);
          if (p == null) return const SplitIncomplete('Check the percentages');
          if (p > 0) bp[id] = p;
        }
        final left = 10000 - bp.values.fold<int>(0, (a, b) => a + b);
        if (left > 0) return SplitIncomplete('${percentText(left)}% left to assign');
        if (left < 0) return SplitIncomplete('${percentText(-left)}% over 100');
        return SplitReady(splitByPercent(total, bp));
      case SplitMethod.shares:
        final weights = {for (final id in _order) id: shares[id] ?? 0};
        if (weights.values.every((w) => w == 0)) return const SplitIncomplete('Give someone at least one share');
        return SplitReady(splitByShares(total, weights));
    }
  }

  /// What was typed, to save with the expense (see [Expense.weights]).
  Map<String, int> weightsFor(Map<String, Money> result) => switch (method) {
    SplitMethod.equal => {for (final id in result.keys) id: 1},
    SplitMethod.exact => {for (final MapEntry(:key, :value) in result.entries) key: value.paise},
    SplitMethod.percent => {
      for (final id in _order)
        if ((parsePercent(percent[id] ?? '') ?? 0) > 0) id: parsePercent(percent[id]!)!,
    },
    SplitMethod.shares => {
      for (final id in _order)
        if ((shares[id] ?? 0) > 0) id: shares[id]!,
    },
  };

  /// The summary line: "₹825 each · 4 people", "Adds up to ₹3,300", or what's
  /// missing.
  String summary() {
    final check = this.check();
    if (check is SplitIncomplete) return check.message;
    final ready = check as SplitReady;
    final total = this.total!;
    return switch (method) {
      SplitMethod.equal =>
        '${_format(ready.shares.values.first)} each · ${ready.shares.length} ${ready.shares.length == 1 ? 'person' : 'people'}',
      SplitMethod.exact => 'Adds up to ${_format(total)}',
      SplitMethod.percent => 'Adds up to 100%',
      SplitMethod.shares => () {
        final count = shares.values.fold<int>(0, (a, b) => a + b);
        return '$count ${count == 1 ? 'share' : 'shares'} · ${_format(Money(total.paise ~/ count))} per share';
      }(),
    };
  }

  /// ₹ with Indian grouping; paise only when there are some.
  static String _format(Money m) {
    final abs = m.abs();
    final whole = abs.paise ~/ 100;
    final rest = abs.paise % 100;
    final digits = whole.toString();
    String grouped;
    if (digits.length <= 3) {
      grouped = digits;
    } else {
      final last3 = digits.substring(digits.length - 3);
      var head = digits.substring(0, digits.length - 3);
      final parts = <String>[];
      while (head.length > 2) {
        parts.insert(0, head.substring(head.length - 2));
        head = head.substring(0, head.length - 2);
      }
      if (head.isNotEmpty) parts.insert(0, head);
      grouped = '${parts.join(',')},$last3';
    }
    return rest == 0 ? '₹$grouped' : '₹$grouped.${rest.toString().padLeft(2, '0')}';
  }
}
