import 'package:material_ui/material_ui.dart';

import '../../core/haptics/haptics.dart';
import '../foundation/haptics_scope.dart';
import '../theme/kraken_theme.dart';
import '../tokens/motion.dart';
import '../tokens/typography.dart';

/// One option in a [KSegmentedControl].
final class KSegment<T> {
  const KSegment(this.value, this.label, {this.icon});
  final T value;

  /// Shown; with an [icon], read by screen readers instead.
  final String label;

  /// Shows this icon instead of the label, for compact toggles.
  final IconData? icon;
}

/// Pick one of a few options: a track with a thumb that slides to the
/// chosen one, iOS-style. Each option reads as a button in a group, marked
/// selected, so screen readers announce it like a radio button.
///
/// [compact] sizes it to its content, for an icon toggle beside a title.
class KSegmentedControl<T> extends StatelessWidget {
  const KSegmentedControl({
    super.key,
    required this.segments,
    required this.value,
    required this.onChanged,
    this.compact = false,
  });

  final List<KSegment<T>> segments;
  final T value;
  final ValueChanged<T> onChanged;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final k = context.k;
    final n = segments.length;
    final index = segments.indexWhere((s) => s.value == value);
    final reduce = MediaQuery.maybeDisableAnimationsOf(context) ?? false;

    void pick(T next) {
      if (next == value) return;
      context.haptic(HapticKind.selection);
      onChanged(next);
    }

    return Container(
      padding: EdgeInsets.all(compact ? 2 : 3),
      decoration: BoxDecoration(color: k.surfaceMuted, borderRadius: BorderRadius.circular(compact ? 10 : 12)),
      child: Stack(
        children: [
          if (index >= 0)
            Positioned.fill(
              child: AnimatedAlign(
                alignment: Alignment(n == 1 ? 0 : -1 + 2 * index / (n - 1), 0),
                duration: reduce ? Duration.zero : const Duration(milliseconds: 350),
                curve: KSpringCurve(KSpring.snappy),
                child: FractionallySizedBox(
                  widthFactor: 1 / n,
                  heightFactor: 1,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: k.surfaceRaised,
                      borderRadius: BorderRadius.circular(compact ? 8 : 9),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.08),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          Row(
            mainAxisSize: compact ? MainAxisSize.min : MainAxisSize.max,
            children: [
              for (final s in segments)
                if (compact) SizedBox(width: 40, child: _segment(s, pick)) else Expanded(child: _segment(s, pick)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _segment(KSegment<T> s, void Function(T) pick) =>
      _Segment(label: s.label, icon: s.icon, compact: compact, selected: s.value == value, onTap: () => pick(s.value));
}

class _Segment extends StatelessWidget {
  const _Segment({
    required this.label,
    required this.icon,
    required this.compact,
    required this.selected,
    required this.onTap,
  });
  final String label;
  final IconData? icon;
  final bool compact;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final k = context.k;
    return Semantics(
      button: true,
      selected: selected,
      inMutuallyExclusiveGroup: true,
      label: label,
      excludeSemantics: true,
      onTap: onTap,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: ConstrainedBox(
          // With the track's padding, a 44 pt touch target (36 when compact).
          constraints: BoxConstraints(minHeight: compact ? 32 : 38),
          child: Center(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 6, vertical: compact ? 4 : 8),
              child: icon != null
                  ? Icon(icon, size: 18, color: selected ? k.ink : k.inkSecondary)
                  : Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: KText.label.copyWith(
                        color: selected ? k.ink : k.inkSecondary,
                        fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                      ),
                    ),
            ),
          ),
        ),
      ),
    );
  }
}
