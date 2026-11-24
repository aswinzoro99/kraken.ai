import 'package:material_ui/material_ui.dart';

import '../../core/haptics/haptics.dart';
import '../foundation/pressable.dart';
import '../theme/kraken_theme.dart';
import '../tokens/layout.dart';
import '../tokens/typography.dart';

/// A quick-reply or filter chip. Plays a selection haptic.
class KChip extends StatelessWidget {
  const KChip({super.key, required this.label, required this.onTap, this.selected = false, this.icon});

  final String label;
  final VoidCallback? onTap;
  final bool selected;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final k = context.k;
    final fg = selected ? k.onPrimary : k.ink;
    return KPressable(
      onTap: onTap,
      haptic: HapticKind.selection,
      semanticLabel: label,
      excludeChildSemantics: true,
      borderRadius: const BorderRadius.all(KRadius.pill),
      child: Container(
        constraints: const BoxConstraints(minHeight: 36),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: selected ? k.primary : k.background,
          border: Border.all(color: selected ? k.primary : k.line),
          borderRadius: const BorderRadius.all(KRadius.pill),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[Icon(icon, size: 16, color: fg), const SizedBox(width: 6)],
            Flexible(
              child: Text(label, style: KText.label.copyWith(color: fg)),
            ),
          ],
        ),
      ),
    );
  }
}

/// A wrapping row of chips that animates in.
class KChipRow extends StatelessWidget {
  const KChipRow({super.key, required this.children, this.alignment = WrapAlignment.start});

  final List<Widget> children;
  final WrapAlignment alignment;

  @override
  Widget build(BuildContext context) =>
      Wrap(spacing: KSpace.xs, runSpacing: KSpace.xs, alignment: alignment, children: children);
}
