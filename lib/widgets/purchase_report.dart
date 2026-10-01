import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import 'purchase_voucher_document.dart';

String _money(num v) => '₹${v.toStringAsFixed(2)}';
String _fmtDate(String? iso) {
  final d = DateTime.tryParse(iso ?? '');
  return d == null ? (iso ?? '-') : DateFormat('dd-MM-yyyy').format(d);
}

/// Groups purchase vouchers by date and prints a GST-style audit register,
/// matching the "AUDIT REPORT" tab: per-date subtotals + a grand-total row.
Future<void> printPurchaseAuditReport(List<Map<String, dynamic>> vouchers) async {
  final byDate = <String, List<Map<String, dynamic>>>{};
  for (final v in vouchers) {
    final key = (v['voucher_date'] as String?) ?? '-';
    byDate.putIfAbsent(key, () => []).add(v);
  }
  final dates = byDate.keys.toList()..sort((a, b) => b.compareTo(a));

  double gTaxable = 0, gCgst = 0, gSgst = 0, gIgst = 0, gTotal = 0;

  final doc = pw.Document();
  doc.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      build: (context) {
        final widgets = <pw.Widget>[
          pw.Text('PURCHASE AUDIT REPORT SYSTEM',
              style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
          pw.Text('REAL-TIME PROCUREMENT MONITORING & SUPPLIER LEDGER ENTRIES DIRECTORY',
              style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700)),
          pw.SizedBox(height: 4),
          pw.Text('Generated: ${DateFormat('dd-MM-yyyy HH:mm').format(DateTime.now())}',
              style: const pw.TextStyle(fontSize: 8)),
          pw.Divider(),
        ];

        for (final date in dates) {
          final rows = byDate[date]!;
          double taxable = 0, cgst = 0, sgst = 0, igst = 0, total = 0;
          widgets.add(pw.SizedBox(height: 6));
          widgets.add(pw.Text(_fmtDate(date), style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9)));
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
              pw.TableRow(children: [
                _h('INV/BILL NO'), _h('PARTY NAME'), _h('TAXABLE'), _h('CGST'), _h('SGST'), _h('IGST'), _h('TOTAL'),
              ]),
              for (final r in rows)
                pw.TableRow(children: [
                  _c('${r['supplier_invoice_no'] ?? 'PV-${r['voucher_no']}'}'),
                  _c('${r['party_name']}'),
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
          widgets.add(pw.Container(
            padding: const pw.EdgeInsets.symmetric(vertical: 2),
            child: pw.Row(mainAxisAlignment: pw.MainAxisAlignment.end, children: [
              pw.Text('Subtotal: ${_money(taxable)}  ${_money(cgst)}  ${_money(sgst)}  ${_money(igst)}  ${_money(total)}',
                  style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700)),
            ]),
          ));
          gTaxable += taxable; gCgst += cgst; gSgst += sgst; gIgst += igst; gTotal += total;
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

/// Prints the "VENDORS LEDGER ACCOUNT STATEMENT" for one supplier, matching
/// the VIEW LEDGER WISE tab's print button.
Future<void> printVendorLedgerStatement({
  required Map<String, dynamic> supplier,
  required List<Map<String, dynamic>> rows, // each: {date, type, ref, narration, debit, credit, balance}
  required double openingBalance,
  required double totalDebit,
  required double totalCredit,
  required double closingBalance,
}) async {
  final doc = pw.Document();
  doc.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      build: (context) => [
        pw.Text('VENDORS LEDGER ACCOUNT STATEMENT',
            style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
        pw.Text('SUPPLIER: ${supplier['supplier_name']}',
            style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: PdfColors.blue800)),
        pw.Text('Vendor ID Reference: ${supplier['id']}', style: const pw.TextStyle(fontSize: 8)),
        pw.Align(
          alignment: pw.Alignment.topRight,
          child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.end, children: [
            pw.Text('Generated: ${DateFormat('dd-MM-yyyy HH:mm').format(DateTime.now())}',
                style: const pw.TextStyle(fontSize: 8)),
            pw.Text('Opening Bal: ${_money(openingBalance)}',
                style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold)),
          ]),
        ),
        pw.Divider(),
        pw.Table(
          columnWidths: const {
            0: pw.FlexColumnWidth(2),
            1: pw.FlexColumnWidth(2),
            2: pw.FlexColumnWidth(2),
            3: pw.FlexColumnWidth(3),
            4: pw.FlexColumnWidth(2),
            5: pw.FlexColumnWidth(2),
            6: pw.FlexColumnWidth(2),
          },
          children: [
            pw.TableRow(children: [
              _h('DATE'), _h('TXN TYPE'), _h('REF NO'), _h('NARRATION'), _h('DEBIT (DR)'), _h('CREDIT (CR)'), _h('BALANCE'),
            ]),
            for (final r in rows)
              pw.TableRow(children: [
                _c(_fmtDate(r['date'] as String?)),
                _c('${r['type']}'),
                _c('${r['ref']}'),
                _c('${r['narration']}'),
                _c(r['debit'] == 0 ? '-' : _money(r['debit'] as num)),
                _c(r['credit'] == 0 ? '-' : _money(r['credit'] as num)),
                _c(_money(r['balance'] as num), bold: true),
              ]),
          ],
        ),
        pw.SizedBox(height: 10),
        pw.Align(
          alignment: pw.Alignment.centerRight,
          child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.end, children: [
            pw.Text('Total Debit Payments (DR): ${_money(totalDebit)}', style: const pw.TextStyle(fontSize: 9)),
            pw.Text('Total Purchase Liability (CR): ${_money(totalCredit)}', style: const pw.TextStyle(fontSize: 9)),
            pw.SizedBox(height: 4),
            pw.Text('Final Closing Balance: ${_money(closingBalance)}',
                style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold, color: PdfColors.red800)),
          ]),
        ),
      ],
    ),
  );
  await Printing.layoutPdf(onLayout: (_) => doc.save());
}

/// Reprints a single purchase voucher using the portal-style ULTRA bill layout.
Future<void> printPurchaseVoucherReprint(
  Map<String, dynamic> voucher,
  List<Map<String, dynamic>> items,
) async {
  final id = voucher['id'];
  if (id is int) {
    await reprintPurchaseVoucher(id);
    return;
  }
  if (id != null) {
    final parsed = int.tryParse('$id');
    if (parsed != null) {
      await reprintPurchaseVoucher(parsed);
    }
  }
}

pw.Widget _h(String text) => pw.Padding(
  padding: const pw.EdgeInsets.symmetric(vertical: 4, horizontal: 3),
  child: pw.Text(text, style: pw.TextStyle(fontSize: 7.5, fontWeight: pw.FontWeight.bold)),
);

pw.Widget _c(String text, {bool bold = false}) => pw.Padding(
  padding: const pw.EdgeInsets.symmetric(vertical: 3, horizontal: 3),
  child: pw.Text(text,
      style: pw.TextStyle(fontSize: 8, fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal)),
);
