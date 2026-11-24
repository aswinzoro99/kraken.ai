import '../../../core/result/result.dart';
import 'email_address.dart';
import 'otp_code.dart';

/// The signed-in person, as far as sign-in knows. Profile details (name,
/// consents) live in the profile feature.
final class AppUser {
  const AppUser({required this.uid, required this.email, this.name});
  final String uid;
  final EmailAddress email;

  /// The name Apple or Google shared, if any; used to prefill sign-up.
  final String? name;

  @override
  bool operator ==(Object other) => other is AppUser && other.uid == uid;
  @override
  int get hashCode => uid.hashCode;
}

/// Why sign-in didn't go through. Each case has its own chat reply.
sealed class AuthFailure {
  const AuthFailure();

  /// A stable code for analytics and logs.
  String get code;
}

final class WrongCode extends AuthFailure {
  const WrongCode(this.attemptsLeft);
  final int attemptsLeft;
  @override
  String get code => 'wrong_code';
}

final class CodeExpired extends AuthFailure {
  const CodeExpired();
  @override
  String get code => 'expired';
}

final class TooManyAttempts extends AuthFailure {
  const TooManyAttempts();
  @override
  String get code => 'too_many_attempts';
}

final class ResendTooSoon extends AuthFailure {
  const ResendTooSoon(this.wait);
  final Duration wait;
  @override
  String get code => 'resend_too_soon';
}

final class NoCodeRequested extends AuthFailure {
  const NoCodeRequested();
  @override
  String get code => 'no_code_requested';
}

/// The person closed the Apple or Google sheet. Not an error to show.
final class SignInCancelled extends AuthFailure {
  const SignInCancelled();
  @override
  String get code => 'cancelled';
}

final class AuthNetworkFailure extends AuthFailure {
  const AuthNetworkFailure();
  @override
  String get code => 'network';
}

/// Accounts people can sign in with instead of an email code.
enum SocialProvider { apple, google }

/// Email sign-in with a 6-digit code, as in the design, or with Apple or
/// Google.
///
/// The real implementation (Phase 1) asks the Dart API to email a code, then
/// exchanges the verified code for a Firebase custom token. No passwords and
/// no links, so it works without Universal Links on a free Apple ID.
abstract interface class AuthRepository {
  /// Emits the current user now and on every change.
  Stream<AppUser?> watchUser();

  AppUser? get currentUser;

  /// Emails a fresh code. Fails with [ResendTooSoon] if asked again quickly.
  Future<Result<void, AuthFailure>> requestCode(EmailAddress email);

  /// Signs in when [code] matches the latest code sent to [email].
  Future<Result<AppUser, AuthFailure>> verifyCode(EmailAddress email, OtpCode code);

  /// Signs in with Apple or Google: the system sheet, then a Firebase
  /// credential (Phase 1). [SignInCancelled] if the person backs out.
  Future<Result<AppUser, AuthFailure>> signInWith(SocialProvider provider);

  Future<void> signOut();

  /// Deletes the account and signs out. The server keeps the person's name
  /// in shared groups without the account link.
  Future<void> deleteAccount();
}
