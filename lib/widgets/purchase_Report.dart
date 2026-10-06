import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'purchase_order_document.dart';

import 'purchase_voucher_document.dart';

// ============================================================
// SAFE NUMERIC PARSING
// ============================================================
//
// API/database values can arrive as:
//   int
//   double
//   String
//   null
//
// Never use:
//   (value as num).toDouble()
//
// because a numeric String such as "17700.00" will cause
// a runtime type error.
//
// ============================================================

double _numValue(dynamic value) {
  if (value is num) {
    return value.toDouble();
  }

  if (value is String) {
    return double.tryParse(value.trim()) ?? 0.0;
  }

  return 0.0;
}

String _money(num v) => '₹${v.toStringAsFixed(2)}';

String _fmtDate(String? iso) {
  final d = DateTime.tryParse(iso ?? '');
  return d == null ? (iso ?? '-') : DateFormat('dd-MM-yyyy').format(d);
}

// ============================================================
// COMMON PDF HELPERS
// ============================================================

pw.Widget _h(String text, {bool right = false}) {
  return pw.Container(
    padding: const pw.EdgeInsets.all(4),
    alignment: right ? pw.Alignment.centerRight : pw.Alignment.centerLeft,
    child: pw.Text(
      text,
      style: pw.TextStyle(
        fontSize: 7,
        fontWeight: pw.FontWeight.bold,
      ),
    ),
  );
}

pw.Widget _c(
  String text, {
  bool bold = false,
}) {
  return pw.Container(
    padding: const pw.EdgeInsets.all(4),
    child: pw.Text(
      text,
      style: pw.TextStyle(
        fontSize: 7,
        fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
      ),
    ),
  );
}

pw.Widget _cr(
  String text, {
  bool bold = false,
}) {
  return pw.Container(
    padding: const pw.EdgeInsets.all(4),
    alignment: pw.Alignment.centerRight,
    child: pw.Text(
      text,
      style: pw.TextStyle(
        fontSize: 7,
        fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
      ),
    ),
  );
}

pw.Widget _summaryValue(
  num value, {
  bool bold = false,
}) {
  return pw.Container(
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
}

// ============================================================
// PURCHASE AUDIT REPORT
//
// IMPORTANT ACCOUNTING RULE:
//
// PURCHASE ORDER
//   = procurement commitment
//   = NOT accounting purchase CR
//
// PURCHASE VOUCHER
//   = actual purchase/accounting transaction
//   = included in accounting purchase CR
//
// The audit PDF intentionally displays BOTH document types.
//
// "TOTAL RECORD VALUE" = PO + Voucher for audit/document review.
//
// It must NOT be used as accounting purchase CR.
// ============================================================

Future<void> printPurchaseAuditReport(
  List<Map<String, dynamic>> vouchers,
  List<Map<String, dynamic>> purchaseOrders,
) async {
  final records = <Map<String, dynamic>>[];

  // ----------------------------------------------------------
  // PURCHASE ORDERS
  // ----------------------------------------------------------

  for (final po in purchaseOrders) {
    records.add({
      ...po,
      '_record_type': 'PURCHASE ORDER',
      '_display_no': po['po_bill_no'] ?? 'PO-${po['po_no'] ?? po['id']}',
      '_display_party': po['_display_party'] ?? po['supplier_name'] ?? '-',
      '_display_date': po['po_date'],
    });
  }

  // ----------------------------------------------------------
  // PURCHASE VOUCHERS
  // ----------------------------------------------------------

  for (final voucher in vouchers) {
    records.add({
      ...voucher,
      '_record_type': 'PURCHASE VOUCHER',
      '_display_no': voucher['supplier_invoice_no'] ??
          'PV-${voucher['voucher_no'] ?? voucher['id']}',
      '_display_party': voucher['party_name'] ?? '-',
      '_display_date': voucher['voucher_date'],
    });
  }

  // ----------------------------------------------------------
  // SORT NEWEST FIRST
  // ----------------------------------------------------------

  records.sort(
    (a, b) =>
        '${b['_display_date'] ?? ''}'.compareTo('${a['_display_date'] ?? ''}'),
  );

  // ==========================================================
  // SEPARATE TOTALS
  // ==========================================================

  double poTaxable = 0;
  double poCgst = 0;
  double poSgst = 0;
  double poIgst = 0;
  double poTotal = 0;

  double voucherTaxable = 0;
  double voucherCgst = 0;
  double voucherSgst = 0;
  double voucherIgst = 0;
  double voucherTotal = 0;

  for (final record in records) {
    final taxable = _numValue(
      record['taxable_total'],
    );

    final cgst = _numValue(
      record['cgst_total'],
    );

    final sgst = _numValue(
      record['sgst_total'],
    );

    final igst = _numValue(
      record['igst_total'],
    );

    final total = _numValue(
      record['grand_total'],
    );

    if (record['_record_type'] == 'PURCHASE ORDER') {
      poTaxable += taxable;
      poCgst += cgst;
      poSgst += sgst;
      poIgst += igst;
      poTotal += total;
    } else {
      voucherTaxable += taxable;
      voucherCgst += cgst;
      voucherSgst += sgst;
      voucherIgst += igst;
      voucherTotal += total;
    }
  }

  // ==========================================================
  // COMBINED AUDIT TOTAL
  // ==========================================================

  final grandTaxable = poTaxable + voucherTaxable;

  final grandCgst = poCgst + voucherCgst;

  final grandSgst = poSgst + voucherSgst;

  final grandIgst = poIgst + voucherIgst;

  final grandTotal = poTotal + voucherTotal;

  // ==========================================================
  // GROUP RECORDS BY DATE
  // ==========================================================

  final byDate = <String, List<Map<String, dynamic>>>{};

  for (final record in records) {
    final date = '${record['_display_date'] ?? '-'}';

    byDate
        .putIfAbsent(
          date,
          () => [],
        )
        .add(record);
  }

  final dates = byDate.keys.toList()
    ..sort(
      (a, b) => b.compareTo(a),
    );

  // ==========================================================
  // CREATE PDF
  // ==========================================================

  final doc = pw.Document();

  doc.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(24),
      build: (context) {
        final widgets = <pw.Widget>[
          // --------------------------------------------------
          // HEADER
          // --------------------------------------------------

          pw.Text(
            'PURCHASE AUDIT REPORT SYSTEM',
            style: pw.TextStyle(
              fontSize: 14,
              fontWeight: pw.FontWeight.bold,
            ),
          ),

          pw.SizedBox(height: 2),

          pw.Text(
            'REAL-TIME PROCUREMENT MONITORING & '
            'SUPPLIER LEDGER ENTRIES DIRECTORY',
            style: const pw.TextStyle(
              fontSize: 8,
              color: PdfColors.grey700,
            ),
          ),

          pw.SizedBox(height: 4),

          pw.Text(
            'Generated: '
            '${DateFormat('dd-MM-yyyy HH:mm').format(DateTime.now())}',
            style: const pw.TextStyle(
              fontSize: 8,
            ),
          ),

          pw.Divider(),
        ];

        // ====================================================
        // DATE-WISE SECTIONS
        // ====================================================

        for (final date in dates) {
          final rows = byDate[date]!;

          double dateTaxable = 0;
          double dateCgst = 0;
          double dateSgst = 0;
          double dateIgst = 0;
          double dateTotal = 0;

          for (final record in rows) {
            dateTaxable += _numValue(
              record['taxable_total'],
            );

            dateCgst += _numValue(
              record['cgst_total'],
            );

            dateSgst += _numValue(
              record['sgst_total'],
            );

            dateIgst += _numValue(
              record['igst_total'],
            );

            dateTotal += _numValue(
              record['grand_total'],
            );
          }

          widgets.add(
            pw.SizedBox(height: 6),
          );

          widgets.add(
            pw.Text(
              _fmtDate(date),
              style: pw.TextStyle(
                fontSize: 9,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
          );

          widgets.add(
            pw.SizedBox(height: 3),
          );

          // ------------------------------------------------
          // DATE-WISE TABLE
          // ------------------------------------------------

          widgets.add(
            pw.Table(
              border: pw.TableBorder.all(
                color: PdfColors.grey500,
                width: 0.6,
              ),
              columnWidths: const {
                0: pw.FlexColumnWidth(1.6),
                1: pw.FlexColumnWidth(2.6),
                2: pw.FlexColumnWidth(2.5),
                3: pw.FlexColumnWidth(1.8),
                4: pw.FlexColumnWidth(1.6),
                5: pw.FlexColumnWidth(1.6),
                6: pw.FlexColumnWidth(1.6),
                7: pw.FlexColumnWidth(2.0),
              },
              children: [
                pw.TableRow(
                  children: [
                    _h('TYPE'),
                    _h('INV / BILL NO'),
                    _h('PARTY NAME'),
                    _h('TAXABLE', right: true),
                    _h('CGST', right: true),
                    _h('SGST', right: true),
                    _h('IGST', right: true),
                    _h('TOTAL', right: true),
                  ],
                ),
                for (final record in rows) _auditPdfRow(record),
                pw.TableRow(
                  children: [
                    _c('TOTAL', bold: true),
                    _c(''),
                    _c(''),
                    _cr(_money(dateTaxable), bold: true),
                    _cr(_money(dateCgst), bold: true),
                    _cr(_money(dateSgst), bold: true),
                    _cr(_money(dateIgst), bold: true),
                    _cr(_money(dateTotal), bold: true),
                  ],
                ),
              ],
            ),
          );
        }

        // ====================================================
        // AUDIT SUMMARY
        // ====================================================

        widgets.add(
          pw.SizedBox(height: 10),
        );

        widgets.add(
          pw.Text(
            'AUDIT SUMMARY',
            style: pw.TextStyle(
              fontSize: 10,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
        );

        widgets.add(
          pw.SizedBox(height: 5),
        );

        // ----------------------------------------------------
        // DOCUMENT TOTALS
        // ----------------------------------------------------

        widgets.add(
          pw.Table(
            border: pw.TableBorder.all(
              color: PdfColors.grey500,
              width: 0.6,
            ),
            columnWidths: const {
              0: pw.FlexColumnWidth(3),
              1: pw.FlexColumnWidth(2),
            },
            children: [
              pw.TableRow(
                children: [
                  _h('PURCHASE ORDER VALUE'),
                  _summaryValue(poTotal),
                ],
              ),
              pw.TableRow(
                children: [
                  _h('PURCHASE VOUCHER VALUE'),
                  _summaryValue(voucherTotal),
                ],
              ),
              pw.TableRow(
                children: [
                  _h('TOTAL RECORD VALUE'),
                  _summaryValue(
                    grandTotal,
                    bold: true,
                  ),
                ],
              ),
            ],
          ),
        );

        widgets.add(
          pw.SizedBox(height: 8),
        );

        // ----------------------------------------------------
        // TAX TOTALS
        // ----------------------------------------------------

        widgets.add(
          pw.Table(
            border: pw.TableBorder.all(
              color: PdfColors.grey500,
              width: 0.6,
            ),
            columnWidths: const {
              0: pw.FlexColumnWidth(1),
              1: pw.FlexColumnWidth(1),
              2: pw.FlexColumnWidth(1),
              3: pw.FlexColumnWidth(1),
              4: pw.FlexColumnWidth(1),
            },
            children: [
              pw.TableRow(
                children: [
                  _h('TAXABLE', right: true),
                  _h('CGST', right: true),
                  _h('SGST', right: true),
                  _h('IGST', right: true),
                  _h('TOTAL', right: true),
                ],
              ),
              pw.TableRow(
                children: [
                  _summaryValue(grandTaxable),
                  _summaryValue(grandCgst),
                  _summaryValue(grandSgst),
                  _summaryValue(grandIgst),
                  _summaryValue(
                    grandTotal,
                    bold: true,
                  ),
                ],
              ),
            ],
          ),
        );

        widgets.add(
          pw.SizedBox(height: 8),
        );

        // ----------------------------------------------------
        // ACCOUNTING NOTE
        // ----------------------------------------------------

        widgets.add(
          pw.Text(
            'Note: Purchase Orders represent procurement '
            'commitments. Purchase Vouchers represent actual '
            'purchase/accounting entries. TOTAL RECORD VALUE '
            'is an audit/document total and is not the '
            'accounting purchase CR total.',
            style: const pw.TextStyle(
              fontSize: 7,
              color: PdfColors.grey700,
            ),
          ),
        );

        return widgets;
      },
    ),
  );

  await Printing.layoutPdf(
    onLayout: (_) => doc.save(),
  );
}

// ============================================================
// AUDIT PDF ROW
// ============================================================

pw.TableRow _auditPdfRow(
  Map<String, dynamic> record,
) {
  final type = '${record['_record_type']}';

  final isPo = type == 'PURCHASE ORDER';

  final displayNo = '${record['_display_no'] ?? '-'}';

  final party = '${record['_display_party'] ?? '-'}';

  final taxable = _numValue(record['taxable_total']);

  final cgst = _numValue(record['cgst_total']);

  final sgst = _numValue(record['sgst_total']);

  final igst = _numValue(record['igst_total']);

  final total = _numValue(record['grand_total']);

  return pw.TableRow(
    children: [
      _c(
        isPo ? 'PO' : 'VOUCHER',
        bold: true,
      ),
      _c(displayNo),
      _c(party),
      _cr(_money(taxable)),
      _cr(_money(cgst)),
      _cr(_money(sgst)),
      _cr(_money(igst)),
      _cr(
        _money(total),
        bold: true,
      ),
    ],
  );
}

// ============================================================
// PURCHASE VOUCHER REPRINT
//
// No items parameter is required.
// The voucher ID is enough because the actual voucher
// and its items are fetched again by reprintPurchaseVoucher.
// ============================================================

Future<void> printPurchaseVoucherReprint(
  Map<String, dynamic> voucher,
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

// ============================================================
// PURCHASE ORDER REPRINT
// ============================================================

Future<void> printPurchaseOrderReprint(
  Map<String, dynamic> purchaseOrder,
) async {
  final id = purchaseOrder['id'];

  if (id is int) {
    await reprintPurchaseOrder(id);
    return;
  }

  if (id != null) {
    final parsed = int.tryParse('$id');

    if (parsed != null) {
      await reprintPurchaseOrder(parsed);
    }
  }
}

// ============================================================
// VENDOR / SUPPLIER LEDGER STATEMENT
//
// Accounting convention:
//
// PURCHASE  -> CREDIT
// PAYMENT   -> DEBIT
//
// Closing = Opening + Debit - Credit
// ============================================================

Future<void> printVendorLedgerStatement({
  required Map<String, dynamic> supplier,
  required List<Map<String, dynamic>> rows,
  required double openingBalance,
  required double totalDebit,
  required double totalCredit,
  required double closingBalance,
}) async {
  final supplierName =
      '${supplier['supplier_name'] ?? supplier['party_name'] ?? '-'}';

  final supplierCode =
      '${supplier['supplier_code'] ?? supplier['code'] ?? '-'}';

  final address = '${supplier['address'] ?? '-'}';

  final doc = pw.Document();

  doc.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(24),
      build: (context) {
        return [
          // --------------------------------------------------
          // HEADER
          // --------------------------------------------------

          pw.Text(
            'SUPPLIER LEDGER STATEMENT',
            style: pw.TextStyle(
              fontSize: 14,
              fontWeight: pw.FontWeight.bold,
            ),
          ),

          pw.SizedBox(height: 3),

          pw.Text(
            supplierName,
            style: pw.TextStyle(
              fontSize: 11,
              fontWeight: pw.FontWeight.bold,
            ),
          ),

          pw.SizedBox(height: 2),

          pw.Text(
            'Supplier Code: $supplierCode',
            style: const pw.TextStyle(
              fontSize: 8,
            ),
          ),

          pw.Text(
            'Address: $address',
            style: const pw.TextStyle(
              fontSize: 8,
            ),
          ),

          pw.SizedBox(height: 4),

          pw.Text(
            'Generated: '
            '${DateFormat('dd-MM-yyyy HH:mm').format(DateTime.now())}',
            style: const pw.TextStyle(
              fontSize: 8,
              color: PdfColors.grey700,
            ),
          ),

          pw.Divider(),

          // --------------------------------------------------
          // OPENING BALANCE
          // --------------------------------------------------

          pw.Container(
            padding: const pw.EdgeInsets.all(6),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text(
                  'OPENING BALANCE',
                  style: pw.TextStyle(
                    fontSize: 9,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.Text(
                  _money(openingBalance),
                  style: pw.TextStyle(
                    fontSize: 9,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),

          pw.SizedBox(height: 6),

          // --------------------------------------------------
          // LEDGER TABLE
          // --------------------------------------------------

          pw.Table(
            border: pw.TableBorder.all(
              color: PdfColors.grey400,
              width: 0.5,
            ),
            columnWidths: const {
              0: pw.FlexColumnWidth(1.3),
              1: pw.FlexColumnWidth(1.5),
              2: pw.FlexColumnWidth(1.8),
              3: pw.FlexColumnWidth(3),
              4: pw.FlexColumnWidth(1.7),
              5: pw.FlexColumnWidth(1.7),
              6: pw.FlexColumnWidth(1.8),
            },
            children: [
              pw.TableRow(
                children: [
                  _h('DATE'),
                  _h('TYPE'),
                  _h('REFERENCE'),
                  _h('NARRATION'),
                  _h('DEBIT'),
                  _h('CREDIT'),
                  _h('BALANCE'),
                ],
              ),
              for (final row in rows)
                pw.TableRow(
                  children: [
                    _c(
                      _fmtDate(
                        '${row['date']}',
                      ),
                    ),
                    _c(
                      '${row['type'] ?? '-'}',
                      bold: true,
                    ),
                    _c(
                      '${row['ref'] ?? '-'}',
                    ),
                    _c(
                      '${row['narration'] ?? '-'}',
                    ),
                    _c(
                      _money(
                        _numValue(
                          row['debit'],
                        ),
                      ),
                    ),
                    _c(
                      _money(
                        _numValue(
                          row['credit'],
                        ),
                      ),
                    ),
                    _c(
                      _money(
                        _numValue(
                          row['balance'],
                        ),
                      ),
                      bold: true,
                    ),
                  ],
                ),
            ],
          ),

          pw.SizedBox(height: 10),

          // --------------------------------------------------
          // LEDGER SUMMARY
          // --------------------------------------------------

          pw.Text(
            'LEDGER SUMMARY',
            style: pw.TextStyle(
              fontSize: 10,
              fontWeight: pw.FontWeight.bold,
            ),
          ),

          pw.SizedBox(height: 5),

          pw.Table(
            border: pw.TableBorder.all(
              color: PdfColors.grey500,
              width: 0.6,
            ),
            columnWidths: const {
              0: pw.FlexColumnWidth(3),
              1: pw.FlexColumnWidth(2),
            },
            children: [
              pw.TableRow(
                children: [
                  _h('OPENING BALANCE'),
                  _summaryValue(openingBalance),
                ],
              ),
              pw.TableRow(
                children: [
                  _h('TOTAL DEBIT / PAYMENTS'),
                  _summaryValue(totalDebit),
                ],
              ),
              pw.TableRow(
                children: [
                  _h('TOTAL CREDIT / PURCHASES'),
                  _summaryValue(totalCredit),
                ],
              ),
              pw.TableRow(
                children: [
                  _h('CLOSING BALANCE'),
                  _summaryValue(
                    closingBalance,
                    bold: true,
                  ),
                ],
              ),
            ],
          ),

          pw.SizedBox(height: 8),

          pw.Text(
            'Note: Purchase entries are shown as CREDIT and '
            'supplier payments are shown as DEBIT. Closing '
            'balance is calculated as Opening + Debit - Credit.',
            style: const pw.TextStyle(
              fontSize: 7,
              color: PdfColors.grey700,
            ),
          ),
        ];
      },
    ),
  );

  await Printing.layoutPdf(
    onLayout: (_) => doc.save(),
  );
}
