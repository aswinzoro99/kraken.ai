import 'dart:async';
import 'dart:convert';
import 'dart:math';

import '../../../core/result/result.dart';
import '../../../core/storage/key_value_store.dart';
import '../../../core/time/clock.dart';
import '../domain/auth_repository.dart';
import '../domain/email_address.dart';
import '../domain/otp_code.dart';
import 'mock_inbox.dart';

/// Email-code sign-in without a server. It keeps the same rules the real API
/// will: codes expire, wrong guesses are limited, resends are rate limited.
/// The session survives restarts so the app behaves like a real install.
final class MockAuthRepository implements AuthRepository {
  MockAuthRepository({
    required this._store,
    required this._inbox,
    this._clock = systemClock,
    Random? random,
    this.latency = const Duration(milliseconds: 500),
    this.codeLifetime = const Duration(minutes: 10),
    this.maxAttempts = 5,
    this.resendCooldown = const Duration(seconds: 30),
  }) : _random = random ?? Random.secure() {
    _current = _restore();
  }

  final KeyValueStore _store;
  final MockInbox _inbox;
  final Clock _clock;
  final Random _random;
  final Duration latency;
  final Duration codeLifetime;
  final int maxAttempts;
  final Duration resendCooldown;

  final _changes = StreamController<AppUser?>.broadcast();
  final Map<String, _IssuedCode> _codes = {};
  AppUser? _current;

  /// Makes the next request fail as if offline. Set from the debug screen.
  bool failNextRequest = false;

  @override
  AppUser? get currentUser => _current;

  @override
  Stream<AppUser?> watchUser() async* {
    yield _current;
    yield* _changes.stream;
  }

  @override
  Future<Result<void, AuthFailure>> requestCode(EmailAddress email) async {
    await _wait();
    if (_consumeFailure()) return const Err(AuthNetworkFailure());
    final now = _clock();
    final previous = _codes[email.value];
    if (previous != null) {
      final since = now.difference(previous.issuedAt);
      if (since < resendCooldown) return Err(ResendTooSoon(resendCooldown - since));
    }
    final code = List.generate(6, (_) => _random.nextInt(10)).join();
    _codes[email.value] = _IssuedCode(code, now);
    _inbox.deliver(MockEmail(to: email.value, code: code, sentAt: now));
    return const Ok(null);
  }

  @override
  Future<Result<AppUser, AuthFailure>> verifyCode(EmailAddress email, OtpCode code) async {
    await _wait();
    if (_consumeFailure()) return const Err(AuthNetworkFailure());
    final issued = _codes[email.value];
    if (issued == null) return const Err(NoCodeRequested());
    if (_clock().difference(issued.issuedAt) > codeLifetime) {
      _codes.remove(email.value);
      return const Err(CodeExpired());
    }
    if (issued.attempts >= maxAttempts) return const Err(TooManyAttempts());
    if (issued.code != code.value) {
      issued.attempts++;
      final left = maxAttempts - issued.attempts;
      return left <= 0 ? const Err(TooManyAttempts()) : Err(WrongCode(left));
    }
    _codes.remove(email.value);
    final user = AppUser(uid: _uidFor(email), email: email);
    await _setUser(user);
    return Ok(user);
  }

  /// The account each provider "returns" here. Always the same one, so the
  /// second time is a returning sign-in.
  static final mockAccounts = {
    SocialProvider.apple: (email: 'kraken.tester@privaterelay.appleid.com', name: 'Kraken Tester'),
    SocialProvider.google: (email: 'kraken.tester@gmail.com', name: 'Kraken Tester'),
  };

  @override
  Future<Result<AppUser, AuthFailure>> signInWith(SocialProvider provider) async {
    await _wait();
    if (_consumeFailure()) return const Err(AuthNetworkFailure());
    final account = mockAccounts[provider]!;
    final email = EmailAddress.tryParse(account.email)!;
    final user = AppUser(uid: _uidFor(email), email: email, name: account.name);
    await _setUser(user);
    return Ok(user);
  }

  @override
  Future<void> signOut() => _setUser(null);

  @override
  Future<void> deleteAccount() async {
    await _wait();
    if (_consumeFailure()) throw StateError('mock: deletion failed (offline)');
    await _setUser(null);
  }

  Future<void> dispose() => _changes.close();

  Future<void> _setUser(AppUser? user) async {
    _current = user;
    if (user == null) {
      await _store.remove(StoreKeys.mockSession);
    } else {
      await _store.setString(StoreKeys.mockSession, jsonEncode({'uid': user.uid, 'email': user.email.value}));
    }
    _changes.add(user);
  }

  AppUser? _restore() {
    final raw = _store.getString(StoreKeys.mockSession);
    if (raw == null) return null;
    final json = jsonDecode(raw) as Map<String, Object?>;
    final email = EmailAddress.tryParse(json['email']! as String);
    return email == null ? null : AppUser(uid: json['uid']! as String, email: email);
  }

  /// A stable fake uid per email, so signing in again finds the same profile.
  static String _uidFor(EmailAddress email) {
    var hash = 0x811c9dc5;
    for (final unit in email.value.codeUnits) {
      hash = ((hash ^ unit) * 0x01000193) & 0xffffffff;
    }
    return 'mock-${hash.toRadixString(16).padLeft(8, '0')}';
  }

  bool _consumeFailure() {
    if (!failNextRequest) return false;
    failNextRequest = false;
    return true;
  }

  Future<void> _wait() => latency == Duration.zero ? Future.value() : Future.delayed(latency);
}

final class _IssuedCode {
  _IssuedCode(this.code, this.issuedAt);
  final String code;
  final DateTime issuedAt;
  int attempts = 0;
}
