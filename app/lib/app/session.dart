import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../core/analytics/analytics.dart';
import '../core/crash/crash_reporter.dart';
import '../features/auth/domain/auth_repository.dart';
import '../features/profile/domain/profile_repository.dart';
import '../features/profile/domain/user_profile.dart';

/// Who is using the app right now. The router decides where people can go
/// from this alone.
sealed class SessionState {
  const SessionState();
}

final class SessionLoading extends SessionState {
  const SessionLoading();
}

final class SignedOutSession extends SessionState {
  const SignedOutSession();
}

/// Signed in, but sign-up isn't finished (no name, 18+ or policy yet).
final class OnboardingSession extends SessionState {
  const OnboardingSession(this.user, this.profile);
  final AppUser user;
  final UserProfile? profile;
}

final class ReadySession extends SessionState {
  const ReadySession(this.user, this.profile);
  final AppUser user;
  final UserProfile profile;
}

extension SessionPerson on SessionState {
  /// The signed-in account, if any.
  String? get uid => switch (this) {
    ReadySession(:final user) || OnboardingSession(:final user) => user.uid,
    _ => null,
  };

  /// The name friends see, once given.
  String? get displayName => switch (this) {
    ReadySession(:final profile) => profile.displayName,
    OnboardingSession(:final profile) => profile?.displayName,
    _ => null,
  };
}

/// Follows the signed-in user and their profile.
class SessionCubit extends Cubit<SessionState> {
  SessionCubit({
    required AuthRepository auth,
    required this._profiles,
    required this._analytics,
    required this._crash,
    required this._policyVersion,
  }) : super(const SessionLoading()) {
    // Errors are reported, never fatal: the session must keep following.
    _userSub = auth.watchUser().listen(_onUser, onError: _report);
  }

  final ProfileRepository _profiles;
  final Analytics _analytics;
  final CrashReporter _crash;
  final String _policyVersion;
  late final StreamSubscription<AppUser?> _userSub;
  StreamSubscription<UserProfile?>? _profileSub;

  void _onUser(AppUser? user) {
    _profileSub?.cancel();
    _analytics.setUserId(user?.uid);
    _crash.setUserId(user?.uid);
    if (user == null) {
      emit(const SignedOutSession());
      return;
    }
    _profileSub = _profiles.watch(user.uid).listen((profile) {
      if (isClosed) return;
      emit(
        profile != null && profile.isCompleteFor(_policyVersion)
            ? ReadySession(user, profile)
            : OnboardingSession(user, profile),
      );
    }, onError: _report);
  }

  void _report(Object error, StackTrace stack) => _crash.recordError(error, stack, reason: 'session stream');

  @override
  Future<void> close() async {
    await _userSub.cancel();
    await _profileSub?.cancel();
    return super.close();
  }
}
