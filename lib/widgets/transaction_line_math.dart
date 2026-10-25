import 'invoice.dart';

int? coerceCatalogId(dynamic value) {
  if (value == null) return null;
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value.trim());
  return null;
}

double coerceCatalogDouble(dynamic value, {double fallback = 0}) {
  if (value == null) return fallback;
  if (value is num) return value.toDouble();
  if (value is String) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return fallback;
    return double.tryParse(trimmed) ?? fallback;
  }
  return fallback;
}

bool isInterStateZone(String zone) =>
    zone.trim().toLowerCase().contains('inter');

/// Total GST % implied by line percents (intra: CGST+SGST; inter: IGST or combined).
double rowTotalGstPercent(double cgstPct, double sgstPct, double igstPct) {
  if (igstPct > 0 && cgstPct == 0 && sgstPct == 0) return igstPct;
  final intra = cgstPct + sgstPct;
  if (intra > 0) return intra;
  return igstPct;
}

/// Reads optional GST fields from catalog product maps (API/master).
double? catalogTotalGstPercent(Map<String, dynamic> product) {
  for (final key in ['gst_percent', 'gst_rate', 'tax_percent']) {
    final v = product[key];
    if (v != null) {
      final parsed = coerceCatalogDouble(v, fallback: -1);
      if (parsed >= 0) return parsed;
    }
  }
  final igst = coerceCatalogDouble(product['igst_percent'], fallback: -1);
  if (igst > 0) return igst;
  final cgst = coerceCatalogDouble(product['cgst_percent'], fallback: 0);
  final sgst = coerceCatalogDouble(product['sgst_percent'], fallback: 0);
  if ((cgst + sgst) > 0) return cgst + sgst;
  return null;
}

void applyZoneGstSplit({
  required bool interState,
  required double totalGstPercent,
  required void Function(double cgst, double sgst, double igst) apply,
}) {
  if (totalGstPercent <= 0) return;
  if (interState) {
    apply(0, 0, totalGstPercent);
  } else {
    apply(totalGstPercent / 2, totalGstPercent / 2, 0);
  }
}

/// Re-splits existing line GST percents for intra vs inter (no fixed 9/18).
void applyZoneGstFromPercents({
  required bool interState,
  required double cgstPct,
  required double sgstPct,
  required double igstPct,
  required void Function(double cgst, double sgst, double igst) apply,
}) {
  applyZoneGstSplit(
    interState: interState,
    totalGstPercent: rowTotalGstPercent(cgstPct, sgstPct, igstPct),
    apply: apply,
  );
}

void applyStandardZoneGst({
  required bool interState,
  required void Function(double cgst, double sgst, double igst) apply,
  double cgstPct = 9,
  double sgstPct = 9,
  double igstPct = 0,
}) {
  applyZoneGstFromPercents(
    interState: interState,
    cgstPct: cgstPct,
    sgstPct: sgstPct,
    igstPct: igstPct,
    apply: apply,
  );
}

/// Dropdown [value] must match an item id exactly once.
int? catalogIdInList(int? id, List<Map<String, dynamic>> rows) {
  if (id == null) return null;
  for (final row in rows) {
    if (coerceCatalogId(row['id']) == id) return id;
  }
  return null;
}

String catalogProductHsn(Map<String, dynamic> product) {
  return '${product['hsn'] ?? product['hsn_code'] ?? ''}'.trim();
}

double catalogSalesRate(Map<String, dynamic> product) {
  if (product['sales_rate'] != null) {
    return coerceCatalogDouble(product['sales_rate']);
  }

  // Legacy rows may only expose `rate` as the selling price —
  // never use purchase_rate here.
  if (product['purchase_rate'] == null && product['rate'] != null) {
    return coerceCatalogDouble(product['rate']);
  }

  return 0;
}

double catalogPurchaseRate(Map<String, dynamic> product) {
  if (product['purchase_rate'] != null) {
    return coerceCatalogDouble(product['purchase_rate']);
  }

  if (product['cost_price'] != null) {
    return coerceCatalogDouble(product['cost_price']);
  }

  // Legacy rows may only expose `rate` as cost —
  // never use sales_rate here.
  if (product['sales_rate'] == null && product['rate'] != null) {
    return coerceCatalogDouble(product['rate']);
  }

  return 0;
}

int? catalogUnitId(Map<String, dynamic> product) =>
    coerceCatalogId(product['unit_id']);

String catalogUomCode(Map<String, dynamic> product) {
  final code = '${product['uom_code'] ?? product['uom'] ?? ''}'.trim();
  return code.isEmpty ? 'PCS' : code;
}

class TransactionLineTotals {
  final double taxable;
  final double cgst;
  final double sgst;
  final double igst;
  final double total;

  const TransactionLineTotals({
    required this.taxable,
    required this.cgst,
    required this.sgst,
    required this.igst,
    required this.total,
  });

  /// Matches saved invoice line math: intra uses CGST+SGST; inter uses IGST only.
  factory TransactionLineTotals.compute({
    required double qty,
    required double rate,
    required double cgstPct,
    required double sgstPct,
    required double igstPct,
    String? stateZone,
  }) {
    final inter = _resolveInterState(stateZone,
        cgstPct: cgstPct, sgstPct: sgstPct, igstPct: igstPct);
    final taxable = qty * rate;
    final cgst = inter ? 0.0 : taxable * cgstPct / 100;
    final sgst = inter ? 0.0 : taxable * sgstPct / 100;
    final igst = inter ? taxable * igstPct / 100 : 0.0;
    return TransactionLineTotals(
      taxable: taxable,
      cgst: cgst,
      sgst: sgst,
      igst: igst,
      total: taxable + cgst + sgst + igst,
    );
  }

  static bool _resolveInterState(String? stateZone,
      {required double cgstPct,
      required double sgstPct,
      required double igstPct}) {
    if (stateZone != null && stateZone.trim().isNotEmpty) {
      return isInterStateZone(stateZone);
    }
    return igstPct > 0 && cgstPct == 0 && sgstPct == 0;
  }
}

String payableAmountInWords(double amount) => formatUltraAmountInWords(amount);

/// Visible matrix field text — keeps whole numbers compact (e.g. 100 not 100.00).
String formatTransactionMatrixNum(double v, {bool blankZero = false}) {
  if (blankZero && v == 0) return '';
  if (v == v.roundToDouble()) return v.toStringAsFixed(0);
  return v.toString();
}

/// Rate column display — always two decimals (e.g. 100.00) for purchase screens.
String formatTransactionMatrixRate(double v, {bool blankZero = false}) {
  if (blankZero && v == 0) return '';
  return v.toStringAsFixed(2);
}
