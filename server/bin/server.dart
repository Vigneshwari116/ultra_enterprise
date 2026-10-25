import 'dart:convert';
import 'dart:io';

import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:shelf_cors_headers/shelf_cors_headers.dart';
import 'package:shelf_router/shelf_router.dart';

import 'package:ultra_api_server/database_connection.dart';
import 'package:ultra_api_server/env.dart';
import 'package:ultra_api_server/register_merged_routes.dart';

/// Local/dev server exposing **merged missing routes only**.
/// On VPS, call [registerMergedRoutes] from the existing `ultra_server` entrypoint
/// so Sales Invoice and Purchase Voucher POST handlers stay untouched.
Future<void> main() async {
  final conn = await openDatabaseFromUrl(Env.databaseUrl);
  final router = Router();

  router.get('/health', (_) async {
    final rows = await conn.execute('SELECT current_database() AS name');
    final dbName = '${rows.first.toColumnMap()['name']}';
    return Response.ok(
      jsonEncode({'ok': true, 'database': dbName}),
      headers: {'content-type': 'application/json'},
    );
  });

  registerMergedRoutes(router, conn);

  final handler = const Pipeline()
      .addMiddleware(corsHeaders())
      .addMiddleware(logRequests())
      .addHandler(router.call);

  final server = await shelf_io.serve(handler, InternetAddress.anyIPv4, Env.port);
  stdout.writeln('Ultra merged routes listening on http://${server.address.host}:${server.port}');
}
