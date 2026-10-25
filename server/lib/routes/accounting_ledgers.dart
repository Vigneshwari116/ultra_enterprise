import 'package:postgres/postgres.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';

import '../accounting/ledger_service.dart';
import '../http.dart';

void registerAccountingLedgerRoutes(Router router, Connection conn) {
  router.get('/api/party-ledgers', (Request r) => getPartyLedger(r, conn));
  router.put('/api/party-ledgers/opening', (Request r) => setPartyLedgerOpening(r, conn));
}

Future<Response> getPartyLedger(Request request, Connection conn) async {
  final kind = request.url.queryParameters['party_kind']?.toUpperCase();
  final partyId = int.tryParse(request.url.queryParameters['party_id'] ?? '');
  if (kind != 'CUSTOMER' && kind != 'SUPPLIER') {
    return jsonError('party_kind must be CUSTOMER or SUPPLIER', status: 400);
  }
  if (partyId == null) return jsonError('party_id is required', status: 400);

  final rows = await conn.execute(
    Sql.named('''
      SELECT id, name, party_kind, party_id, opening_balance, opening_type
      FROM ledgers
      WHERE party_kind = @kind AND party_id = @party_id
    '''),
    parameters: {'kind': kind, 'party_id': partyId},
  );
  if (rows.isEmpty) {
    return jsonOk({
      'party_kind': kind,
      'party_id': partyId,
      'opening_balance': 0,
      'opening_type': kind == 'SUPPLIER' ? 'cr' : 'dr',
      'ledger_id': null,
    });
  }
  final m = serializeRow(rows.first.toColumnMap());
  m['ledger_id'] = m['id'];
  return jsonOk(m);
}

Future<Response> setPartyLedgerOpening(Request request, Connection conn) async {
  final body = await readJsonObject(request);
  final kind = '${body['party_kind'] ?? ''}'.toUpperCase();
  final partyId = (body['party_id'] as num?)?.toInt();
  if (kind != 'CUSTOMER' && kind != 'SUPPLIER') {
    return jsonError('party_kind must be CUSTOMER or SUPPLIER', status: 400);
  }
  if (partyId == null) return jsonError('party_id is required', status: 400);

  final balance = (body['opening_balance'] as num?)?.toDouble() ?? 0;
  if (balance < 0) return jsonError('opening_balance must be non-negative', status: 400);
  final openingType = '${body['opening_type'] ?? ''}'.toLowerCase();
  if (openingType != 'dr' && openingType != 'cr') {
    return jsonError('opening_type must be dr or cr', status: 400);
  }

  try {
    await conn.runTx((tx) async {
      await upsertPartyLedgerOpening(
        session: tx,
        partyKind: kind,
        partyId: partyId,
        openingBalance: balance,
        openingType: openingType,
        syncCustomerMaster: kind == 'CUSTOMER',
      );
    });
    return jsonOk({
      'party_kind': kind,
      'party_id': partyId,
      'opening_balance': balance,
      'opening_type': openingType,
    });
  } catch (e) {
    return jsonError('Failed to update opening balance: $e', status: 400);
  }
}
