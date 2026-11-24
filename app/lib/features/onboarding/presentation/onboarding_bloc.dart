import 'package:bloc_concurrency/bloc_concurrency.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../app/session.dart';
import '../../../core/analytics/consent_gated_analytics.dart';
import '../../../core/analytics/events.dart';
import '../../../core/haptics/haptics.dart';
import '../../../core/result/result.dart';
import '../../../core/storage/key_value_store.dart';
import '../../../core/time/clock.dart';
import '../../auth/domain/auth_repository.dart';
import '../../profile/domain/profile_repository.dart';
import '../../profile/domain/user_profile.dart';
import '../domain/onboarding_machine.dart';
import 'onboarding_copy.dart';

// ---- Events ----

sealed class OnboardingEvent {
  const OnboardingEvent();
}

/// Something the person did. These share one handler that drops new input
/// while the previous one is still being answered (no double sends).
sealed class OnboardingUserEvent extends OnboardingEvent {
  const OnboardingUserEvent();
}

final class OnboardingTextSubmitted extends OnboardingUserEvent {
  const OnboardingTextSubmitted(this.text);
  final String text;
}

final class OnboardingChipPicked extends OnboardingUserEvent {
  const OnboardingChipPicked(this.chip);
  final OnboardingChip chip;
}

final class OnboardingNoticeShown extends OnboardingEvent {
  const OnboardingNoticeShown();
}

// ---- State ----

final class ChatEntry {
  const ChatEntry(this.fromKraken, this.text);
  final bool fromKraken;
  final String text;
}

final class OnboardingChatState {
  const OnboardingChatState({
    required this.machine,
    required this.messages,
    required this.chips,
    this.typing = false,
    this.notice,
  });

  final OnboardingState machine;
  final List<ChatEntry> messages;
  final List<OnboardingChip> chips;

  /// Kraken is "typing" or waiting on the server.
  final bool typing;

  /// A one-off message for a toast (e.g. the policy link).
  final String? notice;

  Stage get stage => machine.stage;
  bool get canInteract => !typing && !machine.isBusy;

  OnboardingChatState copyWith({
    OnboardingState? machine,
    List<ChatEntry>? messages,
    List<OnboardingChip>? chips,
    bool? typing,
    String? notice,
    bool clearNotice = false,
  }) => OnboardingChatState(
    machine: machine ?? this.machine,
    messages: messages ?? this.messages,
    chips: chips ?? this.chips,
    typing: typing ?? this.typing,
    notice: clearNotice ? null : (notice ?? this.notice),
  );
}

// ---- Bloc ----

/// Runs the sign-up chat: feeds events to [OnboardingMachine], paces
/// Kraken's replies, performs effects, and reports analytics and haptics.
class OnboardingBloc extends Bloc<OnboardingEvent, OnboardingChatState> {
  OnboardingBloc({
    required SessionState session,
    required this._auth,
    required this._profiles,
    required ConsentGatedAnalytics analytics,
    required this._haptics,
    required this._store,
    required Clock clock,
    required String policyVersion,
    required this._privacyPolicyUrl,
    this._pacing = const Duration(milliseconds: 700),
  }) : _analytics = analytics,
       _clock = clock,
       _policyVersion = policyVersion,
       _machine = OnboardingMachine(policyVersion: policyVersion),
       _startedAt = clock(),
       super(_initial(OnboardingMachine(policyVersion: policyVersion), session, analytics)) {
    on<OnboardingUserEvent>(_onUserEvent, transformer: droppable());
    on<OnboardingNoticeShown>((_, emit) => emit(state.copyWith(clearNotice: true)));
    _analytics.log(OnboardingStepViewed(state.stage.name));
  }

  final AuthRepository _auth;
  final ProfileRepository _profiles;
  final ConsentGatedAnalytics _analytics;
  final Haptics _haptics;
  final KeyValueStore _store;
  final Clock _clock;
  final String _policyVersion;
  final Uri _privacyPolicyUrl;
  final Duration _pacing;
  final OnboardingMachine _machine;
  final DateTime _startedAt;

  static OnboardingChatState _initial(
    OnboardingMachine machine,
    SessionState session,
    ConsentGatedAnalytics analytics,
  ) {
    final started = Started(
      user: switch (session) {
        OnboardingSession(:final user) || ReadySession(:final user) => user,
        _ => null,
      },
      profile: switch (session) {
        OnboardingSession(:final profile) => profile,
        ReadySession(:final profile) => profile,
        _ => null,
      },
      analyticsAnswered: analytics.consent != AnalyticsConsent.unknown,
    );
    final step = machine.reduce(const OnboardingState(), started);
    return OnboardingChatState(
      machine: step.state,
      messages: [for (final l in step.say) ChatEntry(true, OnboardingCopy.say(l))],
      chips: machine.chipsFor(step.state),
    );
  }

  Future<void> _onUserEvent(OnboardingUserEvent event, Emitter<OnboardingChatState> emit) async {
    if (!state.canInteract) return;
    switch (event) {
      case OnboardingTextSubmitted(:final text):
        if (!state.machine.acceptsText) return;
        await _dispatch(TextSubmitted(text), emit);
      case OnboardingChipPicked(:final chip):
        if (chip == OnboardingChip.skipUpi) _analytics.log(const UpiStepFinished(added: false));
        await _dispatch(ChipPicked(chip), emit);
    }
  }

  Future<void> _dispatch(OnboardingInput input, Emitter<OnboardingChatState> emit, {bool paced = true}) async {
    final before = state.machine;
    final step = _machine.reduce(before, input);
    final echo = switch (step.echo) {
      EchoText(:final text) => text,
      EchoChip(:final chip) => OnboardingCopy.chip(chip),
      null => null,
    };
    final waiting = step.effects.any((e) => e is RequestCode || e is VerifyCode);

    if (input is TextSubmitted && before.stage == Stage.email) {
      _analytics.log(SignInEmailSubmitted(valid: step.effects.any((e) => e is RequestCode)));
    }

    emit(
      state.copyWith(
        machine: step.state,
        messages: [...state.messages, if (echo != null) ChatEntry(false, echo)],
        chips: const [],
        typing: step.say.isNotEmpty || waiting,
      ),
    );

    if (step.say.isNotEmpty) {
      if (paced && _pacing > Duration.zero) await Future<void>.delayed(_pacing);
      if (emit.isDone) return;
      _playFor(step.say);
      emit(
        state.copyWith(
          messages: [...state.messages, for (final l in step.say) ChatEntry(true, OnboardingCopy.say(l))],
          typing: waiting,
        ),
      );
    }
    if (step.state.stage != before.stage) _analytics.log(OnboardingStepViewed(step.state.stage.name));
    if (!waiting) emit(state.copyWith(chips: _machine.chipsFor(step.state), typing: false));

    for (final effect in step.effects) {
      if (emit.isDone) return;
      await _run(effect, emit);
    }
  }

  void _playFor(List<BotLine> lines) {
    if (lines.any((l) => OnboardingCopy.errorLines.contains(l.line))) {
      _haptics.play(HapticKind.error);
    } else if (lines.any((l) => OnboardingCopy.successLines.contains(l.line))) {
      _haptics.play(HapticKind.success);
    }
  }

  Future<void> _run(OnboardingEffect effect, Emitter<OnboardingChatState> emit) async {
    switch (effect) {
      case RequestCode(:final email, :final resend):
        _analytics.log(SignInCodeRequested(resend: resend));
        await _store.setString(StoreKeys.pendingEmail, email.value);
        final result = await _auth.requestCode(email);
        if (emit.isDone) return;
        final next = switch (result) {
          Ok() => const CodeSent(),
          Err(:final failure) => CodeSendFailed(failure),
        };
        if (next is CodeSendFailed) _analytics.log(SignInFailed(next.failure.code));
        await _dispatch(next, emit, paced: false);
      case VerifyCode(:final email, :final code):
        final result = await _auth.verifyCode(email, code);
        if (emit.isDone) return;
        switch (result) {
          case Ok(:final value):
            final profile = await _profiles.fetch(value.uid);
            await _store.remove(StoreKeys.pendingEmail);
            _analytics.log(SignInCompleted(newUser: profile?.displayName == null));
            if (emit.isDone) return;
            await _dispatch(Verified(value, profile), emit, paced: false);
          case Err(:final failure):
            _analytics.log(SignInFailed(failure.code));
            await _dispatch(VerifyFailed(failure), emit, paced: false);
        }
      case SaveName(:final name):
        await _updateProfile((p) => p.copyWith(displayName: name.value));
      case ConfirmAdult():
        await _updateProfile((p) => p.copyWith(adultConfirmedAt: _clock()));
        _analytics.log(const ConsentRecorded(kind: 'adult', granted: true));
      case AcceptPrivacy():
        await _updateProfile((p) => p.copyWith(privacyAcceptedAt: _clock(), privacyPolicyVersion: _policyVersion));
        _analytics.log(const ConsentRecorded(kind: 'privacy', granted: true));
      case OpenPrivacyPolicy():
        emit(state.copyWith(notice: 'Privacy Policy: $_privacyPolicyUrl'));
      case SetAnalyticsConsent(:final granted):
        await _analytics.setConsent(granted ? AnalyticsConsent.granted : AnalyticsConsent.denied);
        _analytics.log(ConsentRecorded(kind: 'analytics', granted: granted));
      case SaveUpi(:final upi):
        await _updateProfile((p) => p.copyWith(upiId: upi.value));
        _analytics.log(const UpiStepFinished(added: true));
      case SaveInvite(:final invite):
        await _updateProfile((p) => p.copyWith(pendingInviteCode: invite.value));
      case SignOutNow():
        _analytics.log(const ConsentRecorded(kind: 'adult', granted: false));
        await _auth.signOut();
      case Completed(:final choice):
        _analytics.log(
          OnboardingCompleted(groupChoice: choice.name, seconds: _clock().difference(_startedAt).inSeconds),
        );
    }
  }

  Future<void> _updateProfile(UserProfile Function(UserProfile) change) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;
    final current = await _profiles.fetch(uid) ?? UserProfile(uid: uid);
    await _profiles.save(change(current));
  }
}
