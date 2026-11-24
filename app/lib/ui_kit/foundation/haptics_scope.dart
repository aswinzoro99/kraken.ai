import 'package:material_ui/material_ui.dart';

import '../../core/haptics/haptics.dart';

/// Makes the app's [Haptics] reachable from any UI kit widget without the
/// kit depending on a state-management package. Missing scope (tests, previews) means silence.
class HapticsScope extends InheritedWidget {
  const HapticsScope({super.key, required this.haptics, required super.child});

  final Haptics haptics;

  static Haptics? maybeOf(BuildContext context) => context.getInheritedWidgetOfExactType<HapticsScope>()?.haptics;

  static void play(BuildContext context, HapticKind kind) => maybeOf(context)?.play(kind);

  @override
  bool updateShouldNotify(HapticsScope oldWidget) => haptics != oldWidget.haptics;
}

extension HapticsContext on BuildContext {
  void haptic(HapticKind kind) => HapticsScope.play(this, kind);
}
