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
  const InvoiceItem({required this.description, required this.hsnCode, required this.qty, required this.price});
  double get amount => qty * price;
}

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
  });

  double get subtotal => items.fold(0.0, (s, i) => s + i.amount);
  double get cgstAmt => subtotal * cgstPercent / 100;
  double get sgstAmt => subtotal * sgstPercent / 100;
  double get igstAmt => subtotal * igstPercent / 100;
  double get grandTotal => subtotal + cgstAmt + sgstAmt + igstAmt + pAndF;
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

String _money(double v) => v.toStringAsFixed(2);

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

/// Shows the OS print / save-as-PDF dialog for the full 5-copy document.
Future<void> printUltraInvoice(InvoiceData data) async {
  await Printing.layoutPdf(onLayout: (format) => buildUltraInvoicePdf(data));
}

/// Lets the user share / save the PDF file directly (e.g. WhatsApp, email,
/// Files app) without going through the print dialog.
Future<void> shareUltraInvoicePdf(InvoiceData data, {String? filename}) async {
  final bytes = await buildUltraInvoicePdf(data);
  await Printing.sharePdf(bytes: bytes, filename: filename ?? '${data.invoiceNo}.pdf');
}

pw.Widget _invoicePage(InvoiceData d, String copyLabel, pw.MemoryImage logo) {
  final border = pw.BoxDecoration(border: pw.Border.all(color: _black, width: 1));
  return pw.Container(
    decoration: border,
    child: pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.stretch,
      children: [
        _topBar(d.documentTitle, copyLabel),
        _companyHeader(logo),
        _consigneeAndMeta(d),
        _itemsTable(d),
        _totalsAndBank(d),
        _termsAndSignature(),
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
        pw.Expanded(child: _cell(right: true, child: pw.Text(documentTitle, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 11)))),
        pw.Expanded(
          child: _cell(
            child: pw.Align(alignment: pw.Alignment.centerRight, child: pw.Text(copyLabel, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 11))),
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
  child: pw.Text(label, style: const pw.TextStyle(fontSize: 7.5)),
);
pw.Widget _metaValue(String value, {bool bold = false}) => pw.Padding(
  padding: const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 3),
  child: pw.Text(value, style: pw.TextStyle(fontSize: 8.5, fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal)),
);

pw.Widget _consigneeAndMeta(InvoiceData d) {
  final metaBorder = pw.TableBorder.all(color: _black, width: 1);
  return pw.Container(
    height: 100,
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
                pw.Padding(
                  padding: const pw.EdgeInsets.all(6),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(d.partySectionTitle, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 7.5)),
                      pw.SizedBox(height: 4),
                      pw.Text(d.consigneeName, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9.5)),
                      pw.Text(d.consigneeAddress, style: const pw.TextStyle(fontSize: 8)),
                    ],
                  ),
                ),
                pw.Spacer(),
                pw.Container(
                  decoration: const pw.BoxDecoration(border: pw.Border(top: pw.BorderSide(color: _black, width: 1))),
                  padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                  child: pw.Row(
                    children: [
                      pw.Expanded(child: pw.Text('GSTIN: ${d.gstin}', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8))),
                      pw.Text('MOBILE: ${d.mobile}', style: const pw.TextStyle(fontSize: 8)),
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
                columnWidths: const {0: pw.FlexColumnWidth(1.7), 1: pw.FlexColumnWidth(2.1), 2: pw.FlexColumnWidth(1.1), 3: pw.FlexColumnWidth(1.5)},
                children: [
                  pw.TableRow(children: [_metaField('Invoice No', ''), _metaValue(d.invoiceNo, bold: true), _metaField('DATE', ''), _metaValue(d.date, bold: true)]),
                  pw.TableRow(children: [_metaField('Cust.P.O :', ''), _metaValue(d.custPo), _metaField('P.O DATE', ''), _metaValue(d.poDate, bold: true)]),
                  pw.TableRow(children: [_metaField('D.C.NO :', ''), _metaValue(d.dcNo), _metaField('D.C DATE', ''), _metaValue(d.dcDate, bold: true)]),
                ],
              ),
              pw.Table(
                border: pw.TableBorder(
                  left: const pw.BorderSide(color: _black, width: 1),
                  right: const pw.BorderSide(color: _black, width: 1),
                  bottom: const pw.BorderSide(color: _black, width: 1),
                  horizontalInside: const pw.BorderSide(color: _black, width: 1),
                ),
                columnWidths: const {0: pw.FlexColumnWidth(1.7), 1: pw.FlexColumnWidth(4.7)},
                children: [
                  pw.TableRow(children: [_metaField('DISPATCH :', ''), _metaValue(d.dispatch, bold: true)]),
                  pw.TableRow(children: [_metaField('EWB NO:', ''), _metaValue(d.ewbNo)]),
                ],
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class _Col {
  final String header;
  final double width;
  final pw.TextAlign align;
  const _Col(this.header, this.width, [this.align = pw.TextAlign.left]);
}

pw.Widget _itemsTable(InvoiceData d) {
  const cols = [
    _Col('SL', 22, pw.TextAlign.center),
    _Col('DESCRIPTION', 210),
    _Col('HSN CODE', 60, pw.TextAlign.center),
    _Col('QTY', 45, pw.TextAlign.center),
    _Col('PRICE', 55, pw.TextAlign.right),
    _Col('AMOUNT', 65, pw.TextAlign.right),
  ];
  List<String> rowValues(int i) {
    final it = d.items[i];
    return [
      '${i + 1}',
      it.description,
      it.hsnCode,
      it.qty.toStringAsFixed(2),
      _money(it.price),
      _money(it.amount),
    ];
  }

  pw.Widget columnBox(_Col col, int colIndex, {required bool isLast}) {
    return pw.Container(
      width: col.width,
      decoration: pw.BoxDecoration(border: pw.Border(right: isLast ? pw.BorderSide.none : const pw.BorderSide(color: _black, width: 1))),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.stretch,
        children: [
          pw.Container(
            decoration: const pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(color: _black, width: 1))),
            padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 5),
            child: pw.Text(col.header, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8), textAlign: col.align),
          ),
          pw.Padding(
            padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 4),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.stretch,
              children: List.generate(
                d.items.length,
                    (i) => pw.Padding(
                  padding: const pw.EdgeInsets.only(bottom: 3),
                  child: pw.Text(rowValues(i)[colIndex], style: const pw.TextStyle(fontSize: 8.5), textAlign: col.align),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  return pw.Container(
    height: 430,
    decoration: const pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(color: _black, width: 1))),
    child: pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.stretch,
      children: List.generate(cols.length, (i) => columnBox(cols[i], i, isLast: i == cols.length - 1)),
    ),
  );
}

pw.Widget _totalsRow(String label, String value, {bool bold = false}) => pw.TableRow(
  children: [
    pw.Padding(padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 4), child: pw.Text(label, style: pw.TextStyle(fontSize: 8.5, fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal))),
    pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      child: pw.Align(alignment: pw.Alignment.centerRight, child: pw.Text(value, style: pw.TextStyle(fontSize: 8.5, fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal))),
    ),
  ],
);

pw.Widget _totalsAndBank(InvoiceData d) {
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
                pw.Text('RUPEES IN WORDS:', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8)),
                pw.Text(d.amountInWords, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9)),
                pw.SizedBox(height: 10),
                pw.Text('BANK: ${d.bankName} | A/C: ${d.accountNo}', style: const pw.TextStyle(fontSize: 8)),
                pw.Text('IFS CODE: ${d.ifscCode} | ADDRESS: ${d.bankAddress}', style: const pw.TextStyle(fontSize: 8)),
              ],
            ),
          ),
        ),
        pw.Expanded(
          flex: 2,
          child: pw.Table(
            border: pw.TableBorder.all(color: _black, width: 1),
            columnWidths: const {0: pw.FlexColumnWidth(2), 1: pw.FlexColumnWidth(1.6)},
            children: [
              _totalsRow('Total', _money(d.subtotal)),
              _totalsRow('CGST : ${d.cgstPercent.toStringAsFixed(2)} %', _money(d.cgstAmt)),
              _totalsRow('SGST : ${d.sgstPercent.toStringAsFixed(2)} %', _money(d.sgstAmt)),
              _totalsRow('IGST : ${d.igstPercent.toStringAsFixed(2)} %', _money(d.igstAmt)),
              _totalsRow('P & F', _money(d.pAndF)),
              _totalsRow('G.Total', _money(d.grandTotal), bold: true),
            ],
          ),
        ),
      ],
    ),
  );
}

pw.Widget _termsAndSignature() {
  const terms = [
    '1. Good once sold will not be taken back or exchange',
    '2. Interest @24% will be charged if not paid within due period.',
    '3. All Disputes Subject to Bangalore Jurisdiction Only.',
    '4. All Payment Should Be Made By A/c Payee Cheque/D.D Only',
    '5. Our Risk/Responsibility Ceases Once Goods Leave Our Premises',
  ];
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
              pw.Text('TERMS & CONDITIONS:', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8)),
              ...terms.map((t) => pw.Text(t, style: const pw.TextStyle(fontSize: 7))),
              pw.SizedBox(height: 16),
              pw.Text('Receiver signature', style: const pw.TextStyle(fontSize: 8)),
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
              child: pw.Text('For ULTRA ENGINEERING WORKS', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8.5)),
            ),
            pw.Container(
              padding: const pw.EdgeInsets.all(6),
              height: 40,
              alignment: pw.Alignment.bottomLeft,
              child: pw.Text('Authorised Signatory', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8.5)),
            ),
          ],
        ),
      ),
    ],
  );
}
