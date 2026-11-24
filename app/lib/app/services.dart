import '../core/analytics/analytics.dart';
import '../core/analytics/consent_gated_analytics.dart';
import '../core/analytics/logging_analytics.dart';
import '../core/config/app_config.dart';
import '../core/crash/crash_reporter.dart';
import '../core/haptics/haptics.dart';
import '../core/storage/key_value_store.dart';
import '../core/time/clock.dart';
import '../features/auth/data/mock_auth_repository.dart';
import '../features/auth/data/mock_inbox.dart';
import '../features/auth/domain/auth_repository.dart';
import '../features/groups/domain/group_ledger.dart';
import '../features/profile/domain/profile_repository.dart';

/// Every app-wide service, built once by the composition root and handed to
/// the widget tree with `RepositoryProvider`. Blocs receive what they need
/// through their constructors; they never look services up themselves.
final class AppServices {
  const AppServices({
    required this.config,
    required this.store,
    required this.clock,
    required this.crash,
    required this.analytics,
    required this.recorder,
    required this.haptics,
    required this.auth,
    required this.profiles,
    required this.groups,
    this.devTools = const DevTools(),
  });

  final AppConfig config;
  final KeyValueStore store;
  final Clock clock;
  final CrashReporter crash;

  /// Use this for every event; it holds events back until consent.
  final ConsentGatedAnalytics analytics;

  /// Recent events kept on the phone, for the debug screen.
  final RecordingAnalytics recorder;
  final Haptics haptics;
  final AuthRepository auth;
  final ProfileRepository profiles;
  final GroupsRepository groups;
  final DevTools devTools;

  void dispose() {
    recorder.dispose();
    haptics.enabled.dispose();
  }
}

/// Hooks that only exist in mock builds: the fake inbox and a handle on the
/// fake server for the debug screen. Empty in production builds.
final class DevTools {
  const DevTools({this.inbox, this.mockAuth, this.recorder});
  final MockInbox? inbox;
  final MockAuthRepository? mockAuth;

  /// Recent analytics events, listed on the debug screen.
  final RecordingAnalytics? recorder;
}

/// Builds the consent gate in front of [sinks], restoring the saved answer.
ConsentGatedAnalytics buildAnalytics(KeyValueStore store, List<Analytics> sinks) {
  final saved = store.getString(StoreKeys.analyticsConsent);
  return ConsentGatedAnalytics(
    MultiAnalytics(sinks),
    initial: AnalyticsConsent.values.firstWhere((c) => c.name == saved, orElse: () => AnalyticsConsent.unknown),
    onConsentChanged: (c) => store.setString(StoreKeys.analyticsConsent, c.name),
  );
}

/// The default sinks: the developer log and the on-phone recorder.
/// Firebase Analytics joins this list in Phase 0, day 5.
List<Analytics> defaultSinks(RecordingAnalytics recorder) => [const LoggingAnalytics(), recorder];
