import 'dart:convert';
import 'dart:typed_data';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../database/app_database.dart';
import 'ultra_logo.dart';

String _fmtDate(String? iso) {
  if (iso == null || iso.isEmpty) return '';
  final d = DateTime.tryParse(iso);
  return d == null ? iso : DateFormat('dd-MM-yyyy').format(d);
}

Future<void> reprintQuotation(int quotationId) async {
  final bytes = await buildQuotationPdf(quotationId);
  if (bytes == null) return;
  await Printing.layoutPdf(onLayout: (_) => bytes);
}

Future<Uint8List?> buildQuotationPdf(int quotationId) async {
  final bundle = await AppDatabase.instance.quotationPrintBundle(quotationId);
  if (bundle == null) return null;
  final q = bundle['quotation'] as Map<String, dynamic>;
  final items = bundle['items'] as List<Map<String, dynamic>>;
  final terms = bundle['terms'] as List<Map<String, dynamic>>;

  final doc = pw.Document();
  final logo = pw.MemoryImage(base64Decode(ultraLogoBase64));

  doc.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(24),
      build: (context) => [
        pw.Row(
          children: [
            pw.Container(width: 50, height: 40, child: pw.Image(logo, fit: pw.BoxFit.contain)),
            pw.SizedBox(width: 10),
            pw.Expanded(
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.center,
                children: [
                  pw.Text('ULTRA ENGINEERING WORKS', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 16)),
                  pw.Text('QUOTATION', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 13)),
                ],
              ),
            ),
          ],
        ),
        pw.SizedBox(height: 8),
        pw.Text('REF: ${q['ref_no']}  |  DATE: ${_fmtDate(q['quotation_date'] as String?)}  |  VALIDITY: ${q['validity_days']} days',
            style: const pw.TextStyle(fontSize: 9)),
        pw.SizedBox(height: 8),
        pw.Text('${q['salutation'] ?? 'Dear Sir,'}', style: const pw.TextStyle(fontSize: 10)),
        if ('${q['subject']}'.isNotEmpty) pw.Text('Subject: ${q['subject']}', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10)),
        if ('${q['body_text']}'.isNotEmpty) pw.Text('${q['body_text']}', style: const pw.TextStyle(fontSize: 9)),
        pw.SizedBox(height: 8),
        pw.Text('To: ${q['party_name']} (${q['party_kind']})', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10)),
        pw.Text('${q['address']}, ${q['city']} - ${q['pincode']}', style: const pw.TextStyle(fontSize: 9)),
        pw.SizedBox(height: 10),
        pw.Table.fromTextArray(
          headers: ['SL', 'PARTICULARS', 'UOM', 'QTY', 'RATE', 'NET'],
          data: List.generate(items.length, (i) {
            final it = items[i];
            return [
              '${i + 1}',
              '${it['description']}',
              '${it['uom']}',
              '${it['quantity']}',
              '${it['rate']}',
              '${it['line_total']}',
            ];
          }),
          headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8),
          cellStyle: const pw.TextStyle(fontSize: 8),
        ),
        pw.SizedBox(height: 10),
        pw.Text('Terms & Conditions:', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10)),
        ...terms.map((t) => pw.Text('${t['sort_order']}. ${t['text']}', style: const pw.TextStyle(fontSize: 8))),
        pw.SizedBox(height: 8),
        pw.Text('Freight: ₹ ${(q['freight'] as num?)?.toStringAsFixed(2) ?? '0.00'}', style: const pw.TextStyle(fontSize: 9)),
        pw.Text('NET TOTAL: ₹ ${(q['net_total'] as num?)?.toStringAsFixed(2) ?? '0.00'}',
            style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 11)),
      ],
    ),
  );
  return doc.save();
}
