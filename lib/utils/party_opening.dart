/// Net opening for supplier payable / customer receivable style reports.
double signedPartyOpeningFromLedger(Map<String, dynamic>? ledger, String partyKind) {
  if (ledger == null) return 0;
  final bal = (ledger['opening_balance'] as num?)?.toDouble() ?? 0;
  final type = '${ledger['opening_type'] ?? ''}'.toLowerCase();
  final kind = partyKind.toUpperCase();
  if (kind == 'SUPPLIER') {
    return type == 'cr' ? bal : -bal;
  }
  return type == 'dr' ? bal : -bal;
}
