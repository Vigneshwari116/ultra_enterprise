import 'package:flutter/material.dart';
import '../database/app_database.dart';
import '../widgets/compact_date_picker.dart';
import '../widgets/sales_report.dart';

const _navy = Color(0xFF122746);
const _navy2 = Color(0xFF19385F);
const _pageBg = Color(0xFFF1F4F8);
const _border = Color(0xFFD8DEE7);
const _green = Color(0xFF2FAE55);
const _teal = Color(0xFF11B9B5);

class SalesReportsScreen extends StatefulWidget {
  const SalesReportsScreen({super.key});

  @override
  State<SalesReportsScreen> createState() => _SalesReportsScreenState();
}

class _SalesReportsScreenState extends State<SalesReportsScreen> {
  int tab = 0;
  List<Map<String, dynamic>> invoices = [];
  List<Map<String, dynamic>> customers = [];
  String? selectedCustomer;
  bool loading = true;
  final searchCtrl = TextEditingController();
  DateTime? fromDate;
  DateTime? toDate;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => loading = true);
    final rows = await AppDatabase.instance.db.rawQuery('''
      SELECT s.*, COALESCE(c.customer_name, '-') AS customer_name
      FROM sales_invoices s
      LEFT JOIN customers c ON c.id = s.customer_id
      ORDER BY s.transaction_date DESC, s.id DESC
    ''');
    final cs = await AppDatabase.instance.customers();
    if (!mounted) return;
    setState(() {
      invoices = rows;
      customers = cs;
      loading = false;
    });
  }

  String _date(dynamic value) {
    if (value == null || value.toString().isEmpty) return '-';
    final s = value.toString();
    final d = DateTime.tryParse(s);
    if (d == null) return s;
    return '${d.day.toString().padLeft(2, '0')}-${d.month.toString().padLeft(2, '0')}-${d.year}';
  }

  bool _inDateRange(Map<String, dynamic> r) {
    final raw = r['transaction_date']?.toString();
    if (raw == null) return true;
    final d = DateTime.tryParse(raw);
    if (d == null) return true;
    if (fromDate != null && d.isBefore(DateTime(fromDate!.year, fromDate!.month, fromDate!.day))) return false;
    if (toDate != null && d.isAfter(DateTime(toDate!.year, toDate!.month, toDate!.day, 23, 59, 59))) return false;
    return true;
  }

  List<Map<String, dynamic>> get filteredInvoices {
    final q = searchCtrl.text.trim().toLowerCase();
    return invoices.where((r) {
      if (!_inDateRange(r)) return false;
      if (selectedCustomer != null && selectedCustomer!.isNotEmpty && r['customer_name'] != selectedCustomer) return false;
      if (q.isEmpty) return true;
      return '${r['invoice_no']}'.toLowerCase().contains(q) ||
          '${r['customer_name']}'.toLowerCase().contains(q) ||
          '${r['uuid']}'.toLowerCase().contains(q);
    }).toList();
  }

  double _sum(String key) => filteredInvoices.fold<double>(0, (v, r) => v + ((r[key] as num?)?.toDouble() ?? 0));

  void _setFrom(DateTime picked) {
    setState(() {
      fromDate = picked;
      if (toDate != null && toDate!.isBefore(picked)) toDate = picked;
    });
  }

  void _setTo(DateTime picked) {
    setState(() {
      toDate = picked;
      if (fromDate != null && picked.isBefore(fromDate!)) fromDate = picked;
    });
  }

  void _clearFilters() {
    setState(() {
      searchCtrl.clear();
      selectedCustomer = null;
      fromDate = null;
      toDate = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: _pageBg,
      child: Column(
        children: [
          _topHeader(),
          Expanded(child: loading ? const Center(child: CircularProgressIndicator()) : _body()),
        ],
      ),
    );
  }

  Widget _topHeader() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(20, 14, 8, 10),
      child: Row(
        children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: const [
              Text('SALES LEDGER AUDIT REPORT', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: _navy)),
              SizedBox(height: 3),
              Text('REAL-TIME REVENUE MONITORING & RECIPIENT LEDGER ENTRIES DIRECTORY', style: TextStyle(fontSize: 8.5, color: Color(0xFF748094), fontWeight: FontWeight.w600)),
            ]),
          ),
          _tab('LEDGER VIEW', 0),
          _tab('AUDIT REPORT', 1),
          _tab('VIEW LEDGER WISE', 2),
        ],
      ),
    );
  }

  Widget _tab(String text, int index) {
    final active = tab == index;
    return InkWell(
      onTap: () => setState(() => tab = index),
      child: Container(
        height: 34,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: active ? _navy : const Color(0xFFF5F7FA),
          border: Border.all(color: _border),
        ),
        child: Text(text, style: TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: active ? Colors.white : _navy)),
      ),
    );
  }

  Widget _body() {
    if (tab == 0) return _ledgerView();
    if (tab == 1) return _auditView();
    return _ledgerWiseView();
  }

  Widget _summaryCards() {
    final gross = _sum('grand_total');
    final received = 0.0;
    final net = gross;
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
      child: Row(children: [
        _summary('GROSS SALES (DR)', gross, Icons.show_chart, const Color(0xFF3B9ED8)),
        const SizedBox(width: 8),
        _summary('TOTAL RECEIPTS (CR)', received, Icons.account_balance, _green),
        const SizedBox(width: 8),
        _summary('NET BALANCES REVENUE', net, Icons.account_balance_wallet_outlined, const Color(0xFFF0A72E)),
      ]),
    );
  }

  Widget _summary(String title, double value, IconData icon, Color iconColor) {
    return Expanded(
      child: Container(
        height: 55,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(color: Colors.white, border: Border.all(color: _border)),
        child: Row(children: [
          Icon(icon, size: 17, color: iconColor),
          const SizedBox(width: 10),
          Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [
            Text(title, style: const TextStyle(fontSize: 8, color: Color(0xFF7A8595), fontWeight: FontWeight.w700)),
            const SizedBox(height: 3),
            Text('₹ ${value.toStringAsFixed(0)}', style: const TextStyle(fontSize: 13, color: _navy, fontWeight: FontWeight.w800)),
          ]),
        ]),
      ),
    );
  }

  Widget _filters() {
    final narrow = MediaQuery.sizeOf(context).width < 720;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: narrow
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextField(
                  controller: searchCtrl,
                  onChanged: (_) => setState(() {}),
                  style: const TextStyle(fontSize: 10),
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.search, size: 16, color: _teal),
                    hintText: 'FILTER BY DATE (YYYY-MM-DD), INVOICE SERIAL ID OR CUSTOMER CONSIGNMENT NAME...',
                    hintStyle: TextStyle(fontSize: 9, color: Color(0xFF9AA3AF)),
                    isDense: true,
                  ),
                ),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerLeft,
                  child: CompactDateRangeBar(
                    from: fromDate,
                    to: toDate,
                    onFromChanged: _setFrom,
                    onToChanged: _setTo,
                    onClear: _clearFilters,
                  ),
                ),
              ],
            )
          : Row(children: [
        Expanded(
          child: TextField(
            controller: searchCtrl,
            onChanged: (_) => setState(() {}),
            style: const TextStyle(fontSize: 10),
            decoration: const InputDecoration(prefixIcon: Icon(Icons.search, size: 16, color: _teal), hintText: 'FILTER BY DATE (YYYY-MM-DD), INVOICE SERIAL ID OR CUSTOMER CONSIGNMENT NAME...', hintStyle: TextStyle(fontSize: 9, color: Color(0xFF9AA3AF)), isDense: true),
          ),
        ),
        const SizedBox(width: 8),
        CompactDateRangeBar(
          from: fromDate,
          to: toDate,
          onFromChanged: _setFrom,
          onToChanged: _setTo,
          onClear: _clearFilters,
        ),
      ]),
    );
  }

  Widget _ledgerView() {
    return SingleChildScrollView(
      child: Column(children: [
        _summaryCards(),
        _filters(),
        const SizedBox(height: 12),
        Padding(padding: const EdgeInsets.symmetric(horizontal: 14), child: Column(children: filteredInvoices.isEmpty ? [_empty()] : filteredInvoices.map(_invoiceRow).toList())),
      ]),
    );
  }

  Widget _invoiceRow(Map<String, dynamic> r) {
    final total = (r['grand_total'] as num?)?.toDouble() ?? 0;
    return Container(
      height: 58,
      margin: const EdgeInsets.only(bottom: 4),
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(color: Colors.white, border: Border.all(color: _border)),
      child: Row(children: [
        Container(width: 3, height: 38, color: _navy),
        const SizedBox(width: 10),
        Expanded(flex: 4, child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [Text('${r['customer_name']}', style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, color: _navy)), const SizedBox(height: 4), Row(children: [Text('SERIAL NO: ${r['invoice_no'] ?? '-'}', style: const TextStyle(fontSize: 8.5, color: _teal, fontWeight: FontWeight.w700)), const SizedBox(width: 8), Text('•  RECORDING DATE: ${_date(r['transaction_date'])}', style: const TextStyle(fontSize: 8, color: Color(0xFF748094)))] )])),
        Expanded(child: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.end, children: [const Text('DEBIT VAL (REV)', style: TextStyle(fontSize: 7.5, color: Color(0xFF748094))), Text('₹${total.toStringAsFixed(0)}', style: const TextStyle(fontSize: 12, color: Color(0xFF2B65B0), fontWeight: FontWeight.w800))])),
        const SizedBox(width: 18),
        Expanded(child: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.end, children: [const Text('CREDIT VAL (REC)', style: TextStyle(fontSize: 7.5, color: Color(0xFF748094))), const Text('₹0', style: TextStyle(fontSize: 12, color: Color(0xFFB93636), fontWeight: FontWeight.w800))])),
        const SizedBox(width: 12),
        OutlinedButton.icon(
          onPressed: () => reprintSalesInvoice(r['id'] as int),
          icon: const Icon(Icons.print, size: 12),
          label: const Text('REPRINT', style: TextStyle(fontSize: 8, fontWeight: FontWeight.w800)),
          style: OutlinedButton.styleFrom(foregroundColor: _navy, side: const BorderSide(color: _border), padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 8)),
        ),
      ]),
    );
  }

  Widget _auditView() {
    final rows = filteredInvoices;
    final taxable = _sum('taxable_total');
    final cgst = _sum('cgst_total');
    final sgst = _sum('sgst_total');
    final igst = _sum('igst_total');
    final total = _sum('grand_total');

    final sorted = List<Map<String, dynamic>>.from(rows);
    sorted.sort((a, b) {
      final da = DateTime.tryParse('${a['transaction_date'] ?? ''}') ?? DateTime(1970);
      final db = DateTime.tryParse('${b['transaction_date'] ?? ''}') ?? DateTime(1970);
      final c = db.compareTo(da);
      if (c != 0) return c;
      return ((b['invoice_no'] as num?) ?? 0).compareTo((a['invoice_no'] as num?) ?? 0);
    });

    return SingleChildScrollView(
      child: Column(children: [
        _summaryCards(),
        _filters(),
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 10, 14, 0),
          child: Align(
            alignment: Alignment.centerRight,
            child: OutlinedButton.icon(
              onPressed: () => printSalesAuditReport(rows),
              icon: const Icon(Icons.picture_as_pdf_outlined, size: 14),
              label: const Text('PRINT AUDIT', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w800)),
              style: OutlinedButton.styleFrom(foregroundColor: _navy, side: const BorderSide(color: _border), padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8)),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: Container(
            color: Colors.white,
            child: Column(children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
                decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: _border))),
                child: const Row(children: [
                  Expanded(flex: 1, child: Text('BILL NO', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: _navy))),
                  Expanded(flex: 1, child: Text('DATE', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: _navy))),
                  Expanded(flex: 4, child: Text('PARTY NAME', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: _navy))),
                  Expanded(child: Text('TAXABLE', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: _navy))),
                  Expanded(child: Text('CGST', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: _navy))),
                  Expanded(child: Text('SGST', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: _navy))),
                  Expanded(child: Text('IGST', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: _navy))),
                  Expanded(child: Text('TOTAL', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: _navy))),
                ]),
              ),
              ...sorted.map(_auditRow),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
                color: const Color(0xFFE1E7F0),
                child: Row(children: [
                  const Expanded(flex: 6, child: Text('GRAND TOTALS:', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: _navy))),
                  Expanded(child: Text(taxable.toStringAsFixed(2), style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w800))),
                  Expanded(child: Text(cgst.toStringAsFixed(2), style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w800))),
                  Expanded(child: Text(sgst.toStringAsFixed(2), style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w800))),
                  Expanded(child: Text(igst.toStringAsFixed(2), style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w800))),
                  Expanded(child: Text(total.toStringAsFixed(2), style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: _green))),
                ]),
              ),
            ]),
          ),
        ),
      ]),
    );
  }

  Widget _auditRow(Map<String, dynamic> r) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Color(0xFFE7EBF0)))),
      child: Row(children: [
        Expanded(flex: 1, child: Text('${r['invoice_no'] ?? '-'}', style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w700))),
        Expanded(flex: 1, child: Text(_date(r['transaction_date']), style: const TextStyle(fontSize: 9))),
        Expanded(flex: 4, child: Text('${r['customer_name']}', style: const TextStyle(fontSize: 9))),
        Expanded(child: Text('${(r['taxable_total'] as num?)?.toDouble().toStringAsFixed(2) ?? '0.00'}', style: const TextStyle(fontSize: 9))),
        Expanded(child: Text('${(r['cgst_total'] as num?)?.toDouble().toStringAsFixed(2) ?? '0.00'}', style: const TextStyle(fontSize: 9))),
        Expanded(child: Text('${(r['sgst_total'] as num?)?.toDouble().toStringAsFixed(2) ?? '0.00'}', style: const TextStyle(fontSize: 9))),
        Expanded(child: Text('${(r['igst_total'] as num?)?.toDouble().toStringAsFixed(2) ?? '0.00'}', style: const TextStyle(fontSize: 9))),
        Expanded(child: Text('${(r['grand_total'] as num?)?.toDouble().toStringAsFixed(2) ?? '0.00'}', style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w700))),
      ]),
    );
  }

  Widget _ledgerWiseView() {
    final name = selectedCustomer;
    final rows = name == null ? <Map<String, dynamic>>[] : filteredInvoices.where((r) => r['customer_name'] == name).toList();
    final gross = rows.fold<double>(0, (v, r) => v + ((r['grand_total'] as num?)?.toDouble() ?? 0));
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          DropdownButtonFormField<String>(
            value: selectedCustomer,
            isExpanded: true,
            decoration: const InputDecoration(hintText: 'CHOOSE OR SELECT DEBTOR CUSTOMER CLIENT REGISTER PROFILE...', filled: true, fillColor: Colors.white),
            items: customers.map((c) => DropdownMenuItem<String>(value: '${c['customer_name']}', child: Text('${c['id']} - ${c['customer_name']}', style: const TextStyle(fontSize: 10)))).toList(),
            onChanged: (v) => setState(() => selectedCustomer = v),
          ),
          if (name != null) ...[
            const SizedBox(height: 12),
            Row(children: [
              _ledgerCard('OPENING BALANCE', 0, _navy),
              const SizedBox(width: 8),
              _ledgerCard('GROSS SALES BILLING (DR)', gross, const Color(0xFF2B8ED2)),
              const SizedBox(width: 8),
              _ledgerCard('TOTAL RECEIVED (CR)', 0, _green),
              const SizedBox(width: 8),
              _ledgerCard('NET OUTSTANDING DUE', -gross, _navy),
            ]),
            const SizedBox(height: 14),
            Container(color: Colors.white, child: Column(children: [
              Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9), child: const Row(children: [Expanded(child: Text('DATE', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: _navy))), Expanded(child: Text('TXN TYPE', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: _navy))), Expanded(child: Text('REF / INVOICE ID', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: _navy))), Expanded(flex: 3, child: Text('PARTICULARS / NARRATION ENTRY', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: _navy))), Expanded(child: Text('DEBIT (DR) [+]', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: Color(0xFF2B8ED2)))), Expanded(child: Text('CREDIT (CR) [-]', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: _green))), Expanded(child: Text('BALANCE (₹)', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: _navy)))])),
              ...rows.map((r) => Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10), decoration: const BoxDecoration(border: Border(top: BorderSide(color: Color(0xFFE7EBF0)))), child: Row(children: [Expanded(child: Text(_date(r['transaction_date']), style: const TextStyle(fontSize: 9))), Expanded(child: Container(alignment: Alignment.centerLeft, child: const Text('SALES', style: TextStyle(fontSize: 8, color: _green, fontWeight: FontWeight.w700)))), Expanded(child: Text('${r['invoice_no'] ?? '-'}', style: const TextStyle(fontSize: 9))), Expanded(flex: 3, child: Text('SALES INVOICE FOR ${r['customer_name']}', style: const TextStyle(fontSize: 9))), Expanded(child: Text('₹${((r['grand_total'] as num?)?.toDouble() ?? 0).toStringAsFixed(2)}', style: const TextStyle(fontSize: 9, color: Color(0xFF2B8ED2)))), Expanded(child: const Text('-', style: TextStyle(fontSize: 9))), Expanded(child: Text('₹${((r['grand_total'] as num?)?.toDouble() ?? 0).toStringAsFixed(2)}', style: const TextStyle(fontSize: 9)))]))),
            ])),
          ] else
            const SizedBox(height: 190, child: Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.supervisor_account_outlined, size: 34, color: Color(0xFF607789)), SizedBox(height: 10), Text('Select a customer client database line row item to view accounts directory tracks.', style: TextStyle(fontSize: 11, color: Color(0xFF7A8595)))]))),
        ]),
      ),
    );
  }

  Widget _ledgerCard(String title, double value, Color color) {
    return Expanded(child: Container(height: 54, padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: Colors.white, border: Border.all(color: _border)), child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [Text(title, style: const TextStyle(fontSize: 7.5, color: Color(0xFF748094))), const SizedBox(height: 3), Text('₹ ${value.toStringAsFixed(2)}', style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w800))])));
  }

  Widget _empty() => const Padding(padding: EdgeInsets.all(40), child: Center(child: Text('No sales records found.', style: TextStyle(fontSize: 11, color: Color(0xFF748094)))));
}
