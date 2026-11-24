import 'dart:convert';

import 'package:http/http.dart' as http;

import 'google_clients.dart';

/// Firebase Auth accounts through the Identity Toolkit admin REST API.
final class Accounts {
  Accounts({required String projectId, required this.client, String? emulatorHost})
    : _base = emulatorHost != null
          ? 'http://$emulatorHost/identitytoolkit.googleapis.com/v1/projects/$projectId'
          : 'https://identitytoolkit.googleapis.com/v1/projects/$projectId';

  final http.Client client;
  final String _base;

  Future<Map<String, Object?>> _post(String path, Map<String, Object?> body) async {
    final response = await client.post(
      Uri.parse('$_base/$path'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(body),
    );
    if (response.statusCode >= 300) throw GoogleApiFailure(response.statusCode, response.body);
    return response.body.isEmpty ? {} : jsonDecode(response.body) as Map<String, Object?>;
  }

  /// The uid of the account with this email, if there is one.
  Future<String?> uidForEmail(String email) async {
    final result = await _post('accounts:lookup', {
      'email': [email],
    });
    final users = result['users'] as List<Object?>?;
    if (users == null || users.isEmpty) return null;
    return (users.first! as Map<String, Object?>)['localId'] as String?;
  }

  /// Creates an account for [email] (verified: they just typed its code).
  Future<String> create(String email) async {
    final result = await _post('accounts', {'email': email, 'emailVerified': true});
    return result['localId']! as String;
  }

  Future<void> delete(String uid) => _post('accounts:delete', {'localId': uid});

  /// The uid for [email], creating the account the first time.
  Future<({String uid, bool created})> findOrCreate(String email) async {
    final existing = await uidForEmail(email);
    if (existing != null) return (uid: existing, created: false);
    return (uid: await create(email), created: true);
  }
}
