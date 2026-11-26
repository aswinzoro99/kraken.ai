import 'package:supabase_flutter/supabase_flutter.dart' as sb;

import '../../../core/result/result.dart';
import '../domain/auth_repository.dart';
import '../domain/email_address.dart';
import '../domain/otp_code.dart';

/// Sign-in through Supabase Auth (phantom-services): 6-digit email codes.
/// Apple and Google come once their client IDs are set up.
final class SupabaseAuthRepository implements AuthRepository {
  SupabaseAuthRepository(this._client);
  final sb.SupabaseClient _client;

  sb.GoTrueClient get _auth => _client.auth;

  static AppUser? _map(sb.User? user) {
    if (user == null) return null;
    final email = EmailAddress.tryParse(user.email ?? '');
    if (email == null) return null;
    final meta = user.userMetadata ?? const {};
    return AppUser(uid: user.id, email: email, name: (meta['full_name'] ?? meta['name']) as String?);
  }

  @override
  AppUser? get currentUser => _map(_auth.currentUser);

  @override
  Stream<AppUser?> watchUser() async* {
    String? last = '';
    yield currentUser;
    last = currentUser?.uid;
    await for (final change in _auth.onAuthStateChange) {
      final user = _map(change.session?.user);
      if (user?.uid == last) continue;
      last = user?.uid;
      yield user;
    }
  }

  /// "…you can only request this after 27 seconds." → 27 s.
  static Duration _wait(sb.AuthException e) {
    final seconds = RegExp(r'(\d+) seconds?').firstMatch(e.message)?.group(1);
    return Duration(seconds: int.tryParse(seconds ?? '') ?? 60);
  }

  static bool _rateLimited(sb.AuthException e) => e.statusCode == '429' || (e.code?.startsWith('over_') ?? false);

  @override
  Future<Result<void, AuthFailure>> requestCode(EmailAddress email) async {
    try {
      await _auth.signInWithOtp(email: email.value, shouldCreateUser: true);
      return const Ok(null);
    } on sb.AuthException catch (e) {
      return Err(_rateLimited(e) ? ResendTooSoon(_wait(e)) : const AuthNetworkFailure());
    } on Object {
      return const Err(AuthNetworkFailure());
    }
  }

  @override
  Future<Result<AppUser, AuthFailure>> verifyCode(EmailAddress email, OtpCode code) async {
    try {
      final response = await _auth.verifyOTP(type: sb.OtpType.email, email: email.value, token: code.value);
      final user = _map(response.user);
      return user == null ? const Err(AuthNetworkFailure()) : Ok(user);
    } on sb.AuthException catch (e) {
      if (_rateLimited(e)) return const Err(TooManyAttempts());
      if (e.code == 'otp_expired' || e.statusCode == '403' || e.statusCode == '400') return const Err(CodeRejected());
      return const Err(AuthNetworkFailure());
    } on Object {
      return const Err(AuthNetworkFailure());
    }
  }

  @override
  Future<Result<AppUser, AuthFailure>> signInWith(SocialProvider provider) async => Err(ProviderUnavailable(provider));

  @override
  Future<void> signOut() => _auth.signOut();

  /// Deletes the account on the server (`delete_account()`), which removes
  /// the profile with it, then forgets the session here.
  @override
  Future<void> deleteAccount() async {
    await _client.rpc<void>('delete_account');
    await _auth.signOut(scope: sb.SignOutScope.local);
  }
}
