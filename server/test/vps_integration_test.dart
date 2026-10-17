import 'dart:convert';
import 'dart:io';

import 'package:postgres/postgres.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';
import 'package:test/test.dart';
import 'package:ultra_api_server/database_connection.dart';
import 'package:ultra_api_server/register_merged_routes.dart';

String _databaseNameFromUrl(String url) {
  final path = Uri.parse(url).path;
  if (path.isEmpty || path == '/') return '';
  return path.replaceFirst('/', '').split('/').first;
}

void _assertTestDatabaseOnly(String url) {
  final db = _databaseNameFromUrl(url);
  if (db == 'ultra_copy' || db == 'ultra_enterprise') {
    throw StateError(
      'Refusing to run: database "$db" is production-like. Use ultra_copy_test only.',
    );
  }
  if (!db.endsWith('_test')) {
    throw StateError(
      'Refusing to run destructive fixture load: database "$db" must end with _test '
      '(e.g. ultra_copy_test).',
    );
  }
}

/// Integration tests against production-shaped schema (vps_ultra_enterprise_schema.sql).
void main() {
  final testDbUrl = Platform.environment['TEST_DATABASE_URL'];
  if (testDbUrl == null || testDbUrl.isEmpty) {
    test('skipped without TEST_DATABASE_URL', () {}, skip: 'Set TEST_DATABASE_URL to ultra_copy_test');
    return;
  }

  _assertTestDatabaseOnly(testDbUrl);

  final fixturesDir = Directory('${File(Platform.script.toFilePath()).parent.path}/fixtures');
  final resetPath = '${fixturesDir.path}/reset_test_schema.sql';
  final schemaPath = '${fixturesDir.path}/vps_ultra_enterprise_schema.sql';
  final seedPath = '${fixturesDir.path}/vps_ultra_enterprise_seed.sql';
  final migrationPath =
      '${Directory(Platform.script.toFilePath()).parent.parent.parent.path}/schema/migrations/001_accounting.sql';

  Connection? conn;

  Future<void> runPsqlFile(String path) async {
    final result = await Process.run(
      'psql',
      [testDbUrl, '-v', 'ON_ERROR_STOP=1', '-q', '-f', path],
    );
    if (result.exitCode != 0) {
      throw StateError('psql failed for $path: ${result.stderr}\n${result.stdout}');
    }
  }

  setUpAll(() async {
    final which = await Process.run('which', ['psql']);
    if (which.exitCode != 0) {
      throw StateError(
        'psql not found on PATH. Install postgresql-client to run vps_integration_test.',
      );
    }
    for (final path in [resetPath, schemaPath, seedPath, migrationPath]) {
      if (!File(path).existsSync()) {
        throw StateError('Missing fixture file: $path');
      }
    }
  });

  setUp(() async {
    await runPsqlFile(resetPath);
    await runPsqlFile(schemaPath);
    await runPsqlFile(seedPath);
    await runPsqlFile(migrationPath);
    conn = await openDatabaseFromUrl(testDbUrl);
  });

  tearDown(() async {
    await conn?.close();
    conn = null;
  });

  Future<Response> post(String path, Map<String, dynamic> body) async {
    final c = conn;
    if (c == null) throw StateError('no connection');
    final router = Router();
    registerMergedRoutes(router, c);
    return router.call(
      Request(
        'POST',
        Uri.parse('http://127.0.0.1$path'),
        body: jsonEncode(body),
        headers: {'content-type': 'application/json'},
      ),
    );
  }

  Map<String, dynamic> _purchaseBody({required double grandTotal}) => {
        'supplier_id': 1,
        'voucher_date': '2026-08-10',
        'taxable_total': 1100,
        'cgst_total': 99,
        'sgst_total': 99,
        'igst_total': 0,
        'grand_total': grandTotal,
        'status': 'POSTED',
        'supplier_invoice_no': 'T/1',
        'items': [
          {
            'product_id': 1,
            'description': 'item',
            'quantity': 1,
            'rate': 100,
            'taxable': 100,
            'total': 118,
          }
        ],
      };

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
    final c = conn;
    expect(c, isNotNull);
    final journals = await c!.execute(
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

    final c = conn;
    final items = await c!.execute('SELECT parent_id, data FROM purchase_voucher_items');
    expect(items.length, 1);
    expect(items.first.toColumnMap()['parent_id'], isNotNull);

    final purJ = await c.execute(
      "SELECT COUNT(*) FROM journal_entries WHERE voucher_type = 'PUR'",
    );
    expect((purJ.first.first as num) > 0, isTrue);
  });

  test('failed purchase save leaves no voucher, items, or journal rows', () async {
    final c = conn!;
    final beforePv = await c.execute('SELECT COUNT(*) FROM purchase_vouchers');
    final beforeIt = await c.execute('SELECT COUNT(*) FROM purchase_voucher_items');
    final beforeJe = await c.execute('SELECT COUNT(*) FROM journal_entries');

    final res = await post('/api/purchase-vouchers', _purchaseBody(grandTotal: 9999));
    expect(res.statusCode, 400);

    final afterPv = await c.execute('SELECT COUNT(*) FROM purchase_vouchers');
    final afterIt = await c.execute('SELECT COUNT(*) FROM purchase_voucher_items');
    final afterJe = await c.execute('SELECT COUNT(*) FROM journal_entries');

    expect(afterPv.first.first, beforePv.first.first);
    expect(afterIt.first.first, beforeIt.first.first);
    expect(afterJe.first.first, beforeJe.first.first);
  });

  test('failed then successful purchase gets consecutive voucher_no', () async {
    final fail = await post('/api/purchase-vouchers', _purchaseBody(grandTotal: 9999));
    expect(fail.statusCode, 400);

    final ok = await post('/api/purchase-vouchers', _purchaseBody(grandTotal: 1298));
    expect(ok.statusCode, 201);
    final body = jsonDecode(await ok.readAsString()) as Map<String, dynamic>;
    final firstNo = (body['voucher'] as Map)['voucher_no'];

    final ok2 = await post('/api/purchase-vouchers', {
      ..._purchaseBody(grandTotal: 1298),
      'supplier_invoice_no': 'T/2',
    });
    expect(ok2.statusCode, 201);
    final body2 = jsonDecode(await ok2.readAsString()) as Map<String, dynamic>;
    final secondNo = (body2['voucher'] as Map)['voucher_no'];

    expect(secondNo, firstNo + 1);
  });
}
