import 'package:postgres/postgres.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';

import '../accounting/fy.dart';
import '../accounting/voucher_numbering.dart';
import '../http.dart';

const _allowedTypes = {
  VoucherTypes.sales,
  VoucherTypes.purchase,
  VoucherTypes.receipt,
  VoucherTypes.payment,
  VoucherTypes.expense,
  VoucherTypes.salary,
};

void registerVoucherNumberRoutes(Router router, Connection conn) {
  router.get('/api/voucher-numbers/next', (Request request) => peekNextVoucherNumber(request, conn));
}

/// Read-only preview of next global sequence and FY display label (does not increment counters).
Future<Response> peekNextVoucherNumber(Request request, Connection conn) async {
  final type = request.url.queryParameters['type']?.trim().toUpperCase();
  if (type == null || type.isEmpty) {
    return jsonError('type query parameter is required (SAL, PUR, REC, PAY, EXP, SLR)');
  }
  if (!_allowedTypes.contains(type)) {
    return jsonError('Invalid voucher type: $type', status: 400);
  }

  final dateParam = request.url.queryParameters['date'];
  final voucherDate = dateParam == null || dateParam.isEmpty
      ? DateTime.now()
      : FinancialYear.parseVoucherDate(dateParam);
  final fy = FinancialYear.fyLabelForDate(voucherDate);

  final counterKey = VoucherSequences.forVoucherType(type);
  final rows = await conn.execute(
    Sql.named('''
      SELECT last_no FROM global_number_counters
      WHERE counter_key = @key
    '''),
    parameters: {'key': counterKey},
  );
  final lastNo = rows.isEmpty ? 0 : (rows.first.first as num).toInt();
  final nextNo = lastNo + 1;
  final display = '$type-$fy-$nextNo';

  return jsonOk({
    'voucher_type': type,
    'fy': fy,
    'next_no': nextNo,
    'display': display,
  });
}
