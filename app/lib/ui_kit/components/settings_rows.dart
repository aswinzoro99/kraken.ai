import 'package:material_ui/material_ui.dart';

import '../../core/haptics/haptics.dart';
import '../foundation/haptics_scope.dart';
import '../foundation/pressable.dart';
import '../theme/kraken_theme.dart';
import '../tokens/layout.dart';
import '../tokens/typography.dart';

/// A settings row with a switch. The whole row toggles.
class KSwitchRow extends StatelessWidget {
  const KSwitchRow({super.key, required this.title, required this.value, required this.onChanged, this.subtitle});

  final String title;
  final String? subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final k = context.k;
    void toggle(bool v) {
      context.haptic(HapticKind.selection);
      onChanged(v);
    }

    return MergeSemantics(
      child: KPressable(
        onTap: () => toggle(!value),
        haptic: null,
        pressedScale: 1,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: KSpace.sm),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: KText.bodyStrong.copyWith(color: k.ink)),
                    if (subtitle != null) Text(subtitle!, style: KText.caption.copyWith(color: k.muted)),
                  ],
                ),
              ),
              Transform.scale(
                scale: 0.85,
                alignment: Alignment.centerRight,
                child: Switch(value: value, onChanged: toggle),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A tappable settings row with a value and chevron.
class KNavRow extends StatelessWidget {
  const KNavRow({super.key, required this.title, this.value, this.icon, this.onTap, this.destructive = false});

  final String title;
  final String? value;
  final IconData? icon;
  final VoidCallback? onTap;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final k = context.k;
    final color = destructive ? k.danger : k.ink;
    return KPressable(
      onTap: onTap,
      pressedScale: 0.985,
      semanticLabel: value == null ? title : '$title, $value',
      excludeChildSemantics: true,
      child: ColoredBox(
        color: k.background,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 14),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 24),
            child: Row(
              children: [
                if (icon != null) ...[
                  Icon(icon, size: 20, color: destructive ? k.danger : k.muted),
                  const SizedBox(width: 14),
                ],
                Expanded(
                  child: Text(title, style: KText.bodyStrong.copyWith(color: color)),
                ),
                if (value != null)
                  Flexible(
                    child: Text(
                      value!,
                      textAlign: TextAlign.end,
                      style: KText.caption.copyWith(color: k.muted),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                if (onTap != null && !destructive) ...[
                  const SizedBox(width: KSpace.xxs),
                  Icon(Icons.chevron_right_rounded, size: 20, color: k.line),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
