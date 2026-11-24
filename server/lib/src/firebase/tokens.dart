import 'dart:convert';

import 'package:dart_jsonwebtoken/dart_jsonwebtoken.dart';
import 'package:http/http.dart' as http;

/// Mints Firebase custom tokens: the app signs in with one after its email
/// code checks out (`signInWithCustomToken`). The claims follow
/// https://firebase.google.com/docs/auth/admin/create-custom-tokens.
abstract interface class TokenMinter {
  Future<String> mint(String uid);
}

const _audience = 'https://identitytoolkit.googleapis.com/google.identity.identitytoolkit.v1.IdentityToolkit';

Map<String, Object?> _claims(String serviceAccount, String uid, DateTime now) {
  final iat = now.millisecondsSinceEpoch ~/ 1000;
  return {'iss': serviceAccount, 'sub': serviceAccount, 'aud': _audience, 'iat': iat, 'exp': iat + 3600, 'uid': uid};
}

String _b64(Object json) => base64Url.encode(utf8.encode(jsonEncode(json))).replaceAll('=', '');

/// The Auth emulator takes unsigned tokens, as the Admin SDKs send it.
final class EmulatorTokenMinter implements TokenMinter {
  EmulatorTokenMinter({DateTime Function()? clock}) : _clock = clock ?? DateTime.now;
  final DateTime Function() _clock;

  @override
  Future<String> mint(String uid) async {
    final claims = _claims('firebase-auth-emulator@example.com', uid, _clock());
    return '${_b64({'alg': 'none', 'typ': 'JWT'})}.${_b64(claims)}.';
  }
}

/// Signs with a service account's private key (local runs with a key file).
final class KeyTokenMinter implements TokenMinter {
  KeyTokenMinter({required this.clientEmail, required this.privateKeyPem, DateTime Function()? clock})
    : _clock = clock ?? DateTime.now;

  final String clientEmail;
  final String privateKeyPem;
  final DateTime Function() _clock;

  @override
  Future<String> mint(String uid) async =>
      JWT(_claims(clientEmail, uid, _clock())).sign(RSAPrivateKey(privateKeyPem), algorithm: JWTAlgorithm.RS256);
}

/// Signs through the IAM Credentials API as the Cloud Run service's own
/// service account, so no key file exists anywhere. That account needs the
/// "Service Account Token Creator" role on itself.
final class IamTokenMinter implements TokenMinter {
  IamTokenMinter({required this.client, http.Client? metadata, DateTime Function()? clock})
    : _metadata = metadata ?? http.Client(),
      _clock = clock ?? DateTime.now;

  /// Authorised as the service (Application Default Credentials).
  final http.Client client;
  final http.Client _metadata;
  final DateTime Function() _clock;
  String? _email;

  Future<String> _serviceAccount() async => _email ??= (await _metadata.get(
    Uri.parse('http://metadata.google.internal/computeMetadata/v1/instance/service-accounts/default/email'),
    headers: {'Metadata-Flavor': 'Google'},
  )).body.trim();

  @override
  Future<String> mint(String uid) async {
    final email = await _serviceAccount();
    final response = await client.post(
      Uri.parse('https://iamcredentials.googleapis.com/v1/projects/-/serviceAccounts/$email:signJwt'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'payload': jsonEncode(_claims(email, uid, _clock()))}),
    );
    if (response.statusCode >= 300) throw StateError('signJwt failed (${response.statusCode}): ${response.body}');
    return (jsonDecode(response.body) as Map<String, Object?>)['signedJwt']! as String;
  }
}

/// Checks the Firebase ID token the app sends (`Authorization: Bearer …`)
/// and returns its uid, or null if it isn't a valid, current token for this
/// project (https://firebase.google.com/docs/auth/admin/verify-id-tokens).
abstract interface class IdTokenVerifier {
  Future<String?> uidOf(String token);
}

bool _claimsOk(Map<String, Object?> p, String projectId, DateTime now) {
  final seconds = now.millisecondsSinceEpoch ~/ 1000;
  final sub = p['sub'];
  return p['aud'] == projectId &&
      p['iss'] == 'https://securetoken.google.com/$projectId' &&
      sub is String &&
      sub.isNotEmpty &&
      (p['exp'] as num? ?? 0) > seconds &&
      (p['iat'] as num? ?? seconds + 1) <= seconds + 300;
}

/// The Auth emulator's tokens are unsigned; only the claims are checked.
final class EmulatorIdTokenVerifier implements IdTokenVerifier {
  EmulatorIdTokenVerifier({required this.projectId, DateTime Function()? clock}) : _clock = clock ?? DateTime.now;
  final String projectId;
  final DateTime Function() _clock;

  @override
  Future<String?> uidOf(String token) async {
    try {
      final payload = JWT.decode(token).payload as Map<String, Object?>;
      return _claimsOk(payload, projectId, _clock()) ? payload['sub']! as String : null;
    } on Object {
      return null;
    }
  }
}

/// Verifies the RS256 signature against Google's published certificates
/// (cached as long as Google says), then the claims.
final class GoogleIdTokenVerifier implements IdTokenVerifier {
  GoogleIdTokenVerifier({required this.projectId, http.Client? client, DateTime Function()? clock})
    : _http = client ?? http.Client(),
      _clock = clock ?? DateTime.now;

  final String projectId;
  final http.Client _http;
  final DateTime Function() _clock;
  Map<String, String> _certs = const {};
  DateTime _certsExpire = DateTime.fromMillisecondsSinceEpoch(0);

  static final _certUrl = Uri.parse(
    'https://www.googleapis.com/robot/v1/metadata/x509/securetoken@system.gserviceaccount.com',
  );

  Future<Map<String, String>> _keys() async {
    if (_clock().isBefore(_certsExpire)) return _certs;
    final response = await _http.get(_certUrl);
    if (response.statusCode != 200) throw StateError('Couldn\'t fetch Google certificates');
    final maxAge = RegExp(r'max-age=(\d+)').firstMatch(response.headers['cache-control'] ?? '')?.group(1);
    _certs = (jsonDecode(response.body) as Map<String, Object?>).cast<String, String>();
    _certsExpire = _clock().add(Duration(seconds: int.tryParse(maxAge ?? '') ?? 3600));
    return _certs;
  }

  @override
  Future<String?> uidOf(String token) async {
    try {
      final header = JWT.decode(token).header ?? const {};
      if (header['alg'] != 'RS256') return null;
      final cert = (await _keys())[header['kid']];
      if (cert == null) return null;
      final payload = JWT.verify(token, RSAPublicKey.cert(cert)).payload as Map<String, Object?>;
      return _claimsOk(payload, projectId, _clock()) ? payload['sub']! as String : null;
    } on JWTException {
      return null;
    } on FormatException {
      return null;
    }
  }
}
