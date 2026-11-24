@Tags(['emulator'])
library;

import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:kraken_server/kraken_server.dart';
import 'package:shelf/shelf.dart';
import 'package:test/test.dart';

/// The whole sign-in path against the real Firebase emulators:
/// code → verify → Firebase sign-in with the custom token → the rules let
/// you write your own profile but not read someone else's → delete.
///
/// Run with the emulators up (see README.md):
///   dart test --tags emulator
void main() {
  const project = 'demo-kraken';
  const auth = 'localhost:9099';
  const firestore = 'localhost:8080';
  final running = Platform.environment.containsKey('KRAKEN_EMULATORS');

  late ConsoleEmailSender mail;
  late Handler api;

  setUpAll(() async {
    if (!running) return;
    // Start clean.
    await http.delete(Uri.parse('http://$auth/emulator/v1/projects/$project/accounts'));
    await http.delete(Uri.parse('http://$firestore/emulator/v1/projects/$project/databases/(default)/documents'));
    mail = ConsoleEmailSender(log: (_) {});
    final config = ServerConfig.fromEnvironment({
      'PROJECT_ID': project,
      'FIREBASE_AUTH_EMULATOR_HOST': auth,
      'FIRESTORE_EMULATOR_HOST': firestore,
    });
    api = (await buildApi(config, sender: mail)).handler;
  });

  Future<Response> call(String path, Object? body, {String? bearer}) async => api(
    Request(
      'POST',
      Uri.parse('http://localhost$path'),
      body: jsonEncode(body),
      headers: {'x-forwarded-for': '10.0.0.1', 'authorization': ?bearer == null ? null : 'Bearer $bearer'},
    ),
  );

  /// Signs in to the Auth emulator the way the app will.
  Future<({String uid, String idToken})> signIn(String email) async {
    expect((await call('/v1/auth/code', {'email': email})).statusCode, 204);
    final code = RegExp(r'\d{6}').firstMatch(mail.sent.last.subject)!.group(0)!;
    final verified = await call('/v1/auth/verify', {'email': email, 'code': code});
    expect(verified.statusCode, 200);
    final token = (jsonDecode(await verified.readAsString()) as Map)['customToken'] as String;
    final session = await http.post(
      Uri.parse('http://$auth/identitytoolkit.googleapis.com/v1/accounts:signInWithCustomToken?key=demo'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'token': token, 'returnSecureToken': true}),
    );
    expect(session.statusCode, 200, reason: session.body);
    final body = jsonDecode(session.body) as Map<String, Object?>;
    final idToken = body['idToken']! as String;
    final payload = jsonDecode(utf8.decode(base64Url.decode(base64Url.normalize(idToken.split('.')[1])))) as Map;
    return (uid: payload['user_id'] as String, idToken: idToken);
  }

  Uri doc(String path) => Uri.parse('http://$firestore/v1/projects/$project/databases/(default)/documents/$path');

  test('sign in with an emailed code, own your profile, then delete it all', () async {
    final aarav = await signIn('aarav@example.com');
    final meera = await signIn('meera@example.com');
    expect(aarav.uid, isNot(meera.uid));

    // The same email signs back in to the same account.
    expect((await signIn('AARAV@example.com')).uid, aarav.uid);

    // Rules: write your own profile, not read someone else's.
    final write = await http.patch(
      doc('users/${aarav.uid}'),
      headers: {'Authorization': 'Bearer ${aarav.idToken}', 'Content-Type': 'application/json'},
      body: jsonEncode({
        'fields': {
          'uid': {'stringValue': aarav.uid},
          'displayName': {'stringValue': 'Aarav'},
        },
      }),
    );
    expect(write.statusCode, 200, reason: write.body);
    final peek = await http.get(doc('users/${aarav.uid}'), headers: {'Authorization': 'Bearer ${meera.idToken}'});
    expect(peek.statusCode, 403);
    final codes = await http.get(doc('authCodes'), headers: {'Authorization': 'Bearer ${aarav.idToken}'});
    expect(codes.statusCode, 403, reason: 'sign-in codes are server-only');

    // Delete: profile and account gone; a forged token can't delete anyone.
    expect((await call('/v1/account/delete', null, bearer: 'forged')).statusCode, 401);
    expect((await call('/v1/account/delete', null, bearer: aarav.idToken)).statusCode, 204);
    final gone = await http.get(doc('users/${aarav.uid}'), headers: {'Authorization': 'Bearer owner'});
    expect(gone.statusCode, 404);
    final lookup = await http.post(
      Uri.parse('http://$auth/identitytoolkit.googleapis.com/v1/projects/$project/accounts:lookup'),
      headers: {'Authorization': 'Bearer owner', 'Content-Type': 'application/json'},
      body: jsonEncode({
        'localId': [aarav.uid],
      }),
    );
    expect((jsonDecode(lookup.body) as Map)['users'], isNull);
  }, skip: running ? false : 'Start the emulators and set KRAKEN_EMULATORS=1 (see README.md)');
}
