import 'package:material_ui/material_ui.dart';

import '../foundation/k_illustrations.dart';
import '../foundation/pressable.dart';
import '../theme/kraken_theme.dart';
import '../tokens/layout.dart';
import '../tokens/typography.dart';

enum KBannerTone { info, warning, success }

/// A quiet one-line hint: "Connect Gmail to get split suggestions".
class KBanner extends StatelessWidget {
  const KBanner({super.key, required this.child, this.icon, this.onTap, this.tone = KBannerTone.info});

  /// Usually a [Text.rich] so part of it can be bold.
  final Widget child;
  final IconData? icon;
  final VoidCallback? onTap;
  final KBannerTone tone;

  @override
  Widget build(BuildContext context) {
    final k = context.k;
    final (bg, fg, iconColor) = switch (tone) {
      KBannerTone.info => (k.surfaceMuted, k.inkSecondary, k.primaryText),
      KBannerTone.warning => (k.warningSoft, k.warning, k.warning),
      KBannerTone.success => (k.successSoft, k.success, k.success),
    };
    final body = Container(
      padding: const EdgeInsets.symmetric(horizontal: KSpace.md, vertical: KSpace.sm),
      decoration: BoxDecoration(color: bg, borderRadius: const BorderRadius.all(KRadius.md)),
      child: Row(
        children: [
          if (icon != null) ...[Icon(icon, size: 18, color: iconColor), const SizedBox(width: KSpace.sm)],
          Expanded(
            child: DefaultTextStyle(
              style: KText.caption.copyWith(color: fg),
              child: child,
            ),
          ),
          if (onTap != null) Icon(Icons.chevron_right_rounded, size: 18, color: k.muted),
        ],
      ),
    );
    return onTap == null ? body : KPressable(onTap: onTap, pressedScale: 0.99, child: body);
  }
}

/// Shown when a list has nothing in it yet. Says what goes here and how to
/// add the first one, under a simple line [illustration] (or a small [icon]).
class KEmptyState extends StatelessWidget {
  const KEmptyState({super.key, this.icon, this.illustration, required this.title, required this.message, this.action})
    : assert(icon != null || illustration != null);

  final IconData? icon;

  /// One of [KIllustrations]; shown on a soft disc.
  final String? illustration;
  final String title;
  final String message;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final k = context.k;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: KSpace.xxxl, vertical: KSpace.xxl),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (illustration case final art?)
            Container(
              width: 128,
              height: 128,
              alignment: Alignment.center,
              decoration: BoxDecoration(color: k.surfaceMuted, shape: BoxShape.circle),
              child: KIllustration(art),
            )
          else
            Icon(icon, size: 28, color: k.muted),
          SizedBox(height: illustration == null ? KSpace.md : KSpace.lg),
          Text(
            title,
            textAlign: TextAlign.center,
            style: KText.heading.copyWith(color: k.ink),
          ),
          const SizedBox(height: KSpace.xxs),
          Text(
            message,
            textAlign: TextAlign.center,
            style: KText.caption.copyWith(color: k.muted),
          ),
          if (action != null) ...[const SizedBox(height: KSpace.lg), action!],
        ],
      ),
    );
  }
}
