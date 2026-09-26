import 'package:intl/intl.dart';

String ultraFmtDate(String? iso) {
  if (iso == null || iso.isEmpty) return '';
  final d = DateTime.tryParse(iso);
  return d == null ? iso : DateFormat('dd-MM-yyyy').format(d);
}

const ultraDefaultBankName = 'STATE BANK OF INDIA';
const ultraDefaultBankAccount = '54009859972';
const ultraDefaultBankIfsc = 'SBIN0040552';
const ultraDefaultBankAddress = 'SINGASANDRA';

String ultraBankName(Map<String, dynamic>? row, String key) {
  final v = '${row?[key] ?? ''}'.trim();
  return v.isEmpty ? ultraDefaultBankName : v;
}

String ultraBankAccount(Map<String, dynamic>? row, String key) {
  final v = '${row?[key] ?? ''}'.trim();
  return v.isEmpty ? ultraDefaultBankAccount : v;
}

String ultraBankIfsc(Map<String, dynamic>? row, String key) {
  final v = '${row?[key] ?? ''}'.trim();
  return v.isEmpty ? ultraDefaultBankIfsc : v;
}

String ultraBankAddress(Map<String, dynamic>? row, String key) {
  final v = '${row?[key] ?? ''}'.trim();
  return v.isEmpty ? ultraDefaultBankAddress : v;
}
