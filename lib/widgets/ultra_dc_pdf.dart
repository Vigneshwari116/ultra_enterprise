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
  final copy = data.copyLabels.isNotEmpty ? data.copyLabels.first : 'ORIGINAL';
  doc.addPage(
    pw.Page(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 6),
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
                      pw.Expanded(child: _dcItems(data)),
                      _dcFooter(data),
                    ],
                  ),
                ),
              ),
              pw.SizedBox(height: 2),
              pw.Align(
                alignment: pw.Alignment.centerRight,
                child: pw.Text(copy, style: _body(size: 9, bold: true)),
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
              pw.Text(UltraCompanyConstants.legalName, style: _body(size: 20, bold: true)),
              pw.Text(UltraCompanyConstants.tagline, style: _body(size: 9, bold: true)),
              pw.Text(UltraCompanyConstants.officeAddressLine,
                  style: _body(size: 7.5), textAlign: pw.TextAlign.center),
              pw.Text(UltraCompanyConstants.contactLine,
                  style: _body(size: 7.5), textAlign: pw.TextAlign.center),
              pw.Text(UltraCompanyConstants.worksAddressLine,
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
            columnWidths: {
              0: const pw.FlexColumnWidth(1.3),
              1: const pw.FlexColumnWidth(0.2),
              2: const pw.FlexColumnWidth(1),
              3: const pw.FlexColumnWidth(1.2),
            },
            children: [
              pw.TableRow(children: [
                _cell('DC No:'),
                _cell('|'),
                _cell(d.invoiceNo, bold: true),
                _cell(d.date, bold: true),
              ]),
              pw.TableRow(children: [
                _cell('Your D.C.No:'),
                _cell('|'),
                _cell(d.custPo),
                _cell(d.poDate, bold: true),
              ]),
              pw.TableRow(children: [
                _cell('P.O NO:'),
                _cell('|'),
                _cell(d.dcNo),
                _cell(d.dcDate, bold: true),
              ]),
              pw.TableRow(children: [
                _cell('DESPATCH'),
                _cell('|'),
                _cell(d.dispatch, bold: true),
                _cell(''),
              ]),
              pw.TableRow(children: [
                _cell('EWB NO :'),
                _cell(''),
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
      child: pw.Text(t, style: _body(size: 7.5, bold: bold)),
    );

pw.Widget _dcItems(InvoiceData d) {
  return pw.Container(
    decoration: const pw.BoxDecoration(
      border: pw.Border(bottom: pw.BorderSide(color: _black, width: 1)),
    ),
    child: pw.Column(
      children: [
        pw.Row(
          children: [
            _hdr('SL.NO', width: 26),
            _hdr('DESCRIPTION', flex: 3),
            _hdr('QTY', width: 40),
            _hdr('RATE', width: 46),
            _hdr('AMOUNT', width: 50),
            _hdr('REMARKS', flex: 2),
          ],
        ),
        pw.Expanded(
          child: pw.Column(
            children: [
              for (var i = 0; i < d.items.length; i++)
                pw.Container(
                  decoration: const pw.BoxDecoration(
                    border: pw.Border(top: pw.BorderSide(color: _black, width: 0.5)),
                  ),
                  child: pw.Row(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      _dat('${i + 1}', width: 26),
                      _dat(d.items[i].description, flex: 3),
                      _dat(d.items[i].qty.toStringAsFixed(2),
                          width: 40, center: true),
                      _dat(formatUltraMoney(d.items[i].price),
                          width: 46, right: true),
                      _dat(formatUltraMoney(d.items[i].amount),
                          width: 50, right: true),
                      _dat(d.items[i].remarks, flex: 2),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ],
    ),
  );
}

pw.Widget _hdr(String t, {double? width, int flex = 1}) {
  final c = pw.Container(
    padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 5),
    decoration: const pw.BoxDecoration(
      border: pw.Border(
        right: pw.BorderSide(color: _black, width: 1),
        bottom: pw.BorderSide(color: _black, width: 1),
      ),
    ),
    child: pw.Text(t, style: _sansHeader()),
  );
  if (width != null) return pw.SizedBox(width: width, child: c);
  return pw.Expanded(flex: flex, child: c);
}

pw.Widget _dat(String t, {double? width, int flex = 1, bool center = false, bool right = false}) {
  final c = pw.Container(
    padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 5),
    decoration: const pw.BoxDecoration(
      border: pw.Border(right: pw.BorderSide(color: _black, width: 1)),
    ),
    child: pw.Text(
      t,
      style: _body(size: 8.5),
      textAlign: right
          ? pw.TextAlign.right
          : center
              ? pw.TextAlign.center
              : pw.TextAlign.left,
    ),
  );
  if (width != null) return pw.SizedBox(width: width, child: c);
  return pw.Expanded(flex: flex, child: c);
}

pw.Widget _dcFooter(InvoiceData d) {
  return pw.Padding(
    padding: const pw.EdgeInsets.all(6),
    child: pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text('GSTIN : ${UltraCompanyConstants.gstin}',
            style: _body(size: 8, bold: true)),
        pw.Text('SERVICE TAX NO: ${UltraCompanyConstants.serviceTaxNo}',
            style: _body(size: 8, bold: true)),
        pw.Text('TAN NO: ${UltraCompanyConstants.tanNo}',
            style: _body(size: 8, bold: true)),
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
