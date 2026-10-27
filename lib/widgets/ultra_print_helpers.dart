import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:printing/printing.dart';

import '../config/ultra_company_constants.dart';
import '../utils/api_errors.dart';

/// Five GST copies, one page each. Purchase orders and vouchers keep these
/// labels, including the first line "ORIGINAL FOR RECIPIENT".
const List<String> ultraDocumentCopyLabels = <String>[
  'ORIGINAL FOR RECIPIENT',
  'DUPLICATE FOR TRANSPORTER',
  'TRIPLICATE FOR SUPPLIER',
  'COPY FOR ACCOUNTS',
  'EXTRA COPY',
];

/// Sales bills, labour bills and proforma. Same five copies, but the first
/// label is the buyer copy (regular_bill.pdf / labour_bill.pdf).
const List<String> ultraSalesBillCopyLabels = <String>[
  'ORIGINAL FOR BUYER',
  'DUPLICATE FOR TRANSPORTER',
  'TRIPLICATE FOR SUPPLIER',
  'COPY FOR ACCOUNTS',
  'EXTRA COPY',
];

/// Outer border inset. `PdfPageFormat.a4.availableHeight` subtracts the format's
/// built-in 2 cm margin (~13% of the page) even when the [Page] margin is
/// smaller, so bill layout must use this height instead.
double get ultraPrintMarginV => PdfPageFormat.a4.height * 0.02;

double ultraPrintContentHeight() =>
    PdfPageFormat.a4.height - (ultraPrintMarginV * 2);

/// Labels for one PDF build. An explicit [copyLabels] list wins, including a
/// one-element reprint banner. Print, Save & Print, REPRINT, share and email
/// omit [copyLabels] and keep [fallback] (the five copies on those documents).
List<String> ultraResolveCopyLabels({
  List<String>? copyLabels,
  List<String> fallback = const <String>[],
}) {
  final chosen = copyLabels ?? fallback;
  if (chosen.isEmpty) return ultraDocumentCopyLabels;
  return chosen;
}

/// Plain numeric document number for print/save-as-PDF file names (no FY prefix).
String ultraPlainDocumentNumber(String raw) {
  final s = raw.trim();
  if (s.isEmpty) return '0';
  final matches = RegExp(r'\d+').allMatches(s);
  if (matches.isEmpty) return s;
  return matches.last.group(0)!;
}

/// System print dialog default name, e.g. `Invoice-209` (no `.pdf` suffix).
String ultraPrintPdfFileNameInvoice(String billNumber) =>
    'Invoice-${ultraPlainDocumentNumber(billNumber)}';

/// e.g. `DC-338`
String ultraPrintPdfFileNameDc(String dcNumber) =>
    'DC-${ultraPlainDocumentNumber(dcNumber)}';

/// Opens the OS / browser print preview (not a direct desktop save).
Future<void> printPdfDocument(
  BuildContext context,
  Uint8List bytes,
  String name,
) async {
  try {
    await Printing.layoutPdf(
      onLayout: (_) async => bytes,
      name: name,
      format: PdfPageFormat.a4,
    );
  } catch (e) {
    if (context.mounted) {
      showReadableErrorSnackBar(context, e);
    }
  }
}

String ultraFmtDate(String? iso) {
  if (iso == null || iso.isEmpty) return '';
  final d = DateTime.tryParse(iso);
  return d == null ? iso : DateFormat('dd-MM-yyyy').format(d);
}

/// ISO-style dates used on quotation / credit-note PDF meta blocks.
String ultraFmtDateIso(String? iso) {
  if (iso == null || iso.isEmpty) return '';
  final d = DateTime.tryParse(iso);
  return d == null ? iso : DateFormat('yyyy-MM-dd').format(d);
}

/// Tax invoice / normal bill: 12-Oct-26
String formatUltraBillDateShort(String? iso) {
  if (iso == null || iso.isEmpty) return '';
  final d = DateTime.tryParse(iso);
  if (d == null) return iso;
  return DateFormat('dd-MMM-yy').format(d);
}

/// Labour bill invoice date: 28 September 2026
String formatUltraBillDateLong(String? iso) {
  if (iso == null || iso.isEmpty) return '';
  final d = DateTime.tryParse(iso);
  if (d == null) return iso;
  return DateFormat('d MMMM yyyy').format(d);
}

/// Delivery challan header date with time: 23-Oct-2026 2:53 pm (single line).
String formatUltraDcDateTime(String? iso, {DateTime? fallbackTime}) {
  if (iso == null || iso.isEmpty) return '';
  final d = DateTime.tryParse(iso);
  if (d == null) return iso;
  final withTime = DateTime(
    d.year,
    d.month,
    d.day,
    fallbackTime?.hour ?? d.hour,
    fallbackTime?.minute ?? d.minute,
  );
  return DateFormat('dd-MMM-yyyy h:mm a').format(withTime);
}

/// Real tax % for printed totals from stored amounts (not hard-coded 9/9/18).
({double cgst, double sgst, double igst}) taxPercentsFromTotals({
  required double taxable,
  required double cgst,
  required double sgst,
  required double igst,
}) {
  if (taxable <= 0) {
    return (cgst: 0, sgst: 0, igst: 0);
  }
  return (
    cgst: cgst / taxable * 100,
    sgst: sgst / taxable * 100,
    igst: igst / taxable * 100,
  );
}

/// Omit internal ids / uuids from printed D.C.NO fields.
String printableDcReference(String? raw) {
  final s = '${raw ?? ''}'.trim();
  if (s.isEmpty) return '';
  if (RegExp(r'^[0-9a-fA-F-]{32,}$').hasMatch(s.replaceAll('-', ''))) {
    return '';
  }
  if (RegExp(r'^[0-9a-f]{8}-[0-9a-f]{4}-', caseSensitive: false).hasMatch(s)) {
    return '';
  }
  return s;
}

String printableDispatch(String? raw) {
  final s = '${raw ?? ''}'.trim();
  if (s.isEmpty || s == '0') return '';
  return pdfLatin1(s);
}

/// Text safe for Times/Helvetica in the `pdf` package (Latin-1 only).
String pdfLatin1(String text) {
  if (text.isEmpty) return text;
  final replaced = text
      .replaceAll('\u2014', '-')
      .replaceAll('\u2013', '-')
      .replaceAll('\u2018', "'")
      .replaceAll('\u2019', "'")
      .replaceAll('\u201c', '"')
      .replaceAll('\u201d', '"');
  final out = StringBuffer();
  for (final unit in replaced.runes) {
    if (unit <= 0xFF) {
      out.writeCharCode(unit);
    }
  }
  return out.toString();
}

/// DC P.O date line: dd-MM-yyyy
String formatUltraDcPoDate(String? iso) {
  if (iso == null || iso.isEmpty) return '';
  final d = DateTime.tryParse(iso);
  return d == null ? iso : DateFormat('dd-MM-yyyy').format(d);
}

/// Labour UEW DC date: dd/MM/yyyy
String formatUltraLabourDcDate(String? iso) {
  if (iso == null || iso.isEmpty) return '';
  final d = DateTime.tryParse(iso);
  return d == null ? iso : DateFormat('dd/MM/yyyy').format(d);
}

/// Money on printed bills: 14,580.00
String formatUltraMoney(num value) {
  return NumberFormat('#,##0.00', 'en_IN').format(value);
}

/// Qty on a delivery challan: whole numbers stay integers (1, 0).
String formatPrintQuantity(num value) {
  final d = value.toDouble();
  if (d == d.roundToDouble()) {
    return d.round().toString();
  }
  return d.toStringAsFixed(2);
}

/// Qty on sales bills, labour bills and proforma: always two decimals (3.00).
String formatBillQuantity(num value) => value.toStringAsFixed(2);

/// Printed grand total: taxable + SGST + CGST + IGST + P&F + round off.
double printedBillGrandTotal({
  required double taxable,
  required double sgst,
  required double cgst,
  required double igst,
  required double pAndF,
  required double roundOff,
}) =>
    taxable + sgst + cgst + igst + pAndF + roundOff;

bool _blankDateToken(String s) {
  final t = s.trim();
  return t.isEmpty || t == '0' || t == '0.0' || t == 'null';
}

String? _calendarDateText(dynamic raw) {
  if (raw == null) return null;
  if (raw is num) {
    if (raw == 0) return null;
    return null;
  }
  if (raw is DateTime) {
    final y = raw.year.toString().padLeft(4, '0');
    final m = raw.month.toString().padLeft(2, '0');
    final d = raw.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }
  final s = '$raw'.trim();
  if (_blankDateToken(s)) return null;
  return s;
}

DateTime? _parsePrintDate(String text) {
  final iso = RegExp(r'^(\d{4})-(\d{2})-(\d{2})').firstMatch(text);
  if (iso != null) {
    return DateTime(
      int.parse(iso.group(1)!),
      int.parse(iso.group(2)!),
      int.parse(iso.group(3)!),
    );
  }
  for (final pattern in [
    'MM/dd/yyyy',
    'dd/MM/yyyy',
    'dd-MM-yyyy',
    'dd-MMM-yyyy',
    'd MMMM yyyy',
    'dd-MMM-yy',
  ]) {
    try {
      return DateFormat(pattern).parseStrict(text);
    } catch (_) {}
  }
  return DateTime.tryParse(text);
}

/// PO date for a sales bill loaded from the API.
///
/// Old invoices sometimes expose `po_date` as a [DateTime] (driver) or as
/// `MM/dd/yyyy` (the previous print format), and a missing date as null or 0.
/// A missing date is blank — never the digit 0, and never the invoice date.
String formatSalesPoDate(dynamic raw) {
  final text = _calendarDateText(raw);
  if (text == null) return '';
  final parsed = _parsePrintDate(text);
  if (parsed == null) {
    return _blankDateToken(text) ? '' : text;
  }
  return DateFormat('dd-MMM-yy').format(parsed);
}

/// Cust.P.O date cell. Blank when the date is missing. Never prints 0.
String salesBillPoDateCell(String poDate) {
  final t = poDate.trim();
  if (_blankDateToken(t)) return '';
  return t;
}

/// D.C.NO date cell on a normal bill. When the DC number is 0 or empty the
/// date column is 0 (regular_bill.pdf), not the invoice date.
String salesBillDcDateCell({required String dcNo, required String dcDate}) {
  final n = dcNo.trim();
  if (n.isEmpty || n == '0') return '0';
  final d = dcDate.trim();
  if (_blankDateToken(d)) return '0';
  return d;
}

/// Labour header DC numbers.
///
/// The customer DC (927000483, 25 September) is stored on the challan number,
/// and our DC (299, 28/09/2026) is stored on `sel_dc_no`. The dates stay on
/// the row they already belong to: SEL date is `sel_dc_date`, UEW date is the
/// challan date.
class LabourDcPrintFields {
  final String selDcNo;
  final String selDcDate;
  final String uewDcNo;
  final String uewDcDate;
  const LabourDcPrintFields({
    required this.selDcNo,
    required this.selDcDate,
    required this.uewDcNo,
    required this.uewDcDate,
  });
}

String printFieldText(dynamic raw) {
  if (raw == null) return '';
  final s = '$raw'.trim();
  if (s == 'null') return '';
  return s;
}

LabourDcPrintFields labourDcPrintFields({
  required dynamic selDcNo,
  required dynamic selDcDate,
  required dynamic challanNo,
  required dynamic challanDate,
}) {
  return LabourDcPrintFields(
    selDcNo: printFieldText(challanNo),
    selDcDate: formatUltraBillDateLong(_isoDay(selDcDate)),
    uewDcNo: printFieldText(selDcNo),
    uewDcDate: formatUltraLabourDcDate(_isoDay(challanDate)),
  );
}

/// Calendar day only, so a UTC timestamp does not shift the printed date.
String? _isoDay(dynamic raw) {
  final text = _calendarDateText(raw);
  if (text == null) return null;
  final parsed = _parsePrintDate(text);
  if (parsed == null) return text;
  final y = parsed.year.toString().padLeft(4, '0');
  final m = parsed.month.toString().padLeft(2, '0');
  final d = parsed.day.toString().padLeft(2, '0');
  return '$y-$m-$d';
}

/// Collapse ",," to "," and drop a dangling "-" (end of a line, or a lone
/// dash between commas such as ", - ").
String cleanConsigneeAddress(String raw) {
  final text = raw.replaceAll('\r\n', '\n').replaceAll('\r', '\n');
  final lines = text
      .split('\n')
      .map(_cleanConsigneeAddressLine)
      .where((line) => line.isNotEmpty);
  return lines.join('\n');
}

String _cleanConsigneeAddressLine(String line) {
  var l = line.trim();
  l = l.replaceAll(RegExp(r',(?:\s*,)+'), ',');
  l = l.replaceAll(RegExp(r',\s*-\s+'), ', ');
  l = l.replaceAll(RegExp(r'\s+-\s*,'), ',');
  l = l.replaceFirst(RegExp(r'(?:[\s,]*-)\s*$'), '');
  l = l.replaceAll(RegExp(r',(?:\s*,)+'), ',');
  l = l.replaceAll(RegExp(r'\s{2,}'), ' ');
  l = l.replaceAll(RegExp(r'\s+,'), ',');
  l = l.replaceAll(RegExp(r',(?!\s)'), ', ');
  l = l.replaceFirst(RegExp(r'^,\s*'), '');
  l = l.replaceFirst(RegExp(r',\s*$'), '');
  return l.trim();
}

bool addressContainsPincode(String address, String pincode) {
  final pin = pincode.replaceAll(RegExp(r'\D'), '');
  if (pin.isEmpty) return false;
  return address.replaceAll(RegExp(r'\s+'), '').contains(pin);
}

/// City / pincode line under the consignee block. Omitted when [address]
/// already contains that pincode.
String consigneeCityLineForPrint({
  required String address,
  required String cityLine,
}) {
  final line = cityLine.trim();
  if (line.isEmpty) return '';
  if (addressContainsPincode(address, line)) return '';
  return line;
}

const ultraDefaultBankName = UltraCompanyConstants.bankName;
const ultraDefaultBankAccount = UltraCompanyConstants.bankAccountNo;
const ultraDefaultBankIfsc = UltraCompanyConstants.bankIfsc;
const ultraDefaultBankAddress = UltraCompanyConstants.bankBranch;

String ultraBankName(Map<String, dynamic>? row, String key) {
  final v = '${row?[key] ?? ''}'.trim();
  return v.isEmpty ? ultraDefaultBankName : v;
}

String ultraBankAccount(Map<String, dynamic>? row, String key) {
  final v = '${row?[key] ?? ''}'.trim();
  return v.isEmpty ? ultraDefaultBankAccount : v;
}

String ultraBankIfsc(Map<String, dynamic>? row, String key) {
  final v = '${row?[key] ?? ''}'.trim();
  return v.isEmpty ? ultraDefaultBankIfsc : v;
}

String ultraBankAddress(Map<String, dynamic>? row, String key) {
  final v = '${row?[key] ?? ''}'.trim();
  return v.isEmpty ? ultraDefaultBankAddress : v;
}

/// Indian amount in words for printed tax invoices (whole rupees from grand total).
String formatUltraAmountInWords(double amount) {
  final rupees = amount.round();
  if (rupees == 0) return 'ZERO ONLY';

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
    'NINETY',
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
  return '${parts.join(' ').replaceAll(RegExp(r'\s+'), ' ').trim()} ONLY';
}
