import 'package:material_ui/material_ui.dart';

import '../../core/haptics/haptics.dart';
import '../foundation/pressable.dart';
import '../theme/kraken_theme.dart';
import '../tokens/layout.dart';
import '../tokens/typography.dart';

final class KBarDatum {
  const KBarDatum({required this.label, required this.value, required this.semanticLabel});

  /// Short axis label, e.g. "Nov".
  final String label;
  final double value;

  /// Read by screen readers, e.g. "November, ₹21,500".
  final String semanticLabel;
}

/// A short run of columns (a few months) where one is selected. The
/// selected column is the accent colour and its label is bold, so the
/// choice isn't shown by colour alone. Tap a column to select it.
class KTrendBars extends StatelessWidget {
  const KTrendBars({super.key, required this.bars, required this.selected, this.onSelect, this.height = 64});

  final List<KBarDatum> bars;
  final int selected;
  final ValueChanged<int>? onSelect;

  /// Height of the tallest column.
  final double height;

  @override
  Widget build(BuildContext context) {
    final k = context.k;
    final max = bars.fold<double>(0, (m, b) => b.value > m ? b.value : m);
    final duration = KMotion.of(context, KMotion.slow);
    return Column(
      children: [
        SizedBox(
          height: height,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              for (var i = 0; i < bars.length; i++)
                Expanded(
                  child: _hit(
                    context,
                    i,
                    Align(
                      alignment: Alignment.bottomCenter,
                      child: AnimatedContainer(
                        duration: duration,
                        curve: KMotion.curve,
                        width: 20,
                        height: max == 0 || bars[i].value <= 0 ? 0 : (bars[i].value / max * height).clamp(3, height),
                        decoration: BoxDecoration(
                          color: i == selected ? k.primary : k.chartMuted,
                          // Rounded at the data end, square on the baseline.
                          borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
        Container(height: 1, color: k.line),
        const SizedBox(height: KSpace.xs),
        KTrendAxis(labels: [for (final b in bars) b.label], selected: selected),
      ],
    );
  }

  Widget _hit(BuildContext context, int i, Widget child) {
    final label = '${bars[i].semanticLabel}${i == selected ? ', selected' : ''}';
    if (onSelect == null) return Semantics(label: label, child: child);
    return KPressable(
      onTap: i == selected ? () {} : () => onSelect!(i),
      haptic: i == selected ? null : HapticKind.selection,
      pressedScale: 0.94,
      semanticLabel: label,
      excludeChildSemantics: true,
      child: child,
    );
  }
}

/// The month labels under a trend chart; the selected one is bold, so the
/// choice isn't shown by colour alone. Screen readers get the marks instead.
class KTrendAxis extends StatelessWidget {
  const KTrendAxis({super.key, required this.labels, required this.selected});

  final List<String> labels;
  final int selected;

  @override
  Widget build(BuildContext context) {
    final k = context.k;
    return ExcludeSemantics(
      child: Row(
        children: [
          for (var i = 0; i < labels.length; i++)
            Expanded(
              child: Text(
                labels[i],
                textAlign: TextAlign.center,
                style: KText.small.copyWith(
                  color: i == selected ? k.ink : k.muted,
                  fontWeight: i == selected ? FontWeight.w600 : FontWeight.w400,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
