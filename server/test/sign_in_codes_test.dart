import 'package:kraken_server/src/auth/sign_in_codes.dart';
import 'package:kraken_server/src/email/email_sender.dart';
import 'package:test/test.dart';

void main() {
  late DateTime now;
  late ConsoleEmailSender mail;
  late MemoryCodeStore store;
  late SignInCodes codes;

  setUp(() {
    now = DateTime.utc(2026, 11, 25, 10);
    mail = ConsoleEmailSender(log: (_) {});
    store = MemoryCodeStore();
    codes = SignInCodes(store: store, sender: mail, pepper: 'test', clock: () => now);
  });

  String sentCode() => RegExp(r'\d{6}').firstMatch(mail.sent.last.subject)!.group(0)!;

  test('emails a six-digit code to the normalised address, and keeps only a hash', () async {
    expect(await codes.request('  Aarav@Example.COM '), isA<CodeSent>());
    expect(mail.sent.single.to, 'aarav@example.com');
    final code = sentCode();
    final stored = await store.read(codes.keyFor('aarav@example.com'));
    expect(stored!.codeHash, isNot(contains(code)));
    expect(stored.codeHash, hasLength(64));
  });

  test('rejects things that are not emails', () async {
    for (final bad in ['', 'aarav', 'aarav@', '@example.com', 'a b@c.com']) {
      expect(await codes.request(bad), isA<InvalidEmail>(), reason: bad);
    }
    expect(mail.sent, isEmpty);
  });

  test('the right code signs in once; the code is then used up', () async {
    await codes.request('aarav@example.com');
    final code = sentCode();
    final first = await codes.verify('AARAV@example.com', code);
    expect(first, isA<Verified>().having((v) => v.email, 'email', 'aarav@example.com'));
    expect(await codes.verify('aarav@example.com', code), isA<NoCodeRequested>());
  });

  test('wrong codes count down, then lock', () async {
    await codes.request('aarav@example.com');
    final wrong = sentCode() == '000000' ? '111111' : '000000';
    for (final left in [4, 3, 2, 1]) {
      expect(
        await codes.verify('aarav@example.com', wrong),
        isA<WrongCode>().having((w) => w.attemptsLeft, 'left', left),
      );
    }
    expect(await codes.verify('aarav@example.com', wrong), isA<TooManyAttempts>());
    expect(await codes.verify('aarav@example.com', sentCode()), isA<TooManyAttempts>());
  });

  test('codes expire after ten minutes', () async {
    await codes.request('aarav@example.com');
    final code = sentCode();
    now = now.add(const Duration(minutes: 10, seconds: 1));
    expect(await codes.verify('aarav@example.com', code), isA<CodeExpired>());
  });

  test('a new code can be asked for after thirty seconds, and replaces the old one', () async {
    await codes.request('aarav@example.com');
    final first = sentCode();
    now = now.add(const Duration(seconds: 10));
    expect(
      await codes.request('aarav@example.com'),
      isA<ResendTooSoon>().having((r) => r.wait, 'wait', const Duration(seconds: 20)),
    );
    now = now.add(const Duration(seconds: 21));
    expect(await codes.request('aarav@example.com'), isA<CodeSent>());
    final second = sentCode();
    if (first != second) expect(await codes.verify('aarav@example.com', first), isA<WrongCode>());
    expect(await codes.verify('aarav@example.com', second), isA<Verified>());
  });

  test('the code email says the code first, in plain words', () {
    final mail = codeEmail('482913');
    expect(mail.subject, 'Your Kraken code: 482913');
    expect(mail.text, contains('10 minutes'));
    expect(mail.html, contains('482913'));
  });
}
