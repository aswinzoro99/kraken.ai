import 'package:ledger/ledger.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../ui_kit/ui_kit.dart';

/// Real bits of the app, filled with example data, for the welcome slides.
/// Built from the same components as the screens they show, so they look
/// exactly like using Kraken. Each part rises in, in order, when its slide
/// comes into view ([active]); nothing loops.

String _money(int rupees) => MoneyFormat.format(Money(rupees * 100));

/// The frame each example sits in: a card on the page, like a piece of the
/// app lifted out.
class ExampleFrame extends StatelessWidget {
  const ExampleFrame({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final k = context.k;
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: 320,
      padding: const EdgeInsets.all(KSpace.lg),
      decoration: BoxDecoration(
        color: k.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: k.line),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: dark ? 0.4 : 0.07),
            blurRadius: 30,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: child,
    );
  }
}

/// Fades and rises its child in, [order] steps after its slide becomes
/// active. Instant under Reduce Motion.
class _Step extends StatelessWidget {
  const _Step({required this.order, required this.active, required this.child});
  final int order;
  final bool active;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final total = KMotion.of(context, Duration(milliseconds: 420 + order * 110));
    if (total == Duration.zero) return child;
    final start = order * 110 / total.inMilliseconds;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: active ? 1 : 0),
      duration: active ? total : Duration.zero,
      builder: (context, t, child) {
        final p = KMotion.curve.transform(((t - start) / (1 - start)).clamp(0.0, 1.0));
        return Opacity(
          opacity: p,
          child: Transform.translate(offset: Offset(0, 14 * (1 - p)), child: child),
        );
      },
      child: child,
    );
  }
}

/// Home's balances: what you're owed, what you owe, and who to pay or nudge.
class BalancesExample extends StatelessWidget {
  const BalancesExample({super.key, required this.active});
  final bool active;

  @override
  Widget build(BuildContext context) {
    final k = context.k;
    return ExampleFrame(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _Step(
            order: 0,
            active: active,
            child: Row(
              children: [
                Expanded(
                  child: _Stat(label: 'Owed to you', amount: _money(4720), color: k.owed),
                ),
                Container(width: 1, height: 44, color: k.divider),
                const SizedBox(width: KSpace.md),
                Expanded(
                  child: _Stat(label: 'You owe', amount: _money(1850), color: k.owe),
                ),
              ],
            ),
          ),
          const SizedBox(height: KSpace.md),
          _Step(
            order: 1,
            active: active,
            child: _Person(name: 'Meera', group: 'Goa Trip', owesYou: false, amount: 1850, action: 'Pay'),
          ),
          Divider(height: KSpace.lg, color: k.divider),
          _Step(
            order: 2,
            active: active,
            child: _Person(name: 'Sreya', group: 'Weekend trek', owesYou: true, amount: 1570, action: 'Remind'),
          ),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.amount, required this.color});
  final String label;
  final String amount;
  final Color color;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(label, style: KText.caption.copyWith(color: context.k.muted)),
      Text(
        amount,
        style: KText.amount.copyWith(color: color, fontSize: 20, fontWeight: FontWeight.w600),
      ),
    ],
  );
}

class _Person extends StatelessWidget {
  const _Person({
    required this.name,
    required this.group,
    required this.owesYou,
    required this.amount,
    required this.action,
  });
  final String name;
  final String group;
  final bool owesYou;
  final int amount;
  final String action;

  @override
  Widget build(BuildContext context) {
    final k = context.k;
    final color = owesYou ? k.owed : k.owe;
    return Row(
      children: [
        KAvatar(name: name, size: 34, circle: true, tone: KTone.neutral),
        const SizedBox(width: KSpace.sm),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(name, style: KText.bodyStrong.copyWith(color: k.ink)),
              Text(group, style: KText.small.copyWith(color: k.muted)),
            ],
          ),
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(owesYou ? 'owes you' : 'you owe', style: KText.small.copyWith(color: color)),
            Text(_money(amount), style: KText.amount.copyWith(color: color)),
          ],
        ),
        const SizedBox(width: KSpace.sm),
        KButton(label: action, variant: KButtonVariant.secondary, size: KButtonSize.small, onPressed: () {}),
      ],
    );
  }
}

/// Talking to Kraken: you say what happened, it adds the expense.
class ChatExample extends StatelessWidget {
  const ChatExample({super.key, required this.active});
  final bool active;

  @override
  Widget build(BuildContext context) {
    final k = context.k;
    return ExampleFrame(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _Step(
            order: 0,
            active: active,
            child: const ChatBubble(author: ChatAuthor.me, text: 'Cab 450 with Arjun, split equally'),
          ),
          const SizedBox(height: KSpace.sm),
          _Step(
            order: 1,
            active: active,
            child: const ChatBubble(author: ChatAuthor.kraken, text: 'Added to Goa Trip. Arjun owes you ₹225.'),
          ),
          const SizedBox(height: KSpace.md),
          _Step(
            order: 2,
            active: active,
            child: Container(
              padding: const EdgeInsets.all(KSpace.md),
              decoration: BoxDecoration(color: k.surfaceMuted, borderRadius: BorderRadius.circular(14)),
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(color: k.surface, shape: BoxShape.circle),
                    child: Icon(Icons.local_taxi_rounded, size: 19, color: k.ink),
                  ),
                  const SizedBox(width: KSpace.sm),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text('Cab', style: KText.bodyStrong.copyWith(color: k.ink)),
                            const SizedBox(width: 6),
                            Icon(Icons.mic_rounded, size: 14, color: k.muted),
                          ],
                        ),
                        Text('You paid ${_money(450)} · 2 people', style: KText.small.copyWith(color: k.muted)),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text('you lent', style: KText.small.copyWith(color: k.owed)),
                      Text(_money(225), style: KText.amount.copyWith(color: k.owed)),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// A scanned bill, split item by item between the people who had each.
class BillExample extends StatelessWidget {
  const BillExample({super.key, required this.active});
  final bool active;

  static const _items = [
    ('Paneer tikka', ['Aarav', 'Meera'], 320),
    ('Butter naan ×3', ['Aarav', 'Meera', 'Sreya'], 180),
    ('Lime soda', ['Sreya'], 120),
  ];

  @override
  Widget build(BuildContext context) {
    final k = context.k;
    return ExampleFrame(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _Step(
            order: 0,
            active: active,
            child: Row(
              children: [
                Icon(Icons.document_scanner_outlined, size: 18, color: k.muted),
                const SizedBox(width: KSpace.xs),
                Expanded(
                  child: Text('Beach shack bill', style: KText.bodyStrong.copyWith(color: k.ink)),
                ),
                const KTag(label: 'Split by item'),
              ],
            ),
          ),
          const SizedBox(height: KSpace.md),
          for (final (i, (name, people, price)) in _items.indexed) ...[
            _Step(
              order: 1 + i,
              active: active,
              child: Row(
                children: [
                  Expanded(
                    child: Text(name, style: KText.label.copyWith(color: k.ink)),
                  ),
                  KAvatarStack(names: people, size: 22),
                  const SizedBox(width: KSpace.sm),
                  SizedBox(
                    width: 52,
                    child: Text(
                      _money(price),
                      textAlign: TextAlign.end,
                      style: KText.amount.copyWith(color: k.ink, fontSize: 14),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: KSpace.sm),
          ],
          Divider(height: KSpace.md, color: k.divider),
          _Step(
            order: 4,
            active: active,
            child: Row(
              children: [
                Expanded(
                  child: Text('Your share', style: KText.bodyStrong.copyWith(color: k.ink)),
                ),
                Text(_money(220), style: KText.amount.copyWith(color: k.ink)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Settling up: pay by UPI or record cash, and see it marked settled.
class SettleExample extends StatelessWidget {
  const SettleExample({super.key, required this.active});
  final bool active;

  @override
  Widget build(BuildContext context) {
    final k = context.k;
    return ExampleFrame(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _Step(
            order: 0,
            active: active,
            child: Row(
              children: [
                KAvatar(name: 'Meera', size: 40, circle: true, tone: KTone.neutral),
                const SizedBox(width: KSpace.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Pay Meera', style: KText.bodyStrong.copyWith(color: k.ink)),
                      Text('Goa Trip', style: KText.small.copyWith(color: k.muted)),
                    ],
                  ),
                ),
                Text(
                  _money(1850),
                  style: KText.amount.copyWith(color: k.owe, fontSize: 20, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
          const SizedBox(height: KSpace.md),
          _Step(
            order: 1,
            active: active,
            child: KButton(label: 'Pay by UPI', expand: true, size: KButtonSize.medium, onPressed: () {}),
          ),
          const SizedBox(height: KSpace.xs),
          _Step(
            order: 2,
            active: active,
            child: KButton(
              label: 'Record a cash payment',
              variant: KButtonVariant.ghost,
              expand: true,
              size: KButtonSize.medium,
              onPressed: () {},
            ),
          ),
          const SizedBox(height: KSpace.sm),
          _Step(
            order: 3,
            active: active,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: KSpace.md, vertical: KSpace.sm),
              decoration: BoxDecoration(color: k.successSoft, borderRadius: BorderRadius.circular(12)),
              child: Row(
                children: [
                  Icon(Icons.check_circle_rounded, size: 18, color: k.success),
                  const SizedBox(width: KSpace.xs),
                  Expanded(
                    child: Text(
                      'Settled with Sreya · ${_money(1570)}',
                      style: KText.caption.copyWith(color: k.success, fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
