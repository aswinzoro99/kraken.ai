import 'package:flutter_test/flutter_test.dart';
import 'package:kraken/app/composition.dart';
import 'package:kraken/app/kraken_app.dart';
import 'package:kraken/app/services.dart';
import 'package:kraken/core/config/app_config.dart';
import 'package:kraken/core/config/flavor.dart';
import 'package:kraken/core/haptics/haptics.dart';
import 'package:kraken/core/storage/key_value_store.dart';
import 'package:kraken/core/time/clock.dart';
import 'package:kraken/features/auth/data/mock_inbox.dart';

final class TestApp {
  TestApp(this.services, this.haptics, this.inbox, this.store);
  final AppServices services;
  final RecordingHapticsEngine haptics;
  final MockInbox inbox;
  final MemoryStore store;
}

/// The "now" every test runs at, so the mock's dates and totals are fixed.
DateTime testNow() => DateTime(2026, 11, 24, 18);

/// Mock services with no delays, for widget and bloc tests.
AppServices testServices({
  Clock clock = testNow,
  MemoryStore? store,
  RecordingHapticsEngine? haptics,
  MockInbox? inbox,
  bool emptyGroups = false,
}) => mockServices(
  config: AppConfig.forFlavor(Flavor.mock).copyWith(chatPacing: Duration.zero),
  store: store ?? MemoryStore(),
  clock: clock,
  latency: Duration.zero,
  hapticsEngine: haptics ?? RecordingHapticsEngine(),
  inbox: inbox,
  emptyGroups: emptyGroups,
);

/// Pumps the whole app on the mock flavor with no delays.
Future<TestApp> pumpKraken(WidgetTester tester, {MemoryStore? store, bool emptyGroups = false}) async {
  final haptics = RecordingHapticsEngine();
  final inbox = MockInbox();
  final memory = store ?? MemoryStore();
  final services = testServices(store: memory, haptics: haptics, inbox: inbox, emptyGroups: emptyGroups);
  addTearDown(services.dispose);
  await tester.pumpWidget(KrakenApp(services: services));
  await tester.pumpAndSettle();
  return TestApp(services, haptics, inbox, memory);
}
