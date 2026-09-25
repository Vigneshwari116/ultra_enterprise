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

Future<void> reprintDeliveryChallan(int challanId) async {
  final bytes = await buildDeliveryChallanPdf(challanId);
  if (bytes == null) return;
  await Printing.layoutPdf(onLayout: (_) => bytes);
}

Future<Uint8List?> buildDeliveryChallanPdf(int challanId) async {
  final bundle = await AppDatabase.instance.deliveryChallanPrintBundle(challanId);
  if (bundle == null) return null;
  final dc = bundle['challan'] as Map<String, dynamic>;
  final items = bundle['items'] as List<Map<String, dynamic>>;
  final type = '${dc['dc_type']}';
  final title = type == 'PROFORMA' ? 'PROFORMA INVOICE' : 'DELIVERY CHALLAN ($type)';

  final doc = pw.Document();
  final logo = pw.MemoryImage(base64Decode(ultraLogoBase64));

  doc.addPage(
    pw.Page(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(24),
      build: (context) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.stretch,
        children: [
          pw.Row(
            children: [
              pw.Container(width: 50, height: 40, child: pw.Image(logo, fit: pw.BoxFit.contain)),
              pw.SizedBox(width: 10),
              pw.Expanded(
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.center,
                  children: [
                    pw.Text('ULTRA ENGINEERING WORKS', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 16)),
                    pw.Text('SPM MANUFACTURERS & FABRICATORS', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold)),
                  ],
                ),
              ),
            ],
          ),
          pw.SizedBox(height: 8),
          pw.Center(child: pw.Text(title, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 14))),
          pw.SizedBox(height: 12),
          pw.Table.fromTextArray(
            headers: ['DOC ID', 'DATE', 'PO REF', 'VEHICLE', 'E-WAY'],
            data: [
              [
                '${dc['doc_id']}',
                _fmtDate(dc['document_date'] as String?),
                '${dc['po_ref_no']}',
                '${dc['vehicle_dispatch']}',
                '${dc['eway_bill_no']}',
              ],
            ],
            headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8),
            cellStyle: const pw.TextStyle(fontSize: 9),
          ),
          pw.SizedBox(height: 10),
          pw.Text('PARTY: ${dc['party_name']}', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10)),
          pw.Text('${dc['billing_address']}, ${dc['city']} - ${dc['pincode']}', style: const pw.TextStyle(fontSize: 9)),
          pw.Text('GSTIN: ${dc['gstin']}', style: const pw.TextStyle(fontSize: 9)),
          pw.SizedBox(height: 10),
          pw.Table.fromTextArray(
            headers: ['SL', 'DESCRIPTION', 'UOM', 'HSN', 'QTY', 'RATE', 'VALUE', 'REMARKS'],
            data: List.generate(items.length, (i) {
              final it = items[i];
              return [
                '${i + 1}',
                '${it['description']}',
                '${it['uom']}',
                '${it['hsn']}',
                '${it['quantity']}',
                '${it['rate']}',
                '${it['extended_value']}',
                '${it['remarks'] ?? ''}',
              ];
            }),
            headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 7),
            cellStyle: const pw.TextStyle(fontSize: 8),
          ),
          pw.SizedBox(height: 12),
          pw.Align(
            alignment: pw.Alignment.centerRight,
            child: pw.Text('GRAND TOTAL: ₹ ${(dc['grand_total'] as num?)?.toStringAsFixed(2) ?? '0.00'}',
                style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 11)),
          ),
        ],
      ),
    ),
  );
  return doc.save();
}
