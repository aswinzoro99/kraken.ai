import 'package:flutter/physics.dart';
import 'package:material_ui/material_ui.dart';

/// Springs, in Apple's terms: `duration` is the response (how quickly it
/// gets there), `bounce` is overshoot. Bounce 0 is critically damped; 0.2 is
/// roughly Apple's 0.8 damping, used only after a gesture with momentum.
abstract final class KSpring {
  /// Default for anything that moves without being thrown: no overshoot.
  static final standard = SpringDescription.withDurationAndBounce(duration: const Duration(milliseconds: 400));

  /// Small, quick moves: the tab lens after a tap, highlights.
  static final snappy = SpringDescription.withDurationAndBounce(duration: const Duration(milliseconds: 300));

  /// After a drag or flick, where the hand gave it momentum.
  static final momentum = SpringDescription.withDurationAndBounce(
    duration: const Duration(milliseconds: 400),
    bounce: 0.2,
  );

  /// Where a flick would come to rest (Apple's deceleration model).
  /// [velocity] is in logical pixels per second.
  static double project(double velocity, {double decelerationRate = 0.998}) =>
      velocity / 1000 * decelerationRate / (1 - decelerationRate);

  /// Resistance past a boundary: the further past, the less it follows.
  static double rubberband(double overshoot, double dimension, {double constant = 0.55}) =>
      (overshoot * dimension * constant) / (dimension + constant * overshoot.abs());
}

/// A critically damped spring as a [Curve], for implicit animations that
/// need a fixed length. Interactive motion uses [SpringSimulation] directly
/// so it can carry the finger's velocity.
class KSpringCurve extends Curve {
  KSpringCurve(SpringDescription spring, {this.seconds = 0.6}) : _sim = SpringSimulation(spring, 0, 1, 0);

  final SpringSimulation _sim;
  final double seconds;

  @override
  double transformInternal(double t) => _sim.x(t * seconds);
}
