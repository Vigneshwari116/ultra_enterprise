import 'dart:convert';
import 'dart:io';

import 'package:postgres/postgres.dart';
import 'package:shelf/shelf.dart';
import 'package:test/test.dart';

import 'auth_test_helper.dart';

/// Handler-level integration tests against PostgreSQL when TEST_DATABASE_URL is set.
void main() {
  final dbUrl = Platform.environment['TEST_DATABASE_URL'] ?? Platform.environment['DATABASE_URL'];

  group('merged routes', () {
    if (dbUrl == null || dbUrl.isEmpty) {
      test('skipped without TEST_DATABASE_URL', () {}, skip: 'Set TEST_DATABASE_URL');
      return;
    }

    late Connection conn;
    late String adminToken;

    setUp(() async {
      conn = await openTestDatabase(dbUrl!);
      await ensureAuthTables(conn);
      adminToken = (await loginTestAdmin(conn)).token;
    });

    tearDown(() async {
      await conn.close();
    });

    Future<Response> call(String method, String path, {String? body}) {
      return callApi(conn, method, path, token: adminToken, body: body);
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
