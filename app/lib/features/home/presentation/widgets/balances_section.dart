import 'package:ledger/ledger.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../ui_kit/ui_kit.dart';
import '../../domain/home_snapshot.dart';
import 'formatting.dart';

/// Who owes whom, per person across groups, with the next step for each:
/// pay the people you owe, nudge the people who owe you.
class BalancesSection extends StatelessWidget {
  const BalancesSection({super.key, required this.balances, required this.onSeeAll, required this.onSettle});

  final BalanceSummary balances;
  final VoidCallback onSeeAll;
  final void Function(PersonBalance person) onSettle;

  static const _rows = 3;

  @override
  Widget build(BuildContext context) {
    final k = context.k;
    final more = balances.people.length > _rows;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        KSectionHeader(title: 'Balances', actionLabel: more ? 'See all' : null, onAction: onSeeAll),
        if (balances.allSettled)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: KSpace.md),
            child: Row(
              children: [
                Icon(Icons.check_circle_outline_rounded, size: 20, color: k.success),
                const SizedBox(width: KSpace.sm),
                Text("You're all settled up", style: KText.body.copyWith(color: k.ink)),
              ],
            ),
          )
        else ...[
          const SizedBox(height: KSpace.xxs),
          IntrinsicHeight(
            child: Row(
              children: [
                Expanded(
                  child: _Stat(
                    label: 'Owed to you',
                    amount: balances.owedToYou,
                    caption: balances.owingYouCount == 0 ? 'Nobody' : 'from ${people(balances.owingYouCount)}',
                    color: k.owed,
                  ),
                ),
                VerticalDivider(width: KSpace.xxl, thickness: 1, color: k.divider),
                Expanded(
                  child: _Stat(
                    label: 'You owe',
                    amount: balances.youOwe,
                    caption: balances.youOweCount == 0 ? 'Nobody' : 'to ${people(balances.youOweCount)}',
                    color: balances.youOwe.isZero ? k.ink : k.owe,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: KSpace.sm),
          KGroupedList(
            indent: 48,
            children: [for (final p in balances.people.take(_rows)) _PersonRow(person: p, onAction: () => onSettle(p))],
          ),
        ],
      ],
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.amount, required this.caption, required this.color});
  final String label;
  final Money amount;
  final String caption;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final k = context.k;
    return MergeSemantics(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: KText.caption.copyWith(color: k.muted)),
          const SizedBox(height: 2),
          KRollingNumber(
            MoneyFormat.format(amount),
            style: KText.amount.copyWith(color: color, fontSize: 20, fontWeight: FontWeight.w600),
          ),
          Text(caption, style: KText.small.copyWith(color: k.muted)),
        ],
      ),
    );
  }
}

class _PersonRow extends StatelessWidget {
  const _PersonRow({required this.person, required this.onAction});
  final PersonBalance person;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    final k = context.k;
    final youOwe = person.amount.isNegative;
    final amount = MoneyFormat.format(person.amount);
    final words = youOwe ? 'you owe' : 'owes you';
    final color = youOwe ? k.owe : k.owed;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: KSpace.sm),
      child: Row(
        children: [
          Expanded(
            // Read as one item: "Meera, Goa Trip, you owe, ₹1,850".
            child: MergeSemantics(
              child: Row(
                children: [
                  ExcludeSemantics(
                    child: KAvatar(name: person.name, size: 36, circle: true, tone: KTone.neutral),
                  ),
                  const SizedBox(width: KSpace.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          person.name,
                          style: KText.bodyStrong.copyWith(color: k.ink),
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          person.groupNames.join(', '),
                          style: KText.small.copyWith(color: k.muted),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(words, style: KText.small.copyWith(color: color)),
                      Text(amount, style: KText.amount.copyWith(color: color)),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: KSpace.md),
          // A shared minimum width so the amounts line up down the list;
          // the button still grows with large text instead of cutting off.
          ConstrainedBox(
            constraints: const BoxConstraints(minWidth: 84),
            child: KButton(
              label: youOwe ? 'Pay' : 'Remind',
              variant: KButtonVariant.secondary,
              size: KButtonSize.small,
              onPressed: onAction,
            ),
          ),
        ],
      ),
    );
  }
}
