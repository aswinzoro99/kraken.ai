import 'dart:ui' show ImageFilter;

import 'package:material_ui/material_ui.dart';

/// Liquid Glass: a floating material that lets the content behind it show
/// through, sharpened rather than smeared. A light blur with boosted colour,
/// a bright specular rim where light catches the edge, a soft sheen across
/// the top, and a shadow that lifts it off the page.
///
/// With Increase Contrast on it becomes a solid surface with a defined edge.
class KLiquidGlass extends StatelessWidget {
  const KLiquidGlass({
    super.key,
    required this.child,
    this.borderRadius = const BorderRadius.all(Radius.circular(999)),
    this.elevated = true,
  });

  final Widget child;
  final BorderRadius borderRadius;

  /// Floating pieces cast a shadow.
  final bool elevated;

  static List<double> _saturation(double s) {
    const r = 0.2126, g = 0.7152, b = 0.0722;
    final ir = (1 - s) * r, ig = (1 - s) * g, ib = (1 - s) * b;
    return [ir + s, ig, ib, 0, 0, ir, ig + s, ib, 0, 0, ir, ig, ib + s, 0, 0, 0, 0, 0, 1, 0];
  }

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final solid = MediaQuery.maybeHighContrastOf(context) ?? false;
    final fill = solid
        ? (dark ? const Color(0xFF1C1C1E) : Colors.white)
        : (dark ? const Color(0xFF26282E).withValues(alpha: 0.55) : Colors.white.withValues(alpha: 0.52));

    final glass = ClipRRect(
      borderRadius: borderRadius,
      child: BackdropFilter(
        filter: solid
            ? ImageFilter.blur()
            : ImageFilter.compose(
                outer: ImageFilter.blur(sigmaX: 9, sigmaY: 9),
                inner: ColorFilter.matrix(_saturation(1.8)),
              ),
        child: Stack(
          children: [
            Positioned.fill(child: ColoredBox(color: fill)),
            child,
            // Light falling across the top of the glass.
            if (!solid)
              Positioned.fill(
                child: IgnorePointer(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.center,
                        colors: [
                          Colors.white.withValues(alpha: dark ? 0.08 : 0.32),
                          Colors.white.withValues(alpha: 0),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            // The specular rim.
            Positioned.fill(
              child: IgnorePointer(
                child: CustomPaint(
                  painter: _RimPainter(borderRadius, dark: dark, solid: solid),
                ),
              ),
            ),
          ],
        ),
      ),
    );
    if (!elevated) return glass;
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: borderRadius,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: dark ? 0.45 : 0.12),
            blurRadius: 28,
            offset: const Offset(0, 10),
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: dark ? 0.25 : 0.05),
            blurRadius: 3,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: glass,
    );
  }
}

/// A hairline edge, brightest where light would hit (top-left), fading
/// along the sides, with a softer return at the bottom-right.
class _RimPainter extends CustomPainter {
  _RimPainter(this.radius, {required this.dark, required this.solid});
  final BorderRadius radius;
  final bool dark;
  final bool solid;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final rrect = radius.toRRect(rect).deflate(0.5);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = solid ? 1 : 1.2;
    if (solid) {
      paint.color = dark ? const Color(0xFF545458) : const Color(0xFFC6C6C8);
    } else {
      final a = dark ? 0.55 : 1.0;
      paint.shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Colors.white.withValues(alpha: 0.9 * a),
          Colors.white.withValues(alpha: 0.25 * a),
          Colors.white.withValues(alpha: 0.08 * a),
          Colors.white.withValues(alpha: 0.5 * a),
        ],
        stops: const [0, 0.35, 0.65, 1],
      ).createShader(rect);
    }
    canvas.drawRRect(rrect, paint);
  }

  @override
  bool shouldRepaint(_RimPainter old) => old.dark != dark || old.solid != solid || old.radius != radius;
}
