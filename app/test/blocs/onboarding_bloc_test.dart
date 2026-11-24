import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kraken/app/services.dart';
import 'package:kraken/app/session.dart';
import 'package:kraken/core/haptics/haptics.dart';
import 'package:kraken/features/onboarding/domain/onboarding_machine.dart';
import 'package:kraken/features/onboarding/presentation/onboarding_bloc.dart';

import '../helpers/test_app.dart';

void main() {
  late AppServices services;
  late RecordingHapticsEngine haptics;

  setUp(() {
    haptics = RecordingHapticsEngine();
    services = testServices(haptics: haptics);
  });
  tearDown(() => services.dispose());

  OnboardingBloc build({SessionState session = const SignedOutSession()}) => OnboardingBloc(
    session: session,
    auth: services.auth,
    profiles: services.profiles,
    analytics: services.analytics,
    haptics: services.haptics,
    store: services.store,
    clock: services.clock,
    policyVersion: services.config.privacyPolicyVersion,
    privacyPolicyUrl: services.config.privacyPolicyUrl,
    pacing: Duration.zero,
  );

  String last(OnboardingChatState s) => s.messages.last.text;

  test('starts with the greeting and the email question', () {
    final bloc = build();
    expect(bloc.state.stage, Stage.email);
    expect(bloc.state.messages.map((m) => m.fromKraken), [true, true]);
    expect(last(bloc.state), contains("What's your email address?"));
    bloc.close();
  });

  blocTest<OnboardingBloc, OnboardingChatState>(
    'a bad email echoes, answers, and buzzes an error',
    build: build,
    act: (bloc) => bloc.add(const OnboardingTextSubmitted('nope')),
    expect: () => [
      isA<OnboardingChatState>()
          .having((s) => s.messages.last.text, 'echo', 'nope')
          .having((s) => s.typing, 'typing', true),
      isA<OnboardingChatState>().having(last, 'reply', contains("doesn't look like an email")),
      isA<OnboardingChatState>().having((s) => s.typing, 'typing', false).having((s) => s.stage, 'stage', Stage.email),
    ],
    verify: (_) => expect(haptics.played, [HapticKind.error]),
  );

  blocTest<OnboardingBloc, OnboardingChatState>(
    'a good email gets a code sent and moves to the code step',
    build: build,
    act: (bloc) => bloc.add(const OnboardingTextSubmitted('Aarav@Example.com')),
    verify: (bloc) {
      expect(bloc.state.stage, Stage.code);
      expect(last(bloc.state), contains('sent a 6-digit code to aarav@example.com'));
      expect(bloc.state.chips, [OnboardingChip.resendCode, OnboardingChip.differentEmail]);
      expect(services.devTools.inbox!.value!.to, 'aarav@example.com');
    },
  );

  blocTest<OnboardingBloc, OnboardingChatState>(
    'input sent while Kraken is answering is dropped, not queued',
    build: build,
    act: (bloc) {
      bloc
        ..add(const OnboardingTextSubmitted('aarav@example.com'))
        ..add(const OnboardingTextSubmitted('123456'));
    },
    verify: (bloc) {
      expect(bloc.state.stage, Stage.code);
      expect(bloc.state.messages.where((m) => !m.fromKraken).map((m) => m.text), ['aarav@example.com']);
    },
  );

  blocTest<OnboardingBloc, OnboardingChatState>(
    'the right code signs in and asks for a name',
    build: build,
    act: (bloc) async {
      bloc.add(const OnboardingTextSubmitted('aarav@example.com'));
      await Future<void>.delayed(Duration.zero);
      bloc.add(OnboardingTextSubmitted(services.devTools.inbox!.value!.code));
    },
    wait: const Duration(milliseconds: 10),
    verify: (bloc) {
      expect(bloc.state.stage, Stage.name);
      expect(services.auth.currentUser?.email.value, 'aarav@example.com');
      expect(haptics.played, contains(HapticKind.success));
    },
  );

  blocTest<OnboardingBloc, OnboardingChatState>(
    'Read the policy raises a one-off notice that clears',
    build: build,
    seed: () => const OnboardingChatState(
      machine: OnboardingState(stage: Stage.privacy, uid: 'u1', displayName: 'Aarav', adult: true),
      messages: [],
      chips: [OnboardingChip.privacyAgree, OnboardingChip.privacyRead],
    ),
    act: (bloc) async {
      bloc.add(const OnboardingChipPicked(OnboardingChip.privacyRead));
      await Future<void>.delayed(Duration.zero);
      bloc.add(const OnboardingNoticeShown());
    },
    verify: (bloc) => expect(bloc.state.notice, isNull),
    expect: () => containsAll([
      isA<OnboardingChatState>().having((s) => s.notice, 'notice', contains('Privacy Policy: https://')),
    ]),
  );
}
