import 'dart:convert';
import 'dart:io';

import 'package:postgres/postgres.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';
import 'package:test/test.dart';
import 'package:ultra_api_server/database_connection.dart';
import 'package:ultra_api_server/register_merged_routes.dart';

/// Accounting phase-1 integration tests (migration + sales POST + journals).
///
/// Requires PostgreSQL. Set TEST_DATABASE_URL (recommended) or DATABASE_URL.
/// Run: cd server && dart test test/accounting_phase1_test.dart
double _asNum(dynamic v) =>
    v is num ? v.toDouble() : double.tryParse('$v') ?? 0;

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
  final bootstrapPath =
      '${repoRoot.path}/server/test/fixtures/accounting_phase1_bootstrap.sql';
  final migrationPath =
      '${repoRoot.path}/server/schema/migrations/001_accounting.sql';

  Future<void> runPsqlFile(String path) async {
    final result = await Process.run(
      'psql',
      [dbUrl!, '-v', 'ON_ERROR_STOP=1', '-q', '-f', path],
    );
    if (result.exitCode != 0) {
      throw StateError(
        'psql failed for $path: ${result.stderr}\n${result.stdout}',
      );
    }
  }

  setUp(() async {
    await runPsqlFile(bootstrapPath);
    await runPsqlFile(migrationPath);
    await runPsqlFile(migrationPath); // idempotent second apply
    conn = await openDatabaseFromUrl(dbUrl!);
  });

  tearDown(() async {
    await conn?.close();
  });

  Future<Response> postSales(Map<String, dynamic> body) async {
    final router = Router();
    registerMergedRoutes(router, conn!);
    return router.call(
      Request(
        'POST',
        Uri.parse('http://127.0.0.1/api/sales-invoices'),
        body: jsonEncode(body),
        headers: {'content-type': 'application/json'},
      ),
    );
  }

  Future<Response> postPurchase(Map<String, dynamic> body) async {
    final router = Router();
    registerMergedRoutes(router, conn!);
    return router.call(
      Request(
        'POST',
        Uri.parse('http://127.0.0.1/api/purchase-vouchers'),
        body: jsonEncode(body),
        headers: {'content-type': 'application/json'},
      ),
    );
  }

  Map<String, dynamic> vpsPurchaseItem() => {
        'hsn': '7412',
        'uom': 'NOS',
        'cgst': 101.25,
        'igst': 0.0,
        'rate': 25.0,
        'sgst': 101.25,
        'total': 1328.0,
        'taxable': 1250.0,
        'quantity': 50.0,
        'product_id': 1,
        'description': '6 DIA QRC RK',
        'cgst_percent': 9.0,
        'igst_percent': 18.0,
        'sgst_percent': 9.0,
      };

  Map<String, dynamic> baseItem() => {
        'product_id': 1,
        'description': 'Test line',
        'hsn': '8471',
        'quantity': 1,
        'rate': 5000,
        'taxable': 5000,
        'total': 5000,
      };

  test('supplier party ledgers start at zero opening (not in supplier JSON)', () async {
    final rows = await conn!.execute('''
      SELECT opening_balance, opening_type
      FROM ledgers WHERE party_kind = 'SUPPLIER' AND party_id = 1
    ''');
    expect(rows, isNotEmpty);
    final m = rows.first.toColumnMap();
    expect(_asNum(m['opening_balance']), 0);
    expect(m['opening_type'], 'cr');
  });

  test('migration creates ledgers and journal tables', () async {
    final ledgers = await conn!.execute('SELECT COUNT(*) FROM ledgers');
    final journals = await conn!.execute(
      "SELECT to_regclass('public.journal_entries') IS NOT NULL AS ok",
    );
    expect((ledgers.first.first as num) >= 13, isTrue);
    expect(journals.first.toColumnMap()['ok'], isTrue);
  });

  test('intra-state sale posts balanced journal with CGST and SGST', () async {
    final body = {
      'customer_id': 1,
      'state_zone_id': 1,
      'transaction_date': '2026-10-10',
      'taxable_total': 5000,
      'cgst_total': 450,
      'sgst_total': 450,
      'igst_total': 0,
      'fwd_charge': 0,
      'grand_total': 5900,
      'items': [
        {
          ...baseItem(),
          'cgst_percent': 9,
          'sgst_percent': 9,
          'cgst': 450,
          'sgst': 450,
          'total': 5900,
        }
      ],
    };
    final res = await postSales(body);
    expect(res.statusCode, 201);
    final lines = await conn!.execute('''
      SELECT l.name, j.debit, j.credit
      FROM journal_entries j
      JOIN ledgers l ON l.id = j.ledger_id
      WHERE j.voucher_type = 'SAL'
      ORDER BY l.name
    ''');
    final map = <String, Map<String, double>>{};
    for (final r in lines) {
      final row = r.toColumnMap();
      map['${row['name']}'] = {
        'dr': _asNum(row['debit']),
        'cr': _asNum(row['credit']),
      };
    }
    expect(map['Phase1 Test Customer']!['dr'], 5900);
    expect(map['Sales']!['cr'], 5000);
    expect(map['Output CGST']!['cr'], 450);
    expect(map['Output SGST']!['cr'], 450);
    expect(map.containsKey('Output IGST'), isFalse);
    final bal = await conn!.execute(
      'SELECT SUM(debit) AS dr, SUM(credit) AS cr FROM journal_entries',
    );
    final dr = _asNum(bal.first.toColumnMap()['dr']);
    final cr = _asNum(bal.first.toColumnMap()['cr']);
    expect((dr - cr).abs() < 0.01, isTrue);
  });

  test('inter-state sale posts IGST only', () async {
    final body = {
      'customer_id': 1,
      'state_zone_id': 2,
      'transaction_date': '2026-10-11',
      'taxable_total': 5000,
      'cgst_total': 0,
      'sgst_total': 0,
      'igst_total': 900,
      'fwd_charge': 0,
      'grand_total': 5900,
      'items': [
        {
          ...baseItem(),
          'igst_percent': 18,
          'igst': 900,
          'total': 5900,
        }
      ],
    };
    final res = await postSales(body);
    expect(res.statusCode, 201);
    final igst = await conn!.execute(
      "SELECT credit FROM journal_entries j JOIN ledgers l ON l.id = j.ledger_id "
      "WHERE l.system_key = 'OUTPUT_IGST'",
    );
    expect(_asNum(igst.first.first), 900);
  });

  test('sale with freight posts Freight & Charges credit', () async {
    final body = {
      'customer_id': 1,
      'state_zone_id': 1,
      'transaction_date': '2026-10-12',
      'taxable_total': 5000,
      'cgst_total': 450,
      'sgst_total': 450,
      'igst_total': 0,
      'fwd_charge': 200,
      'grand_total': 6100,
      'items': [
        {
          ...baseItem(),
          'cgst': 450,
          'sgst': 450,
          'total': 5900,
        }
      ],
    };
    final res = await postSales(body);
    expect(res.statusCode, 201);
    final freight = await conn!.execute(
      "SELECT credit FROM journal_entries j JOIN ledgers l ON l.id = j.ledger_id "
      "WHERE l.system_key = 'FREIGHT'",
    );
    expect(_asNum(freight.first.first), 200);
  });

  test('failed save rolls back invoice and journal', () async {
    final beforeInv = await conn!.execute('SELECT COUNT(*) FROM sales_invoices');
    final beforeJe = await conn!.execute('SELECT COUNT(*) FROM journal_entries');
    final body = {
      'customer_id': 1,
      'state_zone_id': 1,
      'transaction_date': '2026-10-13',
      'taxable_total': 5000,
      'cgst_total': 450,
      'sgst_total': 450,
      'igst_total': 0,
      'fwd_charge': 0,
      'grand_total': 9999,
      'items': [baseItem()],
    };
    final res = await postSales(body);
    expect(res.statusCode, isNot(201));
    final afterInv = await conn!.execute('SELECT COUNT(*) FROM sales_invoices');
    final afterJe = await conn!.execute('SELECT COUNT(*) FROM journal_entries');
    expect(afterInv.first.first, beforeInv.first.first);
    expect(afterJe.first.first, beforeJe.first.first);
  });

  test('ten concurrent saves get unique sequential numbers', () async {
    Future<Response> postOnOwnConn() async {
      final c = await openDatabaseFromUrl(dbUrl!);
      try {
        final router = Router();
        registerMergedRoutes(router, c);
        return await router.call(
          Request(
            'POST',
            Uri.parse('http://127.0.0.1/api/sales-invoices'),
            body: jsonEncode({
              'customer_id': 1,
              'state_zone_id': 1,
              'transaction_date': '2026-10-15',
              'taxable_total': 100,
              'cgst_total': 9,
              'sgst_total': 9,
              'igst_total': 0,
              'fwd_charge': 0,
              'grand_total': 118,
              'items': [
                {
                  ...baseItem(),
                  'rate': 100,
                  'taxable': 100,
                  'cgst': 9,
                  'sgst': 9,
                  'total': 118,
                }
              ],
            }),
            headers: {'content-type': 'application/json'},
          ),
        );
      } finally {
        await c.close();
      }
    }

    final results = await Future.wait(List.generate(10, (_) => postOnOwnConn()));
    expect(results.every((r) => r.statusCode == 201), isTrue);
    final nums = await conn!.execute(
      'SELECT invoice_no FROM sales_invoices ORDER BY invoice_no',
    );
    final values = nums.map((r) => _asNum(r.first).toInt()).toList();
    expect(values.length, 10);
    expect(values.toSet().length, 10);
    expect(values, equals(List.generate(10, (i) => i + 1)));
  });

  test('SQL journal lines for intra, inter, and freight sample bills', () async {
    Future<void> save(Map<String, dynamic> body) async {
      final res = await postSales(body);
      expect(res.statusCode, 201);
    }

    await save({
      'customer_id': 1,
      'state_zone_id': 1,
      'transaction_date': '2026-10-20',
      'taxable_total': 5000,
      'cgst_total': 450,
      'sgst_total': 450,
      'igst_total': 0,
      'fwd_charge': 0,
      'grand_total': 5900,
      'items': [
        {
          ...baseItem(),
          'cgst': 450,
          'sgst': 450,
          'total': 5900,
        }
      ],
    });
    await save({
      'customer_id': 1,
      'state_zone_id': 2,
      'transaction_date': '2026-10-21',
      'taxable_total': 5000,
      'cgst_total': 0,
      'sgst_total': 0,
      'igst_total': 900,
      'fwd_charge': 0,
      'grand_total': 5900,
      'items': [
        {
          ...baseItem(),
          'igst': 900,
          'total': 5900,
        }
      ],
    });
    await save({
      'customer_id': 1,
      'state_zone_id': 1,
      'transaction_date': '2026-10-22',
      'taxable_total': 5000,
      'cgst_total': 450,
      'sgst_total': 450,
      'igst_total': 0,
      'fwd_charge': 200,
      'grand_total': 6100,
      'items': [
        {
          ...baseItem(),
          'cgst': 450,
          'sgst': 450,
          'total': 5900,
        }
      ],
    });

    final rows = await conn!.execute('''
      SELECT j.voucher_no_display, l.name AS ledger, j.debit, j.credit
      FROM journal_entries j
      JOIN ledgers l ON l.id = j.ledger_id
      ORDER BY j.voucher_no_display, l.name
    ''');
    // Visible in `dart test --reporter expanded` output.
    print('\n--- SQL: journal_entries for 3 sample sales bills ---');
    print('voucher_no_display | ledger | debit | credit');
    for (final r in rows) {
      final m = r.toColumnMap();
      print(
        '${m['voucher_no_display']} | ${m['ledger']} | ${m['debit']} | ${m['credit']}',
      );
    }
    final bal = await conn!.execute(
      'SELECT SUM(debit) AS dr, SUM(credit) AS cr FROM journal_entries',
    );
    final m = bal.first.toColumnMap();
    print('TOTAL debit=${m['dr']} credit=${m['cr']}');
  });

  test('legacy DB with invoice_no 1..208 allocates 209 and FY display', () async {
    await conn!.execute('''
      INSERT INTO sales_invoices (
        uuid, invoice_no, customer_id, transaction_date,
        taxable_total, cgst_total, sgst_total, igst_total,
        compound_gst_total, fwd_charge, grand_total, status
      )
      SELECT
        gen_random_uuid(),
        gs,
        1,
        '2025-06-01'::timestamptz,
        0, 0, 0, 0,
        0, 0, 0,
        'POSTED'
      FROM generate_series(1, 208) AS gs
    ''');
    await conn!.execute('SELECT sync_global_voucher_sequences()');

    final res = await postSales({
      'customer_id': 1,
      'state_zone_id': 1,
      'transaction_date': '2026-10-15',
      'taxable_total': 100,
      'cgst_total': 9,
      'sgst_total': 9,
      'igst_total': 0,
      'fwd_charge': 0,
      'grand_total': 118,
      'items': [
        {
          ...baseItem(),
          'rate': 100,
          'taxable': 100,
          'cgst': 9,
          'sgst': 9,
          'total': 118,
        }
      ],
    });
    expect(res.statusCode, 201);
    final body = jsonDecode(await res.readAsString()) as Map<String, dynamic>;
    final inv = body['invoice'] as Map<String, dynamic>;
    expect(inv['invoice_no'], 209);
    expect(inv['voucher_no_display'], 'SAL-26-27-1');

    final row = await conn!.execute('''
      SELECT invoice_no, voucher_no_display, compound_gst_total, grand_total,
        taxable_total + cgst_total + sgst_total + igst_total + fwd_charge AS expected_grand
      FROM sales_invoices WHERE invoice_no = 209
    ''');
    final m = row.first.toColumnMap();
    expect(m['voucher_no_display'], 'SAL-26-27-1');
    expect(_asNum(m['compound_gst_total']), 18);
    expect(_asNum(m['grand_total']), _asNum(m['expected_grand']));
    expect(_asNum(m['grand_total']), 118);

    final fyBody = {
      'customer_id': 1,
      'state_zone_id': 1,
      'taxable_total': 100,
      'cgst_total': 9,
      'sgst_total': 9,
      'igst_total': 0,
      'fwd_charge': 0,
      'grand_total': 118,
      'items': [
        {
          ...baseItem(),
          'rate': 100,
          'taxable': 100,
          'cgst': 9,
          'sgst': 9,
          'total': 118,
        }
      ],
    };
    expect(
      (await postSales({...fyBody, 'transaction_date': '2026-03-31'})).statusCode,
      201,
    );
    expect(
      (await postSales({...fyBody, 'transaction_date': '2026-04-01'})).statusCode,
      201,
    );
    final fyRows = await conn!.execute('''
      SELECT invoice_no, voucher_no_display
      FROM sales_invoices
      WHERE invoice_no >= 210
      ORDER BY transaction_date
    ''');
    expect(fyRows.length, 2);
    expect(fyRows[0].toColumnMap()['invoice_no'], 210);
    expect(fyRows[0].toColumnMap()['voucher_no_display'], 'SAL-25-26-1');
    expect(fyRows[1].toColumnMap()['invoice_no'], 211);
    expect(fyRows[1].toColumnMap()['voucher_no_display'], 'SAL-26-27-1');
  });

  test('FY rollover: display resets; global invoice_no does not', () async {
    await postSales({
      'customer_id': 1,
      'state_zone_id': 1,
      'transaction_date': '2026-03-31',
      'taxable_total': 100,
      'cgst_total': 9,
      'sgst_total': 9,
      'igst_total': 0,
      'fwd_charge': 0,
      'grand_total': 118,
      'items': [
        {
          ...baseItem(),
          'rate': 100,
          'taxable': 100,
          'cgst': 9,
          'sgst': 9,
          'total': 118,
        }
      ],
    });
    await postSales({
      'customer_id': 1,
      'state_zone_id': 1,
      'transaction_date': '2026-04-01',
      'taxable_total': 100,
      'cgst_total': 9,
      'sgst_total': 9,
      'igst_total': 0,
      'fwd_charge': 0,
      'grand_total': 118,
      'items': [
        {
          ...baseItem(),
          'rate': 100,
          'taxable': 100,
          'cgst': 9,
          'sgst': 9,
          'total': 118,
        }
      ],
    });
    final rows = await conn!.execute('''
      SELECT invoice_no, voucher_no_display
      FROM sales_invoices ORDER BY transaction_date
    ''');
    expect(rows[0].toColumnMap()['voucher_no_display'], 'SAL-25-26-1');
    expect(rows[1].toColumnMap()['voucher_no_display'], 'SAL-26-27-1');
    expect(rows[0].toColumnMap()['invoice_no'], 1);
    expect(rows[1].toColumnMap()['invoice_no'], 2);
    final counters = await conn!.execute(
      "SELECT fy, last_no FROM voucher_counters WHERE voucher_type = 'SAL' ORDER BY fy",
    );
    expect(counters.length, 2);
  });

  test('purchase VPS JSON: header totals post; item sums ignored', () async {
    await conn!.execute('''
      INSERT INTO purchase_vouchers (uuid, status, data)
      SELECT
        gen_random_uuid(),
        'POSTED',
        jsonb_build_object(
          'voucher_no', gs,
          'supplier_id', 1,
          'voucher_date', '2025-01-01',
          'taxable_total', 0,
          'cgst_total', 0,
          'sgst_total', 0,
          'igst_total', 0,
          'grand_total', 0,
          'status', 'POSTED'
        )
      FROM generate_series(1, 261) AS gs
    ''');
    await conn!.execute('SELECT sync_global_voucher_sequences()');

    final res = await postPurchase({
      'uuid': 'PURCHASE:262',
      'status': 'POSTED',
      'supplier_id': 1,
      'voucher_date': '2026-08-10',
      'taxable_total': 1100.0,
      'cgst_total': 99.0,
      'sgst_total': 99.0,
      'igst_total': 0.0,
      'grand_total': 1298.0,
      'purchase_order_id': null,
      'supplier_invoice_no': 'SRP/32814',
      'supplier_invoice_date': '2026-08-10',
      'items': [vpsPurchaseItem()],
    });
    expect(res.statusCode, 201);
    final decoded = jsonDecode(await res.readAsString()) as Map<String, dynamic>;
    final voucher = decoded['voucher'] as Map<String, dynamic>;
    expect(voucher['voucher_no'], 262);
    expect(voucher['voucher_no_display'], 'PUR-26-27-1');

    final stored = await conn!.execute(
      Sql.named('''
      SELECT data::jsonb->>'voucher_no' AS voucher_no, voucher_no_display
      FROM purchase_vouchers WHERE id = @id
    '''),
      parameters: {'id': voucher['id']},
    );
    final row = stored.first.toColumnMap();
    expect(row['voucher_no'], '262');
    expect(row['voucher_no_display'], 'PUR-26-27-1');

    final lines = await conn!.execute('''
      SELECT l.name, j.debit, j.credit
      FROM journal_entries j
      JOIN ledgers l ON l.id = j.ledger_id
      WHERE j.voucher_type = 'PUR' AND j.voucher_no = 262
      ORDER BY l.name
    ''');
    final map = <String, Map<String, double>>{};
    for (final r in lines) {
      final m = r.toColumnMap();
      map['${m['name']}'] = {
        'dr': _asNum(m['debit']),
        'cr': _asNum(m['credit']),
      };
    }
    expect(map['Purchase']!['dr'], 1100);
    expect(map['Input CGST']!['dr'], 99);
    expect(map['Input SGST']!['dr'], 99);
    expect(map['Phase1 Test Supplier']!['cr'], 1298);
    expect(map.containsKey('Round Off'), isFalse);
  });

  test('purchase round-off within 1 rupee', () async {
    final res = await postPurchase({
      'supplier_id': 1,
      'voucher_date': '2026-08-11',
      'taxable_total': 100,
      'cgst_total': 9,
      'sgst_total': 9,
      'igst_total': 0,
      'grand_total': 118.5,
      'status': 'POSTED',
      'items': [
        {
          'product_id': 1,
          'description': 'line',
          'quantity': 1,
          'rate': 100,
          'taxable': 100,
          'cgst': 9,
          'sgst': 9,
          'total': 118.5,
        }
      ],
    });
    expect(res.statusCode, 201);
    final lines = await conn!.execute('''
      SELECT l.name, j.debit, j.credit
      FROM journal_entries j
      JOIN ledgers l ON l.id = j.ledger_id
      WHERE j.voucher_type = 'PUR'
      ORDER BY j.id DESC
      LIMIT 10
    ''');
    final names = lines.map((r) => '${r.toColumnMap()['name']}').toSet();
    expect(names.contains('Round Off'), isTrue);
  });
}
