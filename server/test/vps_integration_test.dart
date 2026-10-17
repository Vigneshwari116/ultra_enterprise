import 'dart:convert';
import 'dart:io';

import 'package:postgres/postgres.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';
import 'package:test/test.dart';
import 'package:ultra_api_server/database_connection.dart';
import 'package:ultra_api_server/register_merged_routes.dart';

import 'test_fixture_paths.dart';

double _pgNumeric(dynamic v) => double.tryParse('$v') ?? 0;

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

  final fixturesDir = vpsFixturesDir();
  final resetPath = '$fixturesDir/reset_test_schema.sql';
  final schemaPath = '$fixturesDir/vps_ultra_enterprise_schema.sql';
  final seedPath = '$fixturesDir/vps_ultra_enterprise_seed.sql';
  final migrationPath = vpsMigrationPath();

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
      if (FileSystemEntity.typeSync(path) == FileSystemEntityType.notFound) {
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

  Future<Response> _call(
    String method,
    String path, {
    Map<String, dynamic>? body,
  }) async {
    final c = conn;
    if (c == null) throw StateError('no connection');
    final router = Router();
    registerMergedRoutes(router, c);
    return router.call(
      Request(
        method,
        Uri.parse('http://127.0.0.1$path'),
        body: body == null ? null : jsonEncode(body),
        headers: body == null ? {} : {'content-type': 'application/json'},
      ),
    );
  }

  Future<Response> post(String path, Map<String, dynamic> body) =>
      _call('POST', path, body: body);

  Future<Response> put(String path, Map<String, dynamic> body) =>
      _call('PUT', path, body: body);

  Future<Response> delete(String path) => _call('DELETE', path);

  Future<Map<String, double>> _journalTotals(
    Connection c, {
    required String voucherType,
    required int voucherNo,
  }) async {
    final rows = await c.execute(
      Sql.named('''
        SELECT COALESCE(SUM(debit), 0) AS dr, COALESCE(SUM(credit), 0) AS cr
        FROM journal_entries
        WHERE voucher_type = @type AND voucher_no = @no
      '''),
      parameters: {'type': voucherType, 'no': voucherNo},
    );
    final m = rows.first.toColumnMap();
    return {'dr': _pgNumeric(m['dr']), 'cr': _pgNumeric(m['cr'])};
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

    final dateRows = await c.execute('''
      SELECT j.date::text AS journal_date, si.transaction_date::text AS voucher_date
      FROM journal_entries j
      JOIN sales_invoices si ON si.id = j.source_id
      WHERE j.voucher_type = 'SAL'
      ORDER BY j.id
      LIMIT 1
    ''');
    final dm = dateRows.first.toColumnMap();
    expect(dm['journal_date'], dm['voucher_date']);
    expect(dm['journal_date'], '2026-10-20');
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

    final dateRows = await c.execute('''
      SELECT j.date::text AS journal_date
      FROM journal_entries j
      WHERE j.voucher_type = 'PUR'
      ORDER BY j.id
      LIMIT 1
    ''');
    expect(dateRows.first.toColumnMap()['journal_date'], '2026-08-10');
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

  test('POST receipt posts Dr Cash Cr Customer', () async {
    final res = await post('/api/receipts', {
      'customer_id': 1,
      'receipt_date': '2026-10-21',
      'amount': 500,
      'narration': 'test receipt',
      'cash_bank': 'CASH',
    });
    expect(res.statusCode, 201, reason: await res.readAsString());

    final c = conn;
    final lines = await c!.execute('''
      SELECT l.name, j.debit, j.credit
      FROM journal_entries j
      JOIN ledgers l ON l.id = j.ledger_id
      WHERE j.voucher_type = 'REC'
      ORDER BY l.name
    ''');
    final map = <String, Map<String, double>>{};
    for (final r in lines) {
      final m = r.toColumnMap();
      map['${m['name']}'] = {
        'dr': _pgNumeric(m['debit']),
        'cr': _pgNumeric(m['credit']),
      };
    }
    expect(map['Cash']!['dr'], 500);
    expect(map['VPS Test Customer']!['cr'], 500);
  });

  test('POST payment posts Dr Supplier Cr Cash (default cash_bank)', () async {
    final res = await post('/api/payments', {
      'supplier_id': 1,
      'payment_date': '2026-10-22',
      'amount': 300,
      'payment_mode': 'CASH',
      'reference_no': '',
      'narration': 'test payment',
    });
    expect(res.statusCode, 201, reason: await res.readAsString());

    final c = conn;
    final stored = await c!.execute(
      "SELECT data::jsonb->>'cash_bank' AS cb FROM payments ORDER BY id DESC LIMIT 1",
    );
    expect(stored.first.toColumnMap()['cb'], 'CASH');

    final lines = await c.execute('''
      SELECT l.name, j.debit, j.credit
      FROM journal_entries j
      JOIN ledgers l ON l.id = j.ledger_id
      WHERE j.voucher_type = 'PAY'
      ORDER BY l.name
    ''');
    final map = <String, Map<String, double>>{};
    for (final r in lines) {
      final m = r.toColumnMap();
      map['${m['name']}'] = {
        'dr': _pgNumeric(m['debit']),
        'cr': _pgNumeric(m['credit']),
      };
    }
    expect(map['Cash']!['cr'], 300);
    expect(map['VPS Test Supplier']!['dr'], 300);
  });

  test('PUT purchase-voucher re-posts journals and keeps voucher_no', () async {
    final create = await post('/api/purchase-vouchers', _purchaseBody(grandTotal: 1298));
    expect(create.statusCode, 201);
    final created = jsonDecode(await create.readAsString()) as Map<String, dynamic>;
    final voucherId = (created['id'] as num).toInt();
    final voucherNo = (created['voucher'] as Map)['voucher_no'] as num;

    final before = await _journalTotals(conn!, voucherType: 'PUR', voucherNo: voucherNo.toInt());
    expect(before['dr'], before['cr']);

    final update = await put(
      '/api/purchase-vouchers/$voucherId',
      {
        ..._purchaseBody(grandTotal: 1198),
        'taxable_total': 1000,
        'cgst_total': 99,
        'sgst_total': 99,
        'supplier_invoice_no': 'T/updated',
      },
    );
    expect(update.statusCode, 200, reason: await update.readAsString());
    final updated = jsonDecode(await update.readAsString()) as Map<String, dynamic>;
    expect((updated['voucher'] as Map)['voucher_no'], voucherNo);
    expect((updated['voucher'] as Map)['voucher_no_display'], isNotNull);

    final after = await _journalTotals(conn!, voucherType: 'PUR', voucherNo: voucherNo.toInt());
    expect(after['dr'], after['cr']);
    expect(after['dr'], 1198);
    expect(after['dr'], isNot(before['dr']));
  });

  test('failed PUT purchase leaves original voucher and journals intact', () async {
    final create = await post('/api/purchase-vouchers', _purchaseBody(grandTotal: 1298));
    expect(create.statusCode, 201);
    final created = jsonDecode(await create.readAsString()) as Map<String, dynamic>;
    final voucherId = (created['id'] as num).toInt();
    final voucherNo = ((created['voucher'] as Map)['voucher_no'] as num).toInt();

    final beforeTotals = await _journalTotals(conn!, voucherType: 'PUR', voucherNo: voucherNo);
    final beforeHdr = await conn!.execute(
      Sql.named('SELECT data FROM purchase_vouchers WHERE id = @id'),
      parameters: {'id': voucherId},
    );
    final beforeData = beforeHdr.first.first as String;

    final bad = await put(
      '/api/purchase-vouchers/$voucherId',
      _purchaseBody(grandTotal: 9999),
    );
    expect(bad.statusCode, 400);

    final afterTotals = await _journalTotals(conn!, voucherType: 'PUR', voucherNo: voucherNo);
    expect(afterTotals['dr'], beforeTotals['dr']);
    expect(afterTotals['cr'], beforeTotals['cr']);

    final afterHdr = await conn!.execute(
      Sql.named('SELECT data FROM purchase_vouchers WHERE id = @id'),
      parameters: {'id': voucherId},
    );
    expect(afterHdr.first.first, beforeData);
  });

  test('DELETE purchase-voucher removes header, items, and journals', () async {
    final create = await post('/api/purchase-vouchers', _purchaseBody(grandTotal: 1298));
    expect(create.statusCode, 201);
    final created = jsonDecode(await create.readAsString()) as Map<String, dynamic>;
    final voucherId = (created['id'] as num).toInt();
    final voucherNo = ((created['voucher'] as Map)['voucher_no'] as num).toInt();

    final del = await delete('/api/purchase-vouchers/$voucherId');
    expect(del.statusCode, 200);

    final pv = await conn!.execute(
      Sql.named('SELECT 1 FROM purchase_vouchers WHERE id = @id'),
      parameters: {'id': voucherId},
    );
    expect(pv, isEmpty);
    final items = await conn!.execute(
      Sql.named('SELECT 1 FROM purchase_voucher_items WHERE parent_id = @id'),
      parameters: {'id': voucherId},
    );
    expect(items, isEmpty);
    final je = await _journalTotals(conn!, voucherType: 'PUR', voucherNo: voucherNo);
    expect(je['dr'], 0);
    expect(je['cr'], 0);
  });

  test('PUT receipt changes journal amounts; DELETE removes rows', () async {
    final create = await post('/api/receipts', {
      'customer_id': 1,
      'receipt_date': '2026-10-21',
      'amount': 500,
      'narration': 'before',
      'cash_bank': 'CASH',
    });
    expect(create.statusCode, 201);
    final created = jsonDecode(await create.readAsString()) as Map<String, dynamic>;
    final receiptId = (created['id'] as num).toInt();
    final voucherNo = ((created['receipt'] as Map)['voucher_no'] as num).toInt();

    final upd = await put('/api/receipts/$receiptId', {
      'customer_id': 1,
      'receipt_date': '2026-10-21',
      'amount': 750,
      'narration': 'after',
      'cash_bank': 'CASH',
    });
    expect(upd.statusCode, 200);
    final totals = await _journalTotals(conn!, voucherType: 'REC', voucherNo: voucherNo);
    expect(totals['dr'], 750);
    expect(totals['cr'], 750);

    final del = await delete('/api/receipts/$receiptId');
    expect(del.statusCode, 200);
    final left = await conn!.execute(
      Sql.named('SELECT 1 FROM receipts WHERE id = @id'),
      parameters: {'id': receiptId},
    );
    expect(left, isEmpty);
  });

  test('PUT and DELETE return 404 for unknown id', () async {
    expect((await delete('/api/purchase-vouchers/999999')).statusCode, 404);
    expect((await delete('/api/receipts/999999')).statusCode, 404);
    final bogusPut = await put(
      '/api/purchase-vouchers/999999',
      _purchaseBody(grandTotal: 1298),
    );
    expect(bogusPut.statusCode, 404);
  });
}
