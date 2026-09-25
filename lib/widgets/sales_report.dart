import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../database/app_database.dart';
import 'invoice.dart';

String _money(num v) => v.toStringAsFixed(2);

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

/// Sales audit register PDF — date group header, then bill rows (bill no beside party, not under date).
Future<void> printSalesAuditReport(List<Map<String, dynamic>> invoices) async {
  final byDate = <String, List<Map<String, dynamic>>>{};
  for (final inv in invoices) {
    final key = _fmtDate(inv['transaction_date'] as String?);
    byDate.putIfAbsent(key, () => []).add(inv);
  }
  final dates = byDate.keys.toList()..sort((a, b) => b.compareTo(a));

  double gTaxable = 0, gCgst = 0, gSgst = 0, gIgst = 0, gTotal = 0;

  final doc = pw.Document();
  doc.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      build: (context) {
        final widgets = <pw.Widget>[
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
              0: pw.FlexColumnWidth(2),
              1: pw.FlexColumnWidth(3),
              2: pw.FlexColumnWidth(2),
              3: pw.FlexColumnWidth(2),
              4: pw.FlexColumnWidth(2),
              5: pw.FlexColumnWidth(2),
              6: pw.FlexColumnWidth(2),
            },
            children: [
              pw.TableRow(children: [
                _h('INV/BILL'),
                _h('PARTY NAME'),
                _h('TAXABLE'),
                _h('CGST'),
                _h('SGST'),
                _h('IGST'),
                _h('TOTAL'),
              ]),
            ],
          ),
        ];

        for (final date in dates) {
          final rows = byDate[date]!;
          widgets.add(pw.SizedBox(height: 6));
          widgets.add(pw.Text(date, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9)));
          double taxable = 0, cgst = 0, sgst = 0, igst = 0, total = 0;
          widgets.add(pw.Table(
            columnWidths: const {
              0: pw.FlexColumnWidth(2),
              1: pw.FlexColumnWidth(3),
              2: pw.FlexColumnWidth(2),
              3: pw.FlexColumnWidth(2),
              4: pw.FlexColumnWidth(2),
              5: pw.FlexColumnWidth(2),
              6: pw.FlexColumnWidth(2),
            },
            children: [
              for (final r in rows)
                pw.TableRow(children: [
                  _c('${r['invoice_no'] ?? '-'}'),
                  _c('${r['customer_name'] ?? '-'}'),
                  _c(_money((r['taxable_total'] ?? 0) as num)),
                  _c(_money((r['cgst_total'] ?? 0) as num)),
                  _c(_money((r['sgst_total'] ?? 0) as num)),
                  _c(_money((r['igst_total'] ?? 0) as num)),
                  _c(_money((r['grand_total'] ?? 0) as num), bold: true),
                ]),
            ],
          ));
          for (final r in rows) {
            taxable += ((r['taxable_total'] ?? 0) as num).toDouble();
            cgst += ((r['cgst_total'] ?? 0) as num).toDouble();
            sgst += ((r['sgst_total'] ?? 0) as num).toDouble();
            igst += ((r['igst_total'] ?? 0) as num).toDouble();
            total += ((r['grand_total'] ?? 0) as num).toDouble();
          }
          gTaxable += taxable;
          gCgst += cgst;
          gSgst += sgst;
          gIgst += igst;
          gTotal += total;
        }

        widgets.add(pw.SizedBox(height: 10));
        widgets.add(pw.Container(
          padding: const pw.EdgeInsets.all(6),
          decoration: pw.BoxDecoration(border: pw.Border.all(color: PdfColors.grey500)),
          child: pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
            pw.Text('GRAND TOTALS:', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9)),
            pw.Text(
              '${_money(gTaxable)}   ${_money(gCgst)}   ${_money(gSgst)}   ${_money(gIgst)}   ${_money(gTotal)}',
              style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9),
            ),
          ]),
        ));
        return widgets;
      },
    ),
  );
  await Printing.layoutPdf(onLayout: (_) => doc.save());
}

Future<InvoiceData?> invoiceDataFromId(int invoiceId) async {
  final bundle = await AppDatabase.instance.salesInvoicePrintBundle(invoiceId);
  if (bundle == null) return null;
  final inv = bundle['invoice'] as Map<String, dynamic>;
  final rawItems = bundle['items'] as List<Map<String, dynamic>>;
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
  final zone = '${inv['state_zone'] ?? ''}'.toLowerCase();
  final isInter = zone.contains('inter');
  return InvoiceData(
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
    pAndF: 0,
    amountInWords: 'RUPEES ONLY',
    bankName: '${inv['bank_name'] ?? ''}',
    accountNo: '${inv['bank_account_no'] ?? ''}',
    ifscCode: '${inv['ifsc_code'] ?? ''}',
    bankAddress: '${inv['branch_address'] ?? ''}',
  );
}

Future<void> reprintSalesInvoice(int invoiceId) async {
  final data = await invoiceDataFromId(invoiceId);
  if (data == null) return;
  await printUltraInvoice(data);
}
