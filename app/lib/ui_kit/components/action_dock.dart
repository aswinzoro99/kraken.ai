import 'package:material_ui/material_ui.dart';

import '../../core/haptics/haptics.dart';
import '../foundation/haptics_scope.dart';
import '../foundation/pressable.dart';
import '../theme/kraken_theme.dart';
import '../tokens/layout.dart';
import '../tokens/typography.dart';

/// The slim bar floating above the tabs: Scan, the mic, Add.
/// Hold the mic to talk; tap it for tap-to-talk.
class KActionDock extends StatelessWidget {
  const KActionDock({
    super.key,
    required this.onScan,
    required this.onAddExpense,
    required this.onMicTap,
    this.onMicHoldStart,
    this.onMicHoldEnd,
  });

  final VoidCallback onScan;
  final VoidCallback onAddExpense;
  final VoidCallback onMicTap;
  final VoidCallback? onMicHoldStart;
  final VoidCallback? onMicHoldEnd;

  @override
  Widget build(BuildContext context) {
    final k = context.k;
    Widget side(IconData icon, String label, VoidCallback onTap) => Expanded(
      child: KPressable(
        onTap: onTap,
        semanticLabel: label,
        excludeChildSemantics: true,
        child: SizedBox(
          height: 52,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 19, color: k.ink),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  label,
                  style: KText.label.copyWith(color: k.ink),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
    return Container(
      height: 60,
      padding: const EdgeInsets.symmetric(horizontal: KSpace.xxs),
      decoration: BoxDecoration(
        color: k.background,
        border: Border.all(color: k.line),
        borderRadius: const BorderRadius.all(Radius.circular(30)),
        boxShadow: [BoxShadow(color: k.ink.withValues(alpha: 0.05), blurRadius: 24, offset: const Offset(0, 8))],
      ),
      child: Row(
        children: [
          side(Icons.document_scanner_outlined, 'Scan', onScan),
          _Mic(onTap: onMicTap, onHoldStart: onMicHoldStart, onHoldEnd: onMicHoldEnd),
          side(Icons.add_rounded, 'Add', onAddExpense),
        ],
      ),
    );
  }
}

class _Mic extends StatefulWidget {
  const _Mic({required this.onTap, this.onHoldStart, this.onHoldEnd});
  final VoidCallback onTap;
  final VoidCallback? onHoldStart;
  final VoidCallback? onHoldEnd;

  @override
  State<_Mic> createState() => _MicState();
}

class _MicState extends State<_Mic> {
  bool _holding = false;

  @override
  Widget build(BuildContext context) {
    final k = context.k;
    return Semantics(
      button: true,
      label: 'Hold to add an expense by voice',
      onTap: widget.onTap,
      child: GestureDetector(
        excludeFromSemantics: true,
        onTap: () {
          HapticsScope.play(context, HapticKind.tap);
          widget.onTap();
        },
        onLongPressStart: (_) {
          setState(() => _holding = true);
          HapticsScope.play(context, HapticKind.heavy);
          widget.onHoldStart?.call();
        },
        onLongPressEnd: (_) {
          setState(() => _holding = false);
          HapticsScope.play(context, HapticKind.tap);
          widget.onHoldEnd?.call();
        },
        child: AnimatedScale(
          scale: _holding ? 1.1 : 1,
          duration: KMotion.of(context, KMotion.base),
          curve: KMotion.curve,
          child: Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(color: k.primary, shape: BoxShape.circle),
            child: Icon(Icons.mic_rounded, size: 22, color: k.onPrimary),
          ),
        ),
      ),
    );
  }
}
