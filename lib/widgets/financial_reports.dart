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
                  '${r['date'] ?? ''}',
                  voucherDisplayNo(r),
                  '${r['narration'] ?? ''}',
                  parseApiAmount(r['debit']).toStringAsFixed(2),
                  parseApiAmount(r['credit']).toStringAsFixed(2),
                  parseApiAmount(r['running_balance']).toStringAsFixed(2),
                ],
              )
              .toList(),
          headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9),
          cellStyle: const pw.TextStyle(fontSize: 8.5),
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
                  parseApiAmount(r['opening_debit']).toStringAsFixed(2),
                  parseApiAmount(r['opening_credit']).toStringAsFixed(2),
                  parseApiAmount(r['period_debit']).toStringAsFixed(2),
                  parseApiAmount(r['period_credit']).toStringAsFixed(2),
                  parseApiAmount(r['closing_debit']).toStringAsFixed(2),
                  parseApiAmount(r['closing_credit']).toStringAsFixed(2),
                ],
              )
              .toList(),
          headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9),
          cellStyle: const pw.TextStyle(fontSize: 8.5),
        ),
      ],
    ),
  );
  await Printing.layoutPdf(onLayout: (_) => doc.save());
}
