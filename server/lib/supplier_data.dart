/// Strip fields that must not live in VPS `suppliers.data` JSON.
Map<String, dynamic> sanitizeSupplierData(Map<String, dynamic> body) {
  final out = Map<String, dynamic>.from(body);
  out.remove('id');
  out.remove('uuid');
  out.remove('status');
  out.remove('created_at');
  out.remove('data');
  out.remove('opening_balance_cr');
  out.remove('opening_balance_dr');
  out.remove('opening_balance');
  out.remove('opening_type');
  return out;
}
