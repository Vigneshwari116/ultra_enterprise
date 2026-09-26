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

pw.Widget _h(String t) => pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 3),
      child: pw.Text(t, style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold)),
    );

pw.Widget _c(String t, {bool bold = false}) => pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 3),
      child: pw.Text(t, style: pw.TextStyle(fontSize: 8, fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal)),
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
                  _c('${r['invoice_no'] ?? '-'}'),
                  _c(_fmtDate(r['transaction_date'] as String?)),
                  _c('${r['customer_name'] ?? '-'}'),
                  _c(_money(toDouble(r['taxable_total']))),
                  _c(_money(toDouble(r['cgst_total']))),
                  _c(_money(toDouble(r['sgst_total']))),
                  _c(_money(toDouble(r['igst_total']))),
                  _c(_money(toDouble(r['grand_total'])), bold: true),
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

Future<InvoiceData?> invoiceDataFromId(int invoiceId) async {
  final bundle = await UltraRepository.instance.salesInvoicePrintBundle(invoiceId);
  if (bundle == null) return null;
  final inv = bundle['invoice'] as Map<String, dynamic>;
  final rawItems = bundle['items'] as List<Map<String, dynamic>>;
  final items = rawItems
      .map(
        (it) => InvoiceItem(
          description: '${it['description'] ?? ''}',
          hsnCode: '${it['hsn'] ?? ''}',
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
  final freight = grand - taxable - cgstAmt - sgstAmt - igstAmt;
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
    consigneeAddress: '${inv['customer_address'] ?? ''}',
    gstin: '${inv['customer_gstin'] ?? ''}',
    mobile: '${inv['customer_mobile'] ?? ''}',
    items: items,
    cgstPercent: isInter ? 0 : 9,
    sgstPercent: isInter ? 0 : 9,
    igstPercent: isInter ? 18 : 0,
    pAndF: freight > 0 ? freight : 0,
    cgstAmountOverride: cgstAmt,
    sgstAmountOverride: sgstAmt,
    igstAmountOverride: igstAmt,
    grandTotalOverride: grand,
    amountInWords: formatUltraAmountInWords(grand),
    bankName: ultraBankName(inv, 'bank_name'),
    accountNo: ultraBankAccount(inv, 'bank_account_no'),
    ifscCode: ultraBankIfsc(inv, 'ifsc_code'),
    bankAddress: ultraBankAddress(inv, 'branch_address'),
  );
}

Future<void> reprintSalesInvoice(int invoiceId) async {
  final data = await invoiceDataFromId(invoiceId);
  if (data == null) return;
  await printUltraInvoice(data);
}
