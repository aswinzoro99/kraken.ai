import 'package:material_ui/material_ui.dart';

import '../../core/haptics/haptics.dart';
import '../foundation/haptics_scope.dart';
import '../theme/kraken_theme.dart';
import '../tokens/colors.dart';
import '../tokens/motion.dart';
import '../tokens/typography.dart';

/// What a [KThemePicker] tile shows: the app in light, in dark, or split
/// between the two (follow the phone).
enum KThemePreview { light, dark, split }

final class KThemeChoice<T> {
  const KThemeChoice(this.value, this.label, this.preview);
  final T value;
  final String label;
  final KThemePreview preview;
}

/// Pick how the app looks, from tiles that show it: a small sketch of the
/// app in each theme, with a radio under the label (iOS Display &
/// Brightness style). Screen readers hear each tile as a radio button.
class KThemePicker<T> extends StatelessWidget {
  const KThemePicker({super.key, required this.choices, required this.value, required this.onChanged});

  final List<KThemeChoice<T>> choices;
  final T value;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    void pick(T next) {
      if (next == value) return;
      context.haptic(HapticKind.selection);
      onChanged(next);
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < choices.length; i++) ...[
          if (i > 0) const SizedBox(width: 12),
          Expanded(
            child: _Tile(choice: choices[i], selected: choices[i].value == value, onTap: () => pick(choices[i].value)),
          ),
        ],
      ],
    );
  }
}

class _Tile<T> extends StatelessWidget {
  const _Tile({required this.choice, required this.selected, required this.onTap});
  final KThemeChoice<T> choice;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final k = context.k;
    final reduce = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    final duration = reduce ? Duration.zero : const Duration(milliseconds: 250);
    return Semantics(
      button: true,
      selected: selected,
      inMutuallyExclusiveGroup: true,
      label: choice.label,
      excludeSemantics: true,
      onTap: onTap,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Column(
          children: [
            AnimatedContainer(
              duration: duration,
              curve: KSpringCurve(KSpring.snappy),
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(17),
                border: Border.all(color: selected ? k.primary : Colors.transparent, width: 2),
              ),
              child: AnimatedScale(
                scale: selected ? 1 : 0.96,
                duration: duration,
                curve: KSpringCurve(KSpring.snappy),
                child: _Preview(choice.preview),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              choice.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: KText.label.copyWith(
                color: selected ? k.ink : k.inkSecondary,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
              ),
            ),
            const SizedBox(height: 6),
            _Radio(selected: selected, duration: duration),
          ],
        ),
      ),
    );
  }
}

class _Radio extends StatelessWidget {
  const _Radio({required this.selected, required this.duration});
  final bool selected;
  final Duration duration;

  @override
  Widget build(BuildContext context) {
    final k = context.k;
    return AnimatedContainer(
      duration: duration,
      width: 20,
      height: 20,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: selected ? k.primary : Colors.transparent,
        border: Border.all(color: selected ? k.primary : k.placeholder, width: 1.5),
      ),
      child: selected ? Icon(Icons.check_rounded, size: 14, color: k.onPrimary) : null,
    );
  }
}

/// A sketch of Home: a caption, the total, the month bars and the tab bar,
/// in that theme's real colours whatever theme the app is in now.
class _Preview extends StatelessWidget {
  const _Preview(this.preview);
  final KThemePreview preview;

  @override
  Widget build(BuildContext context) {
    final frame = context.k.line;
    final screen = switch (preview) {
      KThemePreview.light => const _Screen(KColors.light),
      KThemePreview.dark => const _Screen(KColors.dark),
      KThemePreview.split => Stack(
        fit: StackFit.expand,
        children: [
          const _Screen(KColors.light),
          ClipPath(clipper: _Diagonal(), child: const _Screen(KColors.dark)),
        ],
      ),
    };
    return AspectRatio(
      aspectRatio: 0.8,
      child: DecoratedBox(
        position: DecorationPosition.foreground,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: frame),
        ),
        child: ClipRRect(borderRadius: BorderRadius.circular(12), child: screen),
      ),
    );
  }
}

class _Screen extends StatelessWidget {
  const _Screen(this.c);
  final KColors c;

  Widget _line(Color color, double widthFactor, double height) => Align(
    alignment: Alignment.centerLeft,
    child: FractionallySizedBox(
      widthFactor: widthFactor,
      child: Container(
        height: height,
        decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(height)),
      ),
    ),
  );

  @override
  Widget build(BuildContext context) => ColoredBox(
    color: c.background,
    child: Padding(
      padding: const EdgeInsets.fromLTRB(10, 12, 10, 7),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _line(c.muted, 0.5, 4),
          const SizedBox(height: 5),
          _line(c.ink, 0.75, 8),
          const Spacer(),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              for (final (i, h) in const [10.0, 13.0, 11.0, 17.0].indexed) ...[
                if (i > 0) const SizedBox(width: 4),
                Expanded(
                  child: Container(
                    height: h,
                    decoration: BoxDecoration(
                      color: i == 3 ? c.primary : c.chartMuted,
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(2)),
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 7),
          Container(
            height: 9,
            decoration: BoxDecoration(color: c.surfaceMuted, borderRadius: BorderRadius.circular(9)),
          ),
        ],
      ),
    ),
  );
}

/// The lower-right half, cut on a diagonal.
class _Diagonal extends CustomClipper<Path> {
  @override
  Path getClip(Size s) => Path()
    ..moveTo(s.width * 0.7, 0)
    ..lineTo(s.width, 0)
    ..lineTo(s.width, s.height)
    ..lineTo(s.width * 0.3, s.height)
    ..close();

  @override
  bool shouldReclip(_Diagonal old) => false;
}
