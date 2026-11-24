import 'dart:convert';
import 'dart:io';

import 'package:dart_jsonwebtoken/dart_jsonwebtoken.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:kraken_server/src/firebase/tokens.dart';
import 'package:test/test.dart';

void main() {
  final key = File('test/fixtures/test_key.pem').readAsStringSync();
  final cert = File('test/fixtures/test_cert.pem').readAsStringSync();
  final now = DateTime.now();
  const project = 'kraken-dev';

  test('custom tokens carry the claims Firebase expects, signed RS256', () async {
    final token = await KeyTokenMinter(
      clientEmail: 'api@kraken-dev.iam.gserviceaccount.com',
      privateKeyPem: key,
    ).mint('u1');
    final jwt = JWT.verify(token, RSAPublicKey.cert(cert));
    final claims = jwt.payload as Map<String, Object?>;
    expect(claims['uid'], 'u1');
    expect(claims['iss'], 'api@kraken-dev.iam.gserviceaccount.com');
    expect(claims['aud'], contains('google.identity.identitytoolkit.v1.IdentityToolkit'));
    expect((claims['exp']! as int) - (claims['iat']! as int), 3600);
  });

  test('the emulator gets unsigned custom tokens', () async {
    final token = await EmulatorTokenMinter().mint('u1');
    expect(token.endsWith('.'), isTrue);
    expect(JWT.decode(token).header?['alg'], 'none');
  });

  String idToken({String aud = project, String? iss, int expIn = 3600, String kid = 'k1', String sub = 'u1'}) {
    final iat = now.millisecondsSinceEpoch ~/ 1000;
    return JWT(
      {'aud': aud, 'iss': iss ?? 'https://securetoken.google.com/$aud', 'sub': sub, 'iat': iat, 'exp': iat + expIn},
      header: {'kid': kid},
    ).sign(RSAPrivateKey(key), algorithm: JWTAlgorithm.RS256);
  }

  GoogleIdTokenVerifier verifier() {
    var fetches = 0;
    final client = MockClient((request) async {
      fetches++;
      expect(fetches, 1, reason: 'certificates are cached');
      return http.Response(jsonEncode({'k1': cert}), 200, headers: {'cache-control': 'public, max-age=3600'});
    });
    return GoogleIdTokenVerifier(projectId: project, client: client);
  }

  test('valid ID tokens give their uid; anything off gives null', () async {
    final v = verifier();
    expect(await v.uidOf(idToken()), 'u1');
    expect(await v.uidOf(idToken(aud: 'someone-else')), isNull, reason: 'other project');
    expect(await v.uidOf(idToken(iss: 'https://evil.example')), isNull, reason: 'wrong issuer');
    expect(await v.uidOf(idToken(expIn: -10)), isNull, reason: 'expired');
    expect(await v.uidOf(idToken(kid: 'unknown')), isNull, reason: 'unknown key');
    expect(await v.uidOf(idToken(sub: '')), isNull, reason: 'no uid');
    expect(await v.uidOf('not.a.token'), isNull);
    final unsigned = await EmulatorTokenMinter().mint('u1');
    expect(await v.uidOf(unsigned), isNull, reason: 'unsigned tokens only pass on emulators');
  });
}
