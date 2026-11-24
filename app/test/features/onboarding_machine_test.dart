import 'package:flutter_test/flutter_test.dart';
import 'package:kraken/features/auth/domain/auth_repository.dart';
import 'package:kraken/features/auth/domain/email_address.dart';
import 'package:kraken/features/onboarding/domain/onboarding_machine.dart';
import 'package:kraken/features/profile/domain/user_profile.dart';

const policy = '2026-11-24';
const m = OnboardingMachine(policyVersion: policy);
final email = EmailAddress.tryParse('aarav@example.com')!;
final user = AppUser(uid: 'u1', email: email);

List<Line> lines(Step s) => [for (final b in s.say) b.line];

/// Runs inputs from a fresh start and returns the last step.
Step run(List<OnboardingInput> inputs, {Started start = const Started()}) {
  var step = m.reduce(const OnboardingState(), start);
  for (final i in inputs) {
    step = m.reduce(step.state, i);
  }
  return step;
}

final toCode = <OnboardingInput>[const TextSubmitted('aarav@example.com'), const CodeSent()];
final toName = [...toCode, const TextSubmitted('482913'), Verified(user, null)];

void main() {
  group('email step', () {
    test('greets and asks for an email', () {
      final s = m.reduce(const OnboardingState(), const Started());
      expect(s.state.stage, Stage.email);
      expect(lines(s), [Line.greet, Line.askEmail]);
    });

    test('rejects a bad email and stays', () {
      final s = run([const TextSubmitted('aarav at gmail')]);
      expect(s.state.stage, Stage.email);
      expect(lines(s), [Line.badEmail]);
      expect(s.echo, isA<EchoText>());
      expect(s.effects, isEmpty);
    });

    test('a good email sends a code, normalised', () {
      final s = run([const TextSubmitted(' Aarav@Example.com ')]);
      expect(s.state.stage, Stage.sendingCode);
      final effect = s.effects.single as RequestCode;
      expect(effect.email.value, 'aarav@example.com');
      expect(effect.resend, isFalse);
    });

    test('ignores text while busy', () {
      final s = run([const TextSubmitted('aarav@example.com'), const TextSubmitted('again@example.com')]);
      expect(s.effects, isEmpty);
      expect(s.echo, isNull);
    });

    test('a network failure offers Try again', () {
      final s = run([const TextSubmitted('aarav@example.com'), const CodeSendFailed(AuthNetworkFailure())]);
      expect(s.state.stage, Stage.email);
      expect(lines(s), [Line.network]);
      expect(m.chipsFor(s.state), [OnboardingChip.retry]);
      final retry = m.reduce(s.state, const ChipPicked(OnboardingChip.retry));
      expect(retry.effects.single, isA<RequestCode>());
    });
  });

  group('code step', () {
    test('code sent names the email and offers resend or change', () {
      final s = run(toCode);
      expect(s.state.stage, Stage.code);
      expect(s.say.single, const BotLine(Line.codeSent, email: 'aarav@example.com'));
      expect(m.chipsFor(s.state), [OnboardingChip.resendCode, OnboardingChip.differentEmail]);
    });

    test('rejects a code that is not 6 digits', () {
      expect(lines(run([...toCode, const TextSubmitted('1234')])), [Line.badCodeShape]);
    });

    test('a 6-digit code is verified', () {
      final s = run([...toCode, const TextSubmitted('482 913')]);
      expect(s.state.stage, Stage.verifying);
      expect((s.effects.single as VerifyCode).code.value, '482913');
    });

    test('wrong code says how many tries are left', () {
      final s = run([...toCode, const TextSubmitted('000000'), const VerifyFailed(WrongCode(2))]);
      expect(s.state.stage, Stage.code);
      expect(s.say.single, const BotLine(Line.wrongCode, count: 2));
    });

    test('expired, locked and offline codes each have a reply', () {
      Line after(AuthFailure f) => lines(run([...toCode, const TextSubmitted('000000'), VerifyFailed(f)])).single;
      expect(after(const CodeExpired()), Line.codeExpired);
      expect(after(const NoCodeRequested()), Line.codeExpired);
      expect(after(const TooManyAttempts()), Line.tooManyAttempts);
      expect(after(const AuthNetworkFailure()), Line.network);
    });

    test('resend sends again and says so', () {
      final picked = run([...toCode, const ChipPicked(OnboardingChip.resendCode)]);
      expect((picked.effects.single as RequestCode).resend, isTrue);
      final sent = m.reduce(picked.state, const CodeSent());
      expect(lines(sent), [Line.codeResent]);
    });

    test('resending too soon gives the wait in seconds', () {
      final s = run([
        ...toCode,
        const ChipPicked(OnboardingChip.resendCode),
        const CodeSendFailed(ResendTooSoon(Duration(seconds: 21))),
      ]);
      expect(s.state.stage, Stage.code);
      expect(s.say.single, const BotLine(Line.resendTooSoon, count: 21));
    });

    test('a different email goes back to the email step', () {
      final s = run([...toCode, const ChipPicked(OnboardingChip.differentEmail)]);
      expect(s.state.stage, Stage.email);
      expect(s.state.email, isNull);
      expect(lines(s), [Line.askEmailAgain]);
    });
  });

  group('profile steps', () {
    test('a new person is verified and asked their name', () {
      final s = run(toName);
      expect(s.state.stage, Stage.name);
      expect(lines(s), [Line.verified, Line.askName]);
    });

    test('rejects an empty-looking name', () {
      expect(lines(run([...toName, const TextSubmitted('123')])), [Line.badName]);
    });

    test('name, 18+, privacy, stats, UPI, then groups', () {
      var s = run([...toName, const TextSubmitted('Aarav')]);
      expect(s.state.stage, Stage.adult);
      expect(s.say.first, const BotLine(Line.niceToMeetYou, name: 'Aarav'));
      expect(s.effects.first, isA<SaveName>());

      s = m.reduce(s.state, const ChipPicked(OnboardingChip.adultYes));
      expect(s.state.stage, Stage.privacy);
      expect(s.effects.first, isA<ConfirmAdult>());

      final read = m.reduce(s.state, const ChipPicked(OnboardingChip.privacyRead));
      expect(read.state.stage, Stage.privacy);
      expect(read.effects.single, isA<OpenPrivacyPolicy>());

      s = m.reduce(s.state, const ChipPicked(OnboardingChip.privacyAgree));
      expect(s.state.stage, Stage.analytics);
      expect(s.effects.first, isA<AcceptPrivacy>());

      s = m.reduce(s.state, const ChipPicked(OnboardingChip.analyticsNo));
      expect(s.state.stage, Stage.upi);
      expect((s.effects.first as SetAnalyticsConsent).granted, isFalse);

      final badUpi = m.reduce(s.state, const TextSubmitted('aarav'));
      expect(lines(badUpi), [Line.badUpi]);
      s = m.reduce(s.state, const TextSubmitted('aarav@okaxis'));
      expect(s.state.stage, Stage.group);
      expect((s.effects.first as SaveUpi).upi.value, 'aarav@okaxis');
    });

    test('under 18 ends the sign-up and signs out', () {
      final s = run([...toName, const TextSubmitted('Aarav'), const ChipPicked(OnboardingChip.adultNo)]);
      expect(s.state.stage, Stage.blocked);
      expect(lines(s), [Line.underAge]);
      expect(s.effects.single, isA<SignOutNow>());
      final again = m.reduce(s.state, const ChipPicked(OnboardingChip.startOver));
      expect(again.state.stage, Stage.email);
    });

    test('chips that are not offered are ignored', () {
      final s = run([...toName, const ChipPicked(OnboardingChip.privacyAgree)]);
      expect(s.state.stage, Stage.name);
      expect(s.effects, isEmpty);
    });
  });

  group('group step', () {
    final toGroup = [
      ...toName,
      const TextSubmitted('Aarav'),
      const ChipPicked(OnboardingChip.adultYes),
      const ChipPicked(OnboardingChip.privacyAgree),
      const ChipPicked(OnboardingChip.analyticsYes),
      const ChipPicked(OnboardingChip.skipUpi),
    ];

    test('skip finishes', () {
      final s = run([...toGroup, const ChipPicked(OnboardingChip.skipGroup)]);
      expect(s.state.stage, Stage.done);
      expect(lines(s), [Line.allSet]);
      expect((s.effects.single as Completed).choice, GroupChoice.skip);
    });

    test('create finishes with the create choice', () {
      final s = run([...toGroup, const ChipPicked(OnboardingChip.createGroup)]);
      expect(lines(s), [Line.createGroupNext, Line.allSetStart]);
      expect((s.effects.single as Completed).choice, GroupChoice.create);
    });

    test('an invite link is checked and saved', () {
      final asked = run([...toGroup, const ChipPicked(OnboardingChip.haveInvite)]);
      expect(asked.state.stage, Stage.invite);
      expect(lines(m.reduce(asked.state, const TextSubmitted('hello'))), [Line.badInvite]);
      final s = m.reduce(asked.state, const TextSubmitted('https://kraken-prod.web.app/i/K7Q2XA'));
      expect(s.state.stage, Stage.done);
      expect((s.effects.first as SaveInvite).invite.value, 'K7Q2XA');
    });
  });

  group('returning people', () {
    final complete = UserProfile(
      uid: 'u1',
      displayName: 'Aarav',
      adultConfirmedAt: DateTime(2026),
      privacyAcceptedAt: DateTime(2026),
      privacyPolicyVersion: policy,
    );

    test('skip straight to done, asking only for missing stats consent', () {
      final s = run([...toCode, const TextSubmitted('482913'), Verified(user, complete)]);
      expect(lines(s), [Line.verified, Line.welcomeBack, Line.askAnalytics]);
      final done = m.reduce(s.state, const ChipPicked(OnboardingChip.analyticsYes));
      expect(done.state.stage, Stage.done);
      expect(lines(done), [Line.analyticsThanks, Line.allSet]);
    });

    test('are asked again when the privacy policy changes', () {
      final old = UserProfile(
        uid: 'u1',
        displayName: 'Aarav',
        adultConfirmedAt: DateTime(2026),
        privacyAcceptedAt: DateTime(2025),
        privacyPolicyVersion: '2025-01-01',
      );
      final s = run([...toCode, const TextSubmitted('482913'), Verified(user, old)]);
      expect(s.state.stage, Stage.privacy);
    });

    test('resume an unfinished sign-up after a restart', () {
      final s = m.reduce(
        const OnboardingState(),
        Started(
          user: user,
          profile: const UserProfile(uid: 'u1', displayName: 'Aarav'),
        ),
      );
      expect(s.state.stage, Stage.adult);
      expect(s.say.first, const BotLine(Line.resume, name: 'Aarav'));
    });
  });
}
