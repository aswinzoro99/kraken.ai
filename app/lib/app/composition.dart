// The composition root: the one place that decides which implementation
// backs each interface for a flavor. Swap mocks for Firebase here.

import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/analytics/analytics.dart';
import '../core/config/app_config.dart';
import '../core/config/flavor.dart';
import '../core/crash/crash_reporter.dart';
import '../core/haptics/haptics.dart';
import '../core/storage/key_value_store.dart';
import '../core/time/clock.dart';
import '../features/auth/data/mock_auth_repository.dart';
import '../features/auth/data/mock_inbox.dart';
import '../features/auth/data/supabase_auth_repository.dart';
import '../features/groups/data/mock_groups_repository.dart';
import '../features/profile/data/mock_profile_repository.dart';
import '../features/profile/data/supabase_profile_repository.dart';
import 'services.dart';

Future<AppServices> compose(AppConfig config) async {
  final store = await SharedPrefsStore.create();
  return switch (config.flavor) {
    Flavor.mock => mockServices(config: config, store: await startSignedOut(store)),
    Flavor.dev || Flavor.prod => supabaseServices(config: config, store: store),
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

/// Real sign-in and profiles on Supabase (phantom-services). Groups,
/// expenses and invites are kept on the phone (MockGroupsRepository) until
/// their server side is built.
Future<AppServices> supabaseServices({required AppConfig config, required KeyValueStore store}) async {
  await Supabase.initialize(url: config.supabaseUrl.toString(), publishableKey: config.supabaseAnonKey);
  final client = Supabase.instance.client;
  final recorder = RecordingAnalytics();
  return AppServices(
    config: config,
    store: store,
    clock: systemClock,
    crash: LoggingCrashReporter(),
    analytics: buildAnalytics(store, defaultSinks(recorder)),
    recorder: recorder,
    haptics: Haptics(const SystemHapticsEngine(), store),
    auth: SupabaseAuthRepository(client),
    profiles: SupabaseProfileRepository(client),
    // Phase 2 runs on the phone until the groups server exists: your
    // groups start empty and are saved on this phone.
    groups: MockGroupsRepository(seed: false, store: store),
    devTools: DevTools(recorder: recorder),
  );
}
