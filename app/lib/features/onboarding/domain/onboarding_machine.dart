// The sign-up chat as a pure state machine (build guide, Phase 1 day 3).
//
// `reduce(state, input)` returns the next state, what Kraken says, what the
// person's bubble shows, and the side effects to run. It does no I/O, so
// every step and error is unit-tested without Flutter or Firebase. The
// controller runs the effects and feeds their results back in as inputs.

import '../../auth/domain/auth_repository.dart';
import '../../auth/domain/email_address.dart';
import '../../auth/domain/otp_code.dart';
import '../../profile/domain/user_profile.dart';
import '../../profile/domain/value_objects.dart';

enum Stage { email, sendingCode, code, verifying, name, adult, privacy, analytics, upi, group, invite, done, blocked }

enum GroupChoice { invite, create, skip }

/// Quick-reply chips. Labels live in the presentation layer.
enum OnboardingChip {
  resendCode,
  differentEmail,
  retry,
  adultYes,
  adultNo,
  privacyAgree,
  privacyRead,
  analyticsYes,
  analyticsNo,
  skipUpi,
  haveInvite,
  createGroup,
  skipGroup,
  startOver,
}

/// Everything Kraken can say. Copy lives in the presentation layer.
enum Line {
  greet,
  askEmail,
  badEmail,
  codeSent,
  codeResent,
  badCodeShape,
  wrongCode,
  codeExpired,
  tooManyAttempts,
  resendTooSoon,
  askEmailAgain,
  network,
  verified,
  welcomeBack,
  resume,
  askName,
  badName,
  niceToMeetYou,
  askAdult,
  underAge,
  askPrivacy,
  policyPointer,
  askAnalytics,
  analyticsThanks,
  askUpi,
  badUpi,
  upiSaved,
  askGroup,
  askInvite,
  badInvite,
  inviteSaved,
  createGroupNext,
  allSet,
  allSetStart,
}

final class BotLine {
  const BotLine(this.line, {this.email, this.name, this.count});
  final Line line;
  final String? email;
  final String? name;
  final int? count;

  @override
  bool operator ==(Object other) =>
      other is BotLine && other.line == line && other.email == email && other.name == name && other.count == count;
  @override
  int get hashCode => Object.hash(line, email, name, count);
  @override
  String toString() => 'BotLine(${line.name})';
}

// ---- Inputs ----

sealed class OnboardingInput {
  const OnboardingInput();
}

/// Opening the screen. A signed-in person with an unfinished profile
/// (app closed mid-sign-up) resumes where they left off.
final class Started extends OnboardingInput {
  const Started({this.user, this.profile, this.analyticsAnswered = false});
  final AppUser? user;
  final UserProfile? profile;
  final bool analyticsAnswered;
}

final class TextSubmitted extends OnboardingInput {
  const TextSubmitted(this.text);
  final String text;
}

final class ChipPicked extends OnboardingInput {
  const ChipPicked(this.chip);
  final OnboardingChip chip;
}

final class CodeSent extends OnboardingInput {
  const CodeSent();
}

final class CodeSendFailed extends OnboardingInput {
  const CodeSendFailed(this.failure);
  final AuthFailure failure;
}

final class Verified extends OnboardingInput {
  const Verified(this.user, this.profile);
  final AppUser user;
  final UserProfile? profile;
}

final class VerifyFailed extends OnboardingInput {
  const VerifyFailed(this.failure);
  final AuthFailure failure;
}

// ---- Effects ----

sealed class OnboardingEffect {
  const OnboardingEffect();
}

final class RequestCode extends OnboardingEffect {
  const RequestCode(this.email, {required this.resend});
  final EmailAddress email;
  final bool resend;
}

final class VerifyCode extends OnboardingEffect {
  const VerifyCode(this.email, this.code);
  final EmailAddress email;
  final OtpCode code;
}

final class SaveName extends OnboardingEffect {
  const SaveName(this.name);
  final DisplayName name;
}

final class ConfirmAdult extends OnboardingEffect {
  const ConfirmAdult();
}

final class AcceptPrivacy extends OnboardingEffect {
  const AcceptPrivacy();
}

final class OpenPrivacyPolicy extends OnboardingEffect {
  const OpenPrivacyPolicy();
}

final class SetAnalyticsConsent extends OnboardingEffect {
  const SetAnalyticsConsent({required this.granted});
  final bool granted;
}

final class SaveUpi extends OnboardingEffect {
  const SaveUpi(this.upi);
  final UpiId upi;
}

final class SaveInvite extends OnboardingEffect {
  const SaveInvite(this.invite);
  final InviteCode invite;
}

final class SignOutNow extends OnboardingEffect {
  const SignOutNow();
}

final class Completed extends OnboardingEffect {
  const Completed(this.choice);
  final GroupChoice choice;
}

// ---- State ----

final class OnboardingState {
  const OnboardingState({
    this.stage = Stage.email,
    this.email,
    this.uid,
    this.displayName,
    this.adult = false,
    this.privacy = false,
    this.analyticsAnswered = false,
    this.upiAsked = false,
    this.isNewUser = true,
    this.groupChoice,
    this.resending = false,
    this.canRetrySend = false,
  });

  final Stage stage;
  final EmailAddress? email;
  final String? uid;
  final String? displayName;
  final bool adult;
  final bool privacy;
  final bool analyticsAnswered;
  final bool upiAsked;
  final bool isNewUser;
  final GroupChoice? groupChoice;
  final bool resending;

  /// The last code request failed on the network; offer "Try again".
  final bool canRetrySend;

  bool get isBusy => stage == Stage.sendingCode || stage == Stage.verifying;
  bool get acceptsText => const {Stage.email, Stage.code, Stage.name, Stage.upi, Stage.invite}.contains(stage);

  OnboardingState copyWith({
    Stage? stage,
    EmailAddress? email,
    bool clearEmail = false,
    String? uid,
    String? displayName,
    bool? adult,
    bool? privacy,
    bool? analyticsAnswered,
    bool? upiAsked,
    bool? isNewUser,
    GroupChoice? groupChoice,
    bool? resending,
    bool? canRetrySend,
  }) => OnboardingState(
    stage: stage ?? this.stage,
    email: clearEmail ? null : (email ?? this.email),
    uid: uid ?? this.uid,
    displayName: displayName ?? this.displayName,
    adult: adult ?? this.adult,
    privacy: privacy ?? this.privacy,
    analyticsAnswered: analyticsAnswered ?? this.analyticsAnswered,
    upiAsked: upiAsked ?? this.upiAsked,
    isNewUser: isNewUser ?? this.isNewUser,
    groupChoice: groupChoice ?? this.groupChoice,
    resending: resending ?? this.resending,
    canRetrySend: canRetrySend ?? this.canRetrySend,
  );
}

/// What the person's own bubble shows for an input, if anything.
sealed class Echo {
  const Echo();
}

final class EchoText extends Echo {
  const EchoText(this.text);
  final String text;
}

final class EchoChip extends Echo {
  const EchoChip(this.chip);
  final OnboardingChip chip;
}

final class Step {
  const Step(this.state, {this.say = const [], this.effects = const [], this.echo});
  final OnboardingState state;
  final List<BotLine> say;
  final List<OnboardingEffect> effects;
  final Echo? echo;
}

// ---- The machine ----

final class OnboardingMachine {
  const OnboardingMachine({required this.policyVersion});

  /// The privacy policy version the person must have accepted.
  final String policyVersion;

  Step reduce(OnboardingState s, OnboardingInput input) => switch (input) {
    Started() => _start(input),
    TextSubmitted(:final text) => _text(s, text),
    ChipPicked(:final chip) => _chip(s, chip),
    CodeSent() => Step(
      s.copyWith(stage: Stage.code, resending: false, canRetrySend: false),
      say: [BotLine(s.resending ? Line.codeResent : Line.codeSent, email: s.email?.value)],
    ),
    CodeSendFailed(:final failure) => _sendFailed(s, failure),
    Verified(:final user, :final profile) => _verified(s, user, profile),
    VerifyFailed(:final failure) => _verifyFailed(s, failure),
  };

  /// Chips offered in [s]. Empty while Kraken is busy.
  List<OnboardingChip> chipsFor(OnboardingState s) => switch (s.stage) {
    Stage.email => s.canRetrySend ? const [OnboardingChip.retry] : const [],
    Stage.code => const [OnboardingChip.resendCode, OnboardingChip.differentEmail],
    Stage.adult => const [OnboardingChip.adultYes, OnboardingChip.adultNo],
    Stage.privacy => const [OnboardingChip.privacyAgree, OnboardingChip.privacyRead],
    Stage.analytics => const [OnboardingChip.analyticsYes, OnboardingChip.analyticsNo],
    Stage.upi => const [OnboardingChip.skipUpi],
    Stage.group => const [OnboardingChip.haveInvite, OnboardingChip.createGroup, OnboardingChip.skipGroup],
    Stage.invite => const [OnboardingChip.skipGroup],
    Stage.blocked => const [OnboardingChip.startOver],
    Stage.sendingCode || Stage.verifying || Stage.name || Stage.done => const [],
  };

  Step _start(Started input) {
    final user = input.user;
    if (user == null) {
      return const Step(OnboardingState(), say: [BotLine(Line.greet), BotLine(Line.askEmail)]);
    }
    final base = _fromProfile(
      OnboardingState(email: user.email, uid: user.uid, analyticsAnswered: input.analyticsAnswered),
      input.profile,
    );
    return _advance(base, [BotLine(Line.resume, name: base.displayName)]);
  }

  OnboardingState _fromProfile(OnboardingState s, UserProfile? p) => s.copyWith(
    displayName: p?.displayName,
    adult: p?.adultConfirmedAt != null,
    privacy: p?.privacyAcceptedAt != null && p?.privacyPolicyVersion == policyVersion,
    isNewUser: p?.displayName == null,
    upiAsked: p?.upiId != null,
  );

  Step _text(OnboardingState s, String raw) {
    final text = raw.trim();
    if (text.isEmpty || !s.acceptsText) return Step(s);
    final echo = EchoText(text);
    switch (s.stage) {
      case Stage.email:
        final email = EmailAddress.tryParse(text);
        if (email == null) return Step(s, echo: echo, say: const [BotLine(Line.badEmail)]);
        return Step(
          s.copyWith(stage: Stage.sendingCode, email: email, resending: false, canRetrySend: false),
          echo: echo,
          effects: [RequestCode(email, resend: false)],
        );
      case Stage.code:
        final code = OtpCode.tryParse(text);
        if (code == null) return Step(s, echo: echo, say: const [BotLine(Line.badCodeShape)]);
        return Step(
          s.copyWith(stage: Stage.verifying),
          echo: echo,
          effects: [VerifyCode(s.email!, code)],
        );
      case Stage.name:
        final name = DisplayName.tryParse(text);
        if (name == null) return Step(s, echo: echo, say: const [BotLine(Line.badName)]);
        final next = _advance(s.copyWith(displayName: name.value), [BotLine(Line.niceToMeetYou, name: name.value)]);
        return Step(next.state, echo: echo, say: next.say, effects: [SaveName(name), ...next.effects]);
      case Stage.upi:
        final upi = UpiId.tryParse(text);
        if (upi == null) return Step(s, echo: echo, say: const [BotLine(Line.badUpi)]);
        final next = _advance(s.copyWith(upiAsked: true), const [BotLine(Line.upiSaved)]);
        return Step(next.state, echo: echo, say: next.say, effects: [SaveUpi(upi), ...next.effects]);
      case Stage.invite:
        final invite = InviteCode.tryParse(text);
        if (invite == null) return Step(s, echo: echo, say: const [BotLine(Line.badInvite)]);
        return Step(
          s.copyWith(stage: Stage.done, groupChoice: GroupChoice.invite),
          echo: echo,
          say: const [BotLine(Line.inviteSaved), BotLine(Line.allSet)],
          effects: [SaveInvite(invite), const Completed(GroupChoice.invite)],
        );
      case Stage.sendingCode ||
          Stage.verifying ||
          Stage.adult ||
          Stage.privacy ||
          Stage.analytics ||
          Stage.group ||
          Stage.done ||
          Stage.blocked:
        return Step(s);
    }
  }

  Step _chip(OnboardingState s, OnboardingChip chip) {
    if (!chipsFor(s).contains(chip)) return Step(s);
    final echo = EchoChip(chip);
    switch (chip) {
      case OnboardingChip.resendCode:
        return Step(
          s.copyWith(stage: Stage.sendingCode, resending: true),
          echo: echo,
          effects: [RequestCode(s.email!, resend: true)],
        );
      case OnboardingChip.retry:
        return Step(
          s.copyWith(stage: Stage.sendingCode, canRetrySend: false),
          echo: echo,
          effects: [RequestCode(s.email!, resend: s.resending)],
        );
      case OnboardingChip.differentEmail:
        return Step(
          s.copyWith(stage: Stage.email, clearEmail: true),
          echo: echo,
          say: const [BotLine(Line.askEmailAgain)],
        );
      case OnboardingChip.adultYes:
        final next = _advance(s.copyWith(adult: true), const []);
        return Step(next.state, echo: echo, say: next.say, effects: [const ConfirmAdult(), ...next.effects]);
      case OnboardingChip.adultNo:
        return Step(
          const OnboardingState(stage: Stage.blocked),
          echo: echo,
          say: const [BotLine(Line.underAge)],
          effects: const [SignOutNow()],
        );
      case OnboardingChip.privacyAgree:
        final next = _advance(s.copyWith(privacy: true), const []);
        return Step(next.state, echo: echo, say: next.say, effects: [const AcceptPrivacy(), ...next.effects]);
      case OnboardingChip.privacyRead:
        return Step(s, echo: echo, say: const [BotLine(Line.policyPointer)], effects: const [OpenPrivacyPolicy()]);
      case OnboardingChip.analyticsYes || OnboardingChip.analyticsNo:
        final granted = chip == OnboardingChip.analyticsYes;
        final next = _advance(s.copyWith(analyticsAnswered: true), [if (granted) const BotLine(Line.analyticsThanks)]);
        return Step(
          next.state,
          echo: echo,
          say: next.say,
          effects: [
            SetAnalyticsConsent(granted: granted),
            ...next.effects,
          ],
        );
      case OnboardingChip.skipUpi:
        final next = _advance(s.copyWith(upiAsked: true), const []);
        return Step(next.state, echo: echo, say: next.say, effects: next.effects);
      case OnboardingChip.haveInvite:
        return Step(
          s.copyWith(stage: Stage.invite),
          echo: echo,
          say: const [BotLine(Line.askInvite)],
        );
      case OnboardingChip.createGroup:
        return Step(
          s.copyWith(stage: Stage.done, groupChoice: GroupChoice.create),
          echo: echo,
          say: const [BotLine(Line.createGroupNext), BotLine(Line.allSetStart)],
          effects: const [Completed(GroupChoice.create)],
        );
      case OnboardingChip.skipGroup:
        return Step(
          s.copyWith(stage: Stage.done, groupChoice: GroupChoice.skip),
          echo: echo,
          say: const [BotLine(Line.allSet)],
          effects: const [Completed(GroupChoice.skip)],
        );
      case OnboardingChip.startOver:
        return Step(const OnboardingState(), echo: echo, say: const [BotLine(Line.askEmail)]);
    }
  }

  Step _sendFailed(OnboardingState s, AuthFailure failure) => switch (failure) {
    ResendTooSoon(:final wait) => Step(
      s.copyWith(stage: Stage.code, resending: false),
      say: [BotLine(Line.resendTooSoon, count: wait.inSeconds.clamp(1, 3600))],
    ),
    _ => Step(
      // A first send that failed goes back to the email step with a
      // retry chip; a failed resend stays on the code step.
      s.copyWith(stage: s.resending ? Stage.code : Stage.email, canRetrySend: !s.resending),
      say: const [BotLine(Line.network)],
    ),
  };

  Step _verified(OnboardingState s, AppUser user, UserProfile? profile) {
    final known = _fromProfile(s.copyWith(uid: user.uid, email: user.email), profile);
    return _advance(known, [
      const BotLine(Line.verified),
      if (!known.isNewUser) BotLine(Line.welcomeBack, name: known.displayName),
    ]);
  }

  Step _verifyFailed(OnboardingState s, AuthFailure failure) {
    final back = s.copyWith(stage: Stage.code);
    return switch (failure) {
      WrongCode(:final attemptsLeft) => Step(back, say: [BotLine(Line.wrongCode, count: attemptsLeft)]),
      CodeExpired() || NoCodeRequested() => Step(back, say: const [BotLine(Line.codeExpired)]),
      TooManyAttempts() => Step(back, say: const [BotLine(Line.tooManyAttempts)]),
      AuthNetworkFailure() || ResendTooSoon() => Step(back, say: const [BotLine(Line.network)]),
    };
  }

  /// Asks the next missing question, or finishes. Order: name, 18+,
  /// privacy, usage stats, then (new people only) UPI ID and groups.
  Step _advance(OnboardingState s, List<BotLine> before) {
    Step ask(Stage stage, BotLine line) => Step(s.copyWith(stage: stage), say: [...before, line]);
    if (s.displayName == null) return ask(Stage.name, const BotLine(Line.askName));
    if (!s.adult) return ask(Stage.adult, const BotLine(Line.askAdult));
    if (!s.privacy) return ask(Stage.privacy, const BotLine(Line.askPrivacy));
    if (!s.analyticsAnswered) return ask(Stage.analytics, const BotLine(Line.askAnalytics));
    if (s.isNewUser && !s.upiAsked) return ask(Stage.upi, const BotLine(Line.askUpi));
    if (s.isNewUser && s.groupChoice == null) return ask(Stage.group, const BotLine(Line.askGroup));
    final choice = s.groupChoice ?? GroupChoice.skip;
    return Step(
      s.copyWith(stage: Stage.done, groupChoice: choice),
      say: [...before, const BotLine(Line.allSet)],
      effects: [Completed(choice)],
    );
  }
}
