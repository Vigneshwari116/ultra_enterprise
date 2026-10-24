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

/// Delivery challan PDF (INWARD / OUTWARD) — layout from docs/bill_formats/dc_sample.pdf.
Future<Uint8List> buildUltraDcPdf(InvoiceData data) async {
  final doc = pw.Document();
  final logo = pw.MemoryImage(base64Decode(ultraLogoBase64));
  doc.addPage(
    pw.Page(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      build: (context) {
        final h = context.page.pageFormat.availableHeight;
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
                    children: [
                      _dcCompanyHeader(logo),
                      _dcPartyAndMeta(data),
                      pw.Expanded(
                        child: pw.LayoutBuilder(
                          builder: (ctx, c) => _dcItems(
                            data,
                            bodyHeight: c?.maxHeight ?? 300,
                          ),
                        ),
                      ),
                      _dcFooter(data),
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
              pw.Text(UltraCompanyConstants.dcContactLine,
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

pw.Widget _dcPartyAndMeta(InvoiceData d) {
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
                pw.Text(d.consigneeName, style: _body(size: 9, bold: true)),
                pw.Text(d.consigneeAddress, style: _body(size: 8)),
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
                _cell(d.custPo),
                _cell(d.poDate, bold: true),
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

pw.Widget _cell(String t, {bool bold = false}) => pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 3, vertical: 3),
      child: pw.FittedBox(
        fit: pw.BoxFit.scaleDown,
        alignment: pw.Alignment.centerLeft,
        child: pw.Text(t,
            style: _body(size: 7.5, bold: bold),
            softWrap: false,
            maxLines: 1),
      ),
    );

pw.Widget _dcItems(InvoiceData d, {required double bodyHeight}) {
  const rowH = 17.0;
  const headerH = 24.0;
  final minRows =
      ((bodyHeight - headerH) / rowH).ceil().clamp(d.items.length, 40);
  final rows = <pw.TableRow>[
    pw.TableRow(
      decoration: const pw.BoxDecoration(
        border: pw.Border(bottom: pw.BorderSide(color: _black, width: 1)),
      ),
      children: [
        _hdr('SL.NO'),
        _hdr('DESCRIPTION'),
        _hdr('QTY'),
        _hdr('RATE'),
        _hdr('AMOUNT'),
        _hdr('REMARKS'),
      ],
    ),
  ];
  for (var i = 0; i < minRows; i++) {
    if (i < d.items.length) {
      final it = d.items[i];
      rows.add(pw.TableRow(children: [
        _dat('${i + 1}', align: pw.TextAlign.center),
        _dat(it.description),
        _dat(it.qty.toStringAsFixed(2), align: pw.TextAlign.center),
        _dat(formatUltraMoney(it.price), align: pw.TextAlign.right),
        _dat(formatUltraMoney(it.amount), align: pw.TextAlign.right),
        _dat(it.remarks),
      ]));
    } else {
      rows.add(pw.TableRow(children: List.generate(6, (_) => _dat(''))));
    }
  }
  return pw.Table(
    border: const pw.TableBorder(
      bottom: pw.BorderSide(color: _black, width: 1),
      left: pw.BorderSide(color: _black, width: 1),
      right: pw.BorderSide(color: _black, width: 1),
      verticalInside: pw.BorderSide(color: _black, width: 1),
      horizontalInside: pw.BorderSide(color: _black, width: 0.5),
    ),
    columnWidths: {
      0: const pw.FixedColumnWidth(30),
      1: const pw.FlexColumnWidth(3),
      2: const pw.FixedColumnWidth(40),
      3: const pw.FixedColumnWidth(46),
      4: const pw.FixedColumnWidth(50),
      5: const pw.FlexColumnWidth(2),
    },
    children: rows,
  );
}

pw.Widget _hdr(String t) => pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 5),
      child: pw.Text(t, style: _sansHeader(size: 8)),
    );

pw.Widget _dat(String t, {pw.TextAlign align = pw.TextAlign.left}) => pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 5),
      child: pw.Text(t, style: _body(size: 8.5), textAlign: align),
    );

pw.Widget _dcFooter(InvoiceData d) {
  return pw.Padding(
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
