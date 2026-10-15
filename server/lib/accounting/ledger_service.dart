import 'package:postgres/postgres.dart';

class LedgerIds {
  final int cash;
  final int bank;
  final int sales;
  final int purchase;
  final int outputCgst;
  final int outputSgst;
  final int outputIgst;
  final int inputCgst;
  final int inputSgst;
  final int inputIgst;
  final int freight;
  final int salary;
  final int expenses;

  LedgerIds({
    required this.cash,
    required this.bank,
    required this.sales,
    required this.purchase,
    required this.outputCgst,
    required this.outputSgst,
    required this.outputIgst,
    required this.inputCgst,
    required this.inputSgst,
    required this.inputIgst,
    required this.freight,
    required this.salary,
    required this.expenses,
  });
}

Future<int> ledgerIdBySystemKey(Session session, String key) async {
  final rows = await session.execute(
    Sql.named('SELECT id FROM ledgers WHERE system_key = @key'),
    parameters: {'key': key},
  );
  if (rows.isEmpty) {
    throw StateError('Missing system ledger for key $key — run accounting migration');
  }
  return (rows.first.first as num).toInt();
}

Future<LedgerIds> loadSystemLedgerIds(Session session) async {
  return LedgerIds(
    cash: await ledgerIdBySystemKey(session, 'CASH'),
    bank: await ledgerIdBySystemKey(session, 'BANK'),
    sales: await ledgerIdBySystemKey(session, 'SALES'),
    purchase: await ledgerIdBySystemKey(session, 'PURCHASE'),
    outputCgst: await ledgerIdBySystemKey(session, 'OUTPUT_CGST'),
    outputSgst: await ledgerIdBySystemKey(session, 'OUTPUT_SGST'),
    outputIgst: await ledgerIdBySystemKey(session, 'OUTPUT_IGST'),
    inputCgst: await ledgerIdBySystemKey(session, 'INPUT_CGST'),
    inputSgst: await ledgerIdBySystemKey(session, 'INPUT_SGST'),
    inputIgst: await ledgerIdBySystemKey(session, 'INPUT_IGST'),
    freight: await ledgerIdBySystemKey(session, 'FREIGHT'),
    salary: await ledgerIdBySystemKey(session, 'SALARY'),
    expenses: await ledgerIdBySystemKey(session, 'EXPENSES'),
  );
}

Future<int> ensureCustomerLedger(Session session, int customerId) async {
  final existing = await session.execute(
    Sql.named(
      'SELECT id FROM ledgers WHERE party_kind = \'CUSTOMER\' AND party_id = @id',
    ),
    parameters: {'id': customerId},
  );
  if (existing.isNotEmpty) return (existing.first.first as num).toInt();

  final cust = await session.execute(
    Sql.named(
      'SELECT customer_name, opening_balance_dr, opening_balance_cr FROM customers WHERE id = @id',
    ),
    parameters: {'id': customerId},
  );
  if (cust.isEmpty) throw StateError('Customer not found: $customerId');
  final row = cust.first.toColumnMap();
  final dr = (row['opening_balance_dr'] as num?)?.toDouble() ?? 0;
  final cr = (row['opening_balance_cr'] as num?)?.toDouble() ?? 0;
  final opening = dr >= cr ? dr - cr : cr - dr;
  final openingType = dr >= cr ? 'dr' : 'cr';

  final inserted = await session.execute(
    Sql.named('''
      INSERT INTO ledgers (name, group_type, party_kind, party_id, opening_balance, opening_type)
      VALUES (@name, 'asset', 'CUSTOMER', @party_id, @opening_balance, @opening_type)
      RETURNING id
    '''),
    parameters: {
      'name': row['customer_name'],
      'party_id': customerId,
      'opening_balance': opening,
      'opening_type': openingType,
    },
  );
  return (inserted.first.first as num).toInt();
}
