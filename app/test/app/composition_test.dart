import 'package:flutter_test/flutter_test.dart';
import 'package:kraken/app/composition.dart';
import 'package:kraken/core/storage/key_value_store.dart';
import 'package:kraken/features/auth/domain/email_address.dart';
import 'package:kraken/features/auth/domain/otp_code.dart';

import '../helpers/test_app.dart';

void main() {
  test('the mock build starts signed out, but keeps profiles and settings', () async {
    final store = MemoryStore();
    final first = testServices(store: store);
    final email = EmailAddress.tryParse('aarav@example.com')!;
    await first.auth.requestCode(email);
    await first.auth.verifyCode(email, OtpCode.tryParse(first.devTools.inbox!.value!.code)!);
    await store.setString(StoreKeys.mockProfiles, '{}');
    await store.setString(StoreKeys.appearance, 'dark');
    expect(store.getString(StoreKeys.mockSession), isNotNull);
    first.dispose();

    await startSignedOut(store);
    final relaunched = testServices(store: store);
    addTearDown(relaunched.dispose);
    expect(relaunched.auth.currentUser, isNull);
    expect(store.getString(StoreKeys.mockProfiles), '{}');
    expect(store.getString(StoreKeys.appearance), 'dark');
  });
}
