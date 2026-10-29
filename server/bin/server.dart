import 'dart:io';

import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:shelf_cors_headers/shelf_cors_headers.dart';

import 'package:ultra_api_server/api_handler.dart';
import 'package:ultra_api_server/auth/bootstrap_admin.dart';
import 'package:ultra_api_server/database_connection.dart';
import 'package:ultra_api_server/env.dart';

/// Local/dev server. Business routes stay in [buildApiHandler]; this entrypoint
/// only opens the database, creates the first superuser when needed, and serves HTTP.
Future<void> main() async {
  final conn = await openDatabaseFromUrl(Env.databaseUrl);
  await ensureInitialAdmin(conn);

  final handler = const Pipeline()
      .addMiddleware(corsHeaders())
      .addMiddleware(logRequests())
      .addHandler(buildApiHandler(conn));

  final server = await shelf_io.serve(handler, InternetAddress.anyIPv4, Env.port);
  stdout.writeln('Ultra API listening on http://${server.address.host}:${server.port}');
}
