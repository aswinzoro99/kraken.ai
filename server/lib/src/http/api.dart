import 'dart:convert';

import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';

import '../auth/sign_in_codes.dart';
import '../email/email_sender.dart';
import '../firebase/accounts.dart';
import '../firebase/firestore.dart';
import '../firebase/tokens.dart';

/// Kraken's API. Every error is JSON `{"error": "<code>", ...}` with a
/// stable code the app maps to a message.
///
/// * `POST /v1/auth/code`    {email}       → 204, emails a 6-digit code
/// * `POST /v1/auth/verify`  {email, code} → {customToken, newUser}
/// * `POST /v1/account/delete` (Bearer ID token) → 204
/// * `GET  /healthz`
final class KrakenApi {
  KrakenApi({
    required this.codes,
    required this.accounts,
    required this.firestore,
    required this.minter,
    required this.verifier,
    RateLimiter? limiter,
    this.log = print,
  }) : limiter = limiter ?? RateLimiter(perMinute: 20);

  final SignInCodes codes;
  final Accounts accounts;
  final Firestore firestore;
  final TokenMinter minter;
  final IdTokenVerifier verifier;
  final RateLimiter limiter;
  final void Function(String) log;

  Handler get handler {
    final router = Router()
      ..get('/healthz', (Request _) => Response.ok('ok'))
      ..post('/v1/auth/code', _requestCode)
      ..post('/v1/auth/verify', _verifyCode)
      ..post('/v1/account/delete', _deleteAccount);
    return const Pipeline().addMiddleware(_errors()).addHandler(router.call);
  }

  Future<Response> _requestCode(Request request) async {
    if (!limiter.allow(_client(request))) return _error(429, 'rate_limited');
    final body = await _json(request);
    final outcome = await codes.request((body?['email'] as String?) ?? '');
    return switch (outcome) {
      CodeSent() => Response(204),
      InvalidEmail() => _error(400, 'invalid_email'),
      ResendTooSoon(:final wait) => _error(429, 'resend_too_soon', {'retryAfterSeconds': wait.inSeconds + 1}),
    };
  }

  Future<Response> _verifyCode(Request request) async {
    if (!limiter.allow(_client(request))) return _error(429, 'rate_limited');
    final body = await _json(request);
    final outcome = await codes.verify((body?['email'] as String?) ?? '', (body?['code'] as String?) ?? '');
    switch (outcome) {
      case Verified(:final email):
        final account = await accounts.findOrCreate(email);
        final token = await minter.mint(account.uid);
        return _ok({'customToken': token, 'newUser': account.created});
      case WrongCode(:final attemptsLeft):
        return _error(400, 'wrong_code', {'attemptsLeft': attemptsLeft});
      case CodeExpired():
        return _error(410, 'expired');
      case TooManyAttempts():
        return _error(429, 'too_many_attempts');
      case NoCodeRequested():
        return _error(404, 'no_code_requested');
    }
  }

  /// Deletes the caller's profile, then their sign-in account. Their name
  /// stays in shared groups without the link (from Phase 2, when groups
  /// exist on the server).
  Future<Response> _deleteAccount(Request request) async {
    final uid = await _caller(request);
    if (uid == null) return _error(401, 'unauthenticated');
    await firestore.delete('users/$uid');
    await accounts.delete(uid);
    log('deleted account $uid');
    return Response(204);
  }

  Future<String?> _caller(Request request) async {
    final header = request.headers['authorization'] ?? '';
    if (!header.startsWith('Bearer ')) return null;
    return verifier.uidOf(header.substring(7).trim());
  }

  /// The caller's address: Cloud Run puts it first in X-Forwarded-For.
  static String _client(Request request) {
    final forwarded = request.headers['x-forwarded-for'];
    if (forwarded != null && forwarded.isNotEmpty) return forwarded.split(',').first.trim();
    final info = request.context['shelf.io.connection_info'];
    return info?.toString() ?? 'unknown';
  }

  static Future<Map<String, Object?>?> _json(Request request) async {
    try {
      final decoded = jsonDecode(await request.readAsString());
      return decoded is Map<String, Object?> ? decoded : null;
    } on FormatException {
      return null;
    }
  }

  static Response _ok(Map<String, Object?> body) =>
      Response.ok(jsonEncode(body), headers: {'Content-Type': 'application/json'});

  static Response _error(int status, String code, [Map<String, Object?> extra = const {}]) =>
      Response(status, body: jsonEncode({'error': code, ...extra}), headers: {'Content-Type': 'application/json'});

  /// Unexpected failures become a plain 500 (details only in the log).
  Middleware _errors() =>
      (inner) => (request) async {
        try {
          return await inner(request);
        } on EmailFailure catch (e) {
          log('email failed: $e');
          return _error(502, 'email_failed');
        } on Object catch (e, stack) {
          log('error on ${request.method} ${request.url}: $e\n$stack');
          return _error(500, 'internal');
        }
      };
}

/// A per-address limit over a sliding minute. In memory: Cloud Run runs a
/// single instance at this size, so that's enough.
final class RateLimiter {
  RateLimiter({required this.perMinute, DateTime Function()? clock}) : _clock = clock ?? DateTime.now;
  final int perMinute;
  final DateTime Function() _clock;
  final _hits = <String, List<DateTime>>{};

  bool allow(String key) {
    final now = _clock();
    final recent = (_hits[key] ?? [])..removeWhere((t) => now.difference(t) > const Duration(minutes: 1));
    if (recent.length >= perMinute) return false;
    _hits[key] = recent..add(now);
    if (_hits.length > 10000) _hits.removeWhere((_, times) => times.isEmpty);
    return true;
  }
}
