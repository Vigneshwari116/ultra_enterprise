import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../utils/voucher_display.dart';

Future<void> printLedgerLinesReport({
  required String title,
  required List<Map<String, dynamic>> lines,
  String? subtitle,
}) async {
  final doc = pw.Document();
  doc.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4.landscape,
      margin: const pw.EdgeInsets.all(24),
      build: (context) => [
        pw.Text(title, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 16)),
        if (subtitle != null) pw.Text(subtitle, style: const pw.TextStyle(fontSize: 9)),
        pw.SizedBox(height: 12),
        pw.Table.fromTextArray(
          headers: const [
            'DATE',
            'VOUCHER',
            'NARRATION',
            'DEBIT',
            'CREDIT',
            'BALANCE',
          ],
          data: lines
              .map(
                (r) => [
                  formatReportDate(r['date']),
                  voucherDisplayNo(r),
                  '${r['narration'] ?? ''}',
                  formatReportAmount(r['debit']),
                  formatReportAmount(r['credit']),
                  formatReportAmount(r['running_balance']),
                ],
              )
              .toList(),
          headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 11, color: PdfColors.grey900),
          cellStyle: const pw.TextStyle(fontSize: 11, color: PdfColors.grey900),
        ),
      ],
    ),
  );
  await Printing.layoutPdf(onLayout: (_) => doc.save());
}

Future<void> printTrialBalanceReport({
  required List<Map<String, dynamic>> rows,
  String? subtitle,
}) async {
  final doc = pw.Document();
  doc.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4.landscape,
      margin: const pw.EdgeInsets.all(24),
      build: (context) => [
        pw.Text('TRIAL BALANCE', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 16)),
        if (subtitle != null) pw.Text(subtitle, style: const pw.TextStyle(fontSize: 9)),
        pw.SizedBox(height: 12),
        pw.Table.fromTextArray(
          headers: const [
            'LEDGER',
            'OPEN DR',
            'OPEN CR',
            'PERIOD DR',
            'PERIOD CR',
            'CLOSE DR',
            'CLOSE CR',
          ],
          data: rows
              .map(
                (r) => [
                  '${r['ledger_name'] ?? ''}',
                  formatReportAmount(r['opening_debit']),
                  formatReportAmount(r['opening_credit']),
                  formatReportAmount(r['period_debit']),
                  formatReportAmount(r['period_credit']),
                  formatReportAmount(r['closing_debit']),
                  formatReportAmount(r['closing_credit']),
                ],
              )
              .toList(),
          headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 11, color: PdfColors.grey900),
          cellStyle: const pw.TextStyle(fontSize: 11, color: PdfColors.grey900),
        ),
      ],
    ),
  );
  await Printing.layoutPdf(onLayout: (_) => doc.save());
}
