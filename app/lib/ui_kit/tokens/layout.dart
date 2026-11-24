import 'package:material_ui/material_ui.dart';

/// Spacing steps from the canvas.
abstract final class KSpace {
  static const xxs = 4.0;
  static const xs = 8.0;
  static const sm = 10.0;
  static const md = 12.0;
  static const lg = 16.0;
  static const xl = 20.0;
  static const xxl = 24.0;
  static const xxxl = 32.0;

  /// Side gutter for screens.
  static const gutter = 20.0;
}

abstract final class KRadius {
  static const sm = Radius.circular(6);
  static const md = Radius.circular(12);
  static const lg = Radius.circular(14);
  static const xl = Radius.circular(16);
  static const bubble = Radius.circular(18);
  static const xxl = Radius.circular(20);
  static const dock = Radius.circular(22);
  static const pill = Radius.circular(999);
}

/// Minimum touch target on both platforms.
const kMinTouch = 44.0;

abstract final class KMotion {
  static const fast = Duration(milliseconds: 120);
  static const base = Duration(milliseconds: 200);
  static const slow = Duration(milliseconds: 320);
  static const curve = Curves.easeOutCubic;

  /// Zero when the person asked the OS to reduce motion.
  static Duration of(BuildContext context, Duration d) =>
      MediaQuery.maybeDisableAnimationsOf(context) ?? false ? Duration.zero : d;
}
