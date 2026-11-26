import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/analytics/consent_gated_analytics.dart';
import '../../../core/analytics/events.dart';
import '../../../core/result/result.dart';
import '../../profile/domain/profile_repository.dart';
import '../../profile/domain/user_profile.dart';
import '../../profile/domain/value_objects.dart';
import '../domain/auth_repository.dart';
import '../domain/email_address.dart';
import '../domain/otp_code.dart';

enum LoginMode { logIn, signUp }

enum LoginStep { details, code }

/// What's in flight, so each button shows its own spinner.
enum LoginBusy { none, email, code, apple, google }

final class LoginState {
  const LoginState({
    this.mode = LoginMode.logIn,
    this.step = LoginStep.details,
    this.busy = LoginBusy.none,
    this.email,
    this.nameError,
    this.emailError,
    this.codeError,
    this.notice,
  });

  final LoginMode mode;
  final LoginStep step;
  final LoginBusy busy;

  /// Where the code went.
  final EmailAddress? email;
  final String? nameError;
  final String? emailError;
  final String? codeError;

  /// A one-off message for a toast (e.g. "New code sent").
  final String? notice;

  bool get isBusy => busy != LoginBusy.none;

  /// Errors and notices are cleared unless given again.
  LoginState copyWith({
    LoginMode? mode,
    LoginStep? step,
    LoginBusy? busy,
    EmailAddress? email,
    String? nameError,
    String? emailError,
    String? codeError,
    String? notice,
  }) => LoginState(
    mode: mode ?? this.mode,
    step: step ?? this.step,
    busy: busy ?? this.busy,
    email: email ?? this.email,
    nameError: nameError,
    emailError: emailError,
    codeError: codeError,
    notice: notice,
  );
}

/// The regular log-in / sign-up screen: Apple, Google, or an email code.
///
/// With email codes there's no password, so "log in" and "sign up" differ
/// only in asking for a name: an unknown email simply becomes a new account,
/// and a known one logs in. New accounts then finish on the sign-up form
/// (the router takes them there).
class LoginCubit extends Cubit<LoginState> {
  LoginCubit({required this._auth, required this._profiles, required this._analytics, required this._policyVersion})
    : super(const LoginState());

  final AuthRepository _auth;
  final ProfileRepository _profiles;
  final ConsentGatedAnalytics _analytics;
  final String _policyVersion;

  /// The name from the sign-up form, saved once signed in.
  String? _name;

  bool get _signUp => state.mode == LoginMode.signUp;

  void setMode(LoginMode mode) {
    if (state.isBusy || mode == state.mode) return;
    emit(state.copyWith(mode: mode, step: LoginStep.details));
  }

  Future<void> submitDetails({required String email, String name = ''}) async {
    if (state.isBusy) return;
    final address = EmailAddress.tryParse(email);
    final displayName = _signUp ? DisplayName.tryParse(name) : null;
    final nameError = _signUp && displayName == null ? 'Enter the name your friends will see.' : null;
    final emailError = address == null ? 'Enter an email address like name@example.com.' : null;
    _analytics.log(SignInEmailSubmitted(valid: address != null));
    if (nameError != null || emailError != null) {
      emit(state.copyWith(nameError: nameError, emailError: emailError));
      return;
    }
    _name = displayName?.value;
    _analytics.log(SignInMethodChosen('email', signUp: _signUp));
    emit(state.copyWith(busy: LoginBusy.email));
    final result = await _auth.requestCode(address!);
    if (isClosed) return;
    switch (result) {
      case Ok():
        _analytics.log(const SignInCodeRequested(resend: false));
        emit(state.copyWith(busy: LoginBusy.none, step: LoginStep.code, email: address));
      case Err(:final failure):
        _analytics.log(SignInFailed(failure.code));
        emit(state.copyWith(busy: LoginBusy.none, emailError: describe(failure)));
    }
  }

  Future<void> submitCode(String raw) async {
    final email = state.email;
    if (state.isBusy || email == null) return;
    final code = OtpCode.tryParse(raw);
    if (code == null) {
      emit(state.copyWith(codeError: 'Enter the 6 digits from the email.'));
      return;
    }
    emit(state.copyWith(busy: LoginBusy.code));
    final result = await _auth.verifyCode(email, code);
    if (isClosed) return;
    switch (result) {
      case Ok(:final value):
        await _signedIn(value, name: _name);
      case Err(:final failure):
        _analytics.log(SignInFailed(failure.code));
        emit(state.copyWith(busy: LoginBusy.none, codeError: describe(failure)));
    }
  }

  Future<void> resend() async {
    final email = state.email;
    if (state.isBusy || email == null) return;
    final result = await _auth.requestCode(email);
    if (isClosed) return;
    switch (result) {
      case Ok():
        _analytics.log(const SignInCodeRequested(resend: true));
        emit(state.copyWith(notice: 'New code sent to ${email.value}.'));
      case Err(:final failure):
        emit(state.copyWith(codeError: describe(failure)));
    }
  }

  void useDifferentEmail() {
    if (state.isBusy) return;
    emit(state.copyWith(step: LoginStep.details));
  }

  Future<void> continueWith(SocialProvider provider) async {
    if (state.isBusy) return;
    _analytics.log(SignInMethodChosen(provider.name, signUp: _signUp));
    emit(state.copyWith(busy: provider == SocialProvider.apple ? LoginBusy.apple : LoginBusy.google));
    final result = await _auth.signInWith(provider);
    if (isClosed) return;
    switch (result) {
      case Ok(:final value):
        await _signedIn(value, name: value.name);
      case Err(failure: SignInCancelled()):
        emit(state.copyWith(busy: LoginBusy.none));
      case Err(:final failure):
        _analytics.log(SignInFailed(failure.code));
        emit(state.copyWith(busy: LoginBusy.none, notice: describe(failure)));
    }
  }

  /// Keeps the name we already know, so sign-up doesn't ask again.
  ///
  /// The person is signed in by now, so a failure here (offline) mustn't
  /// block them: the name is just asked for again on "Almost done".
  Future<void> _signedIn(AppUser user, {String? name}) async {
    try {
      final profile = await _profiles.fetch(user.uid);
      final newUser = profile == null || !profile.isCompleteFor(_policyVersion);
      final known = name == null ? null : DisplayName.tryParse(name);
      if (newUser && known != null && profile?.displayName == null) {
        await _profiles.save((profile ?? UserProfile(uid: user.uid)).copyWith(displayName: known.value));
      }
      _analytics.log(SignInCompleted(newUser: newUser));
    } on Object {
      _analytics.log(const SignInFailed('profile_unavailable'));
    } finally {
      if (!isClosed) emit(state.copyWith(busy: LoginBusy.none));
    }
  }

  static String? describe(AuthFailure failure) => switch (failure) {
    WrongCode(:final attemptsLeft) =>
      "That code isn't right. $attemptsLeft ${attemptsLeft == 1 ? 'try' : 'tries'} left.",
    CodeExpired() => 'That code has expired. Send a new one.',
    CodeRejected() => "That code didn't work. Check the digits, or send a new one.",
    TooManyAttempts() => 'Too many tries. Send a new code.',
    ResendTooSoon(:final wait) => 'Wait ${wait.inSeconds + 1} seconds before asking for another code.',
    NoCodeRequested() => 'Ask for a code first.',
    AuthNetworkFailure() => "Couldn't reach Kraken. Check your connection and try again.",
    ProviderUnavailable(:final provider) =>
      "${provider == SocialProvider.apple ? 'Apple' : 'Google'} sign-in isn't set up yet. Use your email for now.",
    SignInCancelled() => null,
  };
}
