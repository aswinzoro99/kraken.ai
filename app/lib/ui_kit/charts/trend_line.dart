import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

import '../../core/haptics/haptics.dart';
import '../foundation/pressable.dart';
import '../theme/kraken_theme.dart';
import '../tokens/layout.dart';
import 'trend_bars.dart';

/// The same months as [KTrendBars], as a line: a 2 px line over a soft
/// area, a ring marker on each month, and a guide down from the selected
/// month, whose marker is filled and larger. Tap a month to select it. The
/// line draws in from the left when it appears.
class KTrendLine extends StatelessWidget {
  const KTrendLine({super.key, required this.points, required this.selected, this.onSelect, this.height = 64});

  final List<KBarDatum> points;
  final int selected;
  final ValueChanged<int>? onSelect;

  /// Height of the plot, from the baseline to the highest month.
  final double height;

  @override
  Widget build(BuildContext context) {
    final k = context.k;
    final duration = KMotion.of(context, KMotion.slow * 2);
    return Column(
      children: [
        SizedBox(
          height: height,
          child: Stack(
            children: [
              Positioned.fill(
                child: TweenAnimationBuilder<double>(
                  tween: Tween(begin: duration == Duration.zero ? 1 : 0, end: 1),
                  duration: duration,
                  curve: KMotion.curve,
                  builder: (context, reveal, _) => CustomPaint(
                    painter: _LinePainter(
                      values: [for (final p in points) p.value],
                      selected: selected,
                      reveal: reveal,
                      line: k.primary,
                      ring: k.background,
                      guide: k.line,
                    ),
                  ),
                ),
              ),
              Row(children: [for (var i = 0; i < points.length; i++) Expanded(child: _hit(i))]),
            ],
          ),
        ),
        Container(height: 1, color: k.line),
        const SizedBox(height: KSpace.xs),
        KTrendAxis(labels: [for (final p in points) p.label], selected: selected),
      ],
    );
  }

  Widget _hit(int i) {
    final label = '${points[i].semanticLabel}${i == selected ? ', selected' : ''}';
    const area = SizedBox.expand();
    if (onSelect == null) return Semantics(label: label, child: area);
    return KPressable(
      onTap: i == selected ? () {} : () => onSelect!(i),
      haptic: i == selected ? null : HapticKind.selection,
      pressedScale: 1,
      semanticLabel: label,
      excludeChildSemantics: true,
      child: area,
    );
  }
}

class _LinePainter extends CustomPainter {
  _LinePainter({
    required this.values,
    required this.selected,
    required this.reveal,
    required this.line,
    required this.ring,
    required this.guide,
  });

  final List<double> values;
  final int selected;

  /// 0 to 1: how much of the line has drawn in.
  final double reveal;
  final Color line;
  final Color ring;
  final Color guide;

  /// Room above the highest month for the selected marker.
  static const _top = 7.0;

  @override
  void paint(Canvas canvas, Size size) {
    final n = values.length;
    if (n == 0) return;
    final max = values.fold<double>(0, math.max);
    final points = [
      for (var i = 0; i < n; i++)
        Offset(
          (i + 0.5) * size.width / n,
          size.height - (max <= 0 ? 0 : values[i].clamp(0, max) / max * (size.height - _top)),
        ),
    ];

    canvas
      ..save()
      ..clipRect(Rect.fromLTWH(0, 0, size.width * reveal, size.height));

    final path = Path()..moveTo(points.first.dx, points.first.dy);
    for (final p in points.skip(1)) {
      path.lineTo(p.dx, p.dy);
    }
    final area = Path.from(path)
      ..lineTo(points.last.dx, size.height)
      ..lineTo(points.first.dx, size.height)
      ..close();
    canvas.drawPath(
      area,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [line.withValues(alpha: 0.16), line.withValues(alpha: 0)],
        ).createShader(Offset.zero & size),
    );

    if (selected >= 0 && selected < n) {
      final p = points[selected];
      canvas.drawLine(
        p,
        Offset(p.dx, size.height),
        Paint()
          ..color = guide
          ..strokeWidth = 1,
      );
    }

    canvas.drawPath(
      path,
      Paint()
        ..color = line
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..strokeJoin = StrokeJoin.round
        ..strokeCap = StrokeCap.round,
    );

    for (var i = 0; i < n; i++) {
      if (i == selected) continue;
      canvas
        ..drawCircle(points[i], 3.5, Paint()..color = ring)
        ..drawCircle(
          points[i],
          3.5,
          Paint()
            ..color = line
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2,
        );
    }
    if (selected >= 0 && selected < n) {
      canvas
        ..drawCircle(points[selected], 6.5, Paint()..color = ring)
        ..drawCircle(points[selected], 4.5, Paint()..color = line);
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_LinePainter old) =>
      old.selected != selected ||
      old.reveal != reveal ||
      old.line != line ||
      old.ring != ring ||
      old.guide != guide ||
      !_sameValues(old.values, values);

  static bool _sameValues(List<double> a, List<double> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}
