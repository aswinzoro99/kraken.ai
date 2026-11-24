import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kraken/app/services.dart';
import 'package:kraken/app/session.dart';
import 'package:kraken/core/analytics/analytics_consent_cubit.dart';
import 'package:kraken/core/analytics/consent_gated_analytics.dart';
import 'package:kraken/features/auth/domain/email_address.dart';
import 'package:kraken/features/auth/domain/otp_code.dart';
import 'package:kraken/features/home/presentation/home_cubit.dart';
import 'package:kraken/features/profile/domain/user_profile.dart';
import 'package:ledger/ledger.dart';

import '../helpers/test_app.dart';

void main() {
  late AppServices services;
  setUp(() => services = testServices());
  tearDown(() => services.dispose());

  SessionCubit session() => SessionCubit(
    auth: services.auth,
    profiles: services.profiles,
    analytics: services.analytics,
    crash: services.crash,
    policyVersion: services.config.privacyPolicyVersion,
  );

  Future<void> signIn() async {
    final email = EmailAddress.tryParse('aarav@example.com')!;
    await services.auth.requestCode(email);
    await services.auth.verifyCode(email, OtpCode.tryParse(services.devTools.inbox!.value!.code)!);
  }

  group('SessionCubit', () {
    blocTest<SessionCubit, SessionState>(
      'signed out by default',
      build: session,
      expect: () => [isA<SignedOutSession>()],
    );

    blocTest<SessionCubit, SessionState>(
      'signing in without a profile means onboarding, then ready once complete',
      build: session,
      act: (_) async {
        await signIn();
        await Future<void>.delayed(Duration.zero);
        final uid = services.auth.currentUser!.uid;
        await services.profiles.save(
          UserProfile(
            uid: uid,
            displayName: 'Aarav',
            adultConfirmedAt: DateTime(2026),
            privacyAcceptedAt: DateTime(2026),
            privacyPolicyVersion: services.config.privacyPolicyVersion,
          ),
        );
      },
      expect: () => [isA<SignedOutSession>(), isA<OnboardingSession>(), isA<ReadySession>()],
    );

    blocTest<SessionCubit, SessionState>(
      'signing out goes back to signed out',
      build: session,
      act: (_) async {
        await signIn();
        await Future<void>.delayed(Duration.zero);
        await services.auth.signOut();
      },
      expect: () => [isA<SignedOutSession>(), isA<OnboardingSession>(), isA<SignedOutSession>()],
    );
  });

  group('HomeCubit', () {
    HomeCubit home() => HomeCubit(repository: services.groups, uid: 'u1', clock: testNow);

    blocTest<HomeCubit, HomeState>(
      'works out this month and per-person balances',
      build: home,
      expect: () => [
        isA<HomeReady>()
            .having((s) => s.month, 'month', DateTime(2026, 11))
            .having((s) => s.snapshot.spending.total, 'spent', const Money.rupees(21500))
            .having((s) => s.snapshot.balances.net, 'net', const Money.rupees(2870)),
      ],
    );

    blocTest<HomeCubit, HomeState>(
      'selecting a month recomputes spending; future months are ignored',
      build: home,
      act: (cubit) async {
        await Future<void>.delayed(Duration.zero);
        cubit
          ..selectMonth(DateTime(2026, 9))
          ..selectMonth(DateTime(2026, 12));
      },
      skip: 1,
      expect: () => [
        isA<HomeReady>()
            .having((s) => s.month, 'month', DateTime(2026, 9))
            .having((s) => s.snapshot.spending.total, 'spent', const Money.rupees(18760)),
      ],
    );
  });

  group('AnalyticsConsentCubit', () {
    blocTest<AnalyticsConsentCubit, AnalyticsConsent>(
      'follows choices made elsewhere and its own switch',
      build: () => AnalyticsConsentCubit(services.analytics),
      act: (cubit) async {
        await services.analytics.setConsent(AnalyticsConsent.granted);
        await cubit.set(granted: false);
      },
      expect: () => [AnalyticsConsent.granted, AnalyticsConsent.denied],
      verify: (_) => expect(services.recorder.names.last, 'setting_changed'),
    );
  });
}
