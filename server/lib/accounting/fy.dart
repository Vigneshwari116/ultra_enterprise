/// Financial year helpers (FY starts 1 April, Asia/Kolkata).
class FinancialYear {
  FinancialYear._();

  static const _kolkata = 'Asia/Kolkata';

  static DateTime toKolkata(DateTime utcOrLocal) {
    // Shelf handlers use UTC timestamps; normalize via offset for FY boundaries.
    // Dart 3.4+: use timezone package would be ideal; approximate with fixed +5:30 for FY date.
    return utcOrLocal.toUtc().add(const Duration(hours: 5, minutes: 30));
  }

  static String fyLabelForDate(DateTime date) {
    final k = toKolkata(date);
    final startYear = k.month >= 4 ? k.year : k.year - 1;
    final y1 = startYear % 100;
    final y2 = (startYear + 1) % 100;
    return '${y1.toString().padLeft(2, '0')}-${y2.toString().padLeft(2, '0')}';
  }

  static DateTime parseVoucherDate(dynamic raw) {
    if (raw == null) return DateTime.now().toUtc();
    if (raw is DateTime) return raw.toUtc();
    final s = '$raw'.trim();
    if (s.isEmpty) return DateTime.now().toUtc();
    final parsed = DateTime.tryParse(s);
    if (parsed != null) return parsed.toUtc();
    return DateTime.now().toUtc();
  }
}
