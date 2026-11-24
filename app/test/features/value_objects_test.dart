import 'package:flutter_test/flutter_test.dart';
import 'package:kraken/features/auth/domain/email_address.dart';
import 'package:kraken/features/auth/domain/otp_code.dart';
import 'package:kraken/features/profile/domain/value_objects.dart';

void main() {
  test('EmailAddress forgives case and stray spaces', () {
    expect(EmailAddress.tryParse('  Aarav@Example.COM ')?.value, 'aarav@example.com');
    expect(EmailAddress.tryParse('aarav @example.com')?.value, 'aarav@example.com');
    for (final bad in ['', 'aarav', 'aarav@', '@example.com', 'a@b', 'a@b.c', 'a@@b.com']) {
      expect(EmailAddress.tryParse(bad), isNull, reason: bad);
    }
  });

  test('OtpCode wants exactly six digits', () {
    expect(OtpCode.tryParse('482 913')?.value, '482913');
    expect(OtpCode.tryParse('482-913')?.value, '482913');
    for (final bad in ['48291', '4829134', 'abcdef', '']) {
      expect(OtpCode.tryParse(bad), isNull, reason: bad);
    }
  });

  test('DisplayName trims and limits', () {
    expect(DisplayName.tryParse('  Aarav   Mehta ')?.value, 'Aarav Mehta');
    expect(DisplayName.tryParse('श्रेया')?.value, 'श्रेया');
    expect(DisplayName.tryParse('   '), isNull);
    expect(DisplayName.tryParse('1234'), isNull);
    expect(DisplayName.tryParse('a' * 41), isNull);
  });

  test('UpiId is name@bank', () {
    expect(UpiId.tryParse(' Aarav.M@OkAxis ')?.value, 'aarav.m@okaxis');
    expect(UpiId.tryParse('9876543210@ybl')?.value, '9876543210@ybl');
    for (final bad in ['aarav', 'aarav@', '@okaxis', 'aarav@ok axis', 'a@1bank']) {
      expect(UpiId.tryParse(bad), isNull, reason: bad);
    }
  });

  test('InviteCode reads links and bare codes', () {
    expect(InviteCode.tryParse('https://kraken-prod.web.app/i/k7q2xa')?.value, 'K7Q2XA');
    expect(InviteCode.tryParse('K7Q2XA')?.value, 'K7Q2XA');
    expect(InviteCode.tryParse('https://example.com/hello'), isNull);
    expect(InviteCode.tryParse('abc'), isNull);
  });
}
