import 'dart:math' as math;
import 'dart:ui' show lerpDouble;

import 'package:flutter/physics.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/haptics/haptics.dart';
import '../foundation/haptics_scope.dart';
import '../foundation/k_icons.dart';
import '../foundation/liquid_glass.dart';
import '../theme/kraken_theme.dart';
import '../tokens/motion.dart';
import '../tokens/typography.dart';
import 'k_avatar.dart';

final class KNavItem {
  /// A tab drawn with one of Kraken's tab icons.
  const KNavItem({required this.label, required KTabIcon this.icon}) : avatarName = null;

  /// The profile tab: the person's avatar (their initial, until there are
  /// photos) instead of an icon. A blank [name] shows a generic person.
  const KNavItem.avatar({required this.label, required String name}) : avatarName = name, icon = null;

  /// Not shown; read out by screen readers.
  final String label;
  final KTabIcon? icon;
  final String? avatarName;
}

/// The tab bar: a floating Liquid Glass capsule of icons with no labels,
/// in the style of Instagram on iOS. Idle tabs show the outline icon in
/// grey; the selected tab shows the filled icon in blue, on a pill that
/// springs from tab to tab. Drag along the bar and the pill follows the
/// finger, ticking as it crosses each tab; let go and it lands where the
/// flick was heading.
///
/// [minimized] (scrolling down) shrinks the whole bar, and the [trailing]
/// control with it; every tab stays visible and tappable. The shell sets
/// `extendBody` so content runs under the glass.
class KBottomNav extends StatefulWidget {
  const KBottomNav({
    super.key,
    required this.items,
    required this.selectedIndex,
    required this.onSelected,
    this.trailing,
    this.minimized = false,
  });

  final List<KNavItem> items;
  final int selectedIndex;
  final ValueChanged<int> onSelected;

  /// A separate glass control beside the capsule (quick actions). It is
  /// given a square to fill, which shrinks with the bar.
  final Widget? trailing;
  final bool minimized;

  /// Bar height at full size and minimised.
  static const height = 58.0;
  static const minimizedHeight = 46.0;

  /// Finds the capsule, for tests.
  static const capsuleKey = ValueKey('k-tab-capsule');

  @override
  State<KBottomNav> createState() => _KBottomNavState();
}

class _KBottomNavState extends State<KBottomNav> with SingleTickerProviderStateMixin {
  late final AnimationController _lens = AnimationController.unbounded(
    vsync: this,
    value: widget.selectedIndex.toDouble(),
  );
  final _curve = KSpringCurve(KSpring.standard);
  bool _dragging = false;
  int _hover = -1;
  double _slot = 1;

  int get _n => widget.items.length;
  bool get _reduceMotion => MediaQuery.maybeDisableAnimationsOf(context) ?? false;

  @override
  void didUpdateWidget(KBottomNav old) {
    super.didUpdateWidget(old);
    if (old.selectedIndex != widget.selectedIndex && !_dragging) _springTo(widget.selectedIndex, KSpring.snappy);
  }

  @override
  void dispose() {
    _lens.dispose();
    super.dispose();
  }

  void _springTo(int index, SpringDescription spring, {double velocity = 0}) {
    if (_reduceMotion) {
      _lens.value = index.toDouble();
      return;
    }
    // From wherever the pill is now, so a new tap mid-flight redirects it.
    _lens.animateWith(SpringSimulation(spring, _lens.value, index.toDouble(), velocity));
  }

  void _tap(int i) {
    HapticsScope.play(context, HapticKind.selection);
    _springTo(i, KSpring.snappy);
    widget.onSelected(i);
  }

  void _dragStart(DragStartDetails d) {
    _lens.stop();
    setState(() {
      _dragging = true;
      _hover = widget.selectedIndex;
    });
    _follow(d.localPosition.dx);
  }

  void _follow(double dx) {
    final max = (_n - 1).toDouble();
    var at = dx / _slot - 0.5;
    // Past either end the pill resists instead of stopping dead.
    if (at < 0) at = -KSpring.rubberband(-at, 1);
    if (at > max) at = max + KSpring.rubberband(at - max, 1);
    _lens.value = at;
    final nearest = at.round().clamp(0, _n - 1);
    if (nearest != _hover) {
      HapticsScope.play(context, HapticKind.selection);
      setState(() => _hover = nearest);
    }
  }

  void _dragEnd(DragEndDetails d) {
    final vx = d.velocity.pixelsPerSecond.dx;
    // Aim for where the flick was heading, not where the finger let go.
    final landing = _lens.value + KSpring.project(vx, decelerationRate: 0.99) / _slot;
    final target = landing.round().clamp(0, _n - 1);
    setState(() {
      _dragging = false;
      _hover = -1;
    });
    _springTo(target, KSpring.momentum, velocity: vx / _slot);
    if (target != widget.selectedIndex) widget.onSelected(target);
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.paddingOf(context).bottom;
    const full = KBottomNav.height;
    const small = KBottomNav.minimizedHeight;
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 6, 16, bottom > 0 ? bottom - 4 : 14),
      child: SizedBox(
        // The slot keeps its full height; the bar shrinks down into it.
        height: full,
        child: LayoutBuilder(
          builder: (context, c) => TweenAnimationBuilder<double>(
            tween: Tween(end: widget.minimized ? 1 : 0),
            duration: _reduceMotion ? Duration.zero : const Duration(milliseconds: 500),
            curve: _curve,
            builder: (context, t, _) {
              final barHeight = lerpDouble(full, small, t)!;
              final button = widget.trailing == null ? 0.0 : barHeight;
              final gap = widget.trailing == null ? 0.0 : lerpDouble(10, 8, t)!;
              final widest = c.maxWidth - (widget.trailing == null ? 0 : full + 10);
              final narrowest = math.min(widest, _n * 44.0 + 8);
              final width = lerpDouble(widest, narrowest, t)!;
              return Row(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  SizedBox(
                    key: KBottomNav.capsuleKey,
                    width: width,
                    height: barHeight,
                    child: KLiquidGlass(child: _tabs(width, barHeight, t)),
                  ),
                  if (widget.trailing != null) ...[
                    SizedBox(width: gap),
                    SizedBox.square(dimension: button, child: widget.trailing),
                  ],
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _tabs(double width, double height, double t) {
    _slot = width / _n;
    final active = _dragging ? _hover : widget.selectedIndex;
    final inset = height * 0.09;
    // The icons are drawn at 24 pt; they shrink to 20 with the bar.
    final iconSize = lerpDouble(24, 20, t)!;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onHorizontalDragStart: _dragStart,
      onHorizontalDragUpdate: (d) => _follow(d.localPosition.dx),
      onHorizontalDragEnd: _dragEnd,
      child: Stack(
        children: [
          AnimatedBuilder(
            animation: _lens,
            builder: (context, child) => Positioned(
              left: _lens.value * _slot + inset,
              top: inset,
              bottom: inset,
              width: _slot - inset * 2,
              child: child!,
            ),
            child: AnimatedScale(
              // The pill swells while it's being dragged, like a droplet.
              scale: _dragging ? 1.1 : 1,
              duration: _reduceMotion ? Duration.zero : const Duration(milliseconds: 250),
              curve: _curve,
              child: const _Pill(),
            ),
          ),
          Row(
            children: [
              for (var i = 0; i < _n; i++)
                Expanded(
                  child: _TabItem(item: widget.items[i], selected: i == active, size: iconSize, onTap: () => _tap(i)),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// The pill behind the selected tab.
class _Pill extends StatelessWidget {
  const _Pill();

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(color: context.k.tabPill, borderRadius: BorderRadius.circular(999)),
  );
}

class _TabItem extends StatelessWidget {
  const _TabItem({required this.item, required this.selected, required this.size, required this.onTap});
  final KNavItem item;
  final bool selected;
  final double size;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final icon = item.icon;
    return Semantics(
      button: true,
      selected: selected,
      label: item.label,
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Center(
          child: icon == null
              ? _ProfileGlyph(name: item.avatarName ?? '', size: size + 4, selected: selected)
              : _TabGlyph(icon: icon, size: size, selected: selected),
        ),
      ),
    );
  }
}

/// The outline icon in grey, cross-fading to the filled icon in blue when
/// the tab is selected. Both stay loaded, so switching never flickers. The
/// fade isn't movement, so it stays under Reduce Motion.
class _TabGlyph extends StatelessWidget {
  const _TabGlyph({required this.icon, required this.size, required this.selected});
  final KTabIcon icon;
  final double size;
  final bool selected;

  static const _fade = Duration(milliseconds: 180);

  @override
  Widget build(BuildContext context) {
    final k = context.k;
    return SizedBox.square(
      dimension: size,
      child: Stack(
        fit: StackFit.expand,
        children: [
          AnimatedOpacity(
            opacity: selected ? 0 : 1,
            duration: _fade,
            child: KSvgIcon(icon.outline, color: k.tabIdle, size: size),
          ),
          AnimatedOpacity(
            opacity: selected ? 1 : 0,
            duration: _fade,
            child: KSvgIcon(icon.filled, color: k.tabSelected, size: size),
          ),
        ],
      ),
    );
  }
}

/// The profile tab: the person's initial in a circle about the size of an
/// icon, in the tab colours, ringed when selected. Instagram uses the
/// profile photo here; Kraken will too once there are photos.
class _ProfileGlyph extends StatelessWidget {
  const _ProfileGlyph({required this.name, required this.size, required this.selected});
  final String name;
  final double size;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final k = context.k;
    final color = selected ? k.tabSelected : k.tabIdle;
    return Container(
      width: size,
      height: size,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: selected ? k.tabSelected : Colors.transparent, width: 1.6),
      ),
      child: Container(
        alignment: Alignment.center,
        decoration: BoxDecoration(color: k.surfaceMuted, shape: BoxShape.circle),
        child: name.trim().isEmpty
            ? Icon(Icons.person_rounded, size: size * 0.55, color: color)
            : Text(
                KAvatar.initialsOf(name).characters.first,
                style: KText.label.copyWith(
                  color: color,
                  fontSize: size * 0.42,
                  fontWeight: FontWeight.w600,
                  height: 1,
                ),
              ),
      ),
    );
  }
}
