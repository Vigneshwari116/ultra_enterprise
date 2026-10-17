/// User-visible sales invoice number: FY display when set, else legacy invoice_no.
String salesInvoiceDisplayNo(Map<String, dynamic> row) {
  final display = row['voucher_no_display'];
  if (display != null && '$display'.trim().isNotEmpty) {
    return '$display';
  }
  final no = row['invoice_no'];
  if (no != null && '$no'.trim().isNotEmpty) {
    return '$no';
  }
  return '-';
}
