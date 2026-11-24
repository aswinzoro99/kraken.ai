import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../core/analytics/analytics_consent_cubit.dart';
import '../core/analytics/consent_gated_analytics.dart';
import '../core/config/app_config.dart';
import '../core/crash/crash_reporter.dart';
import '../core/haptics/haptics.dart';
import '../core/storage/key_value_store.dart';
import '../core/time/clock.dart';
import '../features/auth/domain/auth_repository.dart';
import '../features/groups/domain/group_ledger.dart';
import '../features/profile/domain/profile_repository.dart';
import '../ui_kit/ui_kit.dart';
import 'appearance.dart';
import 'router.dart';
import 'services.dart';
import 'session.dart';

/// The root widget. Provides every service and the app-wide cubits to the
/// tree, owns the router, and applies the theme.
class KrakenApp extends StatefulWidget {
  const KrakenApp({super.key, required this.services});

  final AppServices services;

  @override
  State<KrakenApp> createState() => _KrakenAppState();
}

class _KrakenAppState extends State<KrakenApp> {
  late final AppServices s = widget.services;
  late final SessionCubit _session = SessionCubit(
    auth: s.auth,
    profiles: s.profiles,
    analytics: s.analytics,
    crash: s.crash,
    policyVersion: s.config.privacyPolicyVersion,
  );
  late final AnalyticsConsentCubit _consent = AnalyticsConsentCubit(s.analytics);
  late final AppearanceCubit _appearance = AppearanceCubit(s.store);
  late final StreamListenable _refresh = StreamListenable(_session.stream);
  late final GoRouter _router = createRouter(
    session: _session,
    refresh: _refresh,
    analytics: s.analytics,
    debugAllowed: s.config.showDebugTools,
  );

  @override
  void dispose() {
    _router.dispose();
    _refresh.dispose();
    _session.close();
    _consent.close();
    _appearance.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MultiRepositoryProvider(
      providers: [
        RepositoryProvider<AppConfig>.value(value: s.config),
        RepositoryProvider<KeyValueStore>.value(value: s.store),
        RepositoryProvider<Clock>.value(value: s.clock),
        RepositoryProvider<CrashReporter>.value(value: s.crash),
        RepositoryProvider<ConsentGatedAnalytics>.value(value: s.analytics),
        RepositoryProvider<Haptics>.value(value: s.haptics),
        RepositoryProvider<AuthRepository>.value(value: s.auth),
        RepositoryProvider<ProfileRepository>.value(value: s.profiles),
        RepositoryProvider<GroupsRepository>.value(value: s.groups),
        RepositoryProvider<DevTools>.value(value: s.devTools),
      ],
      child: MultiBlocProvider(
        providers: [
          BlocProvider<SessionCubit>.value(value: _session),
          BlocProvider<AnalyticsConsentCubit>.value(value: _consent),
          BlocProvider<AppearanceCubit>.value(value: _appearance),
        ],
        child: BlocBuilder<AppearanceCubit, Appearance>(
          builder: (context, appearance) => MaterialApp.router(
            title: s.config.appName,
            debugShowCheckedModeBanner: false,
            theme: KrakenTheme.light(),
            darkTheme: KrakenTheme.dark(),
            // Account → Appearance; the phone's setting unless overridden.
            themeMode: switch (appearance) {
              Appearance.system => ThemeMode.system,
              Appearance.light => ThemeMode.light,
              Appearance.dark => ThemeMode.dark,
            },
            routerConfig: _router,
            builder: (context, child) {
              // Honour large text, but cap it where layouts would break (200%,
              // the accessibility target in the build guide).
              final media = MediaQuery.of(context);
              return MediaQuery(
                data: media.copyWith(textScaler: media.textScaler.clamp(maxScaleFactor: 2)),
                child: HapticsScope(haptics: s.haptics, child: child ?? const SizedBox.shrink()),
              );
            },
          ),
        ),
      ),
    );
  }
}

/// Shorthand for the services features use most.
extension AppContext on BuildContext {
  /// Log events here. Held back until the person answers the stats question.
  ConsentGatedAnalytics get analytics => read<ConsentGatedAnalytics>();
  AppConfig get config => read<AppConfig>();
}
