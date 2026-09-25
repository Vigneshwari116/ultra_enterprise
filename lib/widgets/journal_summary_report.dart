import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

Future<void> printJournalSummaryReport(List<Map<String, dynamic>> lines) async {
  final doc = pw.Document();
  doc.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4.landscape,
      margin: const pw.EdgeInsets.all(24),
      build: (context) => [
        pw.Text('JOURNAL SUMMARY REGISTER', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 16)),
        pw.Text('DOUBLE ENTRY FINANCIAL ADJUSTMENT INTERCEPTOR JOURNAL', style: const pw.TextStyle(fontSize: 9)),
        pw.SizedBox(height: 12),
        pw.Table.fromTextArray(
          headers: ['VOUCHER DATE', 'NARRATION', 'DEBIT (TO) ACCOUNT', 'CREDIT (BY) ACCOUNT', 'AMOUNT'],
          data: lines
              .map((r) => [
                    '${r['voucher_date'] ?? ''}',
                    '${r['narration'] ?? ''}',
                    '${r['dr_account_label'] ?? ''}',
                    '${r['cr_account_label'] ?? ''}',
                    ((r['amount'] as num?)?.toDouble() ?? 0).toStringAsFixed(2),
                  ])
              .toList(),
          headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9),
          cellStyle: const pw.TextStyle(fontSize: 8.5),
        ),
        pw.SizedBox(height: 10),
        pw.Text(
          'TOTAL: ₹ ${lines.fold<double>(0, (s, r) => s + ((r['amount'] as num?)?.toDouble() ?? 0)).toStringAsFixed(2)}',
          style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10),
        ),
      ],
    ),
  );
  await Printing.layoutPdf(onLayout: (_) => doc.save());
}
