// Pull to refresh with the Kraken mascot rising out of the water.
// Matches "Pull to refresh — frame by frame" on the design canvas.
//
// Adapted from the design team's kraken_refresh.dart: Kraken's colours in
// light and dark mode, the app's haptics (so the Vibration setting
// applies), its type, and an [edgeOffset] so the kraken rises below the
// status bar rather than under it.

import 'dart:math' as math;

import 'package:custom_refresh_indicator/custom_refresh_indicator.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/haptics/haptics.dart';
import '../foundation/haptics_scope.dart';
import '../theme/kraken_theme.dart';
import '../tokens/typography.dart';

class KrakenRefresh extends StatefulWidget {
  const KrakenRefresh({super.key, required this.onRefresh, required this.child, this.edgeOffset});

  /// Runs when the person lets go past the line. The kraken waves until it
  /// completes, and for at least [_KrakenRefreshState.minRefreshing].
  final Future<void> Function() onRefresh;

  /// The scrollable. Give it AlwaysScrollableScrollPhysics so short lists
  /// can still be pulled, over ClampingScrollPhysics so the list doesn't
  /// also bounce while the space opens above it.
  final Widget child;

  /// Where the revealed space starts. Defaults to the top safe-area inset,
  /// for a scrollable that runs under the status bar.
  final double? edgeOffset;

  @override
  State<KrakenRefresh> createState() => _KrakenRefreshState();
}

class _KrakenRefreshState extends State<KrakenRefresh> with SingleTickerProviderStateMixin {
  /// Pull distance, in logical pixels, that arms the refresh.
  static const double armedOffset = 100;

  /// Shortest time the waving shows, so a fast refresh never flickers.
  static const Duration minRefreshing = Duration(milliseconds: 800);

  /// One cycle of waving arms, bobbing head, bubbles and drifting water.
  late final AnimationController _loop = AnimationController(vsync: this, duration: const Duration(milliseconds: 1100));

  bool _happy = false;

  @override
  void dispose() {
    _loop.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    final watch = Stopwatch()..start();
    await widget.onRefresh();
    final left = minRefreshing - watch.elapsed;
    if (left > Duration.zero) await Future<void>.delayed(left);
  }

  void _onStateChanged(IndicatorStateChange change) {
    if (!mounted) return;
    if (change.didChange(to: IndicatorState.armed)) {
      HapticsScope.play(context, HapticKind.selection);
    }
    if (change.didChange(to: IndicatorState.loading)) {
      setState(() => _happy = false);
      if (!(MediaQuery.maybeDisableAnimationsOf(context) ?? false)) _loop.repeat();
    }
    if (change.didChange(to: IndicatorState.complete)) {
      _loop.stop();
      HapticsScope.play(context, HapticKind.success);
      setState(() => _happy = true);
    }
    if (change.didChange(to: IndicatorState.idle)) {
      _loop
        ..stop()
        ..reset();
      setState(() => _happy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final k = context.k;
    final edge = widget.edgeOffset ?? MediaQuery.paddingOf(context).top;

    return CustomRefreshIndicator(
      onRefresh: _refresh,
      offsetToArmed: armedOffset,
      durations: const RefreshIndicatorDurations(
        cancelDuration: Duration(milliseconds: 300),
        settleDuration: Duration(milliseconds: 150),
        completeDuration: Duration(milliseconds: 600),
        finalizeDuration: Duration(milliseconds: 300),
      ),
      onStateChanged: _onStateChanged,
      builder: (context, child, controller) => AnimatedBuilder(
        animation: Listenable.merge([controller, _loop]),
        child: child,
        builder: (context, child) {
          final pull = controller.value.clamp(0.0, 1.4) * armedOffset;
          return Stack(
            children: [
              Transform.translate(offset: Offset(0, pull), child: child),
              Positioned(
                top: edge,
                left: 0,
                right: 0,
                height: pull,
                child: ClipRect(
                  child: ColoredBox(
                    color: k.surfaceMuted,
                    child: Stack(
                      children: [
                        Positioned.fill(
                          child: ExcludeSemantics(
                            child: CustomPaint(
                              painter: _KrakenPainter(
                                progress: controller.value,
                                loading: controller.isLoading,
                                happy: _happy,
                                loop: _loop.value,
                                color: k.primary,
                                water: k.surfaceMuted,
                              ),
                            ),
                          ),
                        ),
                        Positioned(
                          top: 12,
                          left: 0,
                          right: 0,
                          child: _Label(controller: controller, happy: _happy),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
      child: widget.child,
    );
  }
}

class _Label extends StatelessWidget {
  const _Label({required this.controller, required this.happy});

  final IndicatorController controller;
  final bool happy;

  @override
  Widget build(BuildContext context) {
    final String text;
    final double opacity;
    if (happy) {
      text = 'Up to date';
      opacity = 1;
    } else if (controller.isLoading || controller.isSettling) {
      text = 'Refreshing…';
      opacity = 1;
    } else if (controller.isArmed) {
      text = 'Release to refresh';
      opacity = 1;
    } else {
      text = 'Pull down to refresh';
      opacity = ((controller.value - 0.35) / 0.3).clamp(0.0, 1.0);
    }
    return Semantics(
      liveRegion: true,
      child: Opacity(
        opacity: opacity,
        child: Text(
          text,
          textAlign: TextAlign.center,
          style: KText.small.copyWith(fontWeight: FontWeight.w600, color: context.k.muted),
        ),
      ),
    );
  }
}

/// Draws the kraken in a 100 x 100 unit box, shown 120 px wide, sitting in
/// water whose surface is 14 px above the bottom of the revealed space.
class _KrakenPainter extends CustomPainter {
  _KrakenPainter({
    required this.progress,
    required this.loading,
    required this.happy,
    required this.loop,
    required this.color,
    required this.water,
  });

  /// 0 hidden, 1 at the arming line, up to 1.4 when pulled further.
  final double progress;
  final bool loading;
  final bool happy;

  /// 0 to 1, repeating while loading; stays 0 with reduced motion.
  final double loop;
  final Color color;

  /// The space behind; the water and bubbles are tints of [color] towards
  /// it, so they stay soft in dark mode too.
  final Color water;

  static const Color _pupil = Color(0xFF15171C);
  static const Color _white = Color(0xFFFFFFFF);
  static const double _boxPx = 120;
  static const double _period = 39;

  static final Path _leftArm = Path()
    ..moveTo(32, 64)
    ..cubicTo(24, 60, 18, 52, 20, 42)
    ..arcToPoint(const Offset(29, 44), radius: const Radius.circular(5));

  static final Path _rightArm = Path()
    ..moveTo(68, 64)
    ..cubicTo(76, 60, 82, 52, 80, 42)
    ..arcToPoint(const Offset(71, 44), radius: const Radius.circular(5), clockwise: false);

  static final Path _head = Path()
    ..moveTo(26, 72)
    ..arcToPoint(const Offset(74, 72), radius: const Radius.elliptical(24, 26))
    ..close();

  @override
  void paint(Canvas canvas, Size size) {
    if (size.height <= 0) return;

    final q = progress.clamp(0.0, 1.0);
    final rise = math.pow(1 - q, 3).toDouble() * 100; // 100 px under water at 0
    final arms = ((q - 0.55) / 0.45).clamp(0.0, 1.0); // arms swing up late
    final bounce = 1 + 0.06 * ((progress - 1) / 0.1).clamp(0.0, 1.0);
    final angle = loop * 2 * math.pi;
    final bob = loading ? -1.5 - 1.5 * math.sin(angle) : 0.0;
    final waterLine = size.height - 14;
    final light = Color.lerp(color, water, 0.6)!;
    final sea = Color.lerp(color, water, 0.85)!;
    final cx = size.width / 2;

    // Bubbles rise beside the kraken while loading.
    if (loading && loop > 0) {
      const offsets = [-56.0, 46.0, 60.0];
      for (var i = 0; i < offsets.length; i++) {
        final f = (loop + i / offsets.length) % 1.0;
        final up = 46 * Curves.easeOut.transform(f);
        final fadeIn = (f / 0.2).clamp(0.0, 1.0);
        final fadeOut = 1 - ((f - 0.2) / 0.8).clamp(0.0, 1.0);
        final paint = Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..color = light.withValues(alpha: math.min(fadeIn, fadeOut));
        canvas.drawCircle(Offset(cx + offsets[i], waterLine - 4.5 - up), 3.5 * (0.6 + 0.4 * f), paint);
      }
    }

    // The kraken. Unit (50, 70) is the pivot for the ready bounce.
    canvas
      ..save()
      ..translate(cx, size.height - 12 + rise + bob)
      ..scale(_boxPx / 100 * bounce)
      ..translate(-50, -70);

    final armPaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 7
      ..strokeCap = StrokeCap.round;
    final swing = 70 * (1 - arms);
    final waveLeft = loading ? 12 * math.sin(angle) : 0.0;
    final waveRight = loading ? 12 * math.sin(angle + math.pi / 2) : 0.0;
    _drawArm(canvas, _leftArm, const Offset(32, 64), swing + waveLeft, armPaint);
    _drawArm(canvas, _rightArm, const Offset(68, 64), -swing - waveRight, armPaint);

    canvas.drawPath(_head, Paint()..color = color);

    if (happy) {
      final smile = Paint()
        ..color = _white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round;
      canvas.drawPath(
        Path()
          ..moveTo(37.5, 59.5)
          ..quadraticBezierTo(42, 53.5, 46.5, 59.5)
          ..moveTo(53.5, 59.5)
          ..quadraticBezierTo(58, 53.5, 62.5, 59.5),
        smile,
      );
    } else {
      final white = Paint()..color = _white;
      final pupil = Paint()..color = _pupil;
      final pupilY = 59.5 - 3 * q; // looks down at the list, then up at you
      canvas
        ..drawCircle(const Offset(42, 58), 5.5, white)
        ..drawCircle(const Offset(58, 58), 5.5, white)
        ..drawCircle(Offset(42, pupilY), 2.6, pupil)
        ..drawCircle(Offset(58, pupilY), 2.6, pupil);
    }
    canvas.restore();

    // Water in front, so the kraken rises out of it.
    final shift = loading ? -_period * loop : 0.0;
    var x = shift - _period;
    final surface = Path()..moveTo(x, waterLine);
    while (x < size.width + _period) {
      surface
        ..quadraticBezierTo(x + 9.75, waterLine - 6, x + 19.5, waterLine)
        ..quadraticBezierTo(x + 29.25, waterLine + 6, x + _period, waterLine);
      x += _period;
    }
    final body = Path.from(surface)
      ..lineTo(x, size.height)
      ..lineTo(shift - _period, size.height)
      ..close();
    canvas
      ..drawPath(body, Paint()..color = sea)
      ..drawPath(
        surface,
        Paint()
          ..color = light
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..strokeCap = StrokeCap.round,
      );
  }

  void _drawArm(Canvas canvas, Path path, Offset pivot, double degrees, Paint paint) {
    canvas
      ..save()
      ..translate(pivot.dx, pivot.dy)
      ..rotate(degrees * math.pi / 180)
      ..translate(-pivot.dx, -pivot.dy)
      ..drawPath(path, paint)
      ..restore();
  }

  @override
  bool shouldRepaint(_KrakenPainter old) =>
      old.progress != progress ||
      old.loading != loading ||
      old.happy != happy ||
      old.loop != loop ||
      old.color != color ||
      old.water != water;
}
