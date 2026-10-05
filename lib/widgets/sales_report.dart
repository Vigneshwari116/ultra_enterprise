import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../services/ultra_repository.dart';
import 'invoice.dart';
import 'invoice_pdf_preview.dart';
import 'ultra_print_helpers.dart';

String _money(num v) => v.toStringAsFixed(2);

String _fmtDate(String? iso) => ultraFmtDate(iso);

pw.Widget _h(String t) => pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 3),
      child: pw.Text(t, style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold)),
    );

pw.Widget _c(String t, {bool bold = false}) => pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 3),
      child: pw.Text(t, style: pw.TextStyle(fontSize: 8, fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal)),
    );

Future<void> printSalesAuditReport(List<Map<String, dynamic>> invoices) async {
  final sorted = List<Map<String, dynamic>>.from(invoices);
  sorted.sort((a, b) {
    final da = DateTime.tryParse('${a['transaction_date'] ?? ''}') ?? DateTime(1970);
    final db = DateTime.tryParse('${b['transaction_date'] ?? ''}') ?? DateTime(1970);
    final c = db.compareTo(da);
    if (c != 0) return c;
    return ((b['invoice_no'] as num?) ?? 0).compareTo((a['invoice_no'] as num?) ?? 0);
  });

  double gTaxable = 0, gCgst = 0, gSgst = 0, gIgst = 0, gTotal = 0;
  for (final r in sorted) {
    gTaxable += ((r['taxable_total'] ?? 0) as num).toDouble();
    gCgst += ((r['cgst_total'] ?? 0) as num).toDouble();
    gSgst += ((r['sgst_total'] ?? 0) as num).toDouble();
    gIgst += ((r['igst_total'] ?? 0) as num).toDouble();
    gTotal += ((r['grand_total'] ?? 0) as num).toDouble();
  }

  final doc = pw.Document();
  doc.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      build: (context) {
        return [
          pw.Text('SALES AUDIT REPORT SYSTEM',
              style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
          pw.Text('REAL-TIME TAX COMPLIANCE ACCOUNTING LEDGER DIRECTORY',
              style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700)),
          pw.SizedBox(height: 4),
          pw.Text('Generated: ${DateFormat('dd-MM-yyyy HH:mm').format(DateTime.now())}',
              style: const pw.TextStyle(fontSize: 8)),
          pw.Divider(),
          pw.Table(
            columnWidths: const {
              0: pw.FlexColumnWidth(1.2),
              1: pw.FlexColumnWidth(1.4),
              2: pw.FlexColumnWidth(3),
              3: pw.FlexColumnWidth(1.6),
              4: pw.FlexColumnWidth(1.4),
              5: pw.FlexColumnWidth(1.4),
              6: pw.FlexColumnWidth(1.4),
              7: pw.FlexColumnWidth(1.6),
            },
            children: [
              pw.TableRow(children: [
                _h('BILL NO'),
                _h('DATE'),
                _h('PARTY NAME'),
                _h('TAXABLE'),
                _h('CGST'),
                _h('SGST'),
                _h('IGST'),
                _h('TOTAL'),
              ]),
              for (final r in sorted)
                pw.TableRow(children: [
                  _c('${r['invoice_no'] ?? ''}'),
                  _c(_fmtDate(r['transaction_date'] as String?)),
                  _c('${r['customer_name'] ?? ''}'),
                  _c(_money((r['taxable_total'] ?? 0) as num)),
                  _c(_money((r['cgst_total'] ?? 0) as num)),
                  _c(_money((r['sgst_total'] ?? 0) as num)),
                  _c(_money((r['igst_total'] ?? 0) as num)),
                  _c(_money((r['grand_total'] ?? 0) as num), bold: true),
                ]),
            ],
          ),
          pw.SizedBox(height: 10),
          pw.Container(
            padding: const pw.EdgeInsets.all(6),
            decoration: pw.BoxDecoration(border: pw.Border.all(color: PdfColors.grey500)),
            child: pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
              pw.Text('GRAND TOTALS:', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9)),
              pw.Text(
                '${_money(gTaxable)}   ${_money(gCgst)}   ${_money(gSgst)}   ${_money(gIgst)}   ${_money(gTotal)}',
                style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9),
              ),
            ]),
          ),
        ];
      },
    ),
  );
  await Printing.layoutPdf(onLayout: (_) => doc.save());
}

String _shippingBlockFromInvoice(Map<String, dynamic> inv) {
  final lines = <String>[];
  final name = '${inv['shipping_consignee_name'] ?? ''}'.trim();
  final addr = '${inv['shipping_address'] ?? ''}'.trim();
  final city = '${inv['shipping_city'] ?? ''}'.trim();
  final pin = '${inv['shipping_pincode'] ?? ''}'.trim();
  if (name.isNotEmpty) lines.add(name);
  if (addr.isNotEmpty) lines.add(addr);
  final cityPin = [city, pin].where((e) => e.isNotEmpty).join(' ');
  if (cityPin.isNotEmpty) lines.add(cityPin);
  return lines.join('\n');
}

String _consigneeAddress(Map<String, dynamic> inv) {
  final parts = <String>[];
  final addr = '${inv['customer_address'] ?? ''}'.trim();
  if (addr.isNotEmpty) parts.add(addr);
  return parts.join('\n');
}

Future<InvoiceData?> invoiceDataFromId(int invoiceId) async {
  final bundle = await UltraRepository.instance.salesInvoicePrintBundle(invoiceId);
  if (bundle == null) return null;
  final inv = bundle['invoice'] as Map<String, dynamic>;
  final rawItems = bundle['items'] as List<Map<String, dynamic>>;
  final company = await UltraRepository.instance.companySettings();
  final items = rawItems
      .map(
        (it) => InvoiceItem(
          description: '${it['description'] ?? ''}',
          hsnCode: '${it['hsn'] ?? ''}',
          qty: (it['quantity'] as num?)?.toDouble() ?? 0,
          price: (it['rate'] as num?)?.toDouble() ?? 0,
        ),
      )
      .toList();

  final taxable = (inv['taxable_total'] as num?)?.toDouble() ?? items.fold<double>(0, (s, i) => s + i.amount);
  final cgstAmt = (inv['cgst_total'] as num?)?.toDouble() ?? 0;
  final sgstAmt = (inv['sgst_total'] as num?)?.toDouble() ?? 0;
  final igstAmt = (inv['igst_total'] as num?)?.toDouble() ?? 0;
  final grand = (inv['grand_total'] as num?)?.toDouble() ?? taxable + cgstAmt + sgstAmt + igstAmt;

  final cgstPct = taxable > 0 ? (cgstAmt / taxable * 100) : 0.0;
  final sgstPct = taxable > 0 ? (sgstAmt / taxable * 100) : 0.0;
  final igstPct = taxable > 0 ? (igstAmt / taxable * 100) : 0.0;

  final pAndF = grand - taxable - cgstAmt - sgstAmt - igstAmt;
  final roundOff = 0.0;

  return InvoiceData(
    kind: UltraBillKind.taxInvoice,
    invoiceNo: '${inv['invoice_no'] ?? ''}',
    date: _fmtDate(inv['transaction_date'] as String?),
    custPo: '${inv['po_no'] ?? ''}',
    poDate: _fmtDate(inv['po_date'] as String?),
    dcNo: '${inv['challan_no'] ?? ''}',
    dcDate: _fmtDate(inv['challan_date'] as String?),
    dispatch: '${inv['vehicle_dispatch_mode'] ?? ''}',
    ewbNo: '${inv['eway_bill_no'] ?? ''}',
    consigneeName: '${inv['customer_name'] ?? ''}',
    consigneeAddress: _consigneeAddress(inv),
    gstin: '${inv['customer_gstin'] ?? ''}',
    mobile: '${inv['customer_mobile'] ?? ''}',
    shippingBlock: _shippingBlockFromInvoice(inv),
    items: items,
    cgstPercent: cgstPct,
    sgstPercent: sgstPct,
    igstPercent: igstPct,
    pAndF: pAndF > 0 ? pAndF : 0,
    roundOff: roundOff,
    cgstAmountOverride: cgstAmt,
    sgstAmountOverride: sgstAmt,
    igstAmountOverride: igstAmt,
    grandTotalOverride: grand,
    amountInWords: formatUltraAmountInWords(grand),
    bankName: company.bankName,
    accountNo: company.bankAccountNo,
    ifscCode: company.ifscCode,
    bankAddress: company.branch,
    company: company,
  );
}

Future<void> reprintSalesInvoice(BuildContext context, int invoiceId) async {
  final data = await invoiceDataFromId(invoiceId);
  if (data == null) return;
  await printUltraInvoice(context, data);
}
