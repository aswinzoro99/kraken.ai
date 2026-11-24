import 'package:flutter_test/flutter_test.dart';
import 'package:kraken/core/analytics/analytics.dart';
import 'package:kraken/core/analytics/consent_gated_analytics.dart';
import 'package:kraken/core/analytics/events.dart';

void main() {
  group('ConsentGatedAnalytics', () {
    late RecordingAnalytics sink;
    setUp(() => sink = RecordingAnalytics());

    test('holds events until consent, then sends them in order', () async {
      final gate = ConsentGatedAnalytics(sink);
      await gate.log(const WelcomeStartTapped());
      await gate.log(const SignInEmailSubmitted(valid: true));
      await gate.setUserId('u1');
      expect(sink.events, isEmpty);
      expect(gate.bufferedCount, 2);

      await gate.setConsent(AnalyticsConsent.granted);
      expect(sink.names, ['welcome_start_tapped', 'sign_in_email_submitted']);
      expect(sink.userId, 'u1');

      await gate.log(const SignedOut());
      expect(sink.names.last, 'signed_out');
    });

    test('drops everything when consent is refused', () async {
      final gate = ConsentGatedAnalytics(sink);
      await gate.log(const WelcomeStartTapped());
      await gate.setConsent(AnalyticsConsent.denied);
      await gate.log(const SignedOut());
      expect(sink.events, isEmpty);
      expect(gate.bufferedCount, 0);
    });

    test('caps the buffer', () async {
      final gate = ConsentGatedAnalytics(sink, maxBuffered: 3);
      for (var i = 0; i < 5; i++) {
        await gate.log(ScreenViewed('s$i'));
      }
      await gate.setConsent(AnalyticsConsent.granted);
      expect(sink.events.map((e) => e.params['screen_name']), ['s2', 's3', 's4']);
    });

    test('reports consent changes for persistence', () async {
      final seen = <AnalyticsConsent>[];
      final gate = ConsentGatedAnalytics(sink, onConsentChanged: seen.add);
      await gate.setConsent(AnalyticsConsent.granted);
      await gate.setConsent(AnalyticsConsent.granted);
      await gate.setConsent(AnalyticsConsent.denied);
      expect(seen, [AnalyticsConsent.granted, AnalyticsConsent.denied]);
    });
  });

  group('event catalogue', () {
    final all = <AnalyticsEvent>[
      const AppOpened(flavor: 'mock', coldStartMs: 900),
      const ScreenViewed('groups'),
      const WelcomeStartTapped(),
      const SignInEmailSubmitted(valid: false),
      const SignInCodeRequested(resend: true),
      const SignInFailed('wrong_code'),
      const SignInCompleted(newUser: true),
      const OnboardingStepViewed('name'),
      const ConsentRecorded(kind: 'privacy', granted: true),
      const UpiStepFinished(added: false),
      const OnboardingCompleted(groupChoice: 'skip', seconds: 40),
      const SignedOut(),
      const AccountDeleted(),
      const SettingChanged(setting: 'haptics', enabled: false),
      const ComingSoonTapped('scan_bill'),
      const TabSelected('account'),
      const HomeAction('month_selected', monthsAgo: 2),
      const HomeAction('pay'),
    ];

    test('every event follows the naming and value rules', () {
      for (final e in all) {
        expect(validateEvent(e), isEmpty, reason: e.name);
      }
    });

    test('validation catches bad events', () {
      expect(validateEvent(const _Bad()), hasLength(2));
    });

    test('MultiAnalytics rejects invalid events in debug', () {
      expect(() => MultiAnalytics([RecordingAnalytics()]).log(const _Bad()), throwsArgumentError);
    });
  });
}

final class _Bad extends AnalyticsEvent {
  const _Bad();
  @override
  String get name => 'Bad-Name';
  @override
  Map<String, Object> get params => {'email': 'x' * 101};
}
