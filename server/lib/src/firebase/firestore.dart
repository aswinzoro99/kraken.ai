import 'dart:convert';

import 'package:http/http.dart' as http;

import 'google_clients.dart';

/// The few Firestore calls the server needs, over the REST API
/// (https://firebase.google.com/docs/firestore/use-rest-api). Admin access:
/// security rules don't apply, so callers check permissions themselves.
final class Firestore {
  Firestore({required String projectId, required this.client, String? emulatorHost})
    : _base = emulatorHost != null
          ? 'http://$emulatorHost/v1/projects/$projectId/databases/(default)/documents'
          : 'https://firestore.googleapis.com/v1/projects/$projectId/databases/(default)/documents';

  final http.Client client;
  final String _base;

  Uri _uri(String path) => Uri.parse('$_base/$path');

  /// The document's fields, or null if it doesn't exist.
  Future<Map<String, Object?>?> get(String path) async {
    final response = await client.get(_uri(path));
    if (response.statusCode == 404) return null;
    _check(response);
    final fields = (jsonDecode(response.body) as Map<String, Object?>)['fields'] as Map<String, Object?>?;
    return fields == null ? {} : decodeFields(fields);
  }

  /// Creates or replaces the document.
  Future<void> set(String path, Map<String, Object?> data) async {
    final response = await client.patch(
      _uri(path),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'fields': encodeFields(data)}),
    );
    _check(response);
  }

  /// Deletes the document; fine if it doesn't exist.
  Future<void> delete(String path) async {
    final response = await client.delete(_uri(path));
    if (response.statusCode == 404) return;
    _check(response);
  }

  static void _check(http.Response response) {
    if (response.statusCode >= 300) throw GoogleApiFailure(response.statusCode, response.body);
  }

  // Firestore's typed value format, both ways.

  static Map<String, Object?> encodeFields(Map<String, Object?> data) => {
    for (final MapEntry(:key, :value) in data.entries) key: encodeValue(value),
  };

  static Map<String, Object?> encodeValue(Object? value) => switch (value) {
    null => {'nullValue': null},
    final bool b => {'booleanValue': b},
    final int i => {'integerValue': '$i'},
    final double d => {'doubleValue': d},
    final String s => {'stringValue': s},
    final DateTime t => {'timestampValue': t.toUtc().toIso8601String()},
    final Map<String, Object?> m => {
      'mapValue': {'fields': encodeFields(m)},
    },
    final List<Object?> l => {
      'arrayValue': {
        'values': [for (final v in l) encodeValue(v)],
      },
    },
    _ => throw ArgumentError('Firestore can\'t store ${value.runtimeType}'),
  };

  static Map<String, Object?> decodeFields(Map<String, Object?> fields) => {
    for (final MapEntry(:key, :value) in fields.entries) key: decodeValue(value! as Map<String, Object?>),
  };

  static Object? decodeValue(Map<String, Object?> value) {
    final MapEntry(:key, value: inner) = value.entries.single;
    return switch (key) {
      'nullValue' => null,
      'booleanValue' => inner! as bool,
      'integerValue' => int.parse(inner! as String),
      'doubleValue' => (inner! as num).toDouble(),
      'stringValue' => inner! as String,
      'timestampValue' => DateTime.parse(inner! as String),
      'mapValue' => decodeFields(((inner! as Map<String, Object?>)['fields'] ?? {}) as Map<String, Object?>),
      'arrayValue' => [
        for (final v in ((inner! as Map<String, Object?>)['values'] ?? []) as List<Object?>)
          decodeValue(v! as Map<String, Object?>),
      ],
      _ => throw FormatException('Unknown Firestore value $key'),
    };
  }
}
