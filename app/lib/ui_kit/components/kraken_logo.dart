import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

import '../theme/kraken_theme.dart';
import '../tokens/typography.dart';

/// The Kraken octopus ("Even split"): a round head on three equal
/// tentacles, one bill shared evenly. Drawn as vectors so it is sharp from
/// the 28px chat avatar to the 1024px store icon.
///
/// Geometry is in a 126 × 100 unit box: a domed head 90 units wide, two
/// eyes cut out of it, a straight middle tentacle and two hooked outer
/// tentacles, all 14 units thick with round ends.
abstract final class KrakenGlyphGeometry {
  static const width = 126.0;
  static const height = 100.0;
  static const aspect = width / height;

  /// How wide the glyph sits inside the square app icon.
  static const iconWidthRatio = 0.565;

  /// Corner radius of the app-icon tile, as a share of its side.
  static const tileRadiusRatio = 0.27;
}

class _GlyphPainter extends CustomPainter {
  _GlyphPainter(this.color);
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final s = math.min(size.width / KrakenGlyphGeometry.width, size.height / KrakenGlyphGeometry.height);
    final dx = (size.width - KrakenGlyphGeometry.width * s) / 2;
    final dy = (size.height - KrakenGlyphGeometry.height * s) / 2;
    canvas
      ..save()
      ..translate(dx, dy)
      ..scale(s);

    final fill = Paint()
      ..color = color
      ..isAntiAlias = true;

    // Head: a dome (semicircle on a short straight band) with the eyes
    // punched out, so the glyph works on any background.
    final head = Path()
      ..fillType = PathFillType.evenOdd
      ..addRRect(
        RRect.fromLTRBAndCorners(
          18,
          0,
          108,
          52,
          topLeft: const Radius.circular(45),
          topRight: const Radius.circular(45),
        ),
      )
      ..addOval(Rect.fromCircle(center: const Offset(47.5, 30), radius: 6))
      ..addOval(Rect.fromCircle(center: const Offset(78.5, 30), radius: 6));
    canvas.drawPath(head, fill);

    final stroke = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 14
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..isAntiAlias = true;

    // Middle tentacle: straight down.
    canvas.drawLine(const Offset(63, 46), const Offset(63, 92), stroke);

    // Outer tentacles: down, then a hook curling outward and up.
    final left = Path()
      ..moveTo(31, 46)
      ..lineTo(31, 72)
      ..arcTo(Rect.fromCircle(center: const Offset(19, 72), radius: 12), 0, math.pi, false)
      ..lineTo(7, 62);
    final right = Path()
      ..moveTo(95, 46)
      ..lineTo(95, 72)
      ..arcTo(Rect.fromCircle(center: const Offset(107, 72), radius: 12), math.pi, -math.pi, false)
      ..lineTo(119, 62);
    canvas
      ..drawPath(left, stroke)
      ..drawPath(right, stroke)
      ..restore();
  }

  @override
  bool shouldRepaint(_GlyphPainter old) => old.color != color;
}

/// The bare octopus in one colour. [height] sets the size; width follows.
class KrakenGlyph extends StatelessWidget {
  const KrakenGlyph({super.key, this.height = 24, this.color});

  final double height;

  /// Defaults to the ink colour of the current theme.
  final Color? color;

  @override
  Widget build(BuildContext context) => CustomPaint(
    size: Size(height * KrakenGlyphGeometry.aspect, height),
    painter: _GlyphPainter(color ?? context.k.ink),
  );
}

/// The app-icon tile: a white octopus on Kraken blue. Used for the splash,
/// Kraken's chat avatar and anywhere the app needs a badge.
class KrakenMark extends StatelessWidget {
  const KrakenMark({super.key, this.size = 34, this.background, this.foreground});

  final double size;
  final Color? background;
  final Color? foreground;

  @override
  Widget build(BuildContext context) {
    final k = context.k;
    final glyphWidth = size * KrakenGlyphGeometry.iconWidthRatio;
    return Semantics(
      label: 'Kraken',
      image: true,
      child: Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: background ?? k.primary,
          borderRadius: BorderRadius.circular(size * KrakenGlyphGeometry.tileRadiusRatio),
        ),
        child: KrakenGlyph(height: glyphWidth / KrakenGlyphGeometry.aspect, color: foreground ?? k.onPrimary),
      ),
    );
  }
}

/// The lockup: octopus beside the lower-case "kraken" wordmark, both in ink.
class KrakenLogo extends StatelessWidget {
  const KrakenLogo({super.key, this.fontSize = 22, this.glyphHeight, this.subtitle});

  final double fontSize;

  /// Defaults to a little taller than the wordmark, as in the lockup.
  final double? glyphHeight;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    final k = context.k;
    return Semantics(
      label: 'Kraken',
      container: true,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          ExcludeSemantics(child: KrakenGlyph(height: glyphHeight ?? fontSize * 1.1)),
          SizedBox(width: fontSize * 0.45),
          ExcludeSemantics(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'kraken',
                  style: KText.title.copyWith(fontSize: fontSize, color: k.ink, letterSpacing: -0.02 * fontSize),
                ),
                if (subtitle != null) Text(subtitle!, style: KText.small.copyWith(color: k.muted)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
