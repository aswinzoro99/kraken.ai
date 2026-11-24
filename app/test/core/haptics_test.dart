import 'package:flutter_test/flutter_test.dart';
import 'package:kraken/core/haptics/haptics.dart';
import 'package:kraken/core/storage/key_value_store.dart';

void main() {
  test('plays when on, stays silent when off, and remembers the setting', () async {
    final engine = RecordingHapticsEngine();
    final store = MemoryStore();
    final haptics = Haptics(engine, store);

    await haptics.play(HapticKind.tap);
    await haptics.setEnabled(false);
    await haptics.play(HapticKind.error);
    expect(engine.played, [HapticKind.tap]);
    expect(Haptics(engine, store).enabled.value, isFalse);

    await haptics.setEnabled(true);
    expect(engine.played.last, HapticKind.selection, reason: 'turning it on gives a sample buzz');
  });

  test('never throws when the engine fails', () async {
    final haptics = Haptics(_Broken(), MemoryStore());
    await expectLater(haptics.play(HapticKind.heavy), completes);
  });
}

final class _Broken implements HapticsEngine {
  @override
  Future<void> perform(HapticKind kind) => throw StateError('no engine');
}
