import 'package:material_ui/material_ui.dart';

import '../../core/haptics/haptics.dart';
import '../foundation/pressable.dart';
import '../theme/kraken_theme.dart';
import '../tokens/layout.dart';
import '../tokens/typography.dart';

/// A row with a checkbox, for agreeing to something. The whole row toggles,
/// and screen readers hear it as a checkbox with its label.
class KCheckRow extends StatelessWidget {
  const KCheckRow({super.key, required this.title, required this.value, required this.onChanged, this.subtitle});

  final String title;
  final String? subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final k = context.k;
    final duration = KMotion.of(context, const Duration(milliseconds: 150));
    return MergeSemantics(
      child: Semantics(
        checked: value,
        child: KPressable(
          onTap: () => onChanged(!value),
          haptic: HapticKind.selection,
          pressedScale: 1,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AnimatedContainer(
                  duration: duration,
                  width: 22,
                  height: 22,
                  margin: const EdgeInsets.only(top: 1),
                  decoration: BoxDecoration(
                    color: value ? k.primary : Colors.transparent,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: value ? k.primary : k.placeholder, width: 1.6),
                  ),
                  child: value ? Icon(Icons.check_rounded, size: 16, color: k.onPrimary) : null,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: KText.bodyStrong.copyWith(color: k.ink)),
                      if (subtitle != null) Text(subtitle!, style: KText.caption.copyWith(color: k.muted)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
