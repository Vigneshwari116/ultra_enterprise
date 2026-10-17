import 'dart:convert';

import 'package:postgres/postgres.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';
import 'package:uuid/uuid.dart';

import '../http.dart';
import '../json_util.dart';

const _uuid = Uuid();

void registerLedgerRoutes(Router router, Connection conn) {
  router.get('/api/ledger-accounts', (_) => listLedgerAccounts(conn));
  router.post('/api/ledger-accounts', (r) => createLedgerAccount(r, conn));
  router.put('/api/ledger-accounts/<id>', (Request r, String id) async {
    final lid = int.tryParse(id);
    if (lid == null) return jsonError('Invalid ledger account id', status: 400);
    return updateLedgerAccount(r, conn, lid);
  });
}

Future<Response> listLedgerAccounts(Connection conn) async {
  final rows = await conn.execute(
    'SELECT id, uuid, status, data, created_at FROM ledger_accounts ORDER BY id',
  );
  final list = rows.map((r) {
    final m = flattenEnvelopeRow(serializeRow(r.toColumnMap()));
    m['account_name'] = m['name'] ?? m['account_name'];
    return m;
  }).toList();
  return jsonOk(list);
}

Future<Response> createLedgerAccount(Request request, Connection conn) async {
  final body = await readJsonObject(request);
  final name = body['account_name'] ?? body['name'];
  if ('$name'.trim().isEmpty) return jsonError('account name is required');
  final payload = jsonEncode({
    'name': name,
    'group_name': body['group_name'],
    'head': body['head'],
    'group_wise': body['group_wise'],
    'cr_amount': body['cr_amount'] ?? 0,
    'dr_amount': body['dr_amount'] ?? 0,
  });
  final result = await conn.execute(
    Sql.named('''
      INSERT INTO ledger_accounts (uuid, status, data, created_at)
      VALUES (@uuid, 'ACTIVE', @data, NOW())
      RETURNING id
    '''),
    parameters: {'uuid': _uuid.v4(), 'data': payload},
  );
  final id = result.first.first;
  return jsonOk({'id': id}, status: 201);
}

Future<Response> updateLedgerAccount(Request request, Connection conn, int id) async {
  final body = await readJsonObject(request);
  final existing = await conn.execute(
    Sql.named('SELECT data FROM ledger_accounts WHERE id = @id'),
    parameters: {'id': id},
  );
  if (existing.isEmpty) return jsonError('Ledger account not found: $id', status: 404);
  final merged = flattenEnvelopeRow({'data': existing.first.toColumnMap()['data']});
  merged.addAll(body);
  final name = body['account_name'] ?? body['name'];
  if (name != null) merged['name'] = name;
  await conn.execute(
    Sql.named('UPDATE ledger_accounts SET data = @data WHERE id = @id RETURNING id'),
    parameters: {'id': id, 'data': jsonEncode(merged)},
  );
  return jsonOk({'id': id});
}
