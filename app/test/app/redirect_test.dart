import 'package:flutter_test/flutter_test.dart';
import 'package:kraken/app/router.dart';
import 'package:kraken/app/routes.dart';
import 'package:kraken/app/session.dart';
import 'package:kraken/features/auth/domain/auth_repository.dart';
import 'package:kraken/features/auth/domain/email_address.dart';
import 'package:kraken/features/profile/domain/user_profile.dart';

void main() {
  final user = AppUser(uid: 'u1', email: EmailAddress.tryParse('a@example.com')!);
  final ready = ReadySession(user, const UserProfile(uid: 'u1'));
  String? go(SessionState s, String at, {bool debug = true}) => redirectFor(s, at, debugAllowed: debug);

  test('waits on the splash while loading', () {
    expect(go(const SessionLoading(), Paths.home), Paths.splash);
    expect(go(const SessionLoading(), Paths.splash), isNull);
  });

  test('signed-out people see welcome and sign-in only', () {
    expect(go(const SignedOutSession(), Paths.splash), Paths.welcome);
    expect(go(const SignedOutSession(), Paths.home), Paths.welcome);
    expect(go(const SignedOutSession(), Paths.account), Paths.welcome);
    expect(go(const SignedOutSession(), Paths.signIn), isNull);
    expect(go(const SignedOutSession(), Paths.login), isNull);
    expect(go(const SignedOutSession(), Paths.welcome), isNull);
    // The last sign-up step needs someone signed in.
    expect(go(const SignedOutSession(), Paths.finishSignUp), Paths.login);
  });

  test('unfinished sign-ups finish on the form, or carry on in the chat', () {
    expect(go(OnboardingSession(user, null), Paths.home), Paths.finishSignUp);
    expect(go(OnboardingSession(user, null), Paths.login), Paths.finishSignUp);
    expect(go(OnboardingSession(user, null), Paths.finishSignUp), isNull);
    expect(go(OnboardingSession(user, null), Paths.signIn), isNull);
  });

  test('finished people land in the app, and may stay on the last chat step', () {
    expect(go(ready, Paths.splash), Paths.home);
    expect(go(ready, Paths.welcome), Paths.home);
    expect(go(ready, Paths.login), Paths.home);
    expect(go(ready, Paths.finishSignUp), Paths.home);
    expect(go(ready, Paths.signIn), isNull);
    expect(go(ready, Paths.account), isNull);
  });

  test('debug tools only where allowed', () {
    expect(go(ready, Paths.debug), isNull);
    expect(go(ready, Paths.debug, debug: false), Paths.splash);
  });
}
