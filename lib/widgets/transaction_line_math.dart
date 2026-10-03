import 'invoice.dart';

int? coerceCatalogId(dynamic value) {
  if (value == null) return null;
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value.trim());
  return null;
}

bool isInterStateZone(String zone) => zone.trim().toLowerCase().contains('inter');

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
    if (v != null) return (v as num).toDouble();
  }
  final igst = (product['igst_percent'] as num?)?.toDouble();
  if (igst != null && igst > 0) return igst;
  final cgst = (product['cgst_percent'] as num?)?.toDouble();
  final sgst = (product['sgst_percent'] as num?)?.toDouble();
  if (cgst != null && sgst != null && (cgst + sgst) > 0) return cgst + sgst;
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
  return ((product['sales_rate'] ?? product['rate'] ?? 0) as num).toDouble();
}

double catalogPurchaseRate(Map<String, dynamic> product) {
  return ((product['purchase_rate'] ?? product['rate'] ?? 0) as num).toDouble();
}

int? catalogUnitId(Map<String, dynamic> product) => coerceCatalogId(product['unit_id']);

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
    final inter = _resolveInterState(stateZone, cgstPct: cgstPct, sgstPct: sgstPct, igstPct: igstPct);
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

  static bool _resolveInterState(String? stateZone, {required double cgstPct, required double sgstPct, required double igstPct}) {
    if (stateZone != null && stateZone.trim().isNotEmpty) {
      return isInterStateZone(stateZone);
    }
    return igstPct > 0 && cgstPct == 0 && sgstPct == 0;
  }
}

String payableAmountInWords(double amount) => formatUltraAmountInWords(amount);
