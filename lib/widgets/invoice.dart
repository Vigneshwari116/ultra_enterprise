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
  final String shippingName;
  final String shippingAddress;
  final String serviceTaxNo;
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

  /// When false, totals block shows amount in words only (quotation layout).
  final bool showBankInTotals;

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
    this.shippingName = '',
    this.shippingAddress = '',
    this.serviceTaxNo = '',
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
    this.showBankInTotals = true,
  });

  double get subtotal => items.fold(0.0, (s, i) => s + i.amount);
  double get cgstAmt => cgstAmountOverride ?? subtotal * cgstPercent / 100;
  double get sgstAmt => sgstAmountOverride ?? subtotal * sgstPercent / 100;
  double get igstAmt => igstAmountOverride ?? subtotal * igstPercent / 100;
  double get grandTotal =>
      grandTotalOverride ??
      subtotal + cgstAmt + sgstAmt + igstAmt + pAndF + roundOff;
}

/// Tax invoice copy labels (top-right), matching the paper form (5 copies).
const List<String> ultraInvoiceCopyLabels = [
  'ORIGINAL FOR RECIPIENT',
  'DUPLICATE FOR TRANSPORTER',
  'TRIPLICATE FOR SUPPLIER',
  'COPY FOR ACCOUNTS',
  'EXTRA COPY',
];

/// Purchase order prints as original + duplicate reprint (accounting layout).
const List<String> ultraPurchaseOrderCopyLabels = [
  'ORIGINAL PURCHASE ORDER',
  'DUPLICATE PURCHASE ORDER REPRINT',
];

/// Standard original + duplicate labels derived from the document title.
List<String> ultraOriginalDuplicateLabels(
  String documentTitle, {
  String? duplicateLabel,
}) {
  final title = documentTitle.trim().toUpperCase();
  return [
    'ORIGINAL $title',
    duplicateLabel ?? 'DUPLICATE $title REPRINT',
  ];
}

const PdfColor _black = PdfColor.fromInt(0xFF000000);
final PdfColor _grey = PdfColor.fromInt(0xFF748094);

const double _pageMarginH = 8;
const double _pageMarginV = 6;

class _ItemsGridColumn {
  final String header;
  final double? width;
  final int flex;
  final pw.TextAlign align;
  const _ItemsGridColumn({
    required this.header,
    this.width,
    this.flex = 1,
    this.align = pw.TextAlign.left,
  });
}

/// Shared terms & conditions footer used on all ULTRA document PDFs.
const List<String> _ultraDocumentTerms = [
  '1. Goods once sold will not be taken back or exchanged.',
  '2. Interest @24% will be charged if not paid within due period.',
  '3. All Disputes Subject to Bangalore Jurisdiction Only.',
  '4. All Payment Should Be Made By A/c Payee Cheque/D.D Only',
  '5. Our Risk/Responsibility Ceases Once Goods Leave Our Premises.',
];

pw.TextStyle _ts(
        {double size = 8, pw.FontWeight weight = pw.FontWeight.normal}) =>
    pw.TextStyle(
        font: weight == pw.FontWeight.bold
            ? pw.Font.helveticaBold()
            : pw.Font.helvetica(),
        fontSize: size,
        color: _black);

String _money(double v) => v.toStringAsFixed(2);

/// Indian-style amount in words for printed tax invoices (matches portal PDFs).
String formatUltraAmountInWords(double amount) {
  if (amount == 0) return 'ZERO RUPEES ONLY';
  final rupees = amount.round();
  if (rupees == 0) return 'ZERO RUPEES ONLY';

  const ones = [
    '',
    'ONE',
    'TWO',
    'THREE',
    'FOUR',
    'FIVE',
    'SIX',
    'SEVEN',
    'EIGHT',
    'NINE',
    'TEN',
    'ELEVEN',
    'TWELVE',
    'THIRTEEN',
    'FOURTEEN',
    'FIFTEEN',
    'SIXTEEN',
    'SEVENTEEN',
    'EIGHTEEN',
    'NINETEEN',
  ];
  const tens = [
    '',
    '',
    'TWENTY',
    'THIRTY',
    'FORTY',
    'FIFTY',
    'SIXTY',
    'SEVENTY',
    'EIGHTY',
    'NINETY'
  ];

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
    return r == 0
        ? '${ones[h]} HUNDRED'
        : '${ones[h]} HUNDRED AND ${under1000(r)}';
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
        margin: const pw.EdgeInsets.symmetric(
            horizontal: _pageMarginH, vertical: _pageMarginV),
        build: (context) {
          final pageHeight = context.page.pageFormat.availableHeight;
          return pw.SizedBox(
            height: pageHeight,
            child: _documentPage(data, copyLabel, logo),
          );
        },
      ),
    );
  }
  return doc.save();
}

/// Shows the OS save/share dialog with vector PDF bytes (searchable text, full footer).
String ultraInvoicePdfFilename(InvoiceData data) {
  final no = data.invoiceNo.trim();
  if (no.isNotEmpty) return '$no.pdf';
  final slug = data.documentTitle
      .trim()
      .toUpperCase()
      .replaceAll(RegExp(r'[^A-Z0-9]+'), '_')
      .replaceAll(RegExp(r'_+'), '_')
      .replaceAll(RegExp(r'^_|_$'), '');
  return slug.isEmpty ? 'DOCUMENT.pdf' : '$slug.pdf';
}

Future<void> printUltraInvoice(InvoiceData data) async {
  final bytes = await buildUltraInvoicePdf(data);
  await Printing.sharePdf(
      bytes: bytes, filename: ultraInvoicePdfFilename(data));
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
  await Printing.sharePdf(
      bytes: bytes, filename: filename ?? ultraInvoicePdfFilename(data));
}

pw.Widget _documentShell(List<pw.Widget> children) {
  return pw.Container(
    decoration:
        pw.BoxDecoration(border: pw.Border.all(color: _black, width: 1)),
    child: pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.stretch,
      mainAxisSize: pw.MainAxisSize.max,
      children: children,
    ),
  );
}

/// Expands the line-items grid to consume remaining page height (matches paper form).
pw.Widget _expandableItemsSection(pw.Widget Function(double height) buildTable) {
  return pw.Expanded(
    child: pw.LayoutBuilder(
      builder: (context, constraints) {
        final height = constraints?.maxHeight ?? PdfPageFormat.a4.height * 0.45;
        return pw.SizedBox(height: height, child: buildTable(height));
      },
    ),
  );
}

/// Routes each [UltraBillKind] to its own page layout — no shared tax-invoice body.
pw.Widget _documentPage(InvoiceData d, String copyLabel, pw.MemoryImage logo) {
  switch (d.kind) {
    case UltraBillKind.taxInvoice:
      return _taxInvoicePage(d, copyLabel, logo);
    case UltraBillKind.purchaseOrder:
      return _purchaseOrderPage(d, copyLabel, logo);
    case UltraBillKind.purchaseVoucher:
      return _purchaseVoucherPage(d, copyLabel, logo);
    case UltraBillKind.quotation:
      return _quotationPage(d, copyLabel, logo);
    case UltraBillKind.deliveryChallan:
      return _deliveryChallanPage(d, copyLabel, logo);
    case UltraBillKind.creditNote:
      return _creditNotePage(d, copyLabel, logo);
    case UltraBillKind.debitNote:
      return _debitNotePage(d, copyLabel, logo);
  }
}

pw.Widget _taxInvoicePage(
    InvoiceData d, String copyLabel, pw.MemoryImage logo) {
  return _documentShell([
    _topBar(d.documentTitle, copyLabel),
    _taxCompanyHeaderWithMeta(d, logo),
    _taxConsigneeAndShipping(d),
    _expandableItemsSection((h) => _taxInvoiceItemsTable(d, height: h)),
    _taxInvoiceTotalsAndBank(d),
    _termsAndSignature(d),
  ]);
}

pw.Widget _purchaseOrderPage(
    InvoiceData d, String copyLabel, pw.MemoryImage logo) {
  return _documentShell([
    _topBar(d.documentTitle, copyLabel),
    _companyHeader(logo),
    _consigneeAndMeta(d),
    _expandableItemsSection((h) => _purchaseOrderItemsTable(d, height: h)),
    _purchaseOrderTotalsAndBank(d),
    _termsAndSignature(d),
  ]);
}

pw.Widget _purchaseVoucherPage(
    InvoiceData d, String copyLabel, pw.MemoryImage logo) {
  return _documentShell([
    _topBar(d.documentTitle, copyLabel),
    _companyHeader(logo),
    _consigneeAndMeta(d),
    _expandableItemsSection((h) => _purchaseVoucherItemsTable(d, height: h)),
    _noteTaxTotalsAndBank(d),
    _termsAndSignature(d),
  ]);
}

pw.Widget _quotationPage(InvoiceData d, String copyLabel, pw.MemoryImage logo) {
  return _documentShell([
    _topBar(d.documentTitle, copyLabel),
    _companyHeader(logo),
    _consigneeAndMeta(d),
    _expandableItemsSection((h) => _quotationItemsTable(d, height: h)),
    _forwardingTotalsAndBank(d),
    _termsAndSignature(d),
  ]);
}

pw.Widget _deliveryChallanPage(
    InvoiceData d, String copyLabel, pw.MemoryImage logo) {
  final showTax = d.documentTitle == 'PROFORMA INVOICE' ||
      (d.cgstAmountOverride ?? 0) > 0 ||
      (d.sgstAmountOverride ?? 0) > 0 ||
      (d.igstAmountOverride ?? 0) > 0;
  final totals = showTax
      ? _noteTaxTotalsAndBank(d)
      : _forwardingTotalsAndBank(d);
  return _documentShell([
    _topBar(d.documentTitle, copyLabel),
    _companyHeader(logo),
    _consigneeAndMeta(d),
    _expandableItemsSection((h) => _deliveryChallanItemsTable(d, height: h)),
    totals,
    _termsAndSignature(d),
  ]);
}

pw.Widget _creditNotePage(
    InvoiceData d, String copyLabel, pw.MemoryImage logo) {
  return _documentShell([
    _topBar(d.documentTitle, copyLabel),
    _companyHeader(logo),
    _consigneeAndMeta(d),
    _expandableItemsSection((h) => _adjustmentNoteItemsTable(d, height: h)),
    _noteTaxTotalsAndBank(d),
    _termsAndSignature(d),
  ]);
}

pw.Widget _debitNotePage(InvoiceData d, String copyLabel, pw.MemoryImage logo) {
  return _documentShell([
    _topBar(d.documentTitle, copyLabel),
    _companyHeader(logo),
    _consigneeAndMeta(d),
    _expandableItemsSection((h) => _adjustmentNoteItemsTable(d, height: h)),
    _noteTaxTotalsAndBank(d),
    _termsAndSignature(d),
  ]);
}

pw.Widget _cell(
    {required pw.Widget child,
    bool right = false,
    bool bottom = false,
    pw.EdgeInsets? padding}) {
  return pw.Container(
    padding:
        padding ?? const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 4),
    decoration: pw.BoxDecoration(
      border: pw.Border(
        right: right
            ? const pw.BorderSide(color: _black, width: 1)
            : pw.BorderSide.none,
        bottom: bottom
            ? const pw.BorderSide(color: _black, width: 1)
            : pw.BorderSide.none,
      ),
    ),
    child: child,
  );
}

pw.Widget _topBarTitleText(String text,
    {pw.TextAlign align = pw.TextAlign.left}) {
  return pw.FittedBox(
    fit: pw.BoxFit.scaleDown,
    alignment: align == pw.TextAlign.right
        ? pw.Alignment.centerRight
        : pw.Alignment.centerLeft,
    child: pw.Text(
      text,
      style: _ts(size: 12, weight: pw.FontWeight.bold),
      softWrap: false,
      maxLines: 1,
      textAlign: align,
    ),
  );
}

pw.Widget _topBar(String documentTitle, String copyLabel) {
  return pw.Container(
    decoration: const pw.BoxDecoration(
        border: pw.Border(bottom: pw.BorderSide(color: _black, width: 1))),
    child: pw.Table(
      columnWidths: const {
        0: pw.FlexColumnWidth(2),
        1: pw.FlexColumnWidth(3),
      },
      defaultVerticalAlignment: pw.TableCellVerticalAlignment.middle,
      children: [
        pw.TableRow(
          children: [
            _cell(
              right: true,
              padding:
                  const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 5),
              child: _topBarTitleText(documentTitle.toUpperCase()),
            ),
            _cell(
              padding:
                  const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 5),
              child: _topBarTitleText(copyLabel, align: pw.TextAlign.right),
            ),
          ],
        ),
      ],
    ),
  );
}

pw.Widget _companyHeader(pw.MemoryImage logo) {
  return pw.Container(
    decoration: const pw.BoxDecoration(
        border: pw.Border(bottom: pw.BorderSide(color: _black, width: 1))),
    padding: const pw.EdgeInsets.all(8),
    child: pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.center,
      children: [
        pw.Container(
            width: 62,
            height: 50,
            child: pw.Image(logo, fit: pw.BoxFit.contain)),
        pw.SizedBox(width: 12),
        pw.Expanded(
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.center,
            children: [
              pw.Text('ULTRA ENGINEERING WORKS',
                  style: pw.TextStyle(
                      fontWeight: pw.FontWeight.bold, fontSize: 22)),
              pw.SizedBox(height: 2),
              pw.Text('SPM MANUFACTURERS & FABRICATORS',
                  style: pw.TextStyle(
                      fontWeight: pw.FontWeight.bold, fontSize: 10)),
              pw.SizedBox(height: 2),
              pw.Text(
                  'OFFICE:NO: 15/6, 5th CROSS, VIDYA NAGAR, OPP. S.K.F. FACTORY, BOMMASANDRA INDL. AREA, BENGALURU-560 099.',
                  style: const pw.TextStyle(fontSize: 7.5),
                  textAlign: pw.TextAlign.center),
              pw.Text(
                  'Tele Fax: 080-27834287, Mob: 9342509313 Email: ueworks@gmail.com',
                  style: const pw.TextStyle(fontSize: 7.5),
                  textAlign: pw.TextAlign.center),
              pw.Text(
                  'Works: No.B-48, KSSIDC INDL Estate, Near Karnataka Bank, Bommasandra Indl. Area, BENGALURU-560 099.',
                  style: const pw.TextStyle(fontSize: 7.5),
                  textAlign: pw.TextAlign.center),
            ],
          ),
        ),
      ],
    ),
  );
}

pw.Widget _taxCompanyHeaderWithMeta(InvoiceData d, pw.MemoryImage logo) {
  final metaBorder = pw.TableBorder.all(color: _black, width: 1);
  final metaTop = pw.Table(
    border: metaBorder,
    columnWidths: const {
      0: pw.FlexColumnWidth(1.6),
      1: pw.FlexColumnWidth(1.2),
      2: pw.FlexColumnWidth(0.9),
      3: pw.FlexColumnWidth(1.3),
    },
    children: [
      pw.TableRow(children: [
        _metaField('Invoice No', ''),
        _metaValue(d.invoiceNo, bold: true),
        _metaField('DATE :', ''),
        _metaValue(d.date, bold: true),
      ]),
      pw.TableRow(children: [
        _metaField('Cust.P.O :', ''),
        _metaValue(d.custPo.isEmpty ? '0' : d.custPo),
        _metaField('DATE :', ''),
        _metaValue(d.poDate.isEmpty ? d.date : d.poDate, bold: true),
      ]),
      pw.TableRow(children: [
        _metaField('D.C.NO  :', ''),
        _metaValue(d.dcNo.isEmpty ? '0' : d.dcNo),
        _metaField('DATE :', ''),
        _metaValue(d.dcDate.isEmpty ? d.date : d.dcDate, bold: true),
      ]),
    ],
  );
  final metaBottom = pw.Table(
    border: pw.TableBorder(
      left: const pw.BorderSide(color: _black, width: 1),
      right: const pw.BorderSide(color: _black, width: 1),
      bottom: const pw.BorderSide(color: _black, width: 1),
      horizontalInside: const pw.BorderSide(color: _black, width: 1),
    ),
    columnWidths: const {
      0: pw.FlexColumnWidth(1.6),
      1: pw.FlexColumnWidth(3.4)
    },
    children: [
      pw.TableRow(children: [
        _metaField('DESPATCH :', ''),
        _metaValue(d.dispatch.isEmpty ? '0' : d.dispatch, bold: true)
      ]),
      pw.TableRow(children: [_metaField('EWB NO:', ''), _metaValue(d.ewbNo)]),
    ],
  );

  return pw.Container(
    decoration: const pw.BoxDecoration(
        border: pw.Border(bottom: pw.BorderSide(color: _black, width: 1))),
    padding: const pw.EdgeInsets.fromLTRB(6, 6, 6, 6),
    child: pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Container(
                width: 58,
                height: 46,
                child: pw.Image(logo, fit: pw.BoxFit.contain)),
            pw.SizedBox(height: 2),
            pw.SizedBox(
              width: 118,
              child: pw.Text(
                'Works:No.B-48,KSSIDC INDL Estate,Near KarnatakaBank,Bommasandra Indl.Area,BENGALURU-560 099.',
                style: _ts(size: 6.2),
              ),
            ),
          ],
        ),
        pw.SizedBox(width: 6),
        pw.Expanded(
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.center,
            children: [
              pw.Text('ULTRA ENGINEERING WORKS',
                  style: pw.TextStyle(
                      fontWeight: pw.FontWeight.bold, fontSize: 17)),
              pw.Text('SPM MANUFACTURERS & FABRICATORS',
                  style: pw.TextStyle(
                      fontWeight: pw.FontWeight.bold, fontSize: 8.5)),
              pw.SizedBox(height: 2),
              pw.Text(
                'OFFICE:NO:15/6,5th CROSS ,VIDYA NAGAR,S.K.F.FACTORY',
                style: _ts(size: 6.8),
                textAlign: pw.TextAlign.center,
              ),
              pw.Text('BOMMASANDRA INDL.AREA,BENGALURU-560 099.',
                  style: _ts(size: 6.8), textAlign: pw.TextAlign.center),
              pw.Text('Tele Fax:080-27834287, Mob: 9342509313',
                  style: _ts(size: 6.8), textAlign: pw.TextAlign.center),
            ],
          ),
        ),
        pw.SizedBox(
          width: 168,
          child: pw.Column(children: [metaTop, metaBottom]),
        ),
      ],
    ),
  );
}

pw.Widget _taxConsigneeAndShipping(InvoiceData d) {
  final shipName = d.shippingName.isNotEmpty ? d.shippingName : d.consigneeName;
  final shipAddr = d.shippingAddress.isNotEmpty ? d.shippingAddress : '';
  return pw.Table(
    border: const pw.TableBorder(
      left: pw.BorderSide(color: _black, width: 1),
      right: pw.BorderSide(color: _black, width: 1),
      bottom: pw.BorderSide(color: _black, width: 1),
      verticalInside: pw.BorderSide(color: _black, width: 1),
    ),
    columnWidths: const {
      0: pw.FlexColumnWidth(1),
      1: pw.FlexColumnWidth(1),
    },
    defaultVerticalAlignment: pw.TableCellVerticalAlignment.top,
    children: [
      pw.TableRow(
        children: [
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            mainAxisSize: pw.MainAxisSize.min,
            children: [
              pw.Padding(
                padding: const pw.EdgeInsets.fromLTRB(6, 4, 6, 2),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  mainAxisSize: pw.MainAxisSize.min,
                  children: [
                    pw.Text('NAME & ADDRESS OF CONSIGNEE',
                        style: _ts(size: 7.2, weight: pw.FontWeight.bold)),
                    pw.SizedBox(height: 2),
                    pw.Text(d.consigneeName,
                        style: _ts(size: 8.5, weight: pw.FontWeight.bold)),
                    pw.Text(d.consigneeAddress, style: _ts(size: 7.5)),
                  ],
                ),
              ),
              pw.Container(
                width: double.infinity,
                decoration: const pw.BoxDecoration(
                    border:
                        pw.Border(top: pw.BorderSide(color: _black, width: 1))),
                padding:
                    const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text(d.mobile,
                        style: _ts(size: 8.5, weight: pw.FontWeight.bold)),
                    pw.Text('MOBILE',
                        style: _ts(size: 8, weight: pw.FontWeight.bold)),
                  ],
                ),
              ),
            ],
          ),
          pw.Padding(
            padding: const pw.EdgeInsets.fromLTRB(6, 4, 6, 4),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              mainAxisSize: pw.MainAxisSize.min,
              children: [
                pw.Text('SHIPPING NAME & ADDRESS OF CONSIGNEE',
                    style: _ts(size: 7.2, weight: pw.FontWeight.bold)),
                pw.SizedBox(height: 2),
                pw.Text(shipName,
                    style: _ts(size: 8.5, weight: pw.FontWeight.bold)),
                if (shipAddr.isNotEmpty)
                  pw.Text(shipAddr, style: _ts(size: 7.5)),
              ],
            ),
          ),
        ],
      ),
    ],
  );
}

pw.Widget _metaField(String label, String value) => pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 3),
      child: pw.Text(label, style: _ts(size: 7.5)),
    );
pw.Widget _metaValue(String value, {bool bold = false}) => pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 3),
      child: pw.Text(value,
          style: _ts(
              size: 8.5,
              weight: bold ? pw.FontWeight.bold : pw.FontWeight.normal)),
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
        pw.TableRow(
            children: [_metaField('REF. NO :', ''), _metaValue(d.dcNo)]),
        pw.TableRow(children: [
          _metaField('REF. DATE', ''),
          _metaValue(d.dcDate, bold: true)
        ]),
        pw.TableRow(children: [
          _metaField('DISPATCH :', ''),
          _metaValue(d.dispatch, bold: true)
        ]),
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
        pw.TableRow(children: [
          _metaField('KIND ATTN :', ''),
          _metaValue(d.dispatch, bold: true)
        ]),
        pw.TableRow(children: [
          _metaField('VALIDITY :', ''),
          _metaValue(d.ewbNo, bold: true)
        ]),
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
        pw.TableRow(
            children: [_metaField('REMARKS :', ''), _metaValue(d.ewbNo)]),
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
        pw.TableRow(children: [
          _metaField('DISPATCH :', ''),
          _metaValue(d.dispatch, bold: true)
        ]),
        pw.TableRow(children: [_metaField('EWB NO:', ''), _metaValue(d.ewbNo)]),
      ];
      break;
    case UltraBillKind.creditNote:
    case UltraBillKind.debitNote:
      final noteLabel = d.kind == UltraBillKind.creditNote
          ? 'Credit Note No'
          : 'Debit Note No';
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
        pw.TableRow(children: [
          _metaField('REASON :', ''),
          _metaValue(d.reason, bold: true)
        ]),
        pw.TableRow(children: [
          _metaField('DISPATCH :', ''),
          _metaValue(d.dispatch, bold: true)
        ]),
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
        pw.TableRow(children: [
          _metaField('DISPATCH :', ''),
          _metaValue(d.dispatch, bold: true)
        ]),
        pw.TableRow(children: [_metaField('EWB NO:', ''), _metaValue(d.ewbNo)]),
      ];
  }

  final partyBlock = pw.Column(
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    children: [
      pw.Text(d.partySectionTitle,
          style: _ts(size: 7.5, weight: pw.FontWeight.bold)),
      pw.SizedBox(height: 4),
      ...d.preambleLines.map((l) => pw.Padding(
            padding: const pw.EdgeInsets.only(bottom: 2),
            child: pw.Text(l, style: _ts(size: 8)),
          )),
      pw.Text(d.consigneeName,
          style: _ts(size: 9.5, weight: pw.FontWeight.bold)),
      pw.Text(d.consigneeAddress, style: _ts(size: 8)),
    ],
  );

  return pw.Container(
    decoration: const pw.BoxDecoration(
        border: pw.Border(bottom: pw.BorderSide(color: _black, width: 1))),
    child: pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Expanded(
          flex: 3,
          child: pw.Container(
            decoration: const pw.BoxDecoration(
                border:
                    pw.Border(right: pw.BorderSide(color: _black, width: 1))),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              mainAxisSize: pw.MainAxisSize.min,
              children: [
                pw.Padding(
                    padding: const pw.EdgeInsets.all(6), child: partyBlock),
                pw.Container(
                  decoration: const pw.BoxDecoration(
                      border: pw.Border(
                          top: pw.BorderSide(color: _black, width: 1))),
                  padding:
                      const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                  child: d.kind == UltraBillKind.quotation
                      ? pw.Text('GSTIN: ${d.gstin}',
                          style: _ts(size: 8, weight: pw.FontWeight.bold))
                      : pw.Row(
                          children: [
                            pw.Expanded(
                                child: pw.Text('GSTIN: ${d.gstin}',
                                    style: _ts(
                                        size: 8, weight: pw.FontWeight.bold))),
                            pw.Text(
                              d.mobile.isEmpty
                                  ? 'MOBILE:'
                                  : 'MOBILE: ${d.mobile}',
                              style: _ts(size: 8),
                            ),
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
                  horizontalInside:
                      const pw.BorderSide(color: _black, width: 1),
                ),
                columnWidths: const {
                  0: pw.FlexColumnWidth(1.7),
                  1: pw.FlexColumnWidth(4.7)
                },
                children: metaRowsBottom,
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

pw.CrossAxisAlignment _gridCrossAlign(pw.TextAlign align) {
  switch (align) {
    case pw.TextAlign.center:
      return pw.CrossAxisAlignment.center;
    case pw.TextAlign.right:
      return pw.CrossAxisAlignment.end;
    default:
      return pw.CrossAxisAlignment.start;
  }
}

/// Full-height column grid: vertical lines run top-to-bottom; no row dividers.
pw.Widget _fullHeightItemsGrid({
  required List<_ItemsGridColumn> columns,
  required List<List<String>> rows,
}) {
  return pw.Container(
    decoration: pw.BoxDecoration(border: pw.Border.all(color: _black, width: 1)),
    child: pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < columns.length; i++)
          _itemsGridColumn(
            column: columns[i],
            values: rows.map((r) => r[i]).toList(),
            showRightBorder: i < columns.length - 1,
          ),
      ],
    ),
  );
}

pw.Widget _itemsGridColumn({
  required _ItemsGridColumn column,
  required List<String> values,
  required bool showRightBorder,
}) {
  final body = pw.Column(
    crossAxisAlignment: _gridCrossAlign(column.align),
    children: [
      pw.Container(
        width: double.infinity,
        decoration: const pw.BoxDecoration(
          border: pw.Border(bottom: pw.BorderSide(color: _black, width: 1)),
        ),
        padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 6),
        child: pw.Text(
          column.header,
          style: _ts(size: 8.5, weight: pw.FontWeight.bold),
          textAlign: column.align,
        ),
      ),
      ...values.map(
        (v) => pw.Padding(
          padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 6),
          child: pw.Text(v, style: _ts(size: 9.5), textAlign: column.align),
        ),
      ),
      pw.Expanded(child: pw.SizedBox()),
    ],
  );

  final decorated = pw.Container(
    decoration: showRightBorder
        ? const pw.BoxDecoration(
            border: pw.Border(right: pw.BorderSide(color: _black, width: 1)),
          )
        : null,
    child: body,
  );

  if (column.width != null) {
    return pw.SizedBox(width: column.width, child: decorated);
  }
  return pw.Expanded(flex: column.flex, child: decorated);
}

List<List<String>> _hsnItemRows(InvoiceData d, {bool withRemarks = false}) {
  return List.generate(d.items.length, (index) {
    final it = d.items[index];
    final row = <String>[
      '${index + 1}',
      it.description,
      it.hsnCode,
      it.qty.toStringAsFixed(2),
      _money(it.price),
      _money(it.amount),
    ];
    if (withRemarks) row.add(it.remarks);
    return row;
  });
}

pw.Widget _quotationItemsTable(InvoiceData d, {required double height}) {
  return pw.SizedBox(
    height: height,
    child: _fullHeightItemsGrid(
      columns: const [
        _ItemsGridColumn(header: 'SL', width: 26, align: pw.TextAlign.center),
        _ItemsGridColumn(
            header: 'ITEM SPECIFICATION PARTICULARS', flex: 4),
        _ItemsGridColumn(header: 'QTY', width: 44, align: pw.TextAlign.center),
        _ItemsGridColumn(header: 'RATE', width: 50, align: pw.TextAlign.right),
        _ItemsGridColumn(
            header: 'NET TOTAL', width: 56, align: pw.TextAlign.right),
      ],
      rows: List.generate(d.items.length, (index) {
        final it = d.items[index];
        return [
          '${index + 1}',
          it.description,
          it.qty.toStringAsFixed(2),
          _money(it.price),
          _money(it.amount),
        ];
      }),
    ),
  );
}

pw.Widget _deliveryChallanItemsTable(InvoiceData d, {required double height}) =>
    _hsnItemsTable(
      d,
      height: height,
      slHeader: 'SL',
      hsnHeader: 'HSN CODE',
      priceHeader: 'PRICE/QTY',
      withRemarks: true,
    );

pw.Widget _taxInvoiceItemsTable(InvoiceData d, {required double height}) =>
    _hsnItemsTable(
      d,
      height: height,
      slHeader: 'SL.NO',
      hsnHeader: 'HSN/SAC',
      priceHeader: 'PRICE/UNIT',
      withRemarks: false,
    );

pw.Widget _purchaseOrderItemsTable(InvoiceData d, {required double height}) =>
    _hsnItemsTable(
      d,
      height: height,
      slHeader: 'SL',
      hsnHeader: 'HSN CODE',
      priceHeader: 'PRICE',
      withRemarks: false,
    );

pw.Widget _purchaseVoucherItemsTable(InvoiceData d, {required double height}) =>
    _hsnItemsTable(
      d,
      height: height,
      slHeader: 'SL',
      hsnHeader: 'HSN CODE',
      priceHeader: 'PRICE',
      withRemarks: false,
    );

pw.Widget _adjustmentNoteItemsTable(InvoiceData d, {required double height}) =>
    _hsnItemsTable(
      d,
      height: height,
      slHeader: 'SL',
      hsnHeader: 'HSN CODE',
      priceHeader: 'PRICE/QTY',
      withRemarks: false,
    );

pw.Widget _hsnItemsTable(
  InvoiceData d, {
  required double height,
  required String slHeader,
  required String hsnHeader,
  required String priceHeader,
  required bool withRemarks,
}) {
  final columns = <_ItemsGridColumn>[
    _ItemsGridColumn(header: slHeader, width: 28, align: pw.TextAlign.center),
    const _ItemsGridColumn(header: 'DESCRIPTION', flex: 3),
    _ItemsGridColumn(
        header: hsnHeader, width: 54, align: pw.TextAlign.center),
    _ItemsGridColumn(header: 'QTY', width: 42, align: pw.TextAlign.center),
    _ItemsGridColumn(
        header: priceHeader, width: 50, align: pw.TextAlign.right),
    _ItemsGridColumn(
        header: 'AMOUNT', width: 54, align: pw.TextAlign.right),
    if (withRemarks)
      const _ItemsGridColumn(header: 'REMARKS', flex: 2),
  ];

  return pw.SizedBox(
    height: height,
    child: _fullHeightItemsGrid(
      columns: columns,
      rows: _hsnItemRows(d, withRemarks: withRemarks),
    ),
  );
}

pw.TableRow _totalsRow(String label, String value,
        {String? value2, bool bold = false}) =>
    pw.TableRow(
      children: value2 == null
          ? [
              pw.Padding(
                  padding:
                      const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                  child: pw.Text(label,
                      style: _ts(
                          size: 8.5,
                          weight: bold
                              ? pw.FontWeight.bold
                              : pw.FontWeight.normal))),
              pw.Padding(
                padding:
                    const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                child: pw.Align(
                    alignment: pw.Alignment.centerRight,
                    child: pw.Text(value,
                        style: _ts(
                            size: 8.5,
                            weight: bold
                                ? pw.FontWeight.bold
                                : pw.FontWeight.normal))),
              ),
            ]
          : [
              pw.Padding(
                  padding:
                      const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 3),
                  child: pw.Text(label,
                      style: _ts(
                          size: 8,
                          weight: bold
                              ? pw.FontWeight.bold
                              : pw.FontWeight.normal))),
              pw.Padding(
                  padding:
                      const pw.EdgeInsets.symmetric(horizontal: 2, vertical: 3),
                  child: pw.Text(value, style: _ts(size: 8))),
              pw.Padding(
                padding:
                    const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 3),
                child: pw.Align(
                    alignment: pw.Alignment.centerRight,
                    child: pw.Text(value2,
                        style: _ts(
                            size: 8.5,
                            weight: bold
                                ? pw.FontWeight.bold
                                : pw.FontWeight.normal))),
              ),
            ],
    );

/// Tax Invoice only — Total, CGST, SGST, IGST, P & F, G.Total.
pw.Widget _taxInvoiceTotalsAndBank(InvoiceData d) {
  final totalRows = [
    _totalsRow('Total', ':', value2: _money(d.subtotal)),
    _totalsRow('SGST', ': ${d.sgstPercent.toStringAsFixed(2)} %',
        value2: _money(d.sgstAmt)),
    _totalsRow('CGST', ': ${d.cgstPercent.toStringAsFixed(2)} %',
        value2: _money(d.cgstAmt)),
    _totalsRow('IGST', ': ${d.igstPercent.toStringAsFixed(2)} %',
        value2: _money(d.igstAmt)),
    _totalsRow('P & F', ':', value2: _money(d.pAndF)),
    _totalsRow('Round Off', ':', value2: _money(d.roundOff)),
    _totalsRow('G.Total', ':', value2: _money(d.grandTotal), bold: true),
  ];

  return pw.Table(
    border: const pw.TableBorder(
      left: pw.BorderSide(color: _black, width: 1),
      right: pw.BorderSide(color: _black, width: 1),
      bottom: pw.BorderSide(color: _black, width: 1),
      verticalInside: pw.BorderSide(color: _black, width: 1),
    ),
    columnWidths: const {
      0: pw.FlexColumnWidth(3),
      1: pw.FlexColumnWidth(2),
    },
    defaultVerticalAlignment: pw.TableCellVerticalAlignment.top,
    children: [
      pw.TableRow(
        children: [
          pw.Padding(
            padding: const pw.EdgeInsets.all(6),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              mainAxisSize: pw.MainAxisSize.min,
              children: [
                pw.Text('GSTIN:${d.gstin}',
                    style: _ts(size: 8, weight: pw.FontWeight.bold)),
                if (d.serviceTaxNo.isNotEmpty)
                  pw.Text('SERVICE TAX NO: ${d.serviceTaxNo}',
                      style: _ts(size: 8, weight: pw.FontWeight.bold)),
                pw.SizedBox(height: 4),
                pw.Text('RUPEES IN WORDS:',
                    style: _ts(size: 8, weight: pw.FontWeight.bold)),
                pw.Text(d.amountInWords,
                    style: _ts(size: 8.5, weight: pw.FontWeight.bold)),
                pw.SizedBox(height: 6),
                pw.Table(
                  border: pw.TableBorder.all(color: _black, width: 1),
                  columnWidths: const {
                    0: pw.FlexColumnWidth(1.1),
                    1: pw.FlexColumnWidth(2)
                  },
                  children: [
                    pw.TableRow(children: [
                      pw.Padding(
                          padding: const pw.EdgeInsets.all(3),
                          child: pw.Text('BANK NAME :', style: _ts(size: 7.5))),
                      pw.Padding(
                          padding: const pw.EdgeInsets.all(3),
                          child: pw.Text(d.bankName,
                              style:
                                  _ts(size: 7.5, weight: pw.FontWeight.bold))),
                    ]),
                    pw.TableRow(children: [
                      pw.Padding(
                          padding: const pw.EdgeInsets.all(3),
                          child: pw.Text('ACCOUNT NO', style: _ts(size: 7.5))),
                      pw.Padding(
                          padding: const pw.EdgeInsets.all(3),
                          child: pw.Text(d.accountNo, style: _ts(size: 7.5))),
                    ]),
                    pw.TableRow(children: [
                      pw.Padding(
                          padding: const pw.EdgeInsets.all(3),
                          child: pw.Text('IFS CODE :', style: _ts(size: 7.5))),
                      pw.Padding(
                          padding: const pw.EdgeInsets.all(3),
                          child: pw.Text(d.ifscCode, style: _ts(size: 7.5))),
                    ]),
                    pw.TableRow(children: [
                      pw.Padding(
                          padding: const pw.EdgeInsets.all(3),
                          child: pw.Text('BRANCH :', style: _ts(size: 7.5))),
                      pw.Padding(
                          padding: const pw.EdgeInsets.all(3),
                          child: pw.Text(d.bankAddress,
                              style:
                                  _ts(size: 7.5, weight: pw.FontWeight.bold))),
                    ]),
                  ],
                ),
              ],
            ),
          ),
          pw.Table(
            border: pw.TableBorder.all(color: _black, width: 1),
            columnWidths: const {
              0: pw.FlexColumnWidth(1.4),
              1: pw.FlexColumnWidth(0.5),
              2: pw.FlexColumnWidth(1.2)
            },
            children: totalRows,
          ),
        ],
      ),
    ],
  );
}

/// Challan & Quotation — Subtotal, Forwarding, Total Value/Cost. No GST rows.
pw.Widget _forwardingTotalsAndBank(InvoiceData d) => _sideBySideTotalsAndBank(
      d,
      totalRows: [
        _totalsRow('Subtotal', _money(d.subtotal)),
        _totalsRow(d.forwardingLabel, _money(d.pAndF)),
        _totalsRow(d.totalGrandLabel, _money(d.grandTotal), bold: true),
      ],
    );

/// Credit/Debit Note & Purchase Voucher — tax summary, no P & F.
pw.Widget _noteTaxTotalsAndBank(InvoiceData d) => _sideBySideTotalsAndBank(
      d,
      totalRows: [
        _totalsRow('Subtotal', _money(d.subtotal)),
        if (d.cgstAmt > 0) _totalsRow('CGST', _money(d.cgstAmt)),
        if (d.sgstAmt > 0) _totalsRow('SGST', _money(d.sgstAmt)),
        if (d.igstAmt > 0) _totalsRow('IGST', _money(d.igstAmt)),
        _totalsRow('Round Off', _money(d.roundOff)),
        _totalsRow(d.totalGrandLabel, _money(d.grandTotal), bold: true),
      ],
    );

/// Purchase Order — GST + Estimated Freight.
pw.Widget _purchaseOrderTotalsAndBank(InvoiceData d) =>
    _sideBySideTotalsAndBank(
      d,
      totalRows: [
        _totalsRow('Total', _money(d.subtotal)),
        _totalsRow(
            'CGST : ${d.cgstPercent.toStringAsFixed(2)} %', _money(d.cgstAmt)),
        _totalsRow(
            'SGST : ${d.sgstPercent.toStringAsFixed(2)} %', _money(d.sgstAmt)),
        _totalsRow(
            'IGST : ${d.igstPercent.toStringAsFixed(2)} %', _money(d.igstAmt)),
        _totalsRow(d.forwardingLabel, _money(d.pAndF)),
        _totalsRow('Round Off', _money(d.roundOff)),
        _totalsRow(d.totalGrandLabel, _money(d.grandTotal), bold: true),
      ],
    );

pw.Widget _sideBySideTotalsAndBank(
  InvoiceData d, {
  required List<pw.TableRow> totalRows,
}) {
  return pw.Table(
    border: const pw.TableBorder(
      left: pw.BorderSide(color: _black, width: 1),
      right: pw.BorderSide(color: _black, width: 1),
      bottom: pw.BorderSide(color: _black, width: 1),
      verticalInside: pw.BorderSide(color: _black, width: 1),
    ),
    columnWidths: const {
      0: pw.FlexColumnWidth(3),
      1: pw.FlexColumnWidth(2),
    },
    defaultVerticalAlignment: pw.TableCellVerticalAlignment.top,
    children: [
      pw.TableRow(
        children: [
          pw.Padding(
            padding: const pw.EdgeInsets.all(6),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              mainAxisSize: pw.MainAxisSize.min,
              children: [
                pw.Text('VALUE IN WORDS:',
                    style: _ts(size: 8, weight: pw.FontWeight.bold)),
                pw.Text(d.amountInWords,
                    style: _ts(size: 9, weight: pw.FontWeight.bold)),
                if (d.showBankInTotals) ...[
                  pw.SizedBox(height: 10),
                  pw.Text('BANK: ${d.bankName} | A/C: ${d.accountNo}',
                      style: _ts(size: 8)),
                  pw.Text('IFS CODE: ${d.ifscCode} | ADDRESS: ${d.bankAddress}',
                      style: _ts(size: 8)),
                ],
              ],
            ),
          ),
          pw.Table(
            border: pw.TableBorder.all(color: _black, width: 1),
            columnWidths: const {
              0: pw.FlexColumnWidth(2),
              1: pw.FlexColumnWidth(1.6)
            },
            children: totalRows,
          ),
        ],
      ),
    ],
  );
}

pw.Widget _termsAndSignature(InvoiceData d) {
  final terms = d.customTerms ?? _ultraDocumentTerms;
  return pw.Table(
    border: const pw.TableBorder(
      left: pw.BorderSide(color: _black, width: 1),
      right: pw.BorderSide(color: _black, width: 1),
      bottom: pw.BorderSide(color: _black, width: 1),
      verticalInside: pw.BorderSide(color: _black, width: 1),
    ),
    columnWidths: const {
      0: pw.FlexColumnWidth(3),
      1: pw.FlexColumnWidth(2),
    },
    defaultVerticalAlignment: pw.TableCellVerticalAlignment.top,
    children: [
      pw.TableRow(
        children: [
          pw.Padding(
            padding: const pw.EdgeInsets.all(6),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              mainAxisSize: pw.MainAxisSize.min,
              children: [
                pw.Text('TERMS & CONDITIONS:',
                    style: _ts(size: 8, weight: pw.FontWeight.bold)),
                ...terms.map((t) => pw.Text(t, style: _ts(size: 7))),
                pw.SizedBox(height: 10),
                pw.Text(d.leftSignatureLabel, style: _ts(size: 8)),
              ],
            ),
          ),
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            mainAxisSize: pw.MainAxisSize.min,
            children: [
              pw.Container(
                width: double.infinity,
                decoration: const pw.BoxDecoration(
                    border: pw.Border(
                        bottom: pw.BorderSide(color: _black, width: 1))),
                padding: const pw.EdgeInsets.all(6),
                child: pw.Text('For ULTRA ENGINEERING WORKS',
                    style: _ts(size: 8.5, weight: pw.FontWeight.bold)),
              ),
              pw.Padding(
                padding: const pw.EdgeInsets.fromLTRB(6, 28, 6, 6),
                child: pw.Text('Authorised Signatory',
                    style: _ts(size: 8.5, weight: pw.FontWeight.bold)),
              ),
            ],
          ),
        ],
      ),
    ],
  );
}
