import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../storage/key_value_store.dart';

/// What an action feels like. Pick by meaning, not by strength.
enum HapticKind {
  /// A button or row was pressed.
  tap,

  /// A choice changed: tab, chip, switch, segment.
  selection,

  /// Something was saved or completed.
  success,

  /// Needs attention but nothing failed: undo, a confirm sheet.
  warning,

  /// Input was rejected or an action failed.
  error,

  /// A heavy, physical moment: start of hold-to-talk, a bill captured.
  heavy,
}

/// Turns a [HapticKind] into device feedback.
abstract interface class HapticsEngine {
  Future<void> perform(HapticKind kind);
}

/// Uses the platform's haptic engine. iOS honours the system setting for
/// "System Haptics" on its own.
final class SystemHapticsEngine implements HapticsEngine {
  const SystemHapticsEngine();

  @override
  Future<void> perform(HapticKind kind) async {
    switch (kind) {
      case HapticKind.tap:
        await HapticFeedback.lightImpact();
      case HapticKind.selection:
        await HapticFeedback.selectionClick();
      case HapticKind.success:
        await HapticFeedback.lightImpact();
        await Future<void>.delayed(const Duration(milliseconds: 90));
        await HapticFeedback.mediumImpact();
      case HapticKind.warning:
        await HapticFeedback.mediumImpact();
      case HapticKind.error:
        await HapticFeedback.heavyImpact();
        await Future<void>.delayed(const Duration(milliseconds: 80));
        await HapticFeedback.heavyImpact();
      case HapticKind.heavy:
        await HapticFeedback.heavyImpact();
    }
  }
}

/// Records what would have been played. For tests and the debug screen.
final class RecordingHapticsEngine implements HapticsEngine {
  final List<HapticKind> played = [];

  @override
  Future<void> perform(HapticKind kind) async => played.add(kind);
}

/// The app-wide haptics service. Respects the person's on/off setting.
final class Haptics {
  Haptics(this._engine, this._store) : enabled = ValueNotifier(_store.getBool(StoreKeys.hapticsEnabled) ?? true);

  final HapticsEngine _engine;
  final KeyValueStore _store;

  /// Whether haptics play. Listen to rebuild a settings switch.
  final ValueNotifier<bool> enabled;

  Future<void> setEnabled(bool value) async {
    enabled.value = value;
    await _store.setBool(StoreKeys.hapticsEnabled, value);
    if (value) await _engine.perform(HapticKind.selection);
  }

  /// Plays [kind] if haptics are on. Never throws: a missing engine on a
  /// simulator must not break an action.
  Future<void> play(HapticKind kind) async {
    if (!enabled.value) return;
    try {
      await _engine.perform(kind);
    } catch (_) {}
  }
}
