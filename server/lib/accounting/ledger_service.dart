import 'dart:convert';

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
  final int roundOff;

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
    required this.roundOff,
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
    roundOff: await ledgerIdBySystemKey(session, 'ROUND_OFF'),
  );
}

Future<int> ensureSupplierLedger(Session session, int supplierId) async {
  final existing = await session.execute(
    Sql.named(
      'SELECT id FROM ledgers WHERE party_kind = \'SUPPLIER\' AND party_id = @id',
    ),
    parameters: {'id': supplierId},
  );
  if (existing.isNotEmpty) return (existing.first.first as num).toInt();

  final sup = await session.execute(
    Sql.named('SELECT data::text AS data FROM suppliers WHERE id = @id'),
    parameters: {'id': supplierId},
  );
  if (sup.isEmpty) throw StateError('Supplier not found: $supplierId');
  final dataRaw = sup.first.toColumnMap()['data'];
  Map<String, dynamic> data = {};
  if (dataRaw is String && dataRaw.trim().isNotEmpty) {
    try {
      data = Map<String, dynamic>.from(
        (jsonDecode(dataRaw) as Map).map((k, v) => MapEntry('$k', v)),
      );
    } catch (_) {}
  }
  final name = '${data['supplier_name'] ?? 'Supplier $supplierId}';

  final inserted = await session.execute(
    Sql.named('''
      INSERT INTO ledgers (name, group_type, party_kind, party_id, opening_balance, opening_type)
      VALUES (@name, 'liability', 'SUPPLIER', @party_id, 0, 'cr')
      RETURNING id
    '''),
    parameters: {
      'name': name,
      'party_id': supplierId,
    },
  );
  return (inserted.first.first as num).toInt();
}

/// Signed opening for reports: asset (customer) dr-positive; liability (supplier) cr-positive.
double signedPartyOpeningBalance({
  required String partyKind,
  required double openingBalance,
  required String openingType,
}) {
  final type = openingType.toLowerCase();
  if (partyKind == 'SUPPLIER') {
    return type == 'cr' ? openingBalance : -openingBalance;
  }
  return type == 'dr' ? openingBalance : -openingBalance;
}

Future<void> syncCustomerPartyLedgerFromMaster(Session session, int customerId) async {
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

  await upsertPartyLedgerOpening(
    session: session,
    partyKind: 'CUSTOMER',
    partyId: customerId,
    openingBalance: opening,
    openingType: openingType,
    partyName: '${row['customer_name']}',
    syncCustomerMaster: false,
  );
}

Future<void> upsertPartyLedgerOpening({
  required Session session,
  required String partyKind,
  required int partyId,
  required double openingBalance,
  required String openingType,
  String? partyName,
  bool syncCustomerMaster = false,
}) async {
  final kind = partyKind.toUpperCase();
  if (kind != 'CUSTOMER' && kind != 'SUPPLIER') {
    throw ArgumentError('partyKind must be CUSTOMER or SUPPLIER');
  }
  final type = openingType.toLowerCase();
  if (type != 'dr' && type != 'cr') {
    throw ArgumentError('openingType must be dr or cr');
  }

  if (syncCustomerMaster && kind == 'CUSTOMER') {
    final dr = type == 'dr' ? openingBalance : 0.0;
    final cr = type == 'cr' ? openingBalance : 0.0;
    await session.execute(
      Sql.named('''
        UPDATE customers
        SET opening_balance_dr = @dr, opening_balance_cr = @cr, updated_at = NOW()
        WHERE id = @id
      '''),
      parameters: {'id': partyId, 'dr': dr, 'cr': cr},
    );
  }

  final groupType = kind == 'CUSTOMER' ? 'asset' : 'liability';
  String name = partyName ?? '';
  if (name.isEmpty) {
    if (kind == 'CUSTOMER') {
      final rows = await session.execute(
        Sql.named('SELECT customer_name FROM customers WHERE id = @id'),
        parameters: {'id': partyId},
      );
      if (rows.isEmpty) throw StateError('Customer not found: $partyId');
      name = '${rows.first.first}';
    } else {
      final rows = await session.execute(
        Sql.named('SELECT data::jsonb->>\'supplier_name\' AS n FROM suppliers WHERE id = @id'),
        parameters: {'id': partyId},
      );
      if (rows.isEmpty) throw StateError('Supplier not found: $partyId');
      name = '${rows.first.toColumnMap()['n'] ?? 'Supplier $partyId'}';
    }
  }

  final updated = await session.execute(
    Sql.named('''
      UPDATE ledgers
      SET opening_balance = @opening_balance,
          opening_type = @opening_type,
          name = @name,
          updated_at = NOW()
      WHERE party_kind = @party_kind AND party_id = @party_id
      RETURNING id
    '''),
    parameters: {
      'opening_balance': openingBalance,
      'opening_type': type,
      'name': name,
      'party_kind': kind,
      'party_id': partyId,
    },
  );
  if (updated.isNotEmpty) return;

  await session.execute(
    Sql.named('''
      INSERT INTO ledgers (
        name, group_type, party_kind, party_id, opening_balance, opening_type
      ) VALUES (
        @name, @group_type, @party_kind, @party_id, @opening_balance, @opening_type
      )
    '''),
    parameters: {
      'name': name,
      'group_type': groupType,
      'party_kind': kind,
      'party_id': partyId,
      'opening_balance': openingBalance,
      'opening_type': type,
    },
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
