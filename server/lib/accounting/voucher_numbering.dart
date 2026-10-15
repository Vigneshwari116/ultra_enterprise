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

class AllocatedVoucherNumber {
  final int sequence;
  final String fy;
  final String display;

  AllocatedVoucherNumber({
    required this.sequence,
    required this.fy,
    required this.display,
  });
}

/// Allocates the next voucher number under row lock (same transaction as save).
Future<AllocatedVoucherNumber> allocateVoucherNumber({
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
  final seq = (rows.first.first as num).toInt();
  final display = '$voucherType-$fy-$seq';
  return AllocatedVoucherNumber(sequence: seq, fy: fy, display: display);
}
