import 'package:kraken_server/src/firebase/firestore.dart';
import 'package:test/test.dart';

void main() {
  test('values round-trip through Firestore\'s typed format', () {
    final data = <String, Object?>{
      'name': 'Aarav',
      'paise': 210000,
      'share': 0.5,
      'adult': true,
      'upi': null,
      'at': DateTime.utc(2026, 11, 25, 10, 30),
      'members': ['Aarav', 'Meera'],
      'nested': {'count': 2},
    };
    final encoded = Firestore.encodeFields(data);
    expect(encoded['paise'], {'integerValue': '210000'});
    expect(encoded['at'], {'timestampValue': '2026-11-25T10:30:00.000Z'});
    expect(Firestore.decodeFields(encoded), data);
  });
}
