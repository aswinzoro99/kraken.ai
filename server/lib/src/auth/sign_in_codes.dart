import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';

import '../email/email_sender.dart';

/// A code waiting to be typed in. Only its hash is kept.
final class IssuedCode {
  const IssuedCode({required this.codeHash, required this.issuedAt, this.attempts = 0});
  final String codeHash;
  final DateTime issuedAt;
  final int attempts;

  IssuedCode tried() => IssuedCode(codeHash: codeHash, issuedAt: issuedAt, attempts: attempts + 1);
}

/// Where issued codes live, keyed by a hash of the email (never the email).
abstract interface class CodeStore {
  Future<IssuedCode?> read(String key);
  Future<void> write(String key, IssuedCode code);
  Future<void> remove(String key);
}

final class MemoryCodeStore implements CodeStore {
  final _codes = <String, IssuedCode>{};
  @override
  Future<IssuedCode?> read(String key) async => _codes[key];
  @override
  Future<void> write(String key, IssuedCode code) async => _codes[key] = code;
  @override
  Future<void> remove(String key) async => _codes.remove(key);
}

sealed class RequestOutcome {
  const RequestOutcome();
}

final class CodeSent extends RequestOutcome {
  const CodeSent();
}

final class ResendTooSoon extends RequestOutcome {
  const ResendTooSoon(this.wait);
  final Duration wait;
}

final class InvalidEmail extends RequestOutcome {
  const InvalidEmail();
}

sealed class VerifyOutcome {
  const VerifyOutcome();
}

final class Verified extends VerifyOutcome {
  const Verified(this.email);

  /// Normalised (trimmed, lower case).
  final String email;
}

final class WrongCode extends VerifyOutcome {
  const WrongCode(this.attemptsLeft);
  final int attemptsLeft;
}

final class CodeExpired extends VerifyOutcome {
  const CodeExpired();
}

final class TooManyAttempts extends VerifyOutcome {
  const TooManyAttempts();
}

final class NoCodeRequested extends VerifyOutcome {
  const NoCodeRequested();
}

/// Email sign-in codes, with the same rules as the app's mock: six digits,
/// valid for [lifetime], [maxAttempts] guesses, one resend per [cooldown].
final class SignInCodes {
  SignInCodes({
    required this.store,
    required this.sender,
    required this.pepper,
    DateTime Function()? clock,
    Random? random,
    this.lifetime = const Duration(minutes: 10),
    this.cooldown = const Duration(seconds: 30),
    this.maxAttempts = 5,
  }) : _clock = clock ?? DateTime.now,
       _random = random ?? Random.secure();

  final CodeStore store;
  final EmailSender sender;
  final String pepper;
  final Duration lifetime;
  final Duration cooldown;
  final int maxAttempts;
  final DateTime Function() _clock;
  final Random _random;

  static final _emailShape = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

  /// Trimmed and lower-cased, or null if it isn't an email address.
  static String? normalise(String raw) {
    final email = raw.trim().toLowerCase();
    return _emailShape.hasMatch(email) && email.length <= 254 ? email : null;
  }

  String keyFor(String email) => sha256.convert(utf8.encode(email)).toString();

  String _hash(String key, String code) =>
      Hmac(sha256, utf8.encode(pepper)).convert(utf8.encode('$key:$code')).toString();

  Future<RequestOutcome> request(String rawEmail) async {
    final email = normalise(rawEmail);
    if (email == null) return const InvalidEmail();
    final key = keyFor(email);
    final now = _clock();
    final previous = await store.read(key);
    if (previous != null) {
      final since = now.difference(previous.issuedAt);
      if (since < cooldown) return ResendTooSoon(cooldown - since);
    }
    final code = List.generate(6, (_) => _random.nextInt(10)).join();
    await store.write(key, IssuedCode(codeHash: _hash(key, code), issuedAt: now));
    final mail = codeEmail(code);
    await sender.send(to: email, subject: mail.subject, text: mail.text, html: mail.html);
    return const CodeSent();
  }

  Future<VerifyOutcome> verify(String rawEmail, String code) async {
    final email = normalise(rawEmail);
    if (email == null) return const NoCodeRequested();
    final key = keyFor(email);
    final issued = await store.read(key);
    if (issued == null) return const NoCodeRequested();
    if (_clock().difference(issued.issuedAt) > lifetime) {
      await store.remove(key);
      return const CodeExpired();
    }
    if (issued.attempts >= maxAttempts) return const TooManyAttempts();
    final cleaned = code.trim();
    if (!_sameHash(_hash(key, cleaned), issued.codeHash)) {
      final tried = issued.tried();
      await store.write(key, tried);
      final left = maxAttempts - tried.attempts;
      return left <= 0 ? const TooManyAttempts() : WrongCode(left);
    }
    await store.remove(key);
    return Verified(email);
  }

  /// Compares in constant time, so timing doesn't leak how much matched.
  static bool _sameHash(String a, String b) {
    if (a.length != b.length) return false;
    var diff = 0;
    for (var i = 0; i < a.length; i++) {
      diff |= a.codeUnitAt(i) ^ b.codeUnitAt(i);
    }
    return diff == 0;
  }
}
