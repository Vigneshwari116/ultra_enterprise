import 'dart:convert';
import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../config/ultra_company_constants.dart';
import 'invoice.dart';
import 'ultra_logo.dart';
import 'ultra_print_helpers.dart';

const PdfColor _black = PdfColor.fromInt(0xFF000000);
const double _pageMarginH = 8;
const double _pageMarginV = 3;

/// Max line items on the first page (header + footer included).
const int ultraSalesBillFirstPageItemCapacity = 18;

/// Continuation pages repeat the header; only the last page has footer/totals.
const int ultraSalesBillContinuationPageItemCapacity = 22;

pw.TextStyle _body({double size = 8, bool bold = false}) => pw.TextStyle(
      font: bold ? pw.Font.timesBold() : pw.Font.times(),
      fontSize: size,
      color: _black,
    );

pw.TextStyle _sansHeader({double size = 8, bool bold = true}) => pw.TextStyle(
      font: bold ? pw.Font.helveticaBold() : pw.Font.helvetica(),
      fontSize: size,
      color: _black,
    );

List<List<InvoiceItem>> _paginateItems(List<InvoiceItem> items) {
  if (items.isEmpty) return [[]];
  final pages = <List<InvoiceItem>>[];
  var i = 0;
  final firstCap = ultraSalesBillFirstPageItemCapacity;
  final nextCap = ultraSalesBillContinuationPageItemCapacity;
  pages.add(items.sublist(i, i + firstCap.clamp(0, items.length)));
  i = pages.first.length;
  while (i < items.length) {
    final end = (i + nextCap).clamp(0, items.length);
    pages.add(items.sublist(i, end));
    i = end;
  }
  return pages;
}

Future<Uint8List> buildUltraSalesBillPdf(InvoiceData data) async {
  final doc = pw.Document();
  final logoBytes = base64Decode(ultraLogoBase64);
  final logo = pw.MemoryImage(logoBytes);
  final copyLabel = data.copyLabels.isNotEmpty
      ? data.copyLabels.first
      : ultraSalesBillCopyLabels.first;
  final pages = _paginateItems(data.items);

  for (var p = 0; p < pages.length; p++) {
    final slice = pages[p];
    final isLast = p == pages.length - 1;
    final startIndex = pages
        .sublist(0, p)
        .fold<int>(0, (sum, page) => sum + page.length);
    doc.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.symmetric(
          horizontal: _pageMarginH,
          vertical: _pageMarginV,
        ),
        build: (context) {
          final pageHeight = context.page.pageFormat.availableHeight;
          return pw.SizedBox(
            height: pageHeight,
            child: _salesBillPage(
              data: data,
              copyLabel: copyLabel,
              logo: logo,
              items: slice,
              itemStartIndex: startIndex,
              showFooter: isLast,
              isContinuation: p > 0,
            ),
          );
        },
      ),
    );
  }
  return doc.save();
}

pw.Widget _salesBillPage({
  required InvoiceData data,
  required String copyLabel,
  required pw.MemoryImage logo,
  required List<InvoiceItem> items,
  required int itemStartIndex,
  required bool showFooter,
  required bool isContinuation,
}) {
  final labour = data.salesBillType == UltraSalesBillType.labour;
  return pw.Container(
    decoration: pw.BoxDecoration(border: pw.Border.all(color: _black, width: 1)),
    child: pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.stretch,
      children: [
        _topBar(data.documentTitle, copyLabel),
        if (labour)
          _labourHeaderRow(data, logo)
        else
          _normalCompanyHeader(logo),
        if (!isContinuation) ...[
          if (labour)
            _labourPartyBlocks(data)
          else
            _normalConsigneeAndMeta(data),
        ],
        pw.Expanded(
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.stretch,
            children: [
              pw.Expanded(
                child: pw.DecoratedBox(
                  decoration: const pw.BoxDecoration(
                    border: pw.Border(
                      bottom: pw.BorderSide(color: _black, width: 1),
                    ),
                  ),
                  child: _salesBillItemsPanel(data, items, itemStartIndex),
                ),
              ),
              if (showFooter) ...[
                _totalsAndBank(data),
                _termsAndSignature(data),
              ],
            ],
          ),
        ),
      ],
    ),
  );
}

pw.Widget _topBar(String title, String copyLabel) {
  return pw.Container(
    decoration: const pw.BoxDecoration(
      border: pw.Border(bottom: pw.BorderSide(color: _black, width: 1)),
    ),
    padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 4),
    child: pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.center,
      children: [
        pw.Expanded(
          child: pw.Center(
            child: pw.Text(
              title.toUpperCase(),
              style: _body(size: 12, bold: true),
              textAlign: pw.TextAlign.center,
            ),
          ),
        ),
        pw.Text(copyLabel, style: _body(size: 11, bold: true)),
      ],
    ),
  );
}

pw.Widget _normalCompanyHeader(pw.MemoryImage logo) {
  return pw.Container(
    decoration: const pw.BoxDecoration(
      border: pw.Border(bottom: pw.BorderSide(color: _black, width: 1)),
    ),
    padding: const pw.EdgeInsets.all(8),
    child: pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.center,
      children: [
        pw.SizedBox(
          width: 62,
          height: 50,
          child: pw.Image(logo, fit: pw.BoxFit.contain),
        ),
        pw.SizedBox(width: 10),
        pw.Expanded(
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.center,
            children: [
              pw.Text(UltraCompanyConstants.legalName,
                  style: _body(size: 22, bold: true)),
              pw.SizedBox(height: 2),
              pw.Text(UltraCompanyConstants.tagline,
                  style: _body(size: 10, bold: true)),
              pw.SizedBox(height: 2),
              pw.Text(UltraCompanyConstants.billOfficeLine1,
                  style: _body(size: 7.5), textAlign: pw.TextAlign.center),
              pw.Text(UltraCompanyConstants.billOfficeLine2,
                  style: _body(size: 7.5), textAlign: pw.TextAlign.center),
              pw.RichText(
                textAlign: pw.TextAlign.center,
                text: pw.TextSpan(
                  style: _body(size: 7.5),
                  children: [
                    const pw.TextSpan(
                        text: 'Tele Fax: 080-27834287, Mob: 9342509313 '),
                    pw.TextSpan(
                      text: 'Email: ueworks@gmail.com',
                      style: _body(size: 7.5, bold: true),
                    ),
                  ],
                ),
              ),
              pw.Text(UltraCompanyConstants.billWorksLine,
                  style: _body(size: 7.5), textAlign: pw.TextAlign.center),
            ],
          ),
        ),
      ],
    ),
  );
}

pw.Widget _labourHeaderRow(InvoiceData d, pw.MemoryImage logo) {
  return pw.Container(
    decoration: const pw.BoxDecoration(
      border: pw.Border(bottom: pw.BorderSide(color: _black, width: 1)),
    ),
    padding: const pw.EdgeInsets.all(6),
    child: pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Expanded(
          child: pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.SizedBox(
                  width: 58, height: 46, child: pw.Image(logo, fit: pw.BoxFit.contain)),
              pw.SizedBox(width: 6),
              pw.Expanded(
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(UltraCompanyConstants.legalName,
                        style: _body(size: 16, bold: true)),
                    pw.Text(UltraCompanyConstants.tagline,
                        style: _body(size: 8.5, bold: true)),
                    pw.SizedBox(height: 2),
                    pw.Text(UltraCompanyConstants.billOfficeLine1,
                        style: _body(size: 6.8)),
                    pw.Text(UltraCompanyConstants.billOfficeLine2,
                        style: _body(size: 6.8)),
                    pw.Text(UltraCompanyConstants.billContactLine,
                        style: _body(size: 6.8)),
                    pw.Text(UltraCompanyConstants.billWorksLine,
                        style: _body(size: 6.8)),
                  ],
                ),
              ),
            ],
          ),
        ),
        pw.SizedBox(width: 6),
        pw.SizedBox(width: 232, child: _labourInvoiceBox(d)),
      ],
    ),
  );
}

pw.Widget _metaCell(String text, {bool bold = false, double size = 7.5}) {
  final t = pdfLatin1(text);
  return pw.Padding(
    padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 3),
    child: pw.Text(
      t.isEmpty ? ' ' : t,
      style: _body(size: size, bold: bold),
      softWrap: false,
      maxLines: 1,
    ),
  );
}

String _dispatchValue(String raw) => printableDispatch(raw);

pw.Widget _labourInvoiceBox(InvoiceData d) {
  final border = pw.TableBorder.all(color: _black, width: 1);
  return pw.Table(
    border: border,
    columnWidths: const {
      0: pw.FlexColumnWidth(1.2),
      1: pw.FlexColumnWidth(0.9),
      2: pw.FlexColumnWidth(1.7),
    },
    children: [
      pw.TableRow(children: [
        _metaCell('Invoice No:'),
        _metaCell(d.invoiceNo, bold: true),
        _metaCell('DATE : ${d.date}', bold: true, size: 6.0),
      ]),
      pw.TableRow(children: [
        _metaCell('SEL DC NO :'),
        _metaCell(d.selDcNo.isEmpty ? '0' : d.selDcNo),
        _metaCell(d.selDcDate.isEmpty ? d.date : d.selDcDate, bold: true),
      ]),
      pw.TableRow(children: [
        _metaCell('UEW DC.NO :'),
        _metaCell(d.dcNo.isEmpty ? '0' : d.dcNo),
        _metaCell(d.dcDate.isEmpty ? '0' : d.dcDate, bold: true),
      ]),
      pw.TableRow(children: [
        _metaCell('DESPATCH :'),
        _metaCell(_dispatchValue(d.dispatch), bold: true),
        _metaCell(''),
      ]),
      pw.TableRow(children: [
        _metaCell('EWB NO:'),
        _metaCell(d.ewbNo),
        _metaCell(''),
      ]),
    ],
  );
}

String _mobileLineText(String mobile) {
  final m = pdfLatin1(mobile).trim();
  return m.isEmpty ? 'MOBILE :' : 'MOBILE : $m';
}

pw.Widget _gstinMobileRow({required String gstin, required String mobile}) {
  return pw.Container(
    width: double.infinity,
    decoration: const pw.BoxDecoration(
      border: pw.Border(top: pw.BorderSide(color: _black, width: 1)),
    ),
    padding: const pw.EdgeInsets.fromLTRB(6, 3, 6, 4),
    child: pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Expanded(
          child: pw.Text(
            'GSTIN: ${pdfLatin1(gstin)}',
            style: _body(size: 8, bold: true),
            softWrap: true,
          ),
        ),
        pw.SizedBox(
          width: 110,
          child: pw.Text(
            _mobileLineText(mobile),
            style: _body(size: 8, bold: true),
            textAlign: pw.TextAlign.right,
            softWrap: false,
            maxLines: 1,
          ),
        ),
      ],
    ),
  );
}

pw.Widget _consigneeAddressLines(InvoiceData d) {
  final cityPin = d.consigneeCityLine;
  return pw.Column(
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    children: [
      pw.Text('NAME & ADDRESS OF CONSIGNEE',
          style: _body(size: 7.2, bold: true)),
      pw.SizedBox(height: 2),
      pw.Text(pdfLatin1(d.consigneeName), style: _body(size: 8.5, bold: true)),
      if (d.consigneeAddress.isNotEmpty)
        pw.Text(pdfLatin1(d.consigneeAddress), style: _body(size: 7.5)),
      if (cityPin.isNotEmpty)
        pw.Text(pdfLatin1(cityPin), style: _body(size: 7.5)),
    ],
  );
}

pw.Widget _consigneePartyBlock(InvoiceData d) {
  return pw.Column(
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    children: [
      pw.Padding(
        padding: const pw.EdgeInsets.fromLTRB(6, 4, 6, 2),
        child: _consigneeAddressLines(d),
      ),
      _gstinMobileRow(gstin: d.gstin, mobile: d.mobile),
    ],
  );
}

pw.Widget _labourShippingBlock(InvoiceData d) {
  return pw.Padding(
    padding: const pw.EdgeInsets.fromLTRB(6, 4, 6, 2),
    child: pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text('SHIPPING NAME & ADDRESS OF CONSIGNE',
            style: _body(size: 7.2, bold: true)),
        pw.SizedBox(height: 2),
        pw.Text(
          pdfLatin1(
            d.shippingName.isNotEmpty ? d.shippingName : d.consigneeName,
          ),
          style: _body(size: 8.5, bold: true),
        ),
        if (d.shippingAddress.isNotEmpty)
          pw.Text(pdfLatin1(d.shippingAddress), style: _body(size: 7.5)),
      ],
    ),
  );
}

pw.Widget _normalConsigneeAndMeta(InvoiceData d) {
  return pw.Container(
    decoration: const pw.BoxDecoration(
      border: pw.Border(bottom: pw.BorderSide(color: _black, width: 1)),
    ),
    child: pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Expanded(
          flex: 3,
          child: pw.Container(
            decoration: const pw.BoxDecoration(
              border: pw.Border(right: pw.BorderSide(color: _black, width: 1)),
            ),
            child: _consigneePartyBlock(d),
          ),
        ),
        pw.Expanded(flex: 2, child: _normalInvoiceMetaBox(d)),
      ],
    ),
  );
}

pw.Widget _normalInvoiceMetaBox(InvoiceData d) {
  final border = pw.TableBorder.all(color: _black, width: 1);
  final poDate = d.poDate.isEmpty ? '0' : d.poDate;
  final dcDate = d.dcDate.isEmpty ? '0' : d.dcDate;
  return pw.Column(
    children: [
      pw.Table(
        border: border,
        columnWidths: const {
          0: pw.FlexColumnWidth(1.3),
          1: pw.FlexColumnWidth(1.0),
          2: pw.FlexColumnWidth(1.4),
        },
        children: [
          pw.TableRow(children: [
            _metaCell('Invoice No'),
            _metaCell(d.invoiceNo, bold: true),
            _metaCell('DATE : ${d.date}', bold: true),
          ]),
          pw.TableRow(children: [
            _metaCell('Cust.P.O :'),
            _metaCell(d.custPo.isEmpty ? '0' : d.custPo),
            _metaCell(poDate, bold: true),
          ]),
          pw.TableRow(children: [
            _metaCell('D.C.NO :'),
            _metaCell(d.dcNo.isEmpty ? '0' : d.dcNo),
            _metaCell(dcDate, bold: true),
          ]),
          pw.TableRow(children: [
            _metaCell('DESPATCH :'),
            _metaCell(_dispatchValue(d.dispatch), bold: true),
            _metaCell(''),
          ]),
          pw.TableRow(children: [
            _metaCell('EWB NO:'),
            _metaCell(d.ewbNo),
            _metaCell(''),
          ]),
        ],
      ),
    ],
  );
}

pw.Widget _labourPartyBlocks(InvoiceData d) {
  return pw.Container(
    decoration: const pw.BoxDecoration(
      border: pw.Border(bottom: pw.BorderSide(color: _black, width: 1)),
    ),
    child: pw.IntrinsicHeight(
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.stretch,
        children: [
          pw.Expanded(
            child: pw.Container(
              decoration: const pw.BoxDecoration(
                border: pw.Border(
                  right: pw.BorderSide(color: _black, width: 1),
                ),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.stretch,
                children: [
                  pw.Expanded(
                    child: pw.Padding(
                      padding: const pw.EdgeInsets.fromLTRB(6, 4, 6, 2),
                      child: _consigneeAddressLines(d),
                    ),
                  ),
                  _gstinMobileRow(gstin: d.gstin, mobile: d.mobile),
                ],
              ),
            ),
          ),
          pw.Expanded(child: _labourShippingBlock(d)),
        ],
      ),
    ),
  );
}

List<double> _billItemColumnWidths(double totalWidth) {
  const fixedSum = 42.0 + 54.0 + 44.0 + 76.0 + 58.0;
  final desc = totalWidth - fixedSum;
  return [42, desc, 54, 44, 76, 58];
}

pw.Alignment _cellAlign(pw.TextAlign align) {
  switch (align) {
    case pw.TextAlign.right:
      return pw.Alignment.topRight;
    case pw.TextAlign.center:
      return pw.Alignment.topCenter;
    default:
      return pw.Alignment.topLeft;
  }
}

pw.Widget _billItemRow(
  List<double> widths,
  List<pw.Widget> cells, {
  bool bottomBorder = false,
}) {
  return pw.IntrinsicHeight(
    child: pw.Container(
      decoration: pw.BoxDecoration(
        border: pw.Border(
          bottom: bottomBorder
              ? const pw.BorderSide(color: _black, width: 1)
              : pw.BorderSide.none,
        ),
      ),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < cells.length; i++)
            pw.Container(
              width: widths[i],
              decoration: pw.BoxDecoration(
                border: pw.Border(
                  right: i < cells.length - 1
                      ? const pw.BorderSide(color: _black, width: 1)
                      : pw.BorderSide.none,
                ),
              ),
              child: cells[i],
            ),
        ],
      ),
    ),
  );
}

pw.Widget _billItemVerticalGuides(List<double> widths) {
  return pw.Row(
    crossAxisAlignment: pw.CrossAxisAlignment.stretch,
    children: [
      for (var i = 0; i < widths.length; i++)
        pw.Container(
          width: widths[i],
          decoration: pw.BoxDecoration(
            border: pw.Border(
              right: i < widths.length - 1
                  ? const pw.BorderSide(color: _black, width: 1)
                  : pw.BorderSide.none,
            ),
          ),
        ),
    ],
  );
}

pw.Widget _salesBillItemsPanel(
  InvoiceData d,
  List<InvoiceItem> items,
  int startIndex,
) {
  final labour = d.salesBillType == UltraSalesBillType.labour;
  final hsnHeader = labour ? 'SAC CODE' : 'HSN/SAC';

  return pw.LayoutBuilder(
    builder: (ctx, constraints) {
      final totalW = constraints?.maxWidth ?? 400;
      final widths = _billItemColumnWidths(totalW);
      final headerCells = [
        _tblHead('SL.NO'),
        _tblHead('DESCRIPTION'),
        _tblHead(hsnHeader),
        _tblHead('QTY'),
        _tblHead('PRICE/UNIT'),
        _tblHead('AMOUNT', right: true),
      ];
      final dataRows = <pw.Widget>[];
      for (var i = 0; i < items.length; i++) {
        final it = items[i];
        final sac = labour && it.hsnCode.trim().isEmpty ? '9988' : it.hsnCode;
        dataRows.add(
          _billItemRow(
            widths,
            [
              _tblCell('${startIndex + i + 1}', align: pw.TextAlign.center),
              _tblCell(it.description,
                  bold: true, small: labour, allowWrap: true),
              _tblCell(sac, align: pw.TextAlign.center),
              _tblCell(formatPrintQuantity(it.qty),
                  align: pw.TextAlign.center),
              _tblCell(formatUltraMoney(it.price), align: pw.TextAlign.right),
              _tblCell(formatUltraMoney(it.amount), align: pw.TextAlign.right),
            ],
            bottomBorder: true,
          ),
        );
      }
      return pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.stretch,
        children: [
          _billItemRow(widths, headerCells, bottomBorder: true),
          pw.Expanded(
            child: pw.Stack(
              children: [
                pw.Positioned.fill(
                  child: _billItemVerticalGuides(widths),
                ),
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.stretch,
                  children: dataRows,
                ),
              ],
            ),
          ),
        ],
      );
    },
  );
}

pw.Widget _tblHead(String text, {bool right = false}) => pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 2, vertical: 5),
      child: pw.Text(
        text,
        style: _sansHeader(size: 6.8),
        softWrap: false,
        maxLines: 1,
        textAlign: right ? pw.TextAlign.right : pw.TextAlign.left,
      ),
    );

pw.Widget _tblCell(
  String text, {
  bool bold = false,
  bool small = false,
  bool allowWrap = false,
  pw.TextAlign align = pw.TextAlign.left,
}) =>
    pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 3, vertical: 4),
      child: pw.Align(
        alignment: _cellAlign(align),
        child: pw.Text(
          pdfLatin1(text),
          style: _body(size: small ? 7.5 : 9, bold: bold),
          textAlign: align,
          softWrap: allowWrap,
          maxLines: allowWrap ? null : 1,
        ),
      ),
    );

pw.Widget _totalsAndBank(InvoiceData d) {
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
    children: [
      pw.TableRow(
        children: [
          pw.Padding(
            padding: const pw.EdgeInsets.all(6),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text('GSTIN:${UltraCompanyConstants.gstin}',
                    style: _body(size: 8, bold: true)),
                pw.Text(
                    'SERVICE TAX NO: ${UltraCompanyConstants.serviceTaxNo}',
                    style: _body(size: 8, bold: true)),
                pw.SizedBox(height: 4),
                pw.Text('RUPEES IN WORDS:',
                    style: _body(size: 8, bold: true)),
                pw.Text(pdfLatin1(d.amountInWords), style: _body(size: 8.5)),
                pw.SizedBox(height: 6),
                _bankBox(d),
              ],
            ),
          ),
          _totalsTable(d),
        ],
      ),
    ],
  );
}

pw.Widget _bankBox(InvoiceData d) {
  return pw.Column(
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    children: [
      pw.Text('BANK NAME : ${pdfLatin1(d.bankName)}', style: _body(size: 7.5)),
      pw.Text('ACCOUNT NO ${pdfLatin1(d.accountNo)}', style: _body(size: 7.5)),
      pw.Text('IFS CODE : ${pdfLatin1(d.ifscCode)}', style: _body(size: 7.5)),
      pw.Text('BRANCH : ${pdfLatin1(d.bankAddress)}', style: _body(size: 7.5)),
    ],
  );
}

pw.Widget _totalsTable(InvoiceData d) {
  pw.TableRow row(
    String label,
    String amount, {
    String? ratePercent,
    bool bold = false,
  }) {
    return pw.TableRow(
      children: [
        pw.Padding(
          padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 3),
          child: pw.Text(label, style: _body(size: 8.5, bold: bold)),
        ),
        pw.Padding(
          padding: const pw.EdgeInsets.symmetric(horizontal: 2, vertical: 3),
          child: pw.Text(':', style: _body(size: 8)),
        ),
        pw.Padding(
          padding: const pw.EdgeInsets.symmetric(horizontal: 2, vertical: 3),
          child: pw.Text(
            ratePercent ?? '',
            style: _body(size: 8),
          ),
        ),
        pw.Padding(
          padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 3),
          child: pw.Align(
            alignment: pw.Alignment.centerRight,
            child: pw.Text(amount, style: _body(size: 8.5, bold: bold)),
          ),
        ),
      ],
    );
  }

  return pw.Table(
    border: pw.TableBorder.all(color: _black, width: 1),
    columnWidths: const {
      0: pw.FlexColumnWidth(1.2),
      1: pw.FixedColumnWidth(12),
      2: pw.FlexColumnWidth(0.9),
      3: pw.FlexColumnWidth(1.3),
    },
    children: [
      row('Total', formatUltraMoney(d.subtotal)),
      row(
        'SGST',
        formatUltraMoney(d.sgstAmt),
        ratePercent: '${d.sgstPercent.toStringAsFixed(2)} %',
      ),
      row(
        'CGST',
        formatUltraMoney(d.cgstAmt),
        ratePercent: '${d.cgstPercent.toStringAsFixed(2)} %',
      ),
      row(
        'IGST',
        formatUltraMoney(d.igstAmt),
        ratePercent: '${d.igstPercent.toStringAsFixed(2)} %',
      ),
      row('P & F', formatUltraMoney(d.pAndF)),
      row('Round Off', formatUltraMoney(d.roundOff)),
      row('G.Total', formatUltraMoney(d.grandTotal), bold: true),
    ],
  );
}

pw.Widget _termsAndSignature(InvoiceData d) {
  final terms = d.customTerms ??
      (d.salesBillType == UltraSalesBillType.labour
          ? ultraLabourBillTerms
          : ultraNormalBillTerms);
  return pw.Column(
    children: [
      pw.Table(
        border: const pw.TableBorder(
          left: pw.BorderSide(color: _black, width: 1),
          right: pw.BorderSide(color: _black, width: 1),
          verticalInside: pw.BorderSide(color: _black, width: 1),
        ),
        columnWidths: const {
          0: pw.FlexColumnWidth(3),
          1: pw.FlexColumnWidth(2),
        },
        children: [
          pw.TableRow(
            children: [
              pw.Padding(
                padding: const pw.EdgeInsets.all(6),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text('TERMS & CONDITIONS:',
                        style: _body(size: 8, bold: true)),
                    ...terms.map((t) => pw.Text(t, style: _body(size: 7))),
                  ],
                ),
              ),
              pw.Padding(
                padding: const pw.EdgeInsets.all(6),
                child: pw.Text('For ${UltraCompanyConstants.legalName}',
                    style: _body(size: 8.5, bold: true)),
              ),
            ],
          ),
        ],
      ),
      pw.Container(
        decoration: const pw.BoxDecoration(
          border: pw.Border(
            left: pw.BorderSide(color: _black, width: 1),
            right: pw.BorderSide(color: _black, width: 1),
            bottom: pw.BorderSide(color: _black, width: 1),
            top: pw.BorderSide(color: _black, width: 1),
          ),
        ),
        padding: const pw.EdgeInsets.symmetric(vertical: 6, horizontal: 6),
        child: pw.Row(
          children: [
            pw.Expanded(child: pw.SizedBox()),
            pw.Text(d.leftSignatureLabel, style: _body(size: 8)),
            pw.Expanded(child: pw.SizedBox()),
            pw.Text('Authorised Signatory',
                style: _body(size: 8.5, bold: true)),
          ],
        ),
      ),
    ],
  );
}
