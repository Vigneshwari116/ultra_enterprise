import 'dart:convert';
import 'dart:io';

import 'package:postgres/postgres.dart';
import 'package:shelf/shelf.dart';
import 'package:test/test.dart';

import 'auth_test_helper.dart';
import 'test_fixture_paths.dart';

double _pgNumeric(dynamic v) => double.tryParse('$v') ?? 0;

void main() {
  final testDbUrl = Platform.environment['TEST_DATABASE_URL'];
  if (testDbUrl == null || testDbUrl.isEmpty) {
    test('skipped without TEST_DATABASE_URL', () {}, skip: 'Set TEST_DATABASE_URL');
    return;
  }
  assertTestDatabaseUrl(testDbUrl);

  final fixturesDir = vpsFixturesDir();
  final resetPath = '$fixturesDir/reset_test_schema.sql';
  final schemaPath = '$fixturesDir/vps_ultra_enterprise_schema.sql';
  final seedPath = '$fixturesDir/vps_ultra_enterprise_seed.sql';
  Connection? conn;
  String? adminToken;

  Future<void> runPsqlFile(String path) async {
    final result = await Process.run(
      'psql',
      [testDbUrl, '-v', 'ON_ERROR_STOP=1', '-q', '-f', path],
    );
    if (result.exitCode != 0) {
      throw StateError('psql failed for $path: ${result.stderr}\n${result.stdout}');
    }
  }

  setUp(() async {
    await runPsqlFile(resetPath);
    await runPsqlFile(schemaPath);
    await runPsqlFile(seedPath);
    for (final path in vpsMigrationPaths()) {
      await runPsqlFile(path);
    }
    conn = await openTestDatabase(testDbUrl);
    adminToken = (await loginTestAdmin(conn!)).token;
  });

  tearDown(() async {
    await conn?.close();
    conn = null;
  });

  Future<Response> call(String method, String path) {
    return callApi(conn!, method, path, token: adminToken);
  }

  test('GET trial-balance parses numeric strings from journal_entries', () async {
    final cash = await conn!.execute(
      "SELECT id FROM ledgers WHERE system_key = 'CASH' LIMIT 1",
    );
    final cashId = (cash.first.first as num).toInt();

    await conn!.execute(
      Sql.named('''
        INSERT INTO journal_entries (
          date, voucher_type, voucher_no, voucher_no_display,
          ledger_id, debit, credit, narration, source_id
        ) VALUES (
          '2026-04-01', 'RCP', 1, 'RCP/26-27/00001',
          @lid, 100.50, 0, 'fixture receipt', 1
        )
      '''),
      parameters: {'lid': cashId},
    );

    final response = await call('GET', '/api/reports/trial-balance?from=2026-04-01&to=2026-04-30');
    expect(response.statusCode, 200);
    final body = jsonDecode(await response.readAsString()) as Map<String, dynamic>;
    final rows = body['rows'] as List<dynamic>;
    expect(rows, isNotEmpty);
    final cashRow = rows.cast<Map<String, dynamic>>().firstWhere(
      (r) => _pgNumeric(r['period_debit']) > 0 || _pgNumeric(r['closing_debit']) > 0,
      orElse: () => rows.first as Map<String, dynamic>,
    );
    expect(_pgNumeric(cashRow['period_debit']), greaterThan(0));
  });

  test('GET cash-bank-book returns running balance', () async {
    final response = await call('GET', '/api/reports/cash-bank-book?cash_bank=CASH');
    expect(response.statusCode, 200);
    final body = jsonDecode(await response.readAsString()) as Map<String, dynamic>;
    expect(body['cash_bank'], 'CASH');
    expect(body['lines'], isA<List>());
  });

  test('GET party-ledger requires party_id', () async {
    final response = await call('GET', '/api/reports/party-ledger?party_kind=CUSTOMER');
    expect(response.statusCode, 400);
  });
}
