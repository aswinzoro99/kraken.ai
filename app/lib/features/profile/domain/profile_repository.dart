import 'user_profile.dart';

/// Reads and writes `users/{uid}`. Only the owner can do either; the
/// Firestore rules enforce that, this interface just assumes it.
abstract interface class ProfileRepository {
  Future<UserProfile?> fetch(String uid);

  Stream<UserProfile?> watch(String uid);

  Future<void> save(UserProfile profile);

  Future<void> delete(String uid);
}
