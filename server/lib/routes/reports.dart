import 'package:postgres/postgres.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';

import '../accounting/ledger_service.dart';
import '../http.dart';

double _num(dynamic v) {
  if (v == null) return 0;
  if (v is num) return v.toDouble();
  return double.tryParse('$v'.trim()) ?? 0;
}

DateTime? _parseDate(String? raw) {
  if (raw == null || raw.trim().isEmpty) return null;
  return DateTime.tryParse(raw.trim());
}

double _signedOpening(Map<String, dynamic> ledger) {
  final bal = _num(ledger['opening_balance']);
  final side = '${ledger['opening_type'] ?? 'dr'}'.toLowerCase();
  return side == 'cr' ? -bal : bal;
}

void registerReportRoutes(Router router, Connection conn) {
  router.get('/api/reports/party-ledger', (r) => partyLedgerReport(r, conn));
  router.get('/api/reports/trial-balance', (r) => trialBalanceReport(r, conn));
  router.get('/api/reports/cash-bank-book', (r) => cashBankBookReport(r, conn));
}

Future<Response> partyLedgerReport(Request request, Connection conn) async {
  final q = request.requestedUri.queryParameters;
  final partyKind = '${q['party_kind'] ?? ''}'.toUpperCase();
  final partyId = int.tryParse('${q['party_id'] ?? ''}');
  if (partyKind != 'CUSTOMER' && partyKind != 'SUPPLIER') {
    return jsonError('party_kind must be CUSTOMER or SUPPLIER', status: 400);
  }
  if (partyId == null) return jsonError('party_id is required', status: 400);

  final from = _parseDate(q['from']);
  final to = _parseDate(q['to']);

  final ledgerRows = await conn.execute(
    Sql.named('''
      SELECT id, name, opening_balance, opening_type
      FROM ledgers
      WHERE party_kind = @kind AND party_id = @pid
    '''),
    parameters: {'kind': partyKind, 'pid': partyId},
  );
  if (ledgerRows.isEmpty) {
    return jsonError('Party ledger not found', status: 404);
  }
  final ledger = ledgerRows.first.toColumnMap();
  final ledgerId = (ledger['id'] as num).toInt();

  var balance = _signedOpening(ledger);

  if (from != null) {
    final prior = await conn.execute(
      Sql.named('''
        SELECT COALESCE(SUM(debit), 0) AS dr, COALESCE(SUM(credit), 0) AS cr
        FROM journal_entries
        WHERE ledger_id = @lid AND date < @from::date
      '''),
      parameters: {
        'lid': ledgerId,
        'from': DateTime.utc(from.year, from.month, from.day),
      },
    );
    final p = prior.first.toColumnMap();
    balance += _num(p['dr']) - _num(p['cr']);
  }

  final params = <String, dynamic>{'lid': ledgerId};
  var dateFilter = '';
  if (from != null) {
    dateFilter += ' AND j.date >= @from::date';
    params['from'] = DateTime.utc(from.year, from.month, from.day);
  }
  if (to != null) {
    dateFilter += ' AND j.date <= @to::date';
    params['to'] = DateTime.utc(to.year, to.month, to.day);
  }

  final lines = await conn.execute(
    Sql.named('''
      SELECT j.date, j.voucher_type, j.voucher_no, j.voucher_no_display,
             j.debit, j.credit, j.narration
      FROM journal_entries j
      WHERE j.ledger_id = @lid $dateFilter
      ORDER BY j.date ASC, j.id ASC
    '''),
    parameters: params,
  );

  final rows = <Map<String, dynamic>>[];
  for (final row in lines) {
    final m = row.toColumnMap();
    final dr = _num(m['debit']);
    final cr = _num(m['credit']);
    balance += dr - cr;
    rows.add({
      'date': serializeRow(m)['date'],
      'voucher_type': m['voucher_type'],
      'voucher_no': m['voucher_no'],
      'voucher_no_display': m['voucher_no_display'],
      'debit': dr,
      'credit': cr,
      'narration': m['narration'],
      'running_balance': balance,
    });
  }

  return jsonOk({
    'party_kind': partyKind,
    'party_id': partyId,
    'ledger_name': ledger['name'],
    'opening_balance': _signedOpening(ledger),
    'from': from?.toIso8601String().split('T').first,
    'to': to?.toIso8601String().split('T').first,
    'lines': serializeRows(rows),
  });
}

Future<Response> trialBalanceReport(Request request, Connection conn) async {
  final q = request.requestedUri.queryParameters;
  final from = _parseDate(q['from']);
  final to = _parseDate(q['to']);

  final ledgers = await conn.execute('''
    SELECT id, name, group_type, opening_balance, opening_type
    FROM ledgers
    ORDER BY name
  ''');

  final rows = <Map<String, dynamic>>[];
  for (final lr in ledgers) {
    final ledger = lr.toColumnMap();
    final lid = (ledger['id'] as num).toInt();
    var opening = _signedOpening(ledger);

    final params = <String, dynamic>{'lid': lid};
    var dateFilter = '';
    if (from != null) {
      dateFilter += ' AND date >= @from::date';
      params['from'] = DateTime.utc(from.year, from.month, from.day);
    }
    if (to != null) {
      dateFilter += ' AND date <= @to::date';
      params['to'] = DateTime.utc(to.year, to.month, to.day);
    }

    if (from != null) {
      final prior = await conn.execute(
        Sql.named('''
          SELECT COALESCE(SUM(debit), 0) AS dr, COALESCE(SUM(credit), 0) AS cr
          FROM journal_entries
          WHERE ledger_id = @lid AND date < @from::date
        '''),
        parameters: {
          'lid': lid,
          'from': DateTime.utc(from.year, from.month, from.day),
        },
      );
      final p = prior.first.toColumnMap();
      opening += _num(p['dr']) - _num(p['cr']);
    }

    final period = await conn.execute(
      Sql.named('''
        SELECT COALESCE(SUM(debit), 0) AS dr, COALESCE(SUM(credit), 0) AS cr
        FROM journal_entries
        WHERE ledger_id = @lid $dateFilter
      '''),
      parameters: params,
    );
    final pm = period.first.toColumnMap();
    final periodDr = _num(pm['dr']);
    final periodCr = _num(pm['cr']);
    final closing = opening + periodDr - periodCr;

    rows.add({
      'ledger_id': lid,
      'ledger_name': ledger['name'],
      'group_type': ledger['group_type'],
      'opening_debit': opening > 0 ? opening : 0,
      'opening_credit': opening < 0 ? -opening : 0,
      'period_debit': periodDr,
      'period_credit': periodCr,
      'closing_debit': closing > 0 ? closing : 0,
      'closing_credit': closing < 0 ? -closing : 0,
    });
  }

  return jsonOk({
    'from': from?.toIso8601String().split('T').first,
    'to': to?.toIso8601String().split('T').first,
    'rows': serializeRows(rows),
  });
}

Future<Response> cashBankBookReport(Request request, Connection conn) async {
  final q = request.requestedUri.queryParameters;
  final cashBank = '${q['cash_bank'] ?? 'CASH'}'.toUpperCase();
  if (cashBank != 'CASH' && cashBank != 'BANK') {
    return jsonError('cash_bank must be CASH or BANK', status: 400);
  }
  final from = _parseDate(q['from']);
  final to = _parseDate(q['to']);

  final ledgerId = await ledgerIdBySystemKey(
    conn,
    cashBank == 'BANK' ? 'BANK' : 'CASH',
  );

  final ledgerRows = await conn.execute(
    Sql.named('SELECT name, opening_balance, opening_type FROM ledgers WHERE id = @id'),
    parameters: {'id': ledgerId},
  );
  final ledger = ledgerRows.first.toColumnMap();
  var balance = _signedOpening(ledger);

  if (from != null) {
    final prior = await conn.execute(
      Sql.named('''
        SELECT COALESCE(SUM(debit), 0) AS dr, COALESCE(SUM(credit), 0) AS cr
        FROM journal_entries
        WHERE ledger_id = @lid AND date < @from::date
      '''),
      parameters: {
        'lid': ledgerId,
        'from': DateTime.utc(from.year, from.month, from.day),
      },
    );
    final p = prior.first.toColumnMap();
    balance += _num(p['dr']) - _num(p['cr']);
  }

  final params = <String, dynamic>{'lid': ledgerId};
  var dateFilter = '';
  if (from != null) {
    dateFilter += ' AND j.date >= @from::date';
    params['from'] = DateTime.utc(from.year, from.month, from.day);
  }
  if (to != null) {
    dateFilter += ' AND j.date <= @to::date';
    params['to'] = DateTime.utc(to.year, to.month, to.day);
  }

  final lines = await conn.execute(
    Sql.named('''
      SELECT j.date, j.voucher_type, j.voucher_no, j.voucher_no_display,
             j.debit, j.credit, j.narration
      FROM journal_entries j
      WHERE j.ledger_id = @lid $dateFilter
      ORDER BY j.date ASC, j.id ASC
    '''),
    parameters: params,
  );

  final rows = <Map<String, dynamic>>[];
  for (final row in lines) {
    final m = row.toColumnMap();
    final dr = _num(m['debit']);
    final cr = _num(m['credit']);
    balance += dr - cr;
    rows.add({
      'date': serializeRow(m)['date'],
      'voucher_type': m['voucher_type'],
      'voucher_no': m['voucher_no'],
      'voucher_no_display': m['voucher_no_display'],
      'debit': dr,
      'credit': cr,
      'narration': m['narration'],
      'running_balance': balance,
    });
  }

  return jsonOk({
    'cash_bank': cashBank,
    'ledger_name': ledger['name'],
    'from': from?.toIso8601String().split('T').first,
    'to': to?.toIso8601String().split('T').first,
    'lines': serializeRows(rows),
  });
}
