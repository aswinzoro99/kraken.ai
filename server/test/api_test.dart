import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:kraken_server/kraken_server.dart';
import 'package:kraken_server/src/auth/sign_in_codes.dart';
import 'package:kraken_server/src/firebase/accounts.dart';
import 'package:kraken_server/src/firebase/firestore.dart';
import 'package:kraken_server/src/firebase/tokens.dart';
import 'package:shelf/shelf.dart';
import 'package:test/test.dart';

/// A pretend Firebase behind the REST clients: accounts by email, and
/// deleted documents.
final class FakeFirebase {
  final accounts = <String, String>{};
  final deletedDocs = <String>[];
  final deletedAccounts = <String>[];

  late final client = MockClient((request) async {
    final path = request.url.path;
    if (request.method == 'DELETE') {
      deletedDocs.add(path.split('/documents/').last);
      return http.Response('{}', 200);
    }
    final body = jsonDecode(request.body) as Map<String, Object?>;
    if (path.endsWith('accounts:lookup')) {
      final uid = accounts[(body['email']! as List).first];
      return http.Response(
        jsonEncode(
          uid == null
              ? {}
              : {
                  'users': [
                    {'localId': uid},
                  ],
                },
        ),
        200,
      );
    }
    if (path.endsWith('accounts:delete')) {
      deletedAccounts.add(body['localId']! as String);
      return http.Response('{}', 200);
    }
    if (path.endsWith('/accounts')) {
      final uid = 'uid-${accounts.length + 1}';
      accounts[body['email']! as String] = uid;
      return http.Response(jsonEncode({'localId': uid}), 200);
    }
    return http.Response('unexpected $path', 500);
  });
}

final class FakeVerifier implements IdTokenVerifier {
  @override
  Future<String?> uidOf(String token) async => token == 'good-token' ? 'uid-1' : null;
}

void main() {
  late ConsoleEmailSender mail;
  late FakeFirebase firebase;
  late Handler api;

  setUp(() {
    mail = ConsoleEmailSender(log: (_) {});
    firebase = FakeFirebase();
    api = KrakenApi(
      codes: SignInCodes(store: MemoryCodeStore(), sender: mail, pepper: 'test'),
      accounts: Accounts(projectId: 'demo-kraken', client: firebase.client, emulatorHost: 'localhost:9099'),
      firestore: Firestore(projectId: 'demo-kraken', client: firebase.client, emulatorHost: 'localhost:8080'),
      minter: EmulatorTokenMinter(),
      verifier: FakeVerifier(),
      log: (_) {},
    ).handler;
  });

  Future<Response> post(String path, Object? body, {Map<String, String> headers = const {}}) => Future.value(
    api(
      Request(
        'POST',
        Uri.parse('http://localhost$path'),
        body: body == null ? null : jsonEncode(body),
        headers: {'x-forwarded-for': '1.2.3.4', ...headers},
      ),
    ),
  );

  Future<Map<String, Object?>> json(Response r) async => jsonDecode(await r.readAsString()) as Map<String, Object?>;

  String sentCode() => RegExp(r'\d{6}').firstMatch(mail.sent.last.subject)!.group(0)!;

  test('code, then verify: a new account and a custom token', () async {
    expect((await post('/v1/auth/code', {'email': 'Aarav@example.com'})).statusCode, 204);
    final verified = await post('/v1/auth/verify', {'email': 'aarav@example.com', 'code': sentCode()});
    expect(verified.statusCode, 200);
    final body = await json(verified);
    expect(body['newUser'], isTrue);
    expect(body['customToken'], isA<String>());
    expect(firebase.accounts, {'aarav@example.com': 'uid-1'});

    // Signing in again finds the same account.
    await post('/v1/auth/code', {'email': 'aarav@example.com'}, headers: {'x-forwarded-for': '5.6.7.8'});
    final again = await json(await post('/v1/auth/verify', {'email': 'aarav@example.com', 'code': sentCode()}));
    expect(again['newUser'], isFalse);
    expect(firebase.accounts, hasLength(1));
  });

  test('errors come back as stable codes', () async {
    expect(await json(await post('/v1/auth/code', {'email': 'nope'})), {'error': 'invalid_email'});
    expect(await json(await post('/v1/auth/code', null)), {'error': 'invalid_email'});
    expect(await json(await post('/v1/auth/verify', {'email': 'a@b.co', 'code': '123456'})), {
      'error': 'no_code_requested',
    });
    await post('/v1/auth/code', {'email': 'a@b.co'});
    final again = await post('/v1/auth/code', {'email': 'a@b.co'});
    expect(again.statusCode, 429);
    expect((await json(again))['error'], 'resend_too_soon');
    final wrong = sentCode() == '000000' ? '111111' : '000000';
    final bad = await post('/v1/auth/verify', {'email': 'a@b.co', 'code': wrong});
    expect(await json(bad), {'error': 'wrong_code', 'attemptsLeft': 4});
  });

  test('delete needs a valid ID token, then removes the profile and the account', () async {
    expect((await post('/v1/account/delete', null)).statusCode, 401);
    expect((await post('/v1/account/delete', null, headers: {'authorization': 'Bearer forged'})).statusCode, 401);
    final ok = await post('/v1/account/delete', null, headers: {'authorization': 'Bearer good-token'});
    expect(ok.statusCode, 204);
    expect(firebase.deletedDocs, ['users/uid-1']);
    expect(firebase.deletedAccounts, ['uid-1']);
  });

  test('each address gets 20 sign-in requests a minute', () async {
    for (var i = 0; i < 20; i++) {
      await post('/v1/auth/code', {'email': 'x$i@example.com'});
    }
    final limited = await post('/v1/auth/code', {'email': 'late@example.com'});
    expect(limited.statusCode, 429);
    expect((await json(limited))['error'], 'rate_limited');
  });

  test('health check', () async {
    final response = await api(Request('GET', Uri.parse('http://localhost/healthz')));
    expect(response.statusCode, 200);
  });
}
