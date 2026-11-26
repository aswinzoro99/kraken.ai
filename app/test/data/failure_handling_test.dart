import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:kraken/app/session.dart';
import 'package:kraken/core/analytics/analytics.dart';
import 'package:kraken/core/analytics/consent_gated_analytics.dart';
import 'package:kraken/core/crash/crash_reporter.dart';
import 'package:kraken/core/result/result.dart';
import 'package:kraken/core/storage/key_value_store.dart';
import 'package:kraken/features/auth/data/mock_auth_repository.dart';
import 'package:kraken/features/auth/data/mock_inbox.dart';
import 'package:kraken/features/auth/domain/auth_repository.dart';
import 'package:kraken/features/auth/domain/email_address.dart';
import 'package:kraken/features/auth/domain/otp_code.dart';
import 'package:kraken/features/auth/presentation/finish_sign_up_cubit.dart';
import 'package:kraken/features/auth/presentation/login_cubit.dart';
import 'package:kraken/features/profile/data/supabase_profile_repository.dart';
import 'package:kraken/features/profile/domain/profile_repository.dart';
import 'package:kraken/features/profile/domain/user_profile.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show SupabaseClient;

/// Sign-in whose user stream the test drives, errors included.
final class ScriptedAuth implements AuthRepository {
  final users = StreamController<AppUser?>.broadcast();
  @override
  AppUser? currentUser;
  @override
  Stream<AppUser?> watchUser() => users.stream;
  @override
  Future<Result<void, AuthFailure>> requestCode(EmailAddress email) async => const Ok(null);
  @override
  Future<Result<AppUser, AuthFailure>> verifyCode(EmailAddress email, OtpCode code) async => const Err(CodeRejected());
  @override
  Future<Result<AppUser, AuthFailure>> signInWith(SocialProvider provider) async => Err(ProviderUnavailable(provider));
  @override
  Future<void> signOut() async => users.add(null);
  @override
  Future<void> deleteAccount() async {}
}

/// Profiles whose stream and calls the test controls.
final class ScriptedProfiles implements ProfileRepository {
  final profiles = StreamController<UserProfile?>.broadcast();
  bool failFetch = false;
  bool failSave = false;
  final saved = <UserProfile>[];
  @override
  Future<UserProfile?> fetch(String uid) async => failFetch ? throw StateError('offline') : UserProfile(uid: uid);
  @override
  Stream<UserProfile?> watch(String uid) => profiles.stream;
  @override
  Future<void> save(UserProfile profile) async {
    if (failSave) throw StateError('offline');
    saved.add(profile);
  }

  @override
  Future<void> delete(String uid) async {}
}

final class SilentCrash implements CrashReporter {
  final errors = <Object>[];
  @override
  Future<void> recordError(Object error, StackTrace? stack, {bool fatal = false, String? reason}) async =>
      errors.add(error);
  @override
  void breadcrumb(String message) {}
  @override
  Future<void> setUserId(String? uid) async {}
}

ConsentGatedAnalytics analytics(RecordingAnalytics recorder) =>
    ConsentGatedAnalytics(recorder, initial: AnalyticsConsent.granted, onConsentChanged: (_) {});

final user = AppUser(uid: 'u1', email: EmailAddress.tryParse('a@example.com')!);

http.Response answer(http.BaseRequest request, Object body, {int status = 200}) =>
    http.Response(jsonEncode(body), status, request: request, headers: {'content-type': 'application/json'});

Map<String, Object?> row(String? name) => {
  'id': 'u1',
  'email': 'a@example.com',
  'display_name': name,
  'upi_id': null,
  'adult_confirmed_at': null,
  'privacy_accepted_at': null,
  'privacy_policy_version': null,
};

void main() {
  group('the session keeps following sign-in after errors', () {
    late ScriptedAuth auth;
    late ScriptedProfiles profiles;
    late SilentCrash crash;
    late SessionCubit session;

    setUp(() {
      auth = ScriptedAuth();
      profiles = ScriptedProfiles();
      crash = SilentCrash();
      session = SessionCubit(
        auth: auth,
        profiles: profiles,
        analytics: RecordingAnalytics(),
        crash: crash,
        policyVersion: 'v1',
      );
    });
    tearDown(() => session.close());

    test('an error on the sign-in stream doesn\'t stop sign-out from registering', () async {
      auth.users.add(user);
      await pumpEventQueue();
      profiles.profiles.add(null);
      await pumpEventQueue();
      expect(session.state, isA<OnboardingSession>());

      auth.users.addError(StateError('refresh failed offline'));
      await pumpEventQueue();
      auth.users.add(null);
      await pumpEventQueue();
      expect(session.state, isA<SignedOutSession>(), reason: 'sign-out still registers after the error');
      expect(crash.errors, hasLength(1));
    });

    test('an error on the profile stream is reported, and a later profile still lands', () async {
      auth.users.add(user);
      await pumpEventQueue();
      profiles.profiles.addError(StateError('offline'));
      await pumpEventQueue();
      final now = DateTime(2026);
      profiles.profiles.add(
        UserProfile(
          uid: 'u1',
          displayName: 'Aarav',
          adultConfirmedAt: now,
          privacyAcceptedAt: now,
          privacyPolicyVersion: 'v1',
        ),
      );
      await pumpEventQueue();
      expect(session.state, isA<ReadySession>());
      expect(crash.errors, hasLength(1));
    });
  });

  group('Supabase profiles', () {
    // The Supabase library retries 5xx answers itself; what reaches the
    // repository is a refusal it won't retry, like this one.
    test('a failed first load is retried instead of ending the stream', () async {
      var calls = 0;
      final client = SupabaseClient(
        'https://example.supabase.co',
        'anon',
        httpClient: MockClient((request) async {
          calls++;
          if (calls == 1) return answer(request, {'message': 'JWT expired', 'code': 'PGRST301'}, status: 401);
          return answer(request, [row('Aarav')]);
        }),
      );
      addTearDown(client.dispose);
      final repo = SupabaseProfileRepository(client, retryDelay: Duration.zero);
      final first = await repo.watch('u1').first;
      expect(first?.displayName, 'Aarav');
      expect(calls, 2);
    });

    test('a save made while the first load is in flight still arrives', () async {
      final slowLoad = Completer<Object>();
      final client = SupabaseClient(
        'https://example.supabase.co',
        'anon',
        httpClient: MockClient((request) async {
          if (request.method == 'GET') return answer(request, await slowLoad.future);
          return answer(request, row('Asha'));
        }),
      );
      addTearDown(client.dispose);
      final repo = SupabaseProfileRepository(client, retryDelay: Duration.zero);
      final seen = <String?>[];
      final sub = repo.watch('u1').listen((p) => seen.add(p?.displayName));
      addTearDown(sub.cancel);
      await pumpEventQueue();

      await repo.save(const UserProfile(uid: 'u1', displayName: 'Asha'));
      slowLoad.complete([row(null)]);
      await pumpEventQueue();
      expect(seen, [null, 'Asha'], reason: 'the load, then the newer save');
    });
  });

  test('finishing sign-up: a failed save stops the spinner and says so', () async {
    final auth = MockAuthRepository(store: MemoryStore(), inbox: MockInbox(), latency: Duration.zero);
    await auth.signInWith(SocialProvider.google);
    final profiles = ScriptedProfiles()..failSave = true;
    final recorder = RecordingAnalytics();
    final cubit = FinishSignUpCubit(
      auth: auth,
      profiles: profiles,
      analytics: analytics(recorder),
      clock: () => DateTime(2026),
      policyVersion: 'v1',
    );
    addTearDown(cubit.close);
    await cubit.submit(name: 'Aarav', adult: true, agreed: true, shareStats: false);
    expect(cubit.state.saving, isFalse);
    expect(cubit.state.saveError, contains("Couldn't save"));
    expect(recorder.names, isNot(contains('consent_recorded')), reason: 'consents count only once saved');

    profiles.failSave = false;
    await cubit.submit(name: 'Aarav', adult: true, agreed: true, shareStats: false);
    expect(cubit.state.saveError, isNull);
    expect(profiles.saved.single.displayName, 'Aarav');
  });

  test('a good code with the profile unreachable still stops the spinner', () async {
    final inbox = MockInbox();
    final auth = MockAuthRepository(store: MemoryStore(), inbox: inbox, latency: Duration.zero);
    final recorder = RecordingAnalytics();
    final cubit = LoginCubit(
      auth: auth,
      profiles: ScriptedProfiles()..failFetch = true,
      analytics: analytics(recorder),
      policyVersion: 'v1',
    );
    addTearDown(cubit.close);
    cubit.setMode(LoginMode.signUp);
    await cubit.submitDetails(email: 'a@example.com', name: 'Aarav');
    await cubit.submitCode(inbox.value!.code);
    expect(auth.currentUser, isNotNull, reason: 'signed in all the same');
    expect(cubit.state.busy, LoginBusy.none);
    expect(recorder.names, contains('sign_in_failed'));
  });
}
