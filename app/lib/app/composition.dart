// The composition root: the one place that decides which implementation
// backs each interface for a flavor. Swap mocks for Firebase here.

import '../core/analytics/analytics.dart';
import '../core/config/app_config.dart';
import '../core/config/flavor.dart';
import '../core/crash/crash_reporter.dart';
import '../core/haptics/haptics.dart';
import '../core/storage/key_value_store.dart';
import '../core/time/clock.dart';
import '../features/auth/data/mock_auth_repository.dart';
import '../features/auth/data/mock_inbox.dart';
import '../features/groups/data/mock_groups_repository.dart';
import '../features/profile/data/mock_profile_repository.dart';
import 'services.dart';

Future<AppServices> compose(AppConfig config) async {
  final store = await SharedPrefsStore.create();
  return switch (config.flavor) {
    Flavor.mock => mockServices(config: config, store: await startSignedOut(store)),
    Flavor.dev || Flavor.prod => throw UnsupportedError(
      'The ${config.flavor.name} flavor needs the Firebase projects (build guide, Phase 0 day 3). '
      'Run the mock flavor for now: flutter run -t lib/main_mock.dart',
    ),
  };
}

/// Everything on fakes. Also used by widget tests, with a [MemoryStore],
/// zero latency and a recording haptics engine.
AppServices mockServices({
  required AppConfig config,
  required KeyValueStore store,
  Clock clock = systemClock,
  Duration latency = const Duration(milliseconds: 500),
  HapticsEngine hapticsEngine = const SystemHapticsEngine(),
  bool emptyGroups = false,
  MockInbox? inbox,
}) {
  final mockInbox = inbox ?? MockInbox();
  final recorder = RecordingAnalytics();
  final auth = MockAuthRepository(store: store, inbox: mockInbox, clock: clock, latency: latency);
  return AppServices(
    config: config,
    store: store,
    clock: clock,
    crash: LoggingCrashReporter(),
    analytics: buildAnalytics(store, defaultSinks(recorder)),
    recorder: recorder,
    haptics: Haptics(hapticsEngine, store),
    auth: auth,
    profiles: MockProfileRepository(store),
    groups: MockGroupsRepository(clock: clock, empty: emptyGroups),
    devTools: DevTools(inbox: mockInbox, mockAuth: auth, recorder: recorder),
  );
}

/// The mock build forgets who was signed in each time it launches, so every
/// launch starts at Welcome and the sign-in flow can be tested. Profiles and
/// settings stay: an email used before signs straight back in, a new one
/// goes through the whole sign-up chat.
Future<KeyValueStore> startSignedOut(KeyValueStore store) async {
  await store.remove(StoreKeys.mockSession);
  await store.remove(StoreKeys.pendingEmail);
  return store;
}
