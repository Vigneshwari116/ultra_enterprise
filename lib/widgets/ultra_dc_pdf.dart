import 'dart:convert';
import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../config/ultra_company_constants.dart';
import 'invoice.dart';
import 'ultra_logo.dart';
import 'ultra_print_helpers.dart';

const PdfColor _black = PdfColor.fromInt(0xFF000000);

pw.TextStyle _body({double size = 8, bool bold = false}) => pw.TextStyle(
      font: bold ? pw.Font.timesBold() : pw.Font.times(),
      fontSize: size,
      color: _black,
    );

pw.TextStyle _sansHeader({double size = 8}) => pw.TextStyle(
      font: pw.Font.helveticaBold(),
      fontSize: size,
      color: _black,
    );

/// Delivery challan PDF (INWARD / OUTWARD); layout from docs/bill_formats/dc_sample.pdf.
Future<Uint8List> buildUltraDcPdf(InvoiceData data) async {
  final doc = pw.Document();
  final logo = pw.MemoryImage(base64Decode(ultraLogoBase64));
  doc.addPage(
    pw.Page(
      pageFormat: PdfPageFormat.a4,
      margin: pw.EdgeInsets.symmetric(
        horizontal: 8,
        vertical: ultraPrintMarginV,
      ),
      build: (context) {
        final h = ultraPrintContentHeight();
        return pw.SizedBox(
          height: h,
          child: pw.Column(
            children: [
              pw.Center(
                child: pw.Text(
                  data.documentTitle.toUpperCase(),
                  style: _body(size: 13, bold: true),
                ),
              ),
              pw.SizedBox(height: 4),
              pw.Expanded(
                child: pw.Container(
                  decoration: pw.BoxDecoration(
                    border: pw.Border.all(color: _black, width: 1),
                  ),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.stretch,
                    children: [
                      _dcCompanyHeader(logo),
                      _dcPartyAndMeta(data),
                      pw.Expanded(
                        child: pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.stretch,
                          children: [
                            pw.Expanded(child: _dcItemsPanel(data)),
                            _dcFooter(data),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    ),
  );
  return doc.save();
}

pw.Widget _dcCompanyHeader(pw.MemoryImage logo) {
  return pw.Container(
    decoration: const pw.BoxDecoration(
      border: pw.Border(bottom: pw.BorderSide(color: _black, width: 1)),
    ),
    padding: const pw.EdgeInsets.all(8),
    child: pw.Row(
      children: [
        pw.SizedBox(width: 58, height: 46, child: pw.Image(logo, fit: pw.BoxFit.contain)),
        pw.SizedBox(width: 10),
        pw.Expanded(
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.center,
            children: [
              pw.Text(UltraCompanyConstants.legalName,
                  style: _body(size: 20, bold: true)),
              pw.Text(UltraCompanyConstants.dcOfficeLine1,
                  style: _body(size: 7.5), textAlign: pw.TextAlign.center),
              pw.Text(UltraCompanyConstants.dcOfficeLine2,
                  style: _body(size: 7.5), textAlign: pw.TextAlign.center),
              pw.Text(UltraCompanyConstants.dcWorksLine,
                  style: _body(size: 7.5), textAlign: pw.TextAlign.center),
            ],
          ),
        ),
      ],
    ),
  );
}

List<String> _dcAddressLines(InvoiceData d) {
  final lines = <String>[];
  final cleaned = cleanConsigneeAddress(d.consigneeAddress);
  final raw = pdfLatin1(cleaned).trim();
  if (raw.isNotEmpty) {
    if (raw.contains(',')) {
      lines.addAll(
        raw.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty),
      );
    } else {
      lines.add(raw);
    }
  }
  final city = pdfLatin1(consigneeCityLineForPrint(
    address: cleaned,
    cityLine: d.consigneeCityLine,
  )).trim();
  if (city.isNotEmpty) {
    lines.add(city);
  }
  return lines;
}

pw.Widget _dcPartyAndMeta(InvoiceData d) {
  final yourDc = d.custPo.isEmpty ? '0' : d.custPo;
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
            padding: const pw.EdgeInsets.all(6),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text('NAME & ADDRESS OF CONSIGNEE',
                    style: _body(size: 7.5, bold: true)),
                pw.Text(pdfLatin1(d.consigneeName), style: _body(size: 9)),
                ..._dcAddressLines(d).map(
                  (line) => pw.Text(line, style: _body(size: 8)),
                ),
              ],
            ),
          ),
        ),
        pw.Expanded(
          flex: 2,
          child: pw.Table(
            border: pw.TableBorder.all(color: _black, width: 1),
            columnWidths: const {
              0: pw.FlexColumnWidth(1.2),
              1: pw.FlexColumnWidth(1.0),
              2: pw.FlexColumnWidth(1.3),
            },
            children: [
              pw.TableRow(children: [
                _cell('DC No:'),
                _cell(d.invoiceNo, bold: true),
                _cell(d.date, bold: true),
              ]),
              pw.TableRow(children: [
                _cell('Your D.C.No:'),
                _cell(yourDc),
                _cell(yourDc),
              ]),
              pw.TableRow(children: [
                _cell('P.O NO:'),
                _cell(d.dcNo),
                _cell(d.dcDate, bold: true),
              ]),
              pw.TableRow(children: [
                _cell('DESPATCH'),
                _cell(printableDispatch(d.dispatch), bold: true),
                _cell(''),
              ]),
              pw.TableRow(children: [
                _cell('EWB NO :'),
                _cell(d.ewbNo),
                _cell(''),
              ]),
            ],
          ),
        ),
      ],
    ),
  );
}

pw.Widget _cell(String t, {bool bold = false}) {
  final text = pdfLatin1(t);
  return pw.Padding(
    padding: const pw.EdgeInsets.symmetric(horizontal: 3, vertical: 3),
    child: pw.Text(
      text.isEmpty ? ' ' : text,
      style: _body(size: 7.5, bold: bold),
      softWrap: false,
      maxLines: 1,
    ),
  );
}

List<double> _dcItemColumnWidths(double totalWidth) {
  const fixed = [42.0, 40.0, 46.0, 50.0];
  final remarks = 72.0;
  final desc = totalWidth - fixed.fold<double>(0, (a, b) => a + b) - remarks;
  return [42, desc, 40, 46, 50, remarks];
}

pw.Widget _dcItemRow(
  List<double> widths,
  List<pw.Widget> cells, {
  bool bottomBorder = false,
}) {
  return pw.Row(
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    children: [
      for (var i = 0; i < cells.length; i++)
        pw.Container(
          width: widths[i],
          decoration: pw.BoxDecoration(
            border: pw.Border(
              right: i < cells.length - 1
                  ? const pw.BorderSide(color: _black, width: 1)
                  : pw.BorderSide.none,
              bottom: bottomBorder
                  ? const pw.BorderSide(color: _black, width: 1)
                  : pw.BorderSide.none,
            ),
          ),
          child: cells[i],
        ),
    ],
  );
}

pw.Widget _dcItemVerticalGuides(List<double> widths) {
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

pw.Widget _dcItemsPanel(InvoiceData d) {
  return pw.LayoutBuilder(
    builder: (ctx, constraints) {
      final totalW = constraints?.maxWidth ?? 400;
      final widths = _dcItemColumnWidths(totalW);
      final headerCells = [
        _hdr('SL.NO'),
        _hdr('DESCRIPTION'),
        _hdr('QTY'),
        _hdr('RATE'),
        _hdr('AMOUNT'),
        _hdr('REMARKS'),
      ];
      final dataRows = <pw.Widget>[];
      for (var i = 0; i < d.items.length; i++) {
        final it = d.items[i];
        dataRows.add(
          _dcItemRow(
            widths,
            [
              _dat('${i + 1}', align: pw.TextAlign.center),
              _dat(it.description),
              _dat(formatPrintQuantity(it.qty), align: pw.TextAlign.center),
              _dat(formatPrintQuantity(it.price), align: pw.TextAlign.right),
              _dat(formatUltraMoney(it.amount), align: pw.TextAlign.right),
              _dat(it.remarks),
            ],
            bottomBorder: true,
          ),
        );
      }
      return pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.stretch,
        children: [
          _dcItemRow(widths, headerCells, bottomBorder: true),
          pw.Expanded(
            child: pw.Stack(
              children: [
                pw.Positioned.fill(child: _dcItemVerticalGuides(widths)),
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

pw.Widget _hdr(String t) => pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 2, vertical: 5),
      child: pw.Text(
        t,
        style: _sansHeader(size: 6.8),
        softWrap: false,
        maxLines: 1,
      ),
    );

pw.Widget _dat(String t, {pw.TextAlign align = pw.TextAlign.left}) =>
    pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 5),
      child: pw.Text(
        pdfLatin1(t),
        style: _body(size: 8.5),
        textAlign: align,
      ),
    );

pw.Widget _dcFooter(InvoiceData d) {
  return pw.Container(
    decoration: const pw.BoxDecoration(
      border: pw.Border(top: pw.BorderSide(color: _black, width: 1)),
    ),
    padding: const pw.EdgeInsets.all(6),
    child: pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text('GSTIN : ${UltraCompanyConstants.gstin}',
            style: _body(size: 10, bold: true)),
        pw.Text('SERVICE TAX NO: ${UltraCompanyConstants.serviceTaxNo}',
            style: _body(size: 10, bold: true)),
        pw.Text('TAN NO: ${UltraCompanyConstants.tanNo}',
            style: _body(size: 10, bold: true)),
        pw.SizedBox(height: 8),
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text("Receiver's signature", style: _body(size: 8)),
            pw.Text('For ${UltraCompanyConstants.legalName}',
                style: _body(size: 8.5, bold: true)),
            pw.Text('Authorised Signatory', style: _body(size: 8.5, bold: true)),
          ],
        ),
      ],
    ),
  );
}
