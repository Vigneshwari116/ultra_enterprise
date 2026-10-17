import 'dart:convert';
import 'dart:io';

import 'package:postgres/postgres.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';
import 'package:test/test.dart';
import 'package:ultra_api_server/database_connection.dart';
import 'package:ultra_api_server/register_merged_routes.dart';

/// Integration tests against VPS-shaped schema (see fixtures/vps_ultra_enterprise_schema.sql).
void main() {
  final dbUrl =
      Platform.environment['TEST_DATABASE_URL'] ?? Platform.environment['DATABASE_URL'];

  if (dbUrl == null || dbUrl.isEmpty) {
    test('skipped without TEST_DATABASE_URL', () {}, skip: 'Set TEST_DATABASE_URL');
    return;
  }

  Connection? conn;
  final repoRoot = Directory.current.path.endsWith('server')
      ? Directory.current.parent
      : Directory.current;
  final schemaPath = '${repoRoot.path}/server/test/fixtures/vps_ultra_enterprise_schema.sql';
  final seedPath = '${repoRoot.path}/server/test/fixtures/vps_ultra_enterprise_seed.sql';
  final migrationPath = '${repoRoot.path}/server/schema/migrations/001_accounting.sql';

  Future<void> runPsqlFile(String path) async {
    final result = await Process.run(
      'psql',
      [dbUrl!, '-v', 'ON_ERROR_STOP=1', '-q', '-f', path],
    );
    if (result.exitCode != 0) {
      throw StateError('psql failed for $path: ${result.stderr}\n${result.stdout}');
    }
  }

  setUp(() async {
    await runPsqlFile(schemaPath);
    await runPsqlFile(seedPath);
    await runPsqlFile(migrationPath);
    conn = await openDatabaseFromUrl(dbUrl!);
  });

  tearDown(() async {
    await conn?.close();
  });

  Future<Response> post(String path, Map<String, dynamic> body) async {
    final router = Router();
    registerMergedRoutes(router, conn!);
    return router.call(
      Request(
        'POST',
        Uri.parse('http://127.0.0.1$path'),
        body: jsonEncode(body),
        headers: {'content-type': 'application/json'},
      ),
    );
  }

  test('POST sales-invoices on VPS-shaped schema', () async {
    final res = await post('/api/sales-invoices', {
      'customer_id': 1,
      'state_zone_id': 1,
      'transaction_date': '2026-10-20',
      'taxable_total': 5000,
      'cgst_total': 450,
      'sgst_total': 450,
      'igst_total': 0,
      'fwd_charge': 200,
      'grand_total': 6100,
      'items': [
        {
          'product_id': 1,
          'description': 'line',
          'hsn': '8471',
          'quantity': 1,
          'rate': 5000,
          'taxable': 5000,
          'cgst': 450,
          'sgst': 450,
          'total': 5900,
        }
      ],
    });
    expect(res.statusCode, 201);
    final journals = await conn!.execute(
      "SELECT COUNT(*) FROM journal_entries WHERE voucher_type = 'SAL'",
    );
    expect((journals.first.first as num) > 0, isTrue);
  });

  test('POST purchase-vouchers uses parent_id + data text items', () async {
    final res = await post('/api/purchase-vouchers', {
      'supplier_id': 1,
      'voucher_date': '2026-08-10',
      'taxable_total': 1100,
      'cgst_total': 99,
      'sgst_total': 99,
      'igst_total': 0,
      'grand_total': 1298,
      'status': 'POSTED',
      'supplier_invoice_no': 'T/1',
      'items': [
        {
          'product_id': 1,
          'description': 'item',
          'uom': 'NOS',
          'hsn': '7412',
          'quantity': 50,
          'rate': 25,
          'taxable': 1250,
          'cgst': 101.25,
          'sgst': 101.25,
          'total': 1328,
        }
      ],
    });
    expect(res.statusCode, 201, reason: await res.readAsString());

    final items = await conn!.execute('SELECT parent_id, data FROM purchase_voucher_items');
    expect(items.length, 1);
    expect(items.first.toColumnMap()['parent_id'], isNotNull);

    final purJ = await conn!.execute(
      "SELECT COUNT(*) FROM journal_entries WHERE voucher_type = 'PUR'",
    );
    expect((purJ.first.first as num) > 0, isTrue);
  });

  test('failed purchase save leaves no voucher, items, or journal rows', () async {
    final beforePv = await conn!.execute('SELECT COUNT(*) FROM purchase_vouchers');
    final beforeIt = await conn!.execute('SELECT COUNT(*) FROM purchase_voucher_items');
    final beforeJe = await conn!.execute('SELECT COUNT(*) FROM journal_entries');

    final res = await post('/api/purchase-vouchers', {
      'supplier_id': 1,
      'voucher_date': '2026-08-11',
      'taxable_total': 100,
      'cgst_total': 9,
      'sgst_total': 9,
      'igst_total': 0,
      'grand_total': 9999,
      'status': 'POSTED',
      'items': [
        {
          'product_id': 1,
          'description': 'bad total',
          'quantity': 1,
          'rate': 100,
          'taxable': 100,
          'total': 118,
        }
      ],
    });
    expect(res.statusCode, 400);

    final afterPv = await conn!.execute('SELECT COUNT(*) FROM purchase_vouchers');
    final afterIt = await conn!.execute('SELECT COUNT(*) FROM purchase_voucher_items');
    final afterJe = await conn!.execute('SELECT COUNT(*) FROM journal_entries');

    expect(afterPv.first.first, beforePv.first.first);
    expect(afterIt.first.first, beforeIt.first.first);
    expect(afterJe.first.first, beforeJe.first.first);
  });
}
