import 'package:postgres/postgres.dart';

import 'fy.dart';

/// Voucher type codes stored in voucher_counters and journal_entries.voucher_type.
class VoucherTypes {
  static const sales = 'SAL';
  static const purchase = 'PUR';
  static const receipt = 'REC';
  static const payment = 'PAY';
  static const expense = 'EXP';
  static const salary = 'SLR';
}

/// PostgreSQL sequence backing each voucher type's global internal number.
class VoucherSequences {
  static const salesInvoice = 'sales_invoice_number_seq';
  static const purchaseVoucher = 'purchase_voucher_number_seq';
  static const receipt = 'receipt_voucher_number_seq';
  static const payment = 'payment_voucher_number_seq';
  static const expense = 'expense_voucher_number_seq';
  static const salary = 'salary_voucher_number_seq';

  static const _byVoucherType = <String, String>{
    VoucherTypes.sales: salesInvoice,
    VoucherTypes.purchase: purchaseVoucher,
    VoucherTypes.receipt: receipt,
    VoucherTypes.payment: payment,
    VoucherTypes.expense: expense,
    VoucherTypes.salary: salary,
  };

  static String forVoucherType(String voucherType) {
    final seq = _byVoucherType[voucherType];
    if (seq == null) {
      throw ArgumentError('No global sequence for voucher type $voucherType');
    }
    return seq;
  }
}

class AllocatedVoucherNumber {
  /// Globally unique internal number (invoice_no, voucher_no, journal voucher_no).
  final int sequence;

  final String fy;

  /// User-facing FY-scoped label, e.g. SAL-26-27-1.
  final String display;

  AllocatedVoucherNumber({
    required this.sequence,
    required this.fy,
    required this.display,
  });
}

/// Next value from a whitelisted global sequence (same transaction as save).
Future<int> nextGlobalSequenceValue({
  required Session session,
  required String sequenceName,
}) async {
  _assertAllowedSequence(sequenceName);
  final rows = await session.execute(
    "SELECT nextval('$sequenceName'::regclass)",
  );
  return (rows.first.first as num).toInt();
}

void _assertAllowedSequence(String sequenceName) {
  const allowed = {
    VoucherSequences.salesInvoice,
    VoucherSequences.purchaseVoucher,
    VoucherSequences.receipt,
    VoucherSequences.payment,
    VoucherSequences.expense,
    VoucherSequences.salary,
  };
  if (!allowed.contains(sequenceName)) {
    throw ArgumentError('Unknown sequence: $sequenceName');
  }
}

/// FY display counter (resets each financial year).
Future<({String fy, String display})> allocateVoucherDisplayNumber({
  required Session session,
  required String voucherType,
  required DateTime voucherDate,
}) async {
  final fy = FinancialYear.fyLabelForDate(voucherDate);
  final rows = await session.execute(
    Sql.named('''
      INSERT INTO voucher_counters (voucher_type, fy, last_no)
      VALUES (@type, @fy, 1)
      ON CONFLICT (voucher_type, fy) DO UPDATE
        SET last_no = voucher_counters.last_no + 1
      RETURNING last_no
    '''),
    parameters: {'type': voucherType, 'fy': fy},
  );
  final fySeq = (rows.first.first as num).toInt();
  final display = '$voucherType-$fy-$fySeq';
  return (fy: fy, display: display);
}

/// Allocates global internal [AllocatedVoucherNumber.sequence] and FY [display].
Future<AllocatedVoucherNumber> allocateVoucherNumber({
  required Session session,
  required String voucherType,
  required DateTime voucherDate,
}) async {
  final displayPart = await allocateVoucherDisplayNumber(
    session: session,
    voucherType: voucherType,
    voucherDate: voucherDate,
  );
  final globalNo = await nextGlobalSequenceValue(
    session: session,
    sequenceName: VoucherSequences.forVoucherType(voucherType),
  );
  return AllocatedVoucherNumber(
    sequence: globalNo,
    fy: displayPart.fy,
    display: displayPart.display,
  );
}
