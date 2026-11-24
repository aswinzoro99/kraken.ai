import '../firebase/firestore.dart';
import 'sign_in_codes.dart';

/// Issued codes in Firestore at `authCodes/{sha256(email)}`. Only the server
/// touches this collection; the security rules deny it to every app.
final class FirestoreCodeStore implements CodeStore {
  FirestoreCodeStore(this.firestore);
  final Firestore firestore;

  @override
  Future<IssuedCode?> read(String key) async {
    final data = await firestore.get('authCodes/$key');
    if (data == null) return null;
    return IssuedCode(
      codeHash: data['codeHash']! as String,
      issuedAt: data['issuedAt']! as DateTime,
      attempts: data['attempts'] as int? ?? 0,
    );
  }

  @override
  Future<void> write(String key, IssuedCode code) => firestore.set('authCodes/$key', {
    'codeHash': code.codeHash,
    'issuedAt': code.issuedAt,
    'attempts': code.attempts,
  });

  @override
  Future<void> remove(String key) => firestore.delete('authCodes/$key');
}
