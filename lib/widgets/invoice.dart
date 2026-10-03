import 'dart:convert';
import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'ultra_logo.dart';

/// One line item on the tax invoice.
class InvoiceItem {
  final String description;
  final String hsnCode;
  final double qty;
  final double price;
  final String remarks;
  const InvoiceItem({
    required this.description,
    required this.hsnCode,
    required this.qty,
    required this.price,
    this.remarks = '',
  });
  double get amount => qty * price;
}

enum UltraBillKind {
  taxInvoice,
  deliveryChallan,
  quotation,
  creditNote,
  debitNote,
  purchaseOrder,
  purchaseVoucher,
}

enum UltraTotalsMode { standardGst, forwardingSummary, noteTaxSummary }

/// Everything needed to render the ULTRA ENGINEERING WORKS tax invoice —
/// field names match the printed sample exactly (invoiceNo, custPo, dcNo,
/// dispatch, ewbNo, consignee block, GST break-up, bank details).
class InvoiceData {
  final String invoiceNo;
  final String date;
  final String custPo;
  final String poDate;
  final String dcNo;
  final String dcDate;
  final String dispatch;
  final String ewbNo;
  final String consigneeName;
  final String consigneeAddress;
  final String gstin;
  final String mobile;
  final List<InvoiceItem> items;
  final double cgstPercent;
  final double sgstPercent;
  final double igstPercent;
  final double pAndF;
  final String amountInWords;
  final String bankName;
  final String accountNo;
  final String ifscCode;
  final String bankAddress;
  /// Top-left document title (e.g. TAX INVOICE, PURCHASE ORDER).
  final String documentTitle;
  /// Left party block heading on the printed form.
  final String partySectionTitle;
  /// One page per label; sales uses five copies, PO typically one.
  final List<String> copyLabels;
  final UltraBillKind kind;
  final List<String>? customTerms;
  final String leftSignatureLabel;
  final List<String> preambleLines;
  final String origInvNo;
  final String origInvDate;
  final String reason;
  final double roundOff;
  final String totalGrandLabel;
  final String forwardingLabel;
  final double? cgstAmountOverride;
  final double? sgstAmountOverride;
  final double? igstAmountOverride;
  final double? grandTotalOverride;

  const InvoiceData({
    required this.invoiceNo,
    required this.date,
    this.custPo = '',
    this.poDate = '',
    this.dcNo = '',
    this.dcDate = '',
    required this.dispatch,
    this.ewbNo = '',
    required this.consigneeName,
    required this.consigneeAddress,
    required this.gstin,
    this.mobile = '',
    required this.items,
    this.cgstPercent = 9,
    this.sgstPercent = 9,
    this.igstPercent = 0,
    this.pAndF = 0,
    required this.amountInWords,
    required this.bankName,
    required this.accountNo,
    required this.ifscCode,
    required this.bankAddress,
    this.documentTitle = 'TAX INVOICE',
    this.partySectionTitle = 'NAME & ADDRESS OF CONSIGNEE',
    this.copyLabels = ultraInvoiceCopyLabels,
    this.kind = UltraBillKind.taxInvoice,
    this.customTerms,
    this.leftSignatureLabel = 'Receiver signature',
    this.preambleLines = const [],
    this.origInvNo = '',
    this.origInvDate = '',
    this.reason = '',
    this.roundOff = 0,
    this.totalGrandLabel = 'G.Total',
    this.forwardingLabel = 'P & F',
    this.cgstAmountOverride,
    this.sgstAmountOverride,
    this.igstAmountOverride,
    this.grandTotalOverride,
  });

  UltraTotalsMode get totalsMode {
    switch (kind) {
      case UltraBillKind.deliveryChallan:
      case UltraBillKind.quotation:
        return UltraTotalsMode.forwardingSummary;
      case UltraBillKind.creditNote:
      case UltraBillKind.debitNote:
        return UltraTotalsMode.noteTaxSummary;
      default:
        return UltraTotalsMode.standardGst;
    }
  }

  double get subtotal => items.fold(0.0, (s, i) => s + i.amount);
  double get cgstAmt => cgstAmountOverride ?? subtotal * cgstPercent / 100;
  double get sgstAmt => sgstAmountOverride ?? subtotal * sgstPercent / 100;
  double get igstAmt => igstAmountOverride ?? subtotal * igstPercent / 100;
  double get grandTotal => grandTotalOverride ?? subtotal + cgstAmt + sgstAmt + igstAmt + pAndF + roundOff;
}

/// The five physical copies printed for every tax invoice, top-right label
/// exactly as on the paper form.
const List<String> ultraInvoiceCopyLabels = [
  'ORIGINAL FOR RECIPIENT',
  'DUPLICATE FOR TRANSPORTER',
  'TRIPLICATE FOR SUPPLIER',
  'COPY FOR ACCOUNTS',
  'EXTRA COPY',
];

const PdfColor _black = PdfColor.fromInt(0xFF000000);
final PdfColor _grey = PdfColor.fromInt(0xFF748094);

const int _minItemRows = 8;

pw.TextStyle _ts({double size = 8, pw.FontWeight weight = pw.FontWeight.normal}) =>
    pw.TextStyle(font: weight == pw.FontWeight.bold ? pw.Font.helveticaBold() : pw.Font.helvetica(), fontSize: size, color: _black);

String _money(double v) => v.toStringAsFixed(2);

/// Indian-style amount in words for printed tax invoices (matches portal PDFs).
String formatUltraAmountInWords(double amount) {
  if (amount == 0) return 'ZERO RUPEES ONLY';
  final rupees = amount.round();
  if (rupees == 0) return 'ZERO RUPEES ONLY';

  const ones = [
    '', 'ONE', 'TWO', 'THREE', 'FOUR', 'FIVE', 'SIX', 'SEVEN', 'EIGHT', 'NINE', 'TEN',
    'ELEVEN', 'TWELVE', 'THIRTEEN', 'FOURTEEN', 'FIFTEEN', 'SIXTEEN', 'SEVENTEEN', 'EIGHTEEN', 'NINETEEN',
  ];
  const tens = ['', '', 'TWENTY', 'THIRTY', 'FORTY', 'FIFTY', 'SIXTY', 'SEVENTY', 'EIGHTY', 'NINETY'];

  String under1000(int n) {
    if (n == 0) return '';
    if (n < 20) return ones[n];
    if (n < 100) {
      final t = tens[n ~/ 10];
      final r = n % 10;
      return r == 0 ? t : '$t ${ones[r]}';
    }
    final h = n ~/ 100;
    final r = n % 100;
    return r == 0 ? '${ones[h]} HUNDRED' : '${ones[h]} HUNDRED AND ${under1000(r)}';
  }

  String chunk(int n, String label) {
    if (n == 0) return '';
    return '${under1000(n)} $label'.trim();
  }

  var n = rupees;
  final parts = <String>[];
  final crore = n ~/ 10000000;
  n %= 10000000;
  final lakh = n ~/ 100000;
  n %= 100000;
  final thousand = n ~/ 1000;
  n %= 1000;
  if (crore > 0) parts.add(chunk(crore, 'CRORE'));
  if (lakh > 0) parts.add(chunk(lakh, 'LAKH'));
  if (thousand > 0) parts.add(chunk(thousand, 'THOUSAND'));
  if (n > 0) parts.add(under1000(n));
  return '${parts.join(' ').replaceAll(RegExp(r'\s+'), ' ').trim()} RUPEES ONLY';
}

/// Builds the full multi-copy PDF (one page per copy label) for [data].
Future<Uint8List> buildUltraInvoicePdf(InvoiceData data) async {
  final doc = pw.Document();
  final logoBytes = base64Decode(ultraLogoBase64);
  final logo = pw.MemoryImage(logoBytes);

  for (final copyLabel in data.copyLabels) {
    doc.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(18),
        build: (context) => _invoicePage(data, copyLabel, logo),
      ),
    );
  }
  return doc.save();
}

/// Shows the OS save/share dialog with vector PDF bytes (searchable text, full footer).
Future<void> printUltraInvoice(InvoiceData data) async {
  final bytes = await buildUltraInvoicePdf(data);
  await Printing.sharePdf(bytes: bytes, filename: '${data.invoiceNo}.pdf');
}

/// Opens the system print dialog with the vector PDF (optional physical print).
Future<void> layoutPrintUltraInvoice(InvoiceData data) async {
  final bytes = await buildUltraInvoicePdf(data);
  await Printing.layoutPdf(onLayout: (_) async => bytes);
}

/// Lets the user share / save the PDF file directly (e.g. WhatsApp, email,
/// Files app) without going through the print dialog.
Future<void> shareUltraInvoicePdf(InvoiceData data, {String? filename}) async {
  final bytes = await buildUltraInvoicePdf(data);
  await Printing.sharePdf(bytes: bytes, filename: filename ?? '${data.invoiceNo}.pdf');
}

pw.Widget _invoicePage(InvoiceData d, String copyLabel, pw.MemoryImage logo) {
  final border = pw.BoxDecoration(border: pw.Border.all(color: _black, width: 1));
  final fillerRows = (_minItemRows - d.items.length).clamp(0, 24);
  return pw.Container(
    decoration: border,
    child: pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.stretch,
      children: [
        _topBar(d.documentTitle, copyLabel),
        _companyHeader(logo),
        _consigneeAndMeta(d),
        pw.Expanded(child: _itemsTable(d, fillerRows: fillerRows)),
        _totalsAndBank(d),
        _termsAndSignature(d),
      ],
    ),
  );
}

pw.Widget _cell({required pw.Widget child, bool right = false, bool bottom = false, pw.EdgeInsets? padding}) {
  return pw.Container(
    padding: padding ?? const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 4),
    decoration: pw.BoxDecoration(
      border: pw.Border(
        right: right ? const pw.BorderSide(color: _black, width: 1) : pw.BorderSide.none,
        bottom: bottom ? const pw.BorderSide(color: _black, width: 1) : pw.BorderSide.none,
      ),
    ),
    child: child,
  );
}

pw.Widget _topBar(String documentTitle, String copyLabel) {
  return pw.Container(
    decoration: const pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(color: _black, width: 1))),
    child: pw.Row(
      children: [
        pw.Expanded(child: _cell(right: true, child: pw.Text(documentTitle, style: _ts(size: 11, weight: pw.FontWeight.bold)))),
        pw.Expanded(
          child: _cell(
            child: pw.Align(alignment: pw.Alignment.centerRight, child: pw.Text(copyLabel, style: _ts(size: 11, weight: pw.FontWeight.bold))),
          ),
        ),
      ],
    ),
  );
}

pw.Widget _companyHeader(pw.MemoryImage logo) {
  return pw.Container(
    decoration: const pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(color: _black, width: 1))),
    padding: const pw.EdgeInsets.all(8),
    child: pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.center,
      children: [
        pw.Container(width: 62, height: 50, child: pw.Image(logo, fit: pw.BoxFit.contain)),
        pw.SizedBox(width: 12),
        pw.Expanded(
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.center,
            children: [
              pw.Text('ULTRA ENGINEERING WORKS', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 20)),
              pw.SizedBox(height: 2),
              pw.Text('SPM MANUFACTURERS & FABRICATORS', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9)),
              pw.SizedBox(height: 2),
              pw.Text('OFFICE:NO: 15/6, 5th CROSS, VIDYA NAGAR, OPP. S.K.F. FACTORY, BOMMASANDRA INDL. AREA, BENGALURU-560 099.',
                  style: const pw.TextStyle(fontSize: 7), textAlign: pw.TextAlign.center),
              pw.Text('Tele Fax: 080-27834287, Mob: 9342509313 Email: ueworks@gmail.com',
                  style: const pw.TextStyle(fontSize: 7), textAlign: pw.TextAlign.center),
              pw.Text('Works: No.B-48, KSSIDC INDL Estate, Near Karnataka Bank, Bommasandra Indl. Area, BENGALURU-560 099.',
                  style: const pw.TextStyle(fontSize: 7), textAlign: pw.TextAlign.center),
            ],
          ),
        ),
      ],
    ),
  );
}

pw.Widget _metaField(String label, String value) => pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 3),
      child: pw.Text(label, style: _ts(size: 7.5)),
    );
pw.Widget _metaValue(String value, {bool bold = false}) => pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 3),
      child: pw.Text(value, style: _ts(size: 8.5, weight: bold ? pw.FontWeight.bold : pw.FontWeight.normal)),
    );

pw.Widget _consigneeAndMeta(InvoiceData d) {
  final metaBorder = pw.TableBorder.all(color: _black, width: 1);

  List<pw.TableRow> metaRowsTop;
  List<pw.TableRow> metaRowsBottom;

  switch (d.kind) {
    case UltraBillKind.deliveryChallan:
      metaRowsTop = [
        pw.TableRow(children: [
          _metaField('Challan / DC No', ''),
          _metaValue(d.invoiceNo, bold: true),
          _metaField('DATE', ''),
          _metaValue(d.date, bold: true),
        ]),
        pw.TableRow(children: [
          _metaField('Cust.P.O NO :', ''),
          _metaValue(d.custPo),
          _metaField('PO DATE', ''),
          _metaValue(d.poDate, bold: true),
        ]),
      ];
      metaRowsBottom = [
        pw.TableRow(children: [_metaField('REF. NO :', ''), _metaValue(d.dcNo)]),
        pw.TableRow(children: [_metaField('REF. DATE', ''), _metaValue(d.dcDate, bold: true)]),
        pw.TableRow(children: [_metaField('DISPATCH :', ''), _metaValue(d.dispatch, bold: true)]),
        pw.TableRow(children: [_metaField('EWB NO:', ''), _metaValue(d.ewbNo)]),
      ];
      break;
    case UltraBillKind.quotation:
      metaRowsTop = [
        pw.TableRow(children: [
          _metaField('QT NO :', ''),
          _metaValue(d.invoiceNo, bold: true),
          _metaField('DATE :', ''),
          _metaValue(d.date, bold: true),
        ]),
        pw.TableRow(children: [
          _metaField('REF NO :', ''),
          _metaValue(d.custPo),
          _metaField('REF DATE :', ''),
          _metaValue(d.poDate, bold: true),
        ]),
      ];
      metaRowsBottom = [
        pw.TableRow(children: [_metaField('KIND ATTN :', ''), _metaValue(d.dispatch, bold: true)]),
        pw.TableRow(children: [_metaField('VALIDITY :', ''), _metaValue(d.ewbNo, bold: true)]),
      ];
      break;
    case UltraBillKind.purchaseOrder:
      metaRowsTop = [
        pw.TableRow(children: [
          _metaField('P.O NO :', ''),
          _metaValue(d.invoiceNo, bold: true),
          _metaField('P.O DATE :', ''),
          _metaValue(d.date, bold: true),
        ]),
        pw.TableRow(children: [
          _metaField('Supplier Ref :', ''),
          _metaValue(d.custPo),
          _metaField('Del. Due :', ''),
          _metaValue(d.poDate, bold: true),
        ]),
        pw.TableRow(children: [
          _metaField('Tot.Pkgs :', ''),
          _metaValue(d.dcNo),
          _metaField('Delivery :', ''),
          _metaValue(d.dispatch, bold: true),
        ]),
      ];
      metaRowsBottom = [
        pw.TableRow(children: [_metaField('REMARKS :', ''), _metaValue(d.ewbNo)]),
      ];
      break;
    case UltraBillKind.purchaseVoucher:
      metaRowsTop = [
        pw.TableRow(children: [
          _metaField('Voucher No :', ''),
          _metaValue(d.invoiceNo, bold: true),
          _metaField('DATE :', ''),
          _metaValue(d.date, bold: true),
        ]),
        pw.TableRow(children: [
          _metaField('Supp.Inv No :', ''),
          _metaValue(d.custPo),
          _metaField('Inv.Date :', ''),
          _metaValue(d.poDate, bold: true),
        ]),
        pw.TableRow(children: [
          _metaField('Against P.O :', ''),
          _metaValue(d.dcNo),
          _metaField('P.O DATE', ''),
          _metaValue(d.dcDate, bold: true),
        ]),
      ];
      metaRowsBottom = [
        pw.TableRow(children: [_metaField('DISPATCH :', ''), _metaValue(d.dispatch, bold: true)]),
        pw.TableRow(children: [_metaField('EWB NO:', ''), _metaValue(d.ewbNo)]),
      ];
      break;
    case UltraBillKind.creditNote:
    case UltraBillKind.debitNote:
      final noteLabel = d.kind == UltraBillKind.creditNote ? 'Credit Note No' : 'Debit Note No';
      metaRowsTop = [
        pw.TableRow(children: [
          _metaField(noteLabel, ''),
          _metaValue(d.invoiceNo, bold: true),
          _metaField('DATE', ''),
          _metaValue(d.date, bold: true),
        ]),
        pw.TableRow(children: [
          _metaField('Orig. Inv No :', ''),
          _metaValue(d.origInvNo),
          _metaField('DATE', ''),
          _metaValue(d.origInvDate, bold: true),
        ]),
      ];
      metaRowsBottom = [
        pw.TableRow(children: [_metaField('REASON :', ''), _metaValue(d.reason, bold: true)]),
        pw.TableRow(children: [_metaField('DISPATCH :', ''), _metaValue(d.dispatch, bold: true)]),
        pw.TableRow(children: [_metaField('EWB NO:', ''), _metaValue(d.ewbNo)]),
      ];
      break;
    default:
      metaRowsTop = [
        pw.TableRow(children: [
          _metaField('Invoice No', ''),
          _metaValue(d.invoiceNo, bold: true),
          _metaField('DATE', ''),
          _metaValue(d.date, bold: true),
        ]),
        pw.TableRow(children: [
          _metaField('Cust.P.O :', ''),
          _metaValue(d.custPo),
          _metaField('P.O DATE', ''),
          _metaValue(d.poDate, bold: true),
        ]),
        pw.TableRow(children: [
          _metaField('D.C.NO :', ''),
          _metaValue(d.dcNo),
          _metaField('D.C DATE', ''),
          _metaValue(d.dcDate, bold: true),
        ]),
      ];
      metaRowsBottom = [
        pw.TableRow(children: [_metaField('DISPATCH :', ''), _metaValue(d.dispatch, bold: true)]),
        pw.TableRow(children: [_metaField('EWB NO:', ''), _metaValue(d.ewbNo)]),
      ];
  }

  final partyBlock = pw.Column(
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    children: [
      pw.Text(d.partySectionTitle, style: _ts(size: 7.5, weight: pw.FontWeight.bold)),
      pw.SizedBox(height: 4),
      ...d.preambleLines.map((l) => pw.Padding(
            padding: const pw.EdgeInsets.only(bottom: 2),
            child: pw.Text(l, style: _ts(size: 8)),
          )),
      pw.Text(d.consigneeName, style: _ts(size: 9.5, weight: pw.FontWeight.bold)),
      pw.Text(d.consigneeAddress, style: _ts(size: 8)),
    ],
  );

  return pw.Container(
    height: d.preambleLines.isEmpty ? 100 : 118,
    decoration: const pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(color: _black, width: 1))),
    child: pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.stretch,
      children: [
        pw.Expanded(
          flex: 3,
          child: pw.Container(
            decoration: const pw.BoxDecoration(border: pw.Border(right: pw.BorderSide(color: _black, width: 1))),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Padding(padding: const pw.EdgeInsets.all(6), child: partyBlock),
                pw.Spacer(),
                pw.Container(
                  decoration: const pw.BoxDecoration(border: pw.Border(top: pw.BorderSide(color: _black, width: 1))),
                  padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                  child: pw.Row(
                    children: [
                      pw.Expanded(child: pw.Text('GSTIN: ${d.gstin}', style: _ts(size: 8, weight: pw.FontWeight.bold))),
                      pw.Text('MOBILE: ${d.mobile.isEmpty ? '' : d.mobile}', style: _ts(size: 8)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        pw.Expanded(
          flex: 2,
          child: pw.Column(
            children: [
              pw.Table(
                border: metaBorder,
                columnWidths: const {
                  0: pw.FlexColumnWidth(1.7),
                  1: pw.FlexColumnWidth(2.1),
                  2: pw.FlexColumnWidth(1.1),
                  3: pw.FlexColumnWidth(1.5),
                },
                children: metaRowsTop,
              ),
              pw.Table(
                border: pw.TableBorder(
                  left: const pw.BorderSide(color: _black, width: 1),
                  right: const pw.BorderSide(color: _black, width: 1),
                  bottom: const pw.BorderSide(color: _black, width: 1),
                  horizontalInside: const pw.BorderSide(color: _black, width: 1),
                ),
                columnWidths: const {0: pw.FlexColumnWidth(1.7), 1: pw.FlexColumnWidth(4.7)},
                children: metaRowsBottom,
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

pw.Widget _itemsTable(InvoiceData d, {required int fillerRows}) {
  const border = pw.TableBorder(
    left: pw.BorderSide(color: _black, width: 1),
    right: pw.BorderSide(color: _black, width: 1),
    top: pw.BorderSide(color: _black, width: 1),
    bottom: pw.BorderSide(color: _black, width: 1),
    horizontalInside: pw.BorderSide(color: _black, width: 1),
    verticalInside: pw.BorderSide(color: _black, width: 1),
  );

  pw.Widget cell(String text, {pw.TextAlign align = pw.TextAlign.left, double vPad = 5}) => pw.Padding(
        padding: pw.EdgeInsets.symmetric(horizontal: 4, vertical: vPad),
        child: pw.Text(text, style: _ts(size: 8.5), textAlign: align),
      );

  pw.TableRow emptyRow(int cols) => pw.TableRow(
        children: List.generate(cols, (_) => pw.SizedBox(height: 18)),
      );

  if (d.kind == UltraBillKind.quotation) {
    pw.TableRow headerRow() => pw.TableRow(
          children: [
            cell('SL', align: pw.TextAlign.center),
            cell('ITEM SPECIFICATION PARTICULARS'),
            cell('QTY', align: pw.TextAlign.center),
            cell('RATE', align: pw.TextAlign.right),
            cell('NET TOTAL', align: pw.TextAlign.right),
          ],
        );
    pw.TableRow itemRow(int index) {
      final it = d.items[index];
      return pw.TableRow(
        children: [
          cell('${index + 1}', align: pw.TextAlign.center),
          cell(it.description),
          cell(it.qty.toStringAsFixed(2), align: pw.TextAlign.center),
          cell(_money(it.price), align: pw.TextAlign.right),
          cell(_money(it.amount), align: pw.TextAlign.right),
        ],
      );
    }
    return pw.Table(
      border: border,
      columnWidths: const {
        0: pw.FixedColumnWidth(24),
        1: pw.FlexColumnWidth(3.4),
        2: pw.FixedColumnWidth(42),
        3: pw.FixedColumnWidth(48),
        4: pw.FixedColumnWidth(52),
      },
      defaultVerticalAlignment: pw.TableCellVerticalAlignment.middle,
      children: [
        headerRow(),
        ...List.generate(d.items.length, itemRow),
        ...List.generate(fillerRows, (_) => emptyRow(5)),
      ],
    );
  }

  final priceHeader = d.kind == UltraBillKind.deliveryChallan || d.kind == UltraBillKind.creditNote || d.kind == UltraBillKind.debitNote
      ? 'PRICE/QTY'
      : 'PRICE';
  final withRemarks = d.kind == UltraBillKind.deliveryChallan;
  final colCount = withRemarks ? 7 : 6;

  pw.TableRow headerRow() => pw.TableRow(
        children: [
          cell('SL', align: pw.TextAlign.center),
          cell('DESCRIPTION'),
          cell('HSN CODE', align: pw.TextAlign.center),
          cell('QTY', align: pw.TextAlign.center),
          cell(priceHeader, align: pw.TextAlign.right),
          cell('AMOUNT', align: pw.TextAlign.right),
          if (withRemarks) cell('REMARKS'),
        ],
      );

  pw.TableRow itemRow(int index) {
    final it = d.items[index];
    return pw.TableRow(
      children: [
        cell('${index + 1}', align: pw.TextAlign.center),
        cell(it.description),
        cell(it.hsnCode, align: pw.TextAlign.center),
        cell(it.qty.toStringAsFixed(2), align: pw.TextAlign.center),
        cell(_money(it.price), align: pw.TextAlign.right),
        cell(_money(it.amount), align: pw.TextAlign.right),
        if (withRemarks) cell(it.remarks),
      ],
    );
  }

  final widths = withRemarks
      ? const {
          0: pw.FixedColumnWidth(22),
          1: pw.FlexColumnWidth(2.6),
          2: pw.FixedColumnWidth(52),
          3: pw.FixedColumnWidth(38),
          4: pw.FixedColumnWidth(44),
          5: pw.FixedColumnWidth(48),
          6: pw.FixedColumnWidth(52),
        }
      : const {
          0: pw.FixedColumnWidth(24),
          1: pw.FlexColumnWidth(3.2),
          2: pw.FixedColumnWidth(58),
          3: pw.FixedColumnWidth(42),
          4: pw.FixedColumnWidth(48),
          5: pw.FixedColumnWidth(52),
        };

  return pw.Table(
    border: border,
    columnWidths: widths,
    defaultVerticalAlignment: pw.TableCellVerticalAlignment.middle,
    children: [
      headerRow(),
      ...List.generate(d.items.length, itemRow),
      ...List.generate(fillerRows, (_) => emptyRow(colCount)),
    ],
  );
}

pw.TableRow _totalsRow(String label, String value, {bool bold = false}) => pw.TableRow(
  children: [
    pw.Padding(padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 4), child: pw.Text(label, style: _ts(size: 8.5, weight: bold ? pw.FontWeight.bold : pw.FontWeight.normal))),
    pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      child: pw.Align(alignment: pw.Alignment.centerRight, child: pw.Text(value, style: _ts(size: 8.5, weight: bold ? pw.FontWeight.bold : pw.FontWeight.normal))),
    ),
  ],
);

pw.Widget _totalsAndBank(InvoiceData d) {
  List<pw.TableRow> totalRows;
  switch (d.totalsMode) {
    case UltraTotalsMode.forwardingSummary:
      totalRows = [
        _totalsRow('Subtotal', _money(d.subtotal)),
        _totalsRow(d.forwardingLabel, _money(d.pAndF)),
        _totalsRow(d.totalGrandLabel, _money(d.grandTotal), bold: true),
      ];
      break;
    case UltraTotalsMode.noteTaxSummary:
      totalRows = [
        _totalsRow('Subtotal', _money(d.subtotal)),
        _totalsRow('CGST', _money(d.cgstAmt)),
        _totalsRow('SGST', _money(d.sgstAmt)),
        _totalsRow('Round Off', _money(d.roundOff)),
        _totalsRow(d.totalGrandLabel, _money(d.grandTotal), bold: true),
      ];
      break;
    case UltraTotalsMode.standardGst:
      totalRows = [
        _totalsRow('Total', _money(d.subtotal)),
        _totalsRow('CGST : ${d.cgstPercent.toStringAsFixed(2)} %', _money(d.cgstAmt)),
        _totalsRow('SGST : ${d.sgstPercent.toStringAsFixed(2)} %', _money(d.sgstAmt)),
        _totalsRow('IGST : ${d.igstPercent.toStringAsFixed(2)} %', _money(d.igstAmt)),
        _totalsRow(d.forwardingLabel, _money(d.pAndF)),
        _totalsRow(d.totalGrandLabel, _money(d.grandTotal), bold: true),
      ];
  }

  return pw.Container(
    decoration: const pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(color: _black, width: 1))),
    child: pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.stretch,
      children: [
        pw.Expanded(
          flex: 3,
          child: pw.Container(
            decoration: const pw.BoxDecoration(border: pw.Border(right: pw.BorderSide(color: _black, width: 1))),
            padding: const pw.EdgeInsets.all(6),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text('VALUE IN WORDS:', style: _ts(size: 8, weight: pw.FontWeight.bold)),
                pw.Text(d.amountInWords, style: _ts(size: 9, weight: pw.FontWeight.bold)),
                pw.SizedBox(height: 10),
                pw.Text('BANK: ${d.bankName} | A/C: ${d.accountNo}', style: _ts(size: 8)),
                pw.Text('IFS CODE: ${d.ifscCode} | ADDRESS: ${d.bankAddress}', style: _ts(size: 8)),
              ],
            ),
          ),
        ),
        pw.Expanded(
          flex: 2,
          child: pw.Table(
            border: pw.TableBorder.all(color: _black, width: 1),
            columnWidths: const {0: pw.FlexColumnWidth(2), 1: pw.FlexColumnWidth(1.6)},
            children: totalRows,
          ),
        ),
      ],
    ),
  );
}

pw.Widget _termsAndSignature(InvoiceData d) {
  const defaultTerms = [
    '1. Good once sold will not be taken back or exchange',
    '2. Interest @24% will be charged if not paid within due period.',
    '3. All Disputes Subject to Bangalore Jurisdiction Only.',
    '4. All Payment Should Be Made By A/c Payee Cheque/D.D Only',
    '5. Our Risk/Responsibility Ceases Once Goods Leave Our Premises',
  ];
  final terms = d.customTerms ?? defaultTerms;
  return pw.Row(
    crossAxisAlignment: pw.CrossAxisAlignment.stretch,
    children: [
      pw.Expanded(
        flex: 3,
        child: pw.Container(
          decoration: const pw.BoxDecoration(border: pw.Border(right: pw.BorderSide(color: _black, width: 1))),
          padding: const pw.EdgeInsets.all(6),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text('TERMS & CONDITIONS:', style: _ts(size: 8, weight: pw.FontWeight.bold)),
              ...terms.map((t) => pw.Text(t, style: _ts(size: 7))),
              pw.SizedBox(height: 12),
              pw.Text(d.leftSignatureLabel, style: _ts(size: 8)),
            ],
          ),
        ),
      ),
      pw.Expanded(
        flex: 2,
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.stretch,
          children: [
            pw.Container(
              decoration: const pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(color: _black, width: 1))),
              padding: const pw.EdgeInsets.all(6),
              child: pw.Text('For ULTRA ENGINEERING WORKS', style: _ts(size: 8.5, weight: pw.FontWeight.bold)),
            ),
            pw.Container(
              padding: const pw.EdgeInsets.all(6),
              height: 48,
              alignment: pw.Alignment.bottomLeft,
              child: pw.Text('Authorised Signatory', style: _ts(size: 8.5, weight: pw.FontWeight.bold)),
            ),
          ],
        ),
      ),
    ],
  );
}
