import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:printing/printing.dart';

import '../config/ultra_company_constants.dart';
import '../utils/api_errors.dart';

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
  return s;
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
