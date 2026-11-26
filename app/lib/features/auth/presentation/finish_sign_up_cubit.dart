import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/analytics/consent_gated_analytics.dart';
import '../../../core/analytics/events.dart';
import '../../../core/time/clock.dart';
import '../../profile/domain/profile_repository.dart';
import '../../profile/domain/user_profile.dart';
import '../../profile/domain/value_objects.dart';
import '../domain/auth_repository.dart';

final class FinishSignUpState {
  const FinishSignUpState({this.saving = false, this.nameError, this.saveError});
  final bool saving;
  final String? nameError;

  /// Saving didn't work (offline, or the server refused); shown once.
  final String? saveError;
}

/// The last step of signing up on the form (after email, Apple or Google):
/// a name, 18 or older, the Terms and Privacy Policy, and usage stats. The
/// same facts the chat collects, so either way ends in the same profile.
class FinishSignUpCubit extends Cubit<FinishSignUpState> {
  FinishSignUpCubit({
    required this._auth,
    required this._profiles,
    required this._analytics,
    required this._clock,
    required this._policyVersion,
  }) : super(const FinishSignUpState());

  final AuthRepository _auth;
  final ProfileRepository _profiles;
  final ConsentGatedAnalytics _analytics;
  final Clock _clock;
  final String _policyVersion;

  /// Saves the profile; the session then counts as signed up and the router
  /// opens Home. The button stays disabled until [adult] and [agreed].
  Future<void> submit({
    required String name,
    required bool adult,
    required bool agreed,
    required bool shareStats,
  }) async {
    final uid = _auth.currentUser?.uid;
    if (state.saving || uid == null || !adult || !agreed) return;
    final displayName = DisplayName.tryParse(name);
    if (displayName == null) {
      emit(const FinishSignUpState(nameError: 'Enter the name your friends will see.'));
      return;
    }
    emit(const FinishSignUpState(saving: true));
    try {
      final now = _clock();
      final current = await _profiles.fetch(uid) ?? UserProfile(uid: uid);
      await _profiles.save(
        current.copyWith(
          displayName: displayName.value,
          adultConfirmedAt: now,
          privacyAcceptedAt: now,
          privacyPolicyVersion: _policyVersion,
        ),
      );
    } on Object {
      if (!isClosed) {
        emit(const FinishSignUpState(saveError: "Couldn't save. Check your connection and try again."));
      }
      return;
    }
    // Recorded only once the profile is saved, so a retry doesn't log twice.
    await _analytics.setConsent(shareStats ? AnalyticsConsent.granted : AnalyticsConsent.denied);
    _analytics
      ..log(const ConsentRecorded(kind: 'adult', granted: true))
      ..log(const ConsentRecorded(kind: 'privacy', granted: true))
      ..log(ConsentRecorded(kind: 'analytics', granted: shareStats));
    if (!isClosed) emit(const FinishSignUpState());
  }
}
