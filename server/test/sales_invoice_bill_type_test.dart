import 'dart:convert';
import 'dart:io';

import 'package:postgres/postgres.dart';
import 'package:shelf/shelf.dart';
import 'package:test/test.dart';

import 'auth_test_helper.dart';
import 'test_fixture_paths.dart';

void main() {
  final dbUrl = Platform.environment['TEST_DATABASE_URL'] ??
      Platform.environment['DATABASE_URL'];

  group('sales invoice bill_type', () {
    if (dbUrl == null || dbUrl.isEmpty) {
      test('skipped without TEST_DATABASE_URL', () {}, skip: 'Set TEST_DATABASE_URL');
      return;
    }

    late Connection conn;
    late String adminToken;

    Future<void> runPsqlFile(String path) async {
      final sql = File(path).readAsStringSync();
      await conn.execute(sql);
    }

    setUp(() async {
      conn = await openTestDatabase(dbUrl!);
      final fixturesDir = vpsFixturesDir();
      await runPsqlFile('$fixturesDir/reset_test_schema.sql');
      await runPsqlFile('$fixturesDir/vps_ultra_enterprise_schema.sql');
      for (final path in vpsMigrationPaths()) {
        if (path.endsWith('003_users_sessions.sql')) {
          await applyIdempotentSqlFile(conn, path);
        } else {
          await runPsqlFile(path);
        }
      }
      adminToken = (await loginTestAdmin(conn)).token;
    });

    tearDown(() async {
      await conn.close();
    });

    Future<Response> call(String method, String path, {String? body}) {
      return callApi(conn, method, path, token: adminToken, body: body);
    }

    test('POST and GET round-trip bill_type and sel DC fields', () async {
      final cust = await conn.execute('SELECT id FROM customers LIMIT 1');
      expect(cust, isNotEmpty);
      final customerId = (cust.first.first as num).toInt();
      final prod = await conn.execute('SELECT id FROM products LIMIT 1');
      expect(prod, isNotEmpty);
      final productId = (prod.first.first as num).toInt();

      final body = jsonEncode({
        'uuid': '00000000-0000-4000-8000-00000000a001',
        'customer_id': customerId,
        'transaction_date': '2026-10-12',
        'state_zone_id': 1,
        'bill_type': 'LABOUR',
        'sel_dc_no': 'SEL-99',
        'sel_dc_date': '2026-10-01',
        'challan_dc_no': 'UEW-DC-1',
        'challan_dc_date': '2026-10-02',
        'vehicle_dispatch_mode': 'KA01',
        'taxable_total': 1000,
        'cgst_total': 90,
        'sgst_total': 90,
        'igst_total': 0,
        'grand_total': 1180,
        'fwd_charge': 0,
        'items': [
          {
            'product_id': productId,
            'description': 'Job work',
            'quantity': 1,
            'rate': 1000,
            'cgst_percent': 9,
            'sgst_percent': 9,
            'taxable': 1000,
            'cgst': 90,
            'sgst': 90,
            'total': 1180,
          },
        ],
      });

      final created = await call('POST', '/api/sales-invoices', body: body);
      expect(created.statusCode, 201);
      final createdJson =
          jsonDecode(await created.readAsString()) as Map<String, dynamic>;
      final id = createdJson['id'] as int;

      final got = await call('GET', '/api/sales-invoices/$id');
      expect(got.statusCode, 200);
      final doc = jsonDecode(await got.readAsString()) as Map<String, dynamic>;
      final invoice = doc['invoice'] as Map<String, dynamic>;
      expect(invoice['bill_type'], 'LABOUR');
      expect(invoice['sel_dc_no'], 'SEL-99');
      expect('${invoice['sel_dc_date']}', contains('2026-10-01'));
    });
  });
}
