import 'package:material_ui/material_ui.dart';

import '../../core/haptics/haptics.dart';
import '../foundation/pressable.dart';
import '../theme/kraken_theme.dart';
import '../tokens/colors.dart';
import '../tokens/layout.dart';
import '../tokens/typography.dart';

enum KButtonVariant { primary, secondary, ghost, dark, danger }

enum KButtonSize { small, medium, large }

/// Kraken's button. Every press plays a haptic; a loading button ignores
/// taps and shows a spinner so double-submits can't happen.
class KButton extends StatelessWidget {
  const KButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.variant = KButtonVariant.primary,
    this.size = KButtonSize.large,
    this.icon,
    this.loading = false,
    this.expand = false,
    this.haptic = HapticKind.tap,
  });

  const KButton.secondary({
    super.key,
    required this.label,
    required this.onPressed,
    this.size = KButtonSize.large,
    this.icon,
    this.loading = false,
    this.expand = false,
    this.haptic = HapticKind.tap,
  }) : variant = KButtonVariant.secondary;

  const KButton.ghost({
    super.key,
    required this.label,
    required this.onPressed,
    this.size = KButtonSize.medium,
    this.icon,
    this.loading = false,
    this.expand = false,
    this.haptic = HapticKind.tap,
  }) : variant = KButtonVariant.ghost;

  final String label;
  final VoidCallback? onPressed;
  final KButtonVariant variant;
  final KButtonSize size;
  final IconData? icon;
  final bool loading;
  final bool expand;
  final HapticKind haptic;

  @override
  Widget build(BuildContext context) {
    final k = context.k;
    final (bg, fg, border) = _colors(k);
    final height = switch (size) {
      KButtonSize.small => 32.0,
      KButtonSize.medium => 40.0,
      KButtonSize.large => 48.0,
    };
    final textStyle = (size == KButtonSize.small ? KText.caption : KText.label).copyWith(
      color: fg,
      fontWeight: FontWeight.w600,
      fontSize: size == KButtonSize.large ? 15 : 14,
    );
    final content = loading
        ? SizedBox.square(dimension: 18, child: CircularProgressIndicator(strokeWidth: 2, color: fg))
        : Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[Icon(icon, size: 17, color: fg), const SizedBox(width: 6)],
              Flexible(
                child: Text(label, style: textStyle, overflow: TextOverflow.ellipsis),
              ),
            ],
          );
    final button = Container(
      height: height,
      constraints: const BoxConstraints(minWidth: kMinTouch),
      padding: EdgeInsets.symmetric(horizontal: size == KButtonSize.small ? 12 : 18),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: bg,
        border: border == null ? null : Border.all(color: border),
        borderRadius: const BorderRadius.all(KRadius.md),
      ),
      child: content,
    );
    return KPressable(
      onTap: loading ? null : onPressed,
      enabled: onPressed != null,
      haptic: haptic,
      semanticLabel: loading ? '$label, loading' : label,
      excludeChildSemantics: true,
      borderRadius: const BorderRadius.all(KRadius.lg),
      child: expand ? SizedBox(width: double.infinity, child: button) : button,
    );
  }

  (Color, Color, Color?) _colors(KColors k) => switch (variant) {
    KButtonVariant.primary => (k.primary, k.onPrimary, null),
    KButtonVariant.secondary => (k.surfaceMuted, k.ink, null),
    KButtonVariant.ghost => (Colors.transparent, k.primaryText, null),
    KButtonVariant.dark => (k.inverse, k.onInverse, null),
    KButtonVariant.danger => (k.dangerSoft, k.danger, null),
  };
}

/// The 44×44 bordered square buttons in screen headers (search, new group).
class KIconButton extends StatelessWidget {
  const KIconButton({
    super.key,
    required this.icon,
    required this.label,
    required this.onPressed,
    this.bordered = false,
  });

  final IconData icon;

  /// Read by screen readers; icon buttons have no visible text.
  final String label;
  final VoidCallback? onPressed;
  final bool bordered;

  @override
  Widget build(BuildContext context) {
    final k = context.k;
    return KPressable(
      onTap: onPressed,
      semanticLabel: label,
      excludeChildSemantics: true,
      child: Container(
        width: kMinTouch,
        height: kMinTouch,
        decoration: BoxDecoration(
          color: bordered ? k.surface : Colors.transparent,
          border: bordered ? Border.all(color: k.line) : null,
          borderRadius: const BorderRadius.all(KRadius.md),
        ),
        child: Icon(icon, size: 22, color: k.inkSecondary),
      ),
    );
  }
}
