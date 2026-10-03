import 'dart:convert';
import 'dart:io';

import 'package:postgres/postgres.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';
import 'package:test/test.dart';
import 'package:ultra_api_server/register_merged_routes.dart';

/// Handler-level integration tests against PostgreSQL when TEST_DATABASE_URL is set.
void main() {
  final dbUrl = Platform.environment['TEST_DATABASE_URL'] ?? Platform.environment['DATABASE_URL'];

  group('merged routes', () {
    if (dbUrl == null || dbUrl.isEmpty) {
      test('skipped without TEST_DATABASE_URL', () {}, skip: 'Set TEST_DATABASE_URL');
      return;
    }

    late Connection conn;

    setUp(() async {
      conn = await Connection.openFromUrl(dbUrl);
    });

    tearDown(() async {
      await conn.close();
    });

    Future<Response> call(String method, String path, {String? body}) async {
      final router = Router();
      registerMergedRoutes(router, conn);
      return router.call(
        Request(
          method,
          Uri.parse('http://127.0.0.1$path'),
          body: body,
          headers: body != null ? {'content-type': 'application/json'} : null,
        ),
      );
    }

    test('GET purchase-vouchers/999999999 -> 404', () async {
      final response = await call('GET', '/api/purchase-vouchers/999999999');
      expect(response.statusCode, 404);
      final decoded = jsonDecode(await response.readAsString()) as Map;
      expect(decoded['error'], contains('not found'));
    });

    test('POST customers without name -> 400', () async {
      final response = await call('POST', '/api/customers', body: '{}');
      expect(response.statusCode, 400);
    });

    test('POST purchase-orders without items -> 400', () async {
      final response = await call(
        'POST',
        '/api/purchase-orders',
        body: '{"uuid":"00000000-0000-4000-8000-000000000001"}',
      );
      expect(response.statusCode, 400);
    });
  });
}
