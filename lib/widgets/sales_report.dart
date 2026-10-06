import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../services/ultra_repository.dart';
import 'invoice.dart';
import 'ultra_print_helpers.dart';

String _money(num v) => v.toStringAsFixed(2);

num? toNum(dynamic value) {
  if (value == null) return null;
  if (value is num) return value;
  if (value is String) return num.tryParse(value.trim());
  return null;
}

double toDouble(dynamic value, {double fallback = 0}) => toNum(value)?.toDouble() ?? fallback;

String _fmtDate(String? iso) {
  final d = DateTime.tryParse(iso ?? '');
  return d == null ? (iso ?? '-') : DateFormat('dd-MM-yyyy').format(d);
}

String _fmtInvoicePrintDate(String? iso) {
  final d = DateTime.tryParse(iso ?? '');
  return d == null ? (iso ?? '') : DateFormat('MM/dd/yyyy').format(d);
}

String _partyAddress(Map<String, dynamic> inv) {
  final parts = <String>[
    '${inv['customer_address'] ?? ''}'.trim(),
    '${inv['customer_city'] ?? ''}'.trim(),
    '${inv['customer_pincode'] ?? ''}'.trim(),
  ].where((p) => p.isNotEmpty);
  return parts.join(', ');
}

pw.Widget _h(String t, {bool right = false}) => pw.Container(
      padding: const pw.EdgeInsets.all(4),
      alignment: right ? pw.Alignment.centerRight : pw.Alignment.centerLeft,
      child: pw.Text(t, style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold)),
    );

pw.Widget _c(String t, {bool bold = false, bool right = false}) => pw.Container(
      padding: const pw.EdgeInsets.all(4),
      alignment: right ? pw.Alignment.centerRight : pw.Alignment.centerLeft,
      child: pw.Text(t, style: pw.TextStyle(fontSize: 8, fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal)),
    );

pw.Widget _summaryValue(num value, {bool bold = false}) => pw.Container(
      padding: const pw.EdgeInsets.all(5),
      alignment: pw.Alignment.centerRight,
      child: pw.Text(
        _money(value),
        style: pw.TextStyle(
          fontSize: 8,
          fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
        ),
      ),
    );

/// Sales audit register PDF — columns: bill no, date, then party and tax totals.
Future<void> printSalesAuditReport(List<Map<String, dynamic>> invoices) async {
  final sorted = List<Map<String, dynamic>>.from(invoices);
  sorted.sort((a, b) {
    final da = DateTime.tryParse('${a['transaction_date'] ?? ''}') ?? DateTime(1970);
    final db = DateTime.tryParse('${b['transaction_date'] ?? ''}') ?? DateTime(1970);
    final c = db.compareTo(da);
    if (c != 0) return c;
    return (toNum(b['invoice_no']) ?? 0).compareTo(toNum(a['invoice_no']) ?? 0);
  });

  double gTaxable = 0, gCgst = 0, gSgst = 0, gIgst = 0, gTotal = 0;
  for (final r in sorted) {
    gTaxable += toDouble(r['taxable_total']);
    gCgst += toDouble(r['cgst_total']);
    gSgst += toDouble(r['sgst_total']);
    gIgst += toDouble(r['igst_total']);
    gTotal += toDouble(r['grand_total']);
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
            border: pw.TableBorder.all(color: PdfColors.grey500, width: 0.6),
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
                _h('TAXABLE', right: true),
                _h('CGST', right: true),
                _h('SGST', right: true),
                _h('IGST', right: true),
                _h('TOTAL', right: true),
              ]),
              for (final r in sorted)
                pw.TableRow(children: [
                  _c('${r['invoice_no'] ?? '-'}'),
                  _c(_fmtDate(r['transaction_date']?.toString())),
                  _c('${r['customer_name'] ?? '-'}'),
                  _c(_money(toDouble(r['taxable_total'])), right: true),
                  _c(_money(toDouble(r['cgst_total'])), right: true),
                  _c(_money(toDouble(r['sgst_total'])), right: true),
                  _c(_money(toDouble(r['igst_total'])), right: true),
                  _c(_money(toDouble(r['grand_total'])), bold: true, right: true),
                ]),
            ],
          ),
          pw.SizedBox(height: 10),
          pw.Text('AUDIT SUMMARY',
              style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 5),
          pw.Table(
            border: pw.TableBorder.all(color: PdfColors.grey500, width: 0.6),
            columnWidths: const {
              0: pw.FlexColumnWidth(1),
              1: pw.FlexColumnWidth(1),
              2: pw.FlexColumnWidth(1),
              3: pw.FlexColumnWidth(1),
              4: pw.FlexColumnWidth(1),
            },
            children: [
              pw.TableRow(children: [
                _h('TAXABLE', right: true),
                _h('CGST', right: true),
                _h('SGST', right: true),
                _h('IGST', right: true),
                _h('TOTAL', right: true),
              ]),
              pw.TableRow(children: [
                _summaryValue(gTaxable),
                _summaryValue(gCgst),
                _summaryValue(gSgst),
                _summaryValue(gIgst),
                _summaryValue(gTotal, bold: true),
              ]),
            ],
          ),
        ];
      },
    ),
  );
  await Printing.layoutPdf(onLayout: (_) => doc.save());
}

Future<InvoiceData?> invoiceDataFromId(int invoiceId) async {
  final bundle = await UltraRepository.instance.salesInvoicePrintBundle(invoiceId);
  if (bundle == null) return null;
  final inv = bundle['invoice'] as Map<String, dynamic>;
  final rawItems = bundle['items'] as List<Map<String, dynamic>>;
  final items = rawItems
      .map(
        (it) => InvoiceItem(
          description: '${it['description'] ?? ''}',
          hsnCode: '${it['hsn'] ?? it['hsn_code'] ?? ''}',
          qty: toDouble(it['quantity']),
          price: toDouble(it['rate']),
        ),
      )
      .toList();
  final zone = '${inv['state_zone'] ?? ''}'.toLowerCase();
  final isInter = zone.contains('inter');
  final taxable = toDouble(inv['taxable_total'], fallback: items.fold<double>(0, (s, i) => s + i.amount));
  final cgstAmt = toDouble(inv['cgst_total'], fallback: isInter ? 0.0 : taxable * 0.09);
  final sgstAmt = toDouble(inv['sgst_total'], fallback: isInter ? 0.0 : taxable * 0.09);
  final igstAmt = toDouble(inv['igst_total'], fallback: isInter ? taxable * 0.18 : 0.0);
  final grand = toDouble(inv['grand_total'], fallback: taxable + cgstAmt + sgstAmt + igstAmt);
  final fwdFromApi = inv['fwd_charge'];
  final freight = fwdFromApi != null
      ? toDouble(fwdFromApi)
      : (grand - taxable - cgstAmt - sgstAmt - igstAmt);
  final roundOff = toDouble(inv['round_off'], fallback: 0);
  return InvoiceData(
    kind: UltraBillKind.taxInvoice,
    invoiceNo: '${inv['invoice_no'] ?? ''}',
    date: _fmtInvoicePrintDate(inv['transaction_date'] as String?),
    custPo: '${inv['po_no'] ?? ''}',
    poDate: _fmtInvoicePrintDate(inv['po_date'] as String?),
    dcNo: '${inv['challan_no'] ?? ''}',
    dcDate: _fmtInvoicePrintDate(inv['challan_date'] as String?),
    dispatch: '${inv['vehicle_dispatch_mode'] ?? ''}',
    ewbNo: '${inv['eway_bill_no'] ?? ''}',
    consigneeName: '${inv['customer_name'] ?? ''}',
    consigneeAddress: _partyAddress(inv),
    shippingName: '${inv['shipping_name'] ?? ''}',
    shippingAddress: '${inv['shipping_address'] ?? ''}'.trim(),
    gstin: '${inv['customer_gstin'] ?? ''}',
    mobile: '${inv['customer_mobile'] ?? ''}',
    items: items,
    cgstPercent: isInter ? 0 : 9,
    sgstPercent: isInter ? 0 : 9,
    igstPercent: isInter ? 18 : 0,
    pAndF: freight > 0 ? freight : 0,
    roundOff: roundOff,
    cgstAmountOverride: cgstAmt,
    sgstAmountOverride: sgstAmt,
    igstAmountOverride: igstAmt,
    grandTotalOverride: grand,
    amountInWords: formatUltraAmountInWords(grand),
    bankName: ultraBankName(inv, 'bank_name'),
    accountNo: ultraBankAccount(inv, 'bank_account_no'),
    ifscCode: ultraBankIfsc(inv, 'ifsc_code'),
    bankAddress: ultraBankAddress(inv, 'branch_address'),
    leftSignatureLabel: 'Receiver signature & Seal',
  );
}

Future<void> reprintSalesInvoice(int invoiceId) async {
  final data = await invoiceDataFromId(invoiceId);
  if (data == null) return;
  await printUltraInvoice(data);
}
