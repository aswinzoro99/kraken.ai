import 'package:material_ui/material_ui.dart';

import '../theme/kraken_theme.dart';
import '../tokens/typography.dart';

/// "35% more than 1–24 Oct": change against a named period, with an arrow
/// and words so it never relies on colour. For spending, up is bad.
class KDelta extends StatelessWidget {
  const KDelta({super.key, required this.percent, required this.against});

  final int percent;

  /// The period compared with, e.g. "September" or "1–24 Oct".
  final String against;

  @override
  Widget build(BuildContext context) {
    final k = context.k;
    final (icon, text, color) = switch (percent) {
      > 0 => (Icons.arrow_upward_rounded, '$percent% more than $against', k.owe),
      < 0 => (Icons.arrow_downward_rounded, '${-percent}% less than $against', k.success),
      _ => (Icons.drag_handle_rounded, 'Same as $against', k.muted),
    };
    return Semantics(
      label: text,
      excludeSemantics: true,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              text,
              style: KText.caption.copyWith(color: color, fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }
}
