import 'package:postgres/postgres.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';

import '../http.dart';

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
  final rows = await conn.execute('SELECT * FROM ledger_accounts ORDER BY id');
  final list = rows.map((r) {
    final m = serializeRow(r.toColumnMap());
    m['account_name'] = m['name'];
    return m;
  }).toList();
  return jsonOk(list);
}

Future<Response> createLedgerAccount(Request request, Connection conn) async {
  final body = await readJsonObject(request);
  final name = body['account_name'] ?? body['name'];
  if ('$name'.trim().isEmpty) return jsonError('account name is required');
  final result = await conn.execute(
    Sql.named('''
      INSERT INTO ledger_accounts (name, group_name, head, group_wise, cr_amount, dr_amount, updated_time, created_at)
      VALUES (@name, @group_name, @head, @group_wise, @cr_amount, @dr_amount, NOW(), NOW())
      RETURNING id
    '''),
    parameters: {
      'name': name,
      'group_name': body['group_name'],
      'head': body['head'],
      'group_wise': body['group_wise'],
      'cr_amount': body['cr_amount'] ?? 0,
      'dr_amount': body['dr_amount'] ?? 0,
    },
  );
  final id = result.first.first;
  return jsonOk({'id': id}, status: 201);
}

Future<Response> updateLedgerAccount(Request request, Connection conn, int id) async {
  final body = await readJsonObject(request);
  final name = body['account_name'] ?? body['name'];
  final updated = await conn.execute(
    Sql.named('''
      UPDATE ledger_accounts SET
        name = COALESCE(@name, name),
        group_name = COALESCE(@group_name, group_name),
        head = COALESCE(@head, head),
        group_wise = COALESCE(@group_wise, group_wise),
        cr_amount = COALESCE(@cr_amount, cr_amount),
        dr_amount = COALESCE(@dr_amount, dr_amount),
        updated_time = NOW()
      WHERE id = @id RETURNING id
    '''),
    parameters: {
      'id': id,
      'name': name,
      'group_name': body['group_name'],
      'head': body['head'],
      'group_wise': body['group_wise'],
      'cr_amount': body['cr_amount'],
      'dr_amount': body['dr_amount'],
    },
  );
  if (updated.isEmpty) return jsonError('Ledger account not found: $id', status: 404);
  return jsonOk({'id': id});
}
