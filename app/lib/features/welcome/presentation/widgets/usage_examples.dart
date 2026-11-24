import 'dart:math' as math;

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

/// Talking to Kraken, played out each time the slide comes into view: the
/// mic listens (pulsing, with a live level meter) while your words appear,
/// then they drop into the chat, Kraken answers, and the expense shows up.
/// Under Reduce Motion it shows the end straight away.
class ChatExample extends StatefulWidget {
  const ChatExample({super.key, required this.active});
  final bool active;

  static const said = 'Cab 450 with Arjun, split equally';

  @override
  State<ChatExample> createState() => _ChatExampleState();
}

class _ChatExampleState extends State<ChatExample> with SingleTickerProviderStateMixin {
  late final AnimationController _play = AnimationController(vsync: this, duration: const Duration(milliseconds: 4600));

  bool get _still => MediaQuery.maybeDisableAnimationsOf(context) ?? false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_still) {
      _play.value = 1;
    } else if (widget.active && !_play.isAnimating && _play.value == 0) {
      _play.forward();
    }
  }

  @override
  void didUpdateWidget(ChatExample old) {
    super.didUpdateWidget(old);
    if (widget.active && !old.active && !_still) _play.forward(from: 0);
  }

  @override
  void dispose() {
    _play.dispose();
    super.dispose();
  }

  /// Like live captions: the newest words stay in view, the start trims.
  static String _caption(String text, {int room = 24}) =>
      text.length <= room ? text : '…${text.substring(text.length - room + 1)}';

  /// 0 → 1 across [from, to] of the timeline, eased.
  double _phase(double from, double to) =>
      KMotion.curve.transform(((_play.value - from) / (to - from)).clamp(0.0, 1.0));

  Widget _reveal(double from, Widget child) {
    final p = _phase(from, from + 0.1);
    return Opacity(
      opacity: p,
      child: Transform.translate(offset: Offset(0, 12 * (1 - p)), child: child),
    );
  }

  @override
  Widget build(BuildContext context) {
    final k = context.k;
    return ExampleFrame(
      child: AnimatedBuilder(
        animation: _play,
        builder: (context, _) {
          const listenEnd = 0.46;
          final listening = _play.value > 0 && _play.value < listenEnd;
          final typed = (ChatExample.said.length * _phase(0.06, 0.4)).round();
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _TalkBar(
                listening: listening,
                beat: _play.value * 22,
                text: _play.value < listenEnd
                    ? (typed == 0 ? 'Listening…' : _caption(ChatExample.said.substring(0, typed)))
                    : 'Touch and hold to talk',
                hint: _play.value >= listenEnd,
              ),
              const SizedBox(height: KSpace.md),
              _reveal(0.48, const ChatBubble(author: ChatAuthor.me, text: ChatExample.said)),
              const SizedBox(height: KSpace.sm),
              _reveal(
                0.62,
                const ChatBubble(author: ChatAuthor.kraken, text: 'Added to Goa Trip. Arjun owes you ₹225.'),
              ),
              const SizedBox(height: KSpace.md),
              _reveal(
                0.78,
                Container(
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
          );
        },
      ),
    );
  }
}

/// The mic, as when you hold + in the app: rings pulse out of it and a
/// level meter moves while it listens; afterwards it rests with the hint.
class _TalkBar extends StatelessWidget {
  const _TalkBar({required this.listening, required this.beat, required this.text, required this.hint});
  final bool listening;

  /// Advances while listening; drives the rings and the meter.
  final double beat;
  final String text;
  final bool hint;

  @override
  Widget build(BuildContext context) {
    final k = context.k;
    return Container(
      padding: const EdgeInsets.fromLTRB(8, 8, 14, 8),
      decoration: BoxDecoration(color: k.surfaceMuted, borderRadius: BorderRadius.circular(999)),
      child: Row(
        children: [
          SizedBox.square(
            dimension: 40,
            child: CustomPaint(
              painter: _Rings(color: k.primary, beat: listening ? beat : null),
              child: Center(
                child: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(color: k.primary, shape: BoxShape.circle),
                  child: Icon(Icons.mic_rounded, size: 20, color: k.onPrimary),
                ),
              ),
            ),
          ),
          const SizedBox(width: KSpace.sm),
          Expanded(
            child: Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: (hint ? KText.caption : KText.label).copyWith(
                color: hint ? k.muted : k.ink,
                fontWeight: hint ? FontWeight.w500 : FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(width: KSpace.xs),
          for (var i = 0; i < 4; i++) ...[
            if (i > 0) const SizedBox(width: 3),
            Container(
              width: 3,
              height: listening ? 5 + 13 * (0.5 + 0.5 * math.sin(beat * 2.4 + i * 1.3)) : 5,
              decoration: BoxDecoration(
                color: listening ? k.primary : k.placeholder,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Two rings spreading out from the mic while it listens.
class _Rings extends CustomPainter {
  _Rings({required this.color, required this.beat});
  final Color color;
  final double? beat;

  @override
  void paint(Canvas canvas, Size size) {
    final beat = this.beat;
    if (beat == null) return;
    final centre = size.center(Offset.zero);
    for (final offset in [0.0, 0.5]) {
      final f = (beat * 0.25 + offset) % 1.0;
      canvas.drawCircle(
        centre,
        18 + 10 * f,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..color = color.withValues(alpha: 0.45 * (1 - f)),
      );
    }
  }

  @override
  bool shouldRepaint(_Rings old) => old.beat != beat || old.color != color;
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
