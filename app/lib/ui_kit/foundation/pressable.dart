import 'package:material_ui/material_ui.dart';

import '../../core/haptics/haptics.dart';
import '../tokens/layout.dart';
import 'haptics_scope.dart';

/// The base of every tappable thing in Kraken: a gentle press-down scale,
/// a haptic, keyboard focus and screen-reader semantics in one place.
class KPressable extends StatefulWidget {
  const KPressable({
    super.key,
    required this.child,
    required this.onTap,
    this.onLongPress,
    this.haptic = HapticKind.tap,
    this.semanticLabel,
    this.pressedScale = 0.97,
    this.borderRadius,
    this.enabled = true,
    this.excludeChildSemantics = false,
  });

  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  /// Played on tap. Null for no haptic.
  final HapticKind? haptic;
  final String? semanticLabel;
  final double pressedScale;
  final BorderRadius? borderRadius;
  final bool enabled;
  final bool excludeChildSemantics;

  @override
  State<KPressable> createState() => _KPressableState();
}

class _KPressableState extends State<KPressable> {
  bool _pressed = false;
  bool _focused = false;

  bool get _active => widget.enabled && (widget.onTap != null || widget.onLongPress != null);

  void _setPressed(bool v) {
    if (_pressed != v && mounted) setState(() => _pressed = v);
  }

  void _tap() {
    if (!_active || widget.onTap == null) return;
    if (widget.haptic != null) context.haptic(widget.haptic!);
    widget.onTap!();
  }

  void _longPress() {
    if (!_active || widget.onLongPress == null) return;
    context.haptic(HapticKind.heavy);
    widget.onLongPress!();
  }

  @override
  Widget build(BuildContext context) {
    final duration = KMotion.of(context, KMotion.fast);
    Widget child = AnimatedScale(
      scale: _pressed ? widget.pressedScale : 1,
      duration: duration,
      curve: KMotion.curve,
      child: widget.child,
    );
    if (_focused) {
      child = DecoratedBox(
        position: DecorationPosition.foreground,
        decoration: BoxDecoration(
          border: Border.all(color: Theme.of(context).colorScheme.primary, width: 2),
          borderRadius: widget.borderRadius ?? const BorderRadius.all(KRadius.md),
        ),
        child: child,
      );
    }
    return Semantics(
      button: true,
      enabled: _active,
      label: widget.semanticLabel,
      excludeSemantics: widget.excludeChildSemantics,
      onTap: _active && widget.onTap != null ? _tap : null,
      child: FocusableActionDetector(
        enabled: _active,
        onShowFocusHighlight: (v) => setState(() => _focused = v),
        actions: {ActivateIntent: CallbackAction<ActivateIntent>(onInvoke: (_) => _tap())},
        mouseCursor: _active ? SystemMouseCursors.click : MouseCursor.defer,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          excludeFromSemantics: true,
          onTapDown: _active ? (_) => _setPressed(true) : null,
          onTapUp: _active ? (_) => _setPressed(false) : null,
          onTapCancel: () => _setPressed(false),
          onTap: _active && widget.onTap != null ? _tap : null,
          onLongPress: _active && widget.onLongPress != null ? _longPress : null,
          child: Opacity(opacity: widget.enabled ? 1 : 0.5, child: child),
        ),
      ),
    );
  }
}
