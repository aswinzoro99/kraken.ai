import 'package:material_ui/material_ui.dart';

import '../theme/kraken_theme.dart';
import '../tokens/typography.dart';

/// A small rounded label in the accent tint, like the welcome on Home.
class KTag extends StatelessWidget {
  const KTag({super.key, required this.label, this.icon});

  final String label;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final k = context.k;
    return Container(
      padding: EdgeInsets.fromLTRB(icon == null ? 12 : 9, 6, 12, 6),
      decoration: BoxDecoration(color: k.accentSoft, borderRadius: BorderRadius.circular(999)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            ExcludeSemantics(child: Icon(icon, size: 15, color: k.primaryText)),
            const SizedBox(width: 6),
          ],
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: KText.small.copyWith(color: k.primaryText, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}
