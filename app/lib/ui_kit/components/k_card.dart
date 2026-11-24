import 'package:material_ui/material_ui.dart';

import '../foundation/pressable.dart';
import '../theme/kraken_theme.dart';
import '../tokens/layout.dart';
import '../tokens/typography.dart';

/// A quiet surface for the rare block that must stand apart. Most lists
/// should use [KGroupedList], which has no box at all.
class KCard extends StatelessWidget {
  const KCard({super.key, required this.child, this.padding = EdgeInsets.zero});

  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) => Container(
    padding: padding,
    clipBehavior: Clip.antiAlias,
    decoration: BoxDecoration(color: context.k.surfaceMuted, borderRadius: const BorderRadius.all(KRadius.lg)),
    child: child,
  );
}

/// Rows separated by hairlines, sitting directly on the page.
class KGroupedList extends StatelessWidget {
  const KGroupedList({super.key, required this.children, this.indent = 0});

  final List<Widget> children;

  /// Where dividers start, e.g. past a leading avatar.
  final double indent;

  @override
  Widget build(BuildContext context) {
    final k = context.k;
    return Column(
      children: [
        for (var i = 0; i < children.length; i++) ...[
          if (i > 0) Divider(height: 1, thickness: 1, indent: indent, color: k.divider),
          children[i],
        ],
      ],
    );
  }
}

/// A list row: leading avatar, title and subtitle, trailing value.
class KListRow extends StatelessWidget {
  const KListRow({
    super.key,
    required this.title,
    this.subtitle,
    this.leading,
    this.trailing,
    this.onTap,
    this.semanticLabel,
  });

  final String title;
  final String? subtitle;
  final Widget? leading;
  final Widget? trailing;
  final VoidCallback? onTap;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final k = context.k;
    final row = Padding(
      padding: const EdgeInsets.symmetric(vertical: KSpace.md),
      child: Row(
        children: [
          if (leading != null) ...[leading!, const SizedBox(width: KSpace.md)],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: KText.bodyStrong.copyWith(color: k.ink),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (subtitle != null && subtitle!.isNotEmpty)
                  Text(
                    subtitle!,
                    style: KText.caption.copyWith(color: k.muted),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
          ),
          if (trailing != null) ...[const SizedBox(width: KSpace.md), trailing!],
        ],
      ),
    );
    if (onTap == null) return row;
    return KPressable(
      onTap: onTap,
      pressedScale: 0.99,
      semanticLabel: semanticLabel,
      child: ColoredBox(color: k.background, child: row),
    );
  }
}

/// A small label above a list ("Your groups"), with an optional action.
class KSectionHeader extends StatelessWidget {
  const KSectionHeader({super.key, required this.title, this.actionLabel, this.onAction});

  final String title;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final k = context.k;
    return SizedBox(
      height: 32,
      child: Row(
        children: [
          Expanded(
            child: Semantics(
              header: true,
              child: Text(title, style: KText.overline.copyWith(color: k.muted)),
            ),
          ),
          if (actionLabel != null)
            KPressable(
              onTap: onAction,
              semanticLabel: actionLabel,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: KSpace.xs),
                child: Text(actionLabel!, style: KText.overline.copyWith(color: k.primaryText)),
              ),
            ),
        ],
      ),
    );
  }
}
