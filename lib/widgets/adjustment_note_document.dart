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

String _billNo(Map<String, dynamic> note) {
  final stored = '${note['note_bill_no'] ?? ''}'.trim();
  if (stored.isNotEmpty) return stored;
  final uuid = '${note['uuid'] ?? ''}';
  final year = DateTime.tryParse('${note['issue_date']}')?.year ?? DateTime.now().year;
  final prefix = '${note['note_type']}' == 'DEBIT' ? 'DN' : 'CN';
  if (uuid.length >= 6) return '$prefix-$year-${uuid.replaceAll('-', '').substring(0, 6).toUpperCase()}';
  return '$prefix-$year-${note['note_no']}';
}

String _amountWords(double v) {
  if (v == 0) return 'ZERO RUPEES ONLY';
  return '${v.toStringAsFixed(2)} RUPEES ONLY';
}

Future<void> reprintAdjustmentNote(int noteId) async {
  final bytes = await buildAdjustmentNotePdf(noteId);
  if (bytes == null) return;
  await Printing.layoutPdf(onLayout: (_) => bytes);
}

Future<Uint8List?> buildAdjustmentNotePdf(int noteId) async {
  final bundle = await AppDatabase.instance.adjustmentNotePrintBundle(noteId);
  if (bundle == null) return null;
  final note = bundle['note'] as Map<String, dynamic>;
  final items = bundle['items'] as List<Map<String, dynamic>>;
  final isCredit = '${note['note_type']}' == 'CREDIT';

  final taxable = (note['taxable_total'] as num?)?.toDouble() ?? 0;
  final taxTotal = (note['tax_total'] as num?)?.toDouble() ?? 0;
  final grand = (note['grand_total'] as num?)?.toDouble() ?? 0;
  final cgst = taxTotal / 2;
  final sgst = taxTotal / 2;

  final doc = pw.Document();
  final logo = pw.MemoryImage(base64Decode(ultraLogoBase64));
  final copyTitle = isCredit
      ? 'CREDIT NOTE / SALES REVERSAL DUPLICATE CLIENT REVERSAL COPY'
      : 'DEBIT NOTE / PURCHASE REVERSAL DUPLICATE SUPPLIER REVERSAL COPY';
  final partyHeading = isCredit ? 'NAME & ADDRESS OF CUSTOMER (CREDITED)' : 'NAME & ADDRESS OF SUPPLIER (DEBITED)';
  final noteLabel = isCredit ? 'Credit Note No' : 'Debit Note No';

  doc.addPage(
    pw.Page(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(20),
      build: (context) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.stretch,
        children: [
          pw.Center(child: pw.Text(copyTitle, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10))),
          pw.SizedBox(height: 8),
          pw.Row(
            children: [
              pw.Container(width: 55, height: 45, child: pw.Image(logo, fit: pw.BoxFit.contain)),
              pw.Expanded(
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.center,
                  children: [
                    pw.Text('ULTRA ENGINEERING WORKS', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 16)),
                    pw.Text('SPM MANUFACTURERS & FABRICATORS', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold)),
                    pw.Text('OFFICE:NO: 15/6, 5th CROSS, VIDYA NAGAR, OPP. S.K.F. FACTORY, BOMMASANDRA INDL. AREA, BENGALURU-560 099.',
                        style: const pw.TextStyle(fontSize: 6.5), textAlign: pw.TextAlign.center),
                    pw.Text('Tele Fax: 080-27834287, Mob: 9342509313 Email: ueworks@gmail.com', style: const pw.TextStyle(fontSize: 6.5)),
                    pw.Text('Works: No.B-48, KSSIDC INDL Estate, Near Karnataka Bank, Bommasandra Indl. Area, BENGALURU-560 099.',
                        style: const pw.TextStyle(fontSize: 6.5)),
                  ],
                ),
              ),
            ],
          ),
          pw.SizedBox(height: 8),
          pw.Container(
            padding: const pw.EdgeInsets.all(6),
            decoration: pw.BoxDecoration(border: pw.Border.all()),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(partyHeading, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8)),
                pw.Text('${note['party_name']}', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10)),
                pw.Text('${note['address']}, ${note['city']} - ${note['pincode']}', style: const pw.TextStyle(fontSize: 8.5)),
                pw.Text('GSTIN: ${note['gstin']}', style: const pw.TextStyle(fontSize: 8.5)),
              ],
            ),
          ),
          pw.SizedBox(height: 6),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text('$noteLabel ${_billNo(note)}', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9)),
              pw.Text('DATE ${_fmtDate(note['issue_date'] as String?)}', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9)),
            ],
          ),
          pw.Text('Orig. Inv No : ${note['original_invoice_ref']}    DATE ${_fmtDate(note['original_invoice_date'] as String?)}',
              style: const pw.TextStyle(fontSize: 8.5)),
          pw.Text('REASON : ${note['reversal_reason']}', style: const pw.TextStyle(fontSize: 8.5)),
          pw.Text('DISPATCH : ${note['logistics']}', style: const pw.TextStyle(fontSize: 8.5)),
          pw.Text('EWB NO: ${note['eway_bill']}', style: const pw.TextStyle(fontSize: 8.5)),
          pw.SizedBox(height: 8),
          pw.Table.fromTextArray(
            headers: ['SL', 'DESCRIPTION', 'HSN CODE', 'QTY', 'PRICE/QTY', 'AMOUNT'],
            data: List.generate(items.length, (i) {
              final it = items[i];
              final qty = (it['quantity'] as num?)?.toDouble() ?? 0;
              final rate = (it['rate'] as num?)?.toDouble() ?? 0;
              return [
                '${i + 1}',
                '${it['description']}',
                '${it['hsn']}',
                qty.toStringAsFixed(2),
                rate.toStringAsFixed(2),
                ((it['extended_value'] as num?)?.toDouble() ?? qty * rate).toStringAsFixed(2),
              ];
            }),
            headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8),
            cellStyle: const pw.TextStyle(fontSize: 8),
          ),
          pw.SizedBox(height: 8),
          pw.Text('VALUE IN WORDS:', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8)),
          pw.Text(_amountWords(grand), style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9)),
          pw.SizedBox(height: 6),
          pw.Text('BANK: STATE BANK OF INDIA | A/C: 54009859972', style: const pw.TextStyle(fontSize: 8)),
          pw.Text('IFS CODE: SBIN0040552 | ADDRESS: SINGASANDRA', style: const pw.TextStyle(fontSize: 8)),
          pw.SizedBox(height: 6),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.end,
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.end,
              children: [
                pw.Text('Subtotal ${taxable.toStringAsFixed(2)}', style: const pw.TextStyle(fontSize: 9)),
                pw.Text('CGST ${cgst.toStringAsFixed(2)}', style: const pw.TextStyle(fontSize: 9)),
                pw.Text('SGST ${sgst.toStringAsFixed(2)}', style: const pw.TextStyle(fontSize: 9)),
                pw.Text('Round Off 0.00', style: const pw.TextStyle(fontSize: 9)),
                pw.Text('Total Value ${grand.toStringAsFixed(2)}', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10)),
              ],
            ),
          ),
          pw.Spacer(),
          pw.Text('TERMS & CONDITIONS:', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8)),
          pw.Text('1. Goods once sold will not be taken back or exchanged.', style: const pw.TextStyle(fontSize: 7)),
          pw.Text('2. Interest @24% will be charged if not paid within due period.', style: const pw.TextStyle(fontSize: 7)),
          pw.Text('3. All Disputes Subject to Bangalore Jurisdiction Only.', style: const pw.TextStyle(fontSize: 7)),
          pw.SizedBox(height: 12),
          pw.Align(
            alignment: pw.Alignment.centerRight,
            child: pw.Column(
              children: [
                pw.Text('For ULTRA ENGINEERING WORKS', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9)),
                pw.SizedBox(height: 24),
                pw.Text('Authorised Signatory', style: const pw.TextStyle(fontSize: 8)),
              ],
            ),
          ),
        ],
      ),
    ),
  );
  return doc.save();
}
