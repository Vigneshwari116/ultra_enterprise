import 'package:intl/intl.dart';

/// Invoice PDF date format (MM/DD/YYYY).
String ultraFmtDate(String? iso) {
  if (iso == null || iso.isEmpty) return '';
  final d = DateTime.tryParse(iso);
  if (d == null) {
    final parts = iso.split('-');
    if (parts.length == 3) {
      final y = int.tryParse(parts[0]);
      final m = int.tryParse(parts[1]);
      final day = int.tryParse(parts[2]);
      if (y != null && m != null && day != null) {
        return DateFormat('MM/dd/yyyy').format(DateTime(y, m, day));
      }
    }
    return iso;
  }
  return DateFormat('MM/dd/yyyy').format(d);
}

String ultraFmtDateFromDisplay(String? text) {
  final t = '${text ?? ''}'.trim();
  if (t.isEmpty) return '';
  final d = DateTime.tryParse(t);
  if (d != null) return DateFormat('MM/dd/yyyy').format(d);
  final ddmmyyyy = RegExp(r'^(\d{2})-(\d{2})-(\d{4})$').firstMatch(t);
  if (ddmmyyyy != null) {
    return '${ddmmyyyy.group(2)}/${ddmmyyyy.group(1)}/${ddmmyyyy.group(3)}';
  }
  return t;
}

String ultraBankField(Map<String, dynamic>? row, String key) => '${row?[key] ?? ''}'.trim();
