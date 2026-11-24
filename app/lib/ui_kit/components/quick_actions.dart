import 'dart:math' as math;

import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/gestures.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/haptics/haptics.dart';
import '../foundation/haptics_scope.dart';
import '../foundation/liquid_glass.dart';
import '../foundation/pressable.dart';
import '../theme/kraken_theme.dart';
import '../tokens/motion.dart';
import '../tokens/typography.dart';

/// Something the quick-actions menu offers.
final class KQuickAction {
  const KQuickAction({required this.id, required this.label, required this.description, required this.icon});

  /// Stable id for analytics, e.g. `scan`.
  final String id;
  final String label;
  final String description;
  final IconData icon;
}

enum _Talk { idle, listening, cancel }

/// The round glass + that sits beside the tab bar on every tab.
///
/// * Tap: a glass menu grows out of the button and the + turns into ×.
/// * Press and hold: talk. A capsule shows Kraken listening; release to
///   add, slide away to cancel.
class KQuickActionButton extends StatefulWidget {
  const KQuickActionButton({
    super.key,
    required this.actions,
    required this.onAction,
    required this.onTalk,
    this.onOpened,
  });

  final List<KQuickAction> actions;
  final ValueChanged<KQuickAction> onAction;

  /// A hold ended: `true` when released to add, `false` when cancelled.
  final ValueChanged<bool> onTalk;
  final VoidCallback? onOpened;

  /// How far the finger must slide away to cancel a hold.
  static const cancelDistance = 70.0;

  @override
  State<KQuickActionButton> createState() => _KQuickActionButtonState();
}

class _KQuickActionButtonState extends State<KQuickActionButton> {
  final _talk = ValueNotifier(_Talk.idle);
  final _curve = KSpringCurve(KSpring.standard);
  OverlayEntry? _talkEntry;
  bool _pressed = false;

  bool get _reduceMotion => MediaQuery.maybeDisableAnimationsOf(context) ?? false;

  Rect _rect() {
    final box = context.findRenderObject()! as RenderBox;
    return box.localToGlobal(Offset.zero) & box.size;
  }

  Future<void> _open() async {
    HapticsScope.play(context, HapticKind.tap);
    widget.onOpened?.call();
    final anchor = _rect();
    final picked = await showGeneralDialog<KQuickAction>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Close quick actions',
      barrierColor: Colors.black.withValues(alpha: 0.18),
      transitionDuration: Duration(milliseconds: _reduceMotion ? 150 : 450),
      pageBuilder: (context, animation, _) => _Menu(anchor: anchor, actions: widget.actions, animation: animation),
      transitionBuilder: (context, animation, secondary, child) => child,
    );
    if (picked != null && mounted) widget.onAction(picked);
  }

  void _holdStart(LongPressStartDetails _) {
    HapticsScope.play(context, HapticKind.heavy);
    setState(() => _pressed = false);
    _talk.value = _Talk.listening;
    final anchor = _rect();
    _talkEntry = OverlayEntry(
      builder: (_) => _TalkCapsule(anchor: anchor, state: _talk),
    );
    Overlay.of(context, rootOverlay: true).insert(_talkEntry!);
  }

  void _holdMove(LongPressMoveUpdateDetails d) {
    final next = d.offsetFromOrigin.distance > KQuickActionButton.cancelDistance ? _Talk.cancel : _Talk.listening;
    if (next == _talk.value) return;
    HapticsScope.play(context, next == _Talk.cancel ? HapticKind.warning : HapticKind.selection);
    _talk.value = next;
  }

  void _holdEnd() {
    if (_talk.value == _Talk.idle) return;
    final completed = _talk.value == _Talk.listening;
    _talkEntry?.remove();
    _talkEntry = null;
    _talk.value = _Talk.idle;
    HapticsScope.play(context, completed ? HapticKind.tap : HapticKind.selection);
    widget.onTalk(completed);
  }

  @override
  void dispose() {
    _talkEntry?.remove();
    _talk.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final k = context.k;
    final duration = _reduceMotion ? Duration.zero : const Duration(milliseconds: 300);
    return Semantics(
      button: true,
      label: 'Quick actions',
      hint: 'Double tap for actions. Press and hold to talk.',
      excludeSemantics: true,
      onTap: _open,
      onLongPress: () => widget.onTalk(true),
      child: RawGestureDetector(
        gestures: {
          TapGestureRecognizer: GestureRecognizerFactoryWithHandlers<TapGestureRecognizer>(
            TapGestureRecognizer.new,
            (r) => r
              ..onTapDown = ((_) => setState(() => _pressed = true))
              ..onTapCancel = (() => setState(() => _pressed = false))
              ..onTapUp = ((_) => setState(() => _pressed = false))
              ..onTap = _open,
          ),
          // A short hold starts talking; it shouldn't feel like waiting.
          LongPressGestureRecognizer: GestureRecognizerFactoryWithHandlers<LongPressGestureRecognizer>(
            () => LongPressGestureRecognizer(duration: const Duration(milliseconds: 280)),
            (r) => r
              ..onLongPressStart = _holdStart
              ..onLongPressMoveUpdate = _holdMove
              ..onLongPressEnd = ((_) => _holdEnd())
              ..onLongPressCancel = _holdEnd,
          ),
        },
        child: ValueListenableBuilder<_Talk>(
          valueListenable: _talk,
          builder: (context, talk, _) {
            final talking = talk != _Talk.idle;
            return LayoutBuilder(
              builder: (context, c) {
                // Fills the square it's given (it shrinks with the tab bar).
                final size = c.biggest.shortestSide.isFinite ? c.biggest.shortestSide : 58.0;
                return AnimatedScale(
                  scale: talking ? 1.12 : (_pressed ? 0.92 : 1),
                  duration: duration,
                  curve: _curve,
                  child: SizedBox.square(
                    dimension: size,
                    child: KLiquidGlass(
                      child: Center(
                        child: AnimatedSwitcher(
                          duration: duration,
                          child: talking
                              ? Container(
                                  key: const ValueKey('mic'),
                                  width: size - 12,
                                  height: size - 12,
                                  decoration: BoxDecoration(
                                    color: talk == _Talk.cancel ? k.danger : k.primary,
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(Icons.mic_rounded, color: k.onPrimary, size: size * 0.42),
                                )
                              : Icon(
                                  Icons.add_rounded,
                                  key: const ValueKey('plus'),
                                  size: size * 0.48,
                                  color: k.primary,
                                ),
                        ),
                      ),
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}

/// The menu, anchored to the button it grew out of.
class _Menu extends StatelessWidget {
  const _Menu({required this.anchor, required this.actions, required this.animation});
  final Rect anchor;
  final List<KQuickAction> actions;
  final Animation<double> animation;

  @override
  Widget build(BuildContext context) {
    final k = context.k;
    final size = MediaQuery.sizeOf(context);
    final reduce = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    final grow = CurvedAnimation(
      parent: animation,
      curve: reduce ? Curves.easeOut : KSpringCurve(KSpring.standard),
      reverseCurve: Curves.easeInCubic,
    );
    return Material(
      type: MaterialType.transparency,
      child: Stack(
        children: [
          Positioned(
            right: size.width - anchor.right,
            bottom: size.height - anchor.top + 12,
            child: FadeTransition(
              opacity: animation,
              // Grows out of the button and shrinks back into it.
              child: ScaleTransition(
                alignment: Alignment.bottomRight,
                scale: reduce ? const AlwaysStoppedAnimation(1) : Tween(begin: 0.55, end: 1.0).animate(grow),
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: math.min(300, size.width - 32)),
                  child: KLiquidGlass(
                    borderRadius: BorderRadius.circular(28),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: IntrinsicWidth(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [for (final a in actions) _ActionRow(action: a)],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          // The same button, now a close: + turns into ×.
          Positioned.fromRect(
            rect: anchor,
            child: Semantics(
              button: true,
              label: 'Close quick actions',
              excludeSemantics: true,
              child: GestureDetector(
                onTap: () => Navigator.of(context).pop(),
                child: KLiquidGlass(
                  child: Center(
                    child: RotationTransition(
                      turns: Tween(begin: 0.0, end: 0.125).animate(grow),
                      child: Icon(Icons.add_rounded, size: anchor.shortestSide * 0.48, color: k.primary),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionRow extends StatelessWidget {
  const _ActionRow({required this.action});
  final KQuickAction action;

  @override
  Widget build(BuildContext context) {
    final k = context.k;
    return KPressable(
      onTap: () => Navigator.of(context).pop(action),
      pressedScale: 0.97,
      semanticLabel: '${action.label}. ${action.description}',
      excludeChildSemantics: true,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 10, 20, 10),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(color: k.primary.withValues(alpha: 0.12), shape: BoxShape.circle),
              child: Icon(action.icon, size: 20, color: k.primary),
            ),
            const SizedBox(width: 12),
            Flexible(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(action.label, style: KText.bodyStrong.copyWith(color: k.ink)),
                  Text(action.description, style: KText.small.copyWith(color: k.inkSecondary)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// "Listening…" while the button is held.
class _TalkCapsule extends StatelessWidget {
  const _TalkCapsule({required this.anchor, required this.state});
  final Rect anchor;
  final ValueListenable<_Talk> state;

  @override
  Widget build(BuildContext context) {
    final k = context.k;
    final size = MediaQuery.sizeOf(context);
    final reduce = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    return Positioned(
      left: 16,
      right: 16,
      bottom: size.height - anchor.top + 16,
      child: Material(
        type: MaterialType.transparency,
        child: Center(
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: 1),
            duration: Duration(milliseconds: reduce ? 0 : 400),
            curve: KSpringCurve(KSpring.standard),
            builder: (context, t, child) => Opacity(
              opacity: t.clamp(0, 1),
              child: Transform.scale(scale: 0.9 + 0.1 * t, child: child),
            ),
            child: ValueListenableBuilder<_Talk>(
              valueListenable: state,
              builder: (context, talk, _) {
                final cancel = talk == _Talk.cancel;
                return Semantics(
                  liveRegion: true,
                  label: cancel ? 'Release to cancel' : 'Listening. Release to add, slide away to cancel.',
                  excludeSemantics: true,
                  child: KLiquidGlass(
                    borderRadius: BorderRadius.circular(30),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(18, 12, 22, 12),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _Waveform(active: !cancel, color: cancel ? k.danger : k.primary),
                          const SizedBox(width: 14),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                cancel ? 'Release to cancel' : 'Listening…',
                                style: KText.bodyStrong.copyWith(color: cancel ? k.danger : k.ink),
                              ),
                              Text(
                                cancel ? 'Slide back to keep talking' : 'Release to add · slide away to cancel',
                                style: KText.small.copyWith(color: k.inkSecondary),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

/// A small live level meter. Still under Reduce Motion.
class _Waveform extends StatefulWidget {
  const _Waveform({required this.active, required this.color});
  final bool active;
  final Color color;

  @override
  State<_Waveform> createState() => _WaveformState();
}

class _WaveformState extends State<_Waveform> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1100));

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final reduce = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    reduce ? _c.stop() : _c.repeat();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 26,
    child: AnimatedBuilder(
      animation: _c,
      builder: (context, _) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < 5; i++) ...[
            if (i > 0) const SizedBox(width: 3),
            Container(
              width: 3.5,
              height: widget.active ? 6 + 18 * (0.5 + 0.5 * math.sin(_c.value * 2 * math.pi + i * 0.9)) : 6,
              decoration: BoxDecoration(color: widget.color, borderRadius: BorderRadius.circular(2)),
            ),
          ],
        ],
      ),
    ),
  );
}
