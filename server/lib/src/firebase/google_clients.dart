import 'package:googleapis_auth/auth_io.dart';
import 'package:http/http.dart' as http;

import '../config.dart';

/// An HTTP client allowed to call Firebase's admin APIs.
///
/// * Emulators accept the fixed `Bearer owner` token (admin, bypasses rules).
/// * With a service account key (local runs against real Firebase), that key.
/// * On Cloud Run, the service's own identity (Application Default
///   Credentials from the metadata server).
Future<http.Client> adminClient(ServerConfig config) async {
  if (config.usesEmulators) return _OwnerClient(http.Client());
  const scopes = ['https://www.googleapis.com/auth/cloud-platform'];
  final key = config.serviceAccountJson;
  if (key != null) return clientViaServiceAccount(ServiceAccountCredentials.fromJson(key), scopes);
  return clientViaApplicationDefaultCredentials(scopes: scopes);
}

final class _OwnerClient extends http.BaseClient {
  _OwnerClient(this._inner);
  final http.Client _inner;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    request.headers['Authorization'] = 'Bearer owner';
    return _inner.send(request);
  }

  @override
  void close() => _inner.close();
}

/// Thrown when a Google API answers with an error.
final class GoogleApiFailure implements Exception {
  const GoogleApiFailure(this.status, this.body);
  final int status;
  final String body;
  @override
  String toString() => 'GoogleApiFailure($status): $body';
}
