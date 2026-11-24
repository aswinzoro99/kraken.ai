import 'package:flutter_test/flutter_test.dart';
import 'package:kraken/core/result/result.dart';
import 'package:kraken/core/storage/key_value_store.dart';
import 'package:kraken/features/auth/data/mock_auth_repository.dart';
import 'package:kraken/features/auth/data/mock_inbox.dart';
import 'package:kraken/features/auth/domain/auth_repository.dart';
import 'package:kraken/features/auth/domain/email_address.dart';
import 'package:kraken/features/auth/domain/otp_code.dart';

void main() {
  late DateTime now;
  late MockInbox inbox;
  late MemoryStore store;
  late MockAuthRepository auth;
  final email = EmailAddress.tryParse('aarav@example.com')!;
  OtpCode code(String c) => OtpCode.tryParse(c)!;
  String sent() => inbox.value!.code;
  String wrong() => sent() == '000000' ? '111111' : '000000';

  setUp(() {
    now = DateTime(2026, 11, 24, 10);
    inbox = MockInbox();
    store = MemoryStore();
    auth = MockAuthRepository(store: store, inbox: inbox, clock: () => now, latency: Duration.zero);
  });

  test('signs in with the emailed code and keeps the session', () async {
    expect((await auth.requestCode(email)).isOk, isTrue);
    expect(inbox.value!.to, 'aarav@example.com');
    final result = await auth.verifyCode(email, code(sent()));
    final user = (result as Ok<AppUser, AuthFailure>).value;
    expect(auth.currentUser, user);

    final restarted = MockAuthRepository(store: store, inbox: inbox, latency: Duration.zero);
    expect(restarted.currentUser?.uid, user.uid);
  });

  test('the same email always gets the same uid', () async {
    await auth.requestCode(email);
    final first = await auth.verifyCode(email, code(sent()));
    await auth.signOut();
    now = now.add(const Duration(minutes: 1));
    await auth.requestCode(email);
    final second = await auth.verifyCode(email, code(sent()));
    expect(first.valueOrNull?.uid, second.valueOrNull?.uid);
  });

  test('counts down wrong guesses, then locks the code', () async {
    await auth.requestCode(email);
    final results = [for (var i = 0; i < 5; i++) await auth.verifyCode(email, code(wrong()))];
    expect([for (final r in results.take(4)) ((r as Err).failure as WrongCode).attemptsLeft], [4, 3, 2, 1]);
    expect((results.last as Err).failure, isA<TooManyAttempts>());
    expect((await auth.verifyCode(email, code(sent())) as Err).failure, isA<TooManyAttempts>());
  });

  test('codes expire after ten minutes', () async {
    await auth.requestCode(email);
    final c = sent();
    now = now.add(const Duration(minutes: 11));
    expect((await auth.verifyCode(email, code(c)) as Err).failure, isA<CodeExpired>());
  });

  test('rate limits resends for 30 seconds', () async {
    await auth.requestCode(email);
    now = now.add(const Duration(seconds: 10));
    final again = await auth.requestCode(email);
    expect(((again as Err).failure as ResendTooSoon).wait, const Duration(seconds: 20));
    now = now.add(const Duration(seconds: 21));
    expect((await auth.requestCode(email)).isOk, isTrue);
  });

  test('can pretend to be offline once', () async {
    auth.failNextRequest = true;
    expect((await auth.requestCode(email) as Err).failure, isA<AuthNetworkFailure>());
    expect((await auth.requestCode(email)).isOk, isTrue);
  });

  test('verifying without a code fails clearly', () async {
    expect((await auth.verifyCode(email, code('123456')) as Err).failure, isA<NoCodeRequested>());
  });
}
