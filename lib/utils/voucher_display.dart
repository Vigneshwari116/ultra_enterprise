import 'package:intl/intl.dart';

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

String _numericBillNo(dynamic value) {
  if (value == null) return '-';
  final s = '$value'.trim();
  if (s.isEmpty || s == 'null') return '-';
  return s;
}

/// User-visible voucher/bill number: plain numeric only (no FY prefix or display label).
String voucherDisplayNo(
  Map<String, dynamic> row, {
  String displayKey = 'voucher_no_display',
  String numberKey = 'voucher_no',
  String? legacyPrefix,
}) {
  return _numericBillNo(row[numberKey]);
}

String salesInvoiceDisplayNo(Map<String, dynamic> row) =>
    _numericBillNo(row['invoice_no']);

String purchaseVoucherDisplayNo(Map<String, dynamic> row) =>
    _numericBillNo(row['voucher_no']);

String receiptDisplayNo(Map<String, dynamic> row) =>
    voucherDisplayNo(row, numberKey: 'voucher_no');

String paymentDisplayNo(Map<String, dynamic> row) =>
    voucherDisplayNo(row, numberKey: 'voucher_no');

String expenseVoucherDisplayNo(Map<String, dynamic> row) =>
    voucherDisplayNo(row);

String salaryVoucherDisplayNo(Map<String, dynamic> row) =>
    voucherDisplayNo(row);

/// Report table date: dd-MM-yyyy.
String formatReportDate(dynamic value) {
  if (value == null || '$value'.trim().isEmpty) return '-';
  final s = '$value'.trim();
  final d = DateTime.tryParse(s);
  if (d == null) {
    if (s.length >= 10 && s[4] == '-') {
      final parts = s.substring(0, 10).split('-');
      if (parts.length == 3) return '${parts[2]}-${parts[1]}-${parts[0]}';
    }
    return s;
  }
  return DateFormat('dd-MM-yyyy').format(d);
}

/// Report amounts: 2 decimals with thousands separators.
String formatReportAmount(dynamic value) {
  final n = parseApiAmount(value);
  return NumberFormat('#,##0.00', 'en_IN').format(n);
}
