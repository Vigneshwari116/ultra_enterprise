/// Parses API numeric fields that may arrive as num or string.
double parseApiAmount(dynamic value, {double fallback = 0}) {
  if (value == null) return fallback;
  if (value is num) return value.toDouble();
  return double.tryParse('$value'.trim()) ?? fallback;
}

int? parseApiInt(dynamic value) {
  if (value == null) return null;
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse('$value'.trim());
}

/// User-visible voucher number: FY display when set, else numeric [numberKey].
String voucherDisplayNo(
  Map<String, dynamic> row, {
  String displayKey = 'voucher_no_display',
  String numberKey = 'voucher_no',
  String? legacyPrefix,
}) {
  final display = row[displayKey];
  if (display != null && '$display'.trim().isNotEmpty) {
    return '$display';
  }
  final no = row[numberKey];
  if (no != null && '$no'.trim().isNotEmpty && '$no' != 'null') {
    final prefix = legacyPrefix ?? '';
    return '$prefix$no';
  }
  return '-';
}

String purchaseVoucherDisplayNo(Map<String, dynamic> row) =>
    voucherDisplayNo(row, legacyPrefix: 'PV-');

String receiptDisplayNo(Map<String, dynamic> row) =>
    voucherDisplayNo(row, numberKey: 'voucher_no');

String paymentDisplayNo(Map<String, dynamic> row) =>
    voucherDisplayNo(row, numberKey: 'voucher_no');

String expenseVoucherDisplayNo(Map<String, dynamic> row) =>
    voucherDisplayNo(row);

String salaryVoucherDisplayNo(Map<String, dynamic> row) =>
    voucherDisplayNo(row);
