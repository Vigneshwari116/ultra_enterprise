import 'dart:convert';
import 'dart:typed_data';

import 'package:meta/meta.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../models/company_settings.dart';
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
  final String shippingBlock;
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
  final String documentTitle;
  final String partySectionTitle;
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
  final CompanySettings company;

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
    this.shippingBlock = '',
    required this.items,
    this.cgstPercent = 0,
    this.sgstPercent = 0,
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
    this.leftSignatureLabel = 'Receiver signature & Seal',
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
    this.company = const CompanySettings(),
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

const List<String> ultraInvoiceCopyLabels = [
  'ORIGINAL FOR BUYER',
  'DUPLICATE FOR TRANSPORTER',
  'TRIPLICATE FOR SUPPLIER',
  'COPY FOR ACCOUNTS',
  'EXTRA COPY',
];

const PdfColor _black = PdfColor.fromInt(0xFF000000);

const double _pageMargin = 18;
final double _contentHeight = PdfPageFormat.a4.height - (_pageMargin * 2);
const double _hTopBar = 22;
const double _hCompany = 76;
const double _hParty = 142;
const double _hFooterTotals = 96;
const double _hFooterTerms = 98;
const double _hTableHeader = 20;
const double _rowH = 18;

pw.TextStyle _ts({double size = 8, pw.FontWeight weight = pw.FontWeight.normal}) =>
    pw.TextStyle(font: weight == pw.FontWeight.bold ? pw.Font.helveticaBold() : pw.Font.helvetica(), fontSize: size, color: _black);

String _money(double v) => v.toStringAsFixed(2);

String _blank(String v) => v.trim().isEmpty ? '' : v.trim();

String formatUltraAmountInWords(double amount) {
  if (amount == 0) return 'ZERO ONLY';
  final rupees = amount.round();
  if (rupees == 0) return 'ZERO ONLY';

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
  return '${parts.join(' ').replaceAll(RegExp(r'\s+'), ' ').trim()} ONLY';
}

class _ItemSlice {
  final int start;
  final int count;
  final bool showFooter;
  const _ItemSlice(this.start, this.count, this.showFooter);
}

int _maxRowsInArea(double areaHeight) {
  final body = areaHeight - _hTableHeader;
  if (body <= 0) return 0;
  return (body / _rowH).floor();
}

List<_ItemSlice> _paginateItems(int itemCount) {
  final areaFull = _contentHeight - _hTopBar - _hCompany - _hParty;
  final areaWithFooter = areaFull - _hFooterTotals - _hFooterTerms;
  final rowsFull = _maxRowsInArea(areaFull);
  final rowsWithFooter = _maxRowsInArea(areaWithFooter);
  if (rowsFull <= 0 && rowsWithFooter <= 0) {
    return [_ItemSlice(0, itemCount, true)];
  }
  if (itemCount == 0) return [_ItemSlice(0, 0, true)];
  if (itemCount <= rowsWithFooter) {
    return [_ItemSlice(0, itemCount, true)];
  }
  final pages = <_ItemSlice>[];
  var i = 0;
  while (itemCount - i > rowsWithFooter) {
    pages.add(_ItemSlice(i, rowsFull, false));
    i += rowsFull;
  }
  pages.add(_ItemSlice(i, itemCount - i, true));
  return pages;
}

double _itemsAreaHeight(bool showFooter) {
  var h = _contentHeight - _hTopBar - _hCompany - _hParty;
  if (showFooter) h -= _hFooterTotals + _hFooterTerms;
  return h;
}

Future<Uint8List> buildUltraInvoicePdf(InvoiceData data) async {
  final doc = pw.Document();
  final logoBytes = base64Decode(ultraLogoBase64);
  final logo = pw.MemoryImage(logoBytes);

  for (final copyLabel in data.copyLabels) {
    final slices = _paginateItems(data.items.length);
    for (final slice in slices) {
      doc.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(_pageMargin),
          build: (context) => _invoicePage(
            data,
            copyLabel,
            logo,
            slice,
          ),
        ),
      );
    }
  }
  return doc.save();
}

pw.Widget _invoicePage(InvoiceData d, String copyLabel, pw.MemoryImage logo, _ItemSlice slice) {
  final border = pw.BoxDecoration(border: pw.Border.all(color: _black, width: 1));
  final itemsHeight = _itemsAreaHeight(slice.showFooter);
  final pageItems = d.items.sublist(slice.start, slice.start + slice.count);

  return pw.Container(
    height: _contentHeight,
    decoration: border,
    child: pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.stretch,
      mainAxisSize: pw.MainAxisSize.min,
      children: [
        pw.SizedBox(height: _hTopBar, child: _topBar(d.documentTitle, copyLabel)),
        pw.SizedBox(height: _hCompany, child: _companyHeader(d.company, logo)),
        pw.SizedBox(height: _hParty, child: _consigneeAndMeta(d)),
        pw.SizedBox(
          height: itemsHeight,
          child: _itemsTable(d, pageItems, slice: slice),
        ),
        if (slice.showFooter) ...[
          pw.SizedBox(height: _hFooterTotals, child: _totalsAndBank(d)),
          pw.SizedBox(height: _hFooterTerms, child: _termsAndSignature(d)),
        ],
      ],
    ),
  );
}

pw.Widget _cell({required pw.Widget child, bool right = false, bool bottom = false}) {
  return pw.Container(
    padding: const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 3),
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

pw.Widget _companyHeader(CompanySettings c, pw.MemoryImage logo) {
  final name = _blank(c.companyName);
  final tag = _blank(c.tagline);
  final office = _blank(c.officeAddress);
  final works = _blank(c.worksAddress);
  final phoneLine = [
    if (_blank(c.teleFax).isNotEmpty) 'Tele Fax: ${_blank(c.teleFax)}',
    if (_blank(c.mobile).isNotEmpty) 'Mob: ${_blank(c.mobile)}',
  ].join(', ');

  return pw.Container(
    decoration: const pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(color: _black, width: 1))),
    padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 6),
    child: pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Container(width: 58, height: 48, child: pw.Image(logo, fit: pw.BoxFit.contain)),
        pw.SizedBox(width: 10),
        pw.Expanded(
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            mainAxisAlignment: pw.MainAxisAlignment.center,
            children: [
              if (name.isNotEmpty) pw.Text(name, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 18)),
              if (tag.isNotEmpty) pw.Text(tag, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9)),
              if (office.isNotEmpty) pw.Text(office, style: const pw.TextStyle(fontSize: 7)),
              if (phoneLine.isNotEmpty) pw.Text(phoneLine, style: const pw.TextStyle(fontSize: 7)),
              if (works.isNotEmpty) pw.Text('Works: $works', style: const pw.TextStyle(fontSize: 7)),
            ],
          ),
        ),
      ],
    ),
  );
}

pw.Widget _metaField(String label) => pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      child: pw.Text(label, style: _ts(size: 7.2)),
    );

pw.Widget _metaValue(String value, {bool bold = false}) => pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      child: pw.Text(_blank(value), style: _ts(size: 8, weight: bold ? pw.FontWeight.bold : pw.FontWeight.normal)),
    );

List<pw.TableRow> _metaRowsForKind(InvoiceData d) {
  switch (d.kind) {
    case UltraBillKind.deliveryChallan:
      return [
        pw.TableRow(children: [_metaField('Challan / DC No'), _metaValue(d.invoiceNo, bold: true), _metaField('DATE'), _metaValue(d.date, bold: true)]),
        pw.TableRow(children: [_metaField('Cust.P.O NO :'), _metaValue(d.custPo), _metaField('PO DATE'), _metaValue(d.poDate)]),
        pw.TableRow(children: [_metaField('REF. NO :'), _metaValue(d.dcNo), _metaField('REF. DATE'), _metaValue(d.dcDate)]),
        pw.TableRow(children: [_metaField('DISPATCH :'), _metaValue(d.dispatch), _metaField('EWB NO:'), _metaValue(d.ewbNo)]),
      ];
    case UltraBillKind.quotation:
      return [
        pw.TableRow(children: [_metaField('QT NO :'), _metaValue(d.invoiceNo, bold: true), _metaField('DATE :'), _metaValue(d.date, bold: true)]),
        pw.TableRow(children: [_metaField('REF NO :'), _metaValue(d.custPo), _metaField('REF DATE :'), _metaValue(d.poDate)]),
        pw.TableRow(children: [_metaField('KIND ATTN :'), _metaValue(d.dispatch), _metaField('VALIDITY :'), _metaValue(d.ewbNo)]),
      ];
    case UltraBillKind.purchaseOrder:
      return [
        pw.TableRow(children: [_metaField('P.O NO :'), _metaValue(d.invoiceNo, bold: true), _metaField('P.O DATE :'), _metaValue(d.date, bold: true)]),
        pw.TableRow(children: [_metaField('Supplier Ref :'), _metaValue(d.custPo), _metaField('Del. Due :'), _metaValue(d.poDate)]),
        pw.TableRow(children: [_metaField('Tot.Pkgs :'), _metaValue(d.dcNo), _metaField('Delivery :'), _metaValue(d.dispatch)]),
        pw.TableRow(children: [_metaField('REMARKS :'), _metaValue(d.ewbNo), _metaField(''), _metaValue('')]),
      ];
    case UltraBillKind.purchaseVoucher:
      return [
        pw.TableRow(children: [_metaField('Voucher No :'), _metaValue(d.invoiceNo, bold: true), _metaField('DATE :'), _metaValue(d.date, bold: true)]),
        pw.TableRow(children: [_metaField('Supp.Inv No :'), _metaValue(d.custPo), _metaField('Inv.Date :'), _metaValue(d.poDate)]),
        pw.TableRow(children: [_metaField('Against P.O :'), _metaValue(d.dcNo), _metaField('P.O DATE'), _metaValue(d.dcDate)]),
        pw.TableRow(children: [_metaField('DISPATCH :'), _metaValue(d.dispatch), _metaField('EWB NO:'), _metaValue(d.ewbNo)]),
      ];
    case UltraBillKind.creditNote:
    case UltraBillKind.debitNote:
      final noteLabel = d.kind == UltraBillKind.creditNote ? 'Credit Note No' : 'Debit Note No';
      return [
        pw.TableRow(children: [_metaField(noteLabel), _metaValue(d.invoiceNo, bold: true), _metaField('DATE'), _metaValue(d.date, bold: true)]),
        pw.TableRow(children: [_metaField('Orig. Inv No :'), _metaValue(d.origInvNo), _metaField('DATE'), _metaValue(d.origInvDate)]),
        pw.TableRow(children: [_metaField('REASON :'), _metaValue(d.reason), _metaField('DISPATCH :'), _metaValue(d.dispatch)]),
        pw.TableRow(children: [_metaField('EWB NO:'), _metaValue(d.ewbNo), _metaField(''), _metaValue('')]),
      ];
    default:
      return [
        pw.TableRow(children: [
          _metaField('Invoice No'),
          _metaValue(d.invoiceNo, bold: true),
          _metaField('DATE'),
          pw.Container(
            width: 92,
            padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 2),
            child: pw.Text(_blank(d.date), style: _ts(size: 8, weight: pw.FontWeight.bold), maxLines: 1),
          ),
        ]),
        pw.TableRow(children: [_metaField('Cust.P.O :'), _metaValue(d.custPo), _metaField(''), _metaValue('')]),
        pw.TableRow(children: [_metaField('D.C.NO :'), _metaValue(d.dcNo), _metaField(''), _metaValue('')]),
        pw.TableRow(children: [_metaField('DESPATCH :'), _metaValue(d.dispatch), _metaField(''), _metaValue('')]),
        pw.TableRow(children: [_metaField('EWB NO:'), _metaValue(d.ewbNo), _metaField(''), _metaValue('')]),
      ];
  }
}

pw.Widget _consigneeAndMeta(InvoiceData d) {
  final metaBorder = pw.TableBorder.all(color: _black, width: 1);
  final showShipping = d.kind == UltraBillKind.taxInvoice;

  final partyBlock = pw.Column(
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    children: [
      pw.Text(d.partySectionTitle, style: _ts(size: 7.2, weight: pw.FontWeight.bold)),
      pw.SizedBox(height: 2),
      ...d.preambleLines.map((l) => pw.Text(l, style: _ts(size: 7.5))),
      if (_blank(d.consigneeName).isNotEmpty) pw.Text(d.consigneeName, style: _ts(size: 9, weight: pw.FontWeight.bold)),
      if (_blank(d.consigneeAddress).isNotEmpty) pw.Text(d.consigneeAddress, style: _ts(size: 7.5)),
    ],
  );

  final shippingBlock = pw.Column(
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    children: [
      pw.Text('SHIPPING NAME & ADDRESS OF CONSIGNEE', style: _ts(size: 6.8, weight: pw.FontWeight.bold)),
      pw.SizedBox(height: 2),
      if (_blank(d.shippingBlock).isNotEmpty)
        pw.Text(d.shippingBlock, style: _ts(size: 7.5))
      else
        pw.SizedBox(),
    ],
  );

  final partyCell = pw.Container(
    decoration: const pw.BoxDecoration(border: pw.Border(right: pw.BorderSide(color: _black, width: 1))),
    padding: const pw.EdgeInsets.all(5),
    child: pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        partyBlock,
        pw.Container(
          decoration: const pw.BoxDecoration(border: pw.Border(top: pw.BorderSide(color: _black, width: 1))),
          padding: const pw.EdgeInsets.only(top: 3),
          child: pw.Wrap(
            spacing: 8,
            children: [
              if (_blank(d.gstin).isNotEmpty) pw.Text('GSTIN: ${d.gstin}', style: _ts(size: 7.5, weight: pw.FontWeight.bold)),
              if (_blank(d.mobile).isNotEmpty) pw.Text('MOBILE: ${d.mobile}', style: _ts(size: 7.5)),
            ],
          ),
        ),
      ],
    ),
  );

  final shippingCell = pw.Container(
    decoration: const pw.BoxDecoration(border: pw.Border(right: pw.BorderSide(color: _black, width: 1))),
    padding: const pw.EdgeInsets.all(5),
    child: shippingBlock,
  );

  final metaCell = pw.Table(
    border: metaBorder,
    columnWidths: const {
      0: pw.FlexColumnWidth(1.5),
      1: pw.FlexColumnWidth(1.8),
      2: pw.FlexColumnWidth(0.9),
      3: pw.FlexColumnWidth(1.4),
    },
    children: _metaRowsForKind(d),
  );

  return pw.Container(
    decoration: const pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(color: _black, width: 1))),
    child: pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.stretch,
      children: [
        pw.SizedBox(width: showShipping ? 200 : 240, child: partyCell),
        if (showShipping) pw.SizedBox(width: 148, child: shippingCell),
        pw.Expanded(child: metaCell),
      ],
    ),
  );
}

pw.Widget _itemsTable(InvoiceData d, List<InvoiceItem> pageItems, {required _ItemSlice slice}) {
  const border = pw.TableBorder(
    left: pw.BorderSide(color: _black, width: 1),
    right: pw.BorderSide(color: _black, width: 1),
    top: pw.BorderSide(color: _black, width: 1),
    bottom: pw.BorderSide(color: _black, width: 1),
    horizontalInside: pw.BorderSide(color: _black, width: 1),
    verticalInside: pw.BorderSide(color: _black, width: 1),
  );

  pw.Widget cell(String text, {pw.TextAlign align = pw.TextAlign.left}) => pw.Container(
        height: _rowH,
        alignment: align == pw.TextAlign.center
            ? pw.Alignment.center
            : align == pw.TextAlign.right
                ? pw.Alignment.centerRight
                : pw.Alignment.centerLeft,
        padding: const pw.EdgeInsets.symmetric(horizontal: 3),
        child: pw.Text(text, style: _ts(size: 8), textAlign: align),
      );

  if (d.kind == UltraBillKind.quotation) {
    final rows = <pw.TableRow>[
      pw.TableRow(
        children: [
          cell('SL.NO', align: pw.TextAlign.center),
          cell('DESCRIPTION'),
          cell('QTY', align: pw.TextAlign.center),
          cell('PRICE/UNIT', align: pw.TextAlign.right),
          cell('AMOUNT', align: pw.TextAlign.right),
        ],
      ),
      for (var i = 0; i < pageItems.length; i++)
        pw.TableRow(
          children: [
            cell('${slice.start + i + 1}', align: pw.TextAlign.center),
            cell(pageItems[i].description),
            cell(pageItems[i].qty.toStringAsFixed(2), align: pw.TextAlign.center),
            cell(_money(pageItems[i].price), align: pw.TextAlign.right),
            cell(_money(pageItems[i].amount), align: pw.TextAlign.right),
          ],
        ),
    ];
    final filler = (_maxRowsInArea(_itemsAreaHeight(slice.showFooter)) - 1 - pageItems.length).clamp(0, 48);
    for (var f = 0; f < filler; f++) {
      rows.add(pw.TableRow(children: List.generate(5, (_) => pw.SizedBox(height: _rowH))));
    }
    return pw.Table(
      border: border,
      columnWidths: const {
        0: pw.FixedColumnWidth(26),
        1: pw.FlexColumnWidth(3.2),
        2: pw.FixedColumnWidth(40),
        3: pw.FixedColumnWidth(48),
        4: pw.FixedColumnWidth(52),
      },
      children: rows,
    );
  }

  final withRemarks = d.kind == UltraBillKind.deliveryChallan;
  final priceHeader = d.kind == UltraBillKind.deliveryChallan || d.kind == UltraBillKind.creditNote || d.kind == UltraBillKind.debitNote
      ? 'PRICE/QTY'
      : 'PRICE/UNIT';
  final colCount = withRemarks ? 7 : 6;

  final rows = <pw.TableRow>[
    pw.TableRow(
      children: [
        cell('SL.NO', align: pw.TextAlign.center),
        cell('DESCRIPTION'),
        cell('HSN/SAC', align: pw.TextAlign.center),
        cell('QTY', align: pw.TextAlign.center),
        cell(priceHeader, align: pw.TextAlign.right),
        cell('AMOUNT', align: pw.TextAlign.right),
        if (withRemarks) cell('REMARKS'),
      ],
    ),
    for (var i = 0; i < pageItems.length; i++)
      pw.TableRow(
        children: [
          cell('${slice.start + i + 1}', align: pw.TextAlign.center),
          cell(pageItems[i].description),
          cell(pageItems[i].hsnCode, align: pw.TextAlign.center),
          cell(pageItems[i].qty.toStringAsFixed(2), align: pw.TextAlign.center),
          cell(_money(pageItems[i].price), align: pw.TextAlign.right),
          cell(_money(pageItems[i].amount), align: pw.TextAlign.right),
          if (withRemarks) cell(pageItems[i].remarks),
        ],
      ),
  ];
  final filler = (_maxRowsInArea(_itemsAreaHeight(slice.showFooter)) - 1 - pageItems.length).clamp(0, 48);
  for (var f = 0; f < filler; f++) {
    rows.add(pw.TableRow(children: List.generate(colCount, (_) => pw.SizedBox(height: _rowH))));
  }

  final widths = withRemarks
      ? const {
          0: pw.FixedColumnWidth(24),
          1: pw.FlexColumnWidth(2.5),
          2: pw.FixedColumnWidth(50),
          3: pw.FixedColumnWidth(36),
          4: pw.FixedColumnWidth(44),
          5: pw.FixedColumnWidth(48),
          6: pw.FixedColumnWidth(48),
        }
      : const {
          0: pw.FixedColumnWidth(26),
          1: pw.FlexColumnWidth(3),
          2: pw.FixedColumnWidth(54),
          3: pw.FixedColumnWidth(40),
          4: pw.FixedColumnWidth(46),
          5: pw.FixedColumnWidth(50),
        };

  return pw.Table(border: border, columnWidths: widths, children: rows);
}

pw.TableRow _totalsRow(String label, String value, {bool bold = false}) => pw.TableRow(
      children: [
        pw.Padding(
          padding: const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 3),
          child: pw.Text(label, style: _ts(size: 8, weight: bold ? pw.FontWeight.bold : pw.FontWeight.normal)),
        ),
        pw.Padding(
          padding: const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 3),
          child: pw.Align(
            alignment: pw.Alignment.centerRight,
            child: pw.Text(value, style: _ts(size: 8, weight: bold ? pw.FontWeight.bold : pw.FontWeight.normal)),
          ),
        ),
      ],
    );

pw.Widget _totalsAndBank(InvoiceData d) {
  List<pw.TableRow> totalRows;
  switch (d.totalsMode) {
    case UltraTotalsMode.forwardingSummary:
      totalRows = [
        _totalsRow('Total', _money(d.subtotal)),
        _totalsRow(d.forwardingLabel, _money(d.pAndF)),
        _totalsRow('Round Off', _money(d.roundOff)),
        _totalsRow(d.totalGrandLabel, _money(d.grandTotal), bold: true),
      ];
      break;
    case UltraTotalsMode.noteTaxSummary:
      totalRows = [
        _totalsRow('Total', _money(d.subtotal)),
        _totalsRow('CGST', _money(d.cgstAmt)),
        _totalsRow('SGST', _money(d.sgstAmt)),
        _totalsRow('Round Off', _money(d.roundOff)),
        _totalsRow(d.totalGrandLabel, _money(d.grandTotal), bold: true),
      ];
      break;
    case UltraTotalsMode.standardGst:
      totalRows = [
        _totalsRow('Total', _money(d.subtotal)),
        if (d.cgstPercent > 0 || d.cgstAmt > 0)
          _totalsRow('CGST : ${d.cgstPercent.toStringAsFixed(2)} %', _money(d.cgstAmt)),
        if (d.sgstPercent > 0 || d.sgstAmt > 0)
          _totalsRow('SGST : ${d.sgstPercent.toStringAsFixed(2)} %', _money(d.sgstAmt)),
        if (d.igstPercent > 0 || d.igstAmt > 0)
          _totalsRow('IGST : ${d.igstPercent.toStringAsFixed(2)} %', _money(d.igstAmt)),
        _totalsRow(d.forwardingLabel, _money(d.pAndF)),
        _totalsRow('Round Off', _money(d.roundOff)),
        _totalsRow(d.totalGrandLabel, _money(d.grandTotal), bold: true),
      ];
  }

  final gstLine = _blank(d.company.gstin).isNotEmpty ? 'GSTIN: ${d.company.gstin}' : '';
  final stLine = _blank(d.company.serviceTaxNo).isNotEmpty ? 'SERVICE TAX NO: ${d.company.serviceTaxNo}' : '';

  return pw.Container(
    decoration: const pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(color: _black, width: 1))),
    child: pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.stretch,
      children: [
        pw.SizedBox(
          width: 320,
          child: pw.Container(
            decoration: const pw.BoxDecoration(border: pw.Border(right: pw.BorderSide(color: _black, width: 1))),
            padding: const pw.EdgeInsets.all(5),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              mainAxisAlignment: pw.MainAxisAlignment.start,
              children: [
                if (gstLine.isNotEmpty) pw.Text(gstLine, style: _ts(size: 7.5, weight: pw.FontWeight.bold)),
                if (stLine.isNotEmpty) pw.Text(stLine, style: _ts(size: 7.5, weight: pw.FontWeight.bold)),
                pw.SizedBox(height: 4),
                pw.Text('RUPEES IN WORDS:', style: _ts(size: 7.5, weight: pw.FontWeight.bold)),
                pw.Text(d.amountInWords, style: _ts(size: 8.5, weight: pw.FontWeight.bold)),
                pw.SizedBox(height: 6),
                if (_blank(d.bankName).isNotEmpty) pw.Text('BANK NAME: ${d.bankName}', style: _ts(size: 7.5)),
                if (_blank(d.accountNo).isNotEmpty) pw.Text('ACCOUNT NO: ${d.accountNo}', style: _ts(size: 7.5)),
                if (_blank(d.ifscCode).isNotEmpty) pw.Text('IFS CODE: ${d.ifscCode}', style: _ts(size: 7.5)),
                if (_blank(d.bankAddress).isNotEmpty) pw.Text('BRANCH: ${d.bankAddress}', style: _ts(size: 7.5)),
              ],
            ),
          ),
        ),
        pw.Expanded(
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
  final terms = d.customTerms ?? d.company.terms;
  final companyName = _blank(d.company.companyName);
  return pw.Row(
    crossAxisAlignment: pw.CrossAxisAlignment.stretch,
    children: [
      pw.SizedBox(
        width: 320,
        child: pw.Container(
          decoration: const pw.BoxDecoration(border: pw.Border(right: pw.BorderSide(color: _black, width: 1))),
          padding: const pw.EdgeInsets.all(5),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text('TERMS & CONDITIONS:', style: _ts(size: 7.5, weight: pw.FontWeight.bold)),
              ...terms.map((t) => pw.Text(t, style: _ts(size: 6.8))),
              pw.SizedBox(height: 8),
              pw.Text(d.leftSignatureLabel, style: _ts(size: 7.5)),
            ],
          ),
        ),
      ),
      pw.Expanded(
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.stretch,
          children: [
            pw.Container(
              decoration: const pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(color: _black, width: 1))),
              padding: const pw.EdgeInsets.all(5),
              child: pw.Text(
                companyName.isNotEmpty ? 'For $companyName' : 'For ',
                style: _ts(size: 8, weight: pw.FontWeight.bold),
              ),
            ),
            pw.Container(
              height: 44,
              padding: const pw.EdgeInsets.all(5),
              alignment: pw.Alignment.bottomLeft,
              child: pw.Text('Authorised Signatory', style: _ts(size: 8, weight: pw.FontWeight.bold)),
            ),
          ],
        ),
      ),
    ],
  );
}

/// Builds PDF using the legacy [pw.Expanded] layout — used only to reproduce the truncated-body bug in tests.
@visibleForTesting
Future<Uint8List> buildUltraInvoicePdfLegacyExpanded(InvoiceData data) async {
  final doc = pw.Document();
  final logoBytes = base64Decode(ultraLogoBase64);
  final logo = pw.MemoryImage(logoBytes);
  for (final copyLabel in data.copyLabels) {
    doc.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(18),
        build: (context) => pw.Container(
          decoration: pw.BoxDecoration(border: pw.Border.all(color: _black)),
          child: pw.Column(
            children: [
              _topBar(data.documentTitle, copyLabel),
              _companyHeader(data.company, logo),
              _consigneeAndMeta(data),
              pw.Expanded(
                child: _itemsTable(
                  data,
                  data.items,
                  slice: _ItemSlice(0, data.items.length, true),
                ),
              ),
              _totalsAndBank(data),
              _termsAndSignature(data),
            ],
          ),
        ),
      ),
    );
  }
  return doc.save();
}
