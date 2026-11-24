import 'package:material_ui/material_ui.dart';

import '../theme/kraken_theme.dart';
import '../tokens/layout.dart';
import '../tokens/typography.dart';

/// One category's slice of a total on a single line: name, a thin bar, and
/// the amount. Every row uses the same hue; the bar length carries the
/// size, the text carries the name and number. The percentage is read out
/// to screen readers.
class KShareRow extends StatelessWidget {
  const KShareRow({super.key, required this.label, required this.value, required this.share});

  final String label;

  /// Already formatted, e.g. "₹13,200".
  final String value;

  /// 0–1.
  final double share;

  @override
  Widget build(BuildContext context) {
    final k = context.k;
    final percent = (share * 100).round();
    return Semantics(
      label: '$label, $value, $percent percent',
      excludeSemantics: true,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: Row(children: [
          Expanded(
            flex: 6,
            child: Text(label, style: KText.caption.copyWith(color: k.ink), maxLines: 1, overflow: TextOverflow.ellipsis),
          ),
          const SizedBox(width: KSpace.sm),
          Expanded(
            flex: 5,
            child: LayoutBuilder(
              builder: (context, c) => Stack(children: [
                Container(
                  height: 4,
                  decoration: BoxDecoration(color: k.surfaceMuted, borderRadius: BorderRadius.circular(2)),
                ),
                AnimatedContainer(
                  duration: KMotion.of(context, KMotion.slow),
                  curve: KMotion.curve,
                  height: 4,
                  width: c.maxWidth * share.clamp(0, 1),
                  decoration: BoxDecoration(color: k.primary, borderRadius: BorderRadius.circular(2)),
                ),
              ]),
            ),
          ),
          const SizedBox(width: KSpace.sm),
          ConstrainedBox(
            constraints: const BoxConstraints(minWidth: 64),
            child: Text(
              value,
              textAlign: TextAlign.end,
              softWrap: false,
              style: KText.caption.copyWith(color: k.ink, fontWeight: FontWeight.w500),
            ),
          ),
        ]),
      ),
    );
  }
}
