import 'dart:io';

import 'package:kraken_server/kraken_server.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as io;

Future<void> main() async {
  final config = ServerConfig.fromEnvironment(Platform.environment);
  final api = await buildApi(config);
  final handler = const Pipeline().addMiddleware(logRequests()).addHandler(api.handler);
  final server = await io.serve(handler, InternetAddress.anyIPv4, config.port);
  final where = config.usesEmulators ? 'emulators' : 'project ${config.projectId}';
  print('Kraken API on :${server.port} ($where, mail: ${config.mailer.name})');
}
