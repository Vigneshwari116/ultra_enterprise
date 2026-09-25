import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../database/app_database.dart';
import '../widgets/enterprise_widgets.dart';
import '../widgets/purchase_Report.dart';

class PurchaseReportsScreen extends StatefulWidget {
  const PurchaseReportsScreen({super.key});
  @override
  State<PurchaseReportsScreen> createState() => _PurchaseReportsScreenState();
}

class _PurchaseReportsScreenState extends State<PurchaseReportsScreen> {
  final db = AppDatabase.instance;
  bool loading = true;

  List<Map<String, dynamic>> vouchers = [];
  List<Map<String, dynamic>> payments = [];
  List<Map<String, dynamic>> suppliers = [];
  Map<int, double> paidBySupplier = {};

  int tabIndex = 0; // 0 = Ledger View, 1 = Audit Report, 2 = View Ledger Wise
  final searchCtrl = TextEditingController();
  DateTimeRange? dateRange;
  int? selectedSupplierId;

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    setState(() => loading = true);
    vouchers = await db.purchaseVouchersWithParty();
    payments = await db.allPayments();
    suppliers = await db.suppliers();

    paidBySupplier = {};
    for (final p in payments) {
      final sid = p['supplier_id'] as int?;
      if (sid == null) continue;
      paidBySupplier[sid] = (paidBySupplier[sid] ?? 0) + ((p['amount'] ?? 0) as num).toDouble();
    }

    if (selectedSupplierId == null && suppliers.isNotEmpty) {
      selectedSupplierId = suppliers.first['id'] as int;
    }
    if (selectedSupplierId != null) {
      _ledgerWiseFuture = _computeLedgerWise(selectedSupplierId!);
    }
    if (mounted) setState(() => loading = false);
  }

  Future<_LedgerWiseData>? _ledgerWiseFuture;

  // ---- Aggregates ----
  double get totalPurchaseCr => vouchers.fold(0.0, (s, v) => s + ((v['grand_total'] ?? 0) as num).toDouble());
  double get totalPaidDr => payments.fold(0.0, (s, p) => s + ((p['amount'] ?? 0) as num).toDouble());
  double get netOpeningPayable => suppliers.fold(
      0.0,
          (s, sup) =>
      s +
          ((sup['opening_balance_cr'] ?? 0) as num).toDouble() -
          ((sup['opening_balance_dr'] ?? 0) as num).toDouble());
  double get outstandingBalance => netOpeningPayable + totalPurchaseCr - totalPaidDr;

  List<Map<String, dynamic>> get filteredVouchers {
    var list = vouchers;
    final q = searchCtrl.text.trim().toLowerCase();
    if (q.isNotEmpty) {
      list = list.where((v) {
        return '${v['party_name']}'.toLowerCase().contains(q) ||
            '${v['supplier_invoice_no'] ?? ''}'.toLowerCase().contains(q) ||
            '${v['voucher_no'] ?? ''}'.toLowerCase().contains(q) ||
            '${v['voucher_date'] ?? ''}'.contains(q);
      }).toList();
    }
    if (dateRange != null) {
      list = list.where((v) {
        final d = DateTime.tryParse((v['voucher_date'] as String?) ?? '');
        if (d == null) return false;
        return !d.isBefore(dateRange!.start) && !d.isAfter(dateRange!.end);
      }).toList();
    }
    return list;
  }

  String _fmtDate(String? iso) {
    final d = DateTime.tryParse(iso ?? '');
    return d == null ? (iso ?? '-') : DateFormat('dd-MM-yyyy').format(d);
  }

  @override
  Widget build(BuildContext context) {
    if (loading) return const Center(child: Padding(padding: EdgeInsets.all(40), child: CircularProgressIndicator()));
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _header(),
          const SizedBox(height: 18),
          if (tabIndex != 2) _statCardsRow(),
          if (tabIndex != 2) const SizedBox(height: 16),
          if (tabIndex == 0) _searchAndDateFilter(),
          if (tabIndex == 0) const SizedBox(height: 4),
          const SizedBox(height: 10),
          if (tabIndex == 0) _ledgerViewList(),
          if (tabIndex == 1) _auditReportTable(),
          if (tabIndex == 2) _ledgerWiseView(),
        ],
      ),
    );
  }

  Widget _header() {
    final titles = [
      'REAL-TIME PROCUREMENT MONITORING & SUPPLIER LEDGER ENTRIES DIRECTORY',
      'REAL-TIME PROCUREMENT MONITORING & SUPPLIER LEDGER ENTRIES DIRECTORY',
      'INDIVIDUAL SUPPLIER DETAILED ACCOUNT LEDGER BOOK STATEMENT',
    ];
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('PURCHASE LEDGER AUDIT SYSTEM',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: navy)),
              const SizedBox(height: 4),
              Text(titles[tabIndex],
                  style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Color(0xFF748094))),
            ],
          ),
        ),
        _tabSelector(),
        if (tabIndex != 0) ...[
          const SizedBox(width: 10),
          _printButton(),
        ],
      ],
    );
  }

  Widget _tabSelector() {
    final labels = ['LEDGER VIEW', 'AUDIT REPORT', 'VIEW LEDGER WISE'];
    return Container(
      decoration: BoxDecoration(border: Border.all(color: border), borderRadius: BorderRadius.circular(4)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: List.generate(labels.length, (i) {
          final selected = tabIndex == i;
          return InkWell(
            onTap: () => setState(() => tabIndex = i),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(color: selected ? navy : Colors.white),
              child: Text(labels[i],
                  style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w800,
                      color: selected ? Colors.white : const Color(0xFF748094))),
            ),
          );
        }),
      ),
    );
  }

  Widget _printButton() => InkWell(
    onTap: () async {
      if (tabIndex == 1) {
        await printPurchaseAuditReport(vouchers);
      } else if (tabIndex == 2 && selectedSupplierId != null) {
        await _printLedgerWiseStatement();
      }
    },
    child: Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(border: Border.all(color: border), borderRadius: BorderRadius.circular(4)),
      child: const Icon(Icons.print_outlined, size: 18, color: Color(0xFFB8860B)),
    ),
  );

  Widget _statCardsRow() => Row(children: [
    Expanded(
        child: _statCard('TOTAL PURCHASE (CR)', '₹${totalPurchaseCr.toStringAsFixed(2)}',
            '${vouchers.length} vouchers', Icons.shopping_cart_outlined, const Color(0xFFDD7A29))),
    const SizedBox(width: 16),
    Expanded(
        child: _statCard('TOTAL PAID (DR)', '₹${totalPaidDr.toStringAsFixed(2)}', '${payments.length} payments',
            Icons.credit_card_outlined, const Color(0xFF2E6FDD))),
    const SizedBox(width: 16),
    Expanded(
        child: _statCard('OUTSTANDING BALANCE', '₹${outstandingBalance.toStringAsFixed(2)}',
            'net payable to suppliers', Icons.account_balance_wallet_outlined, const Color(0xFFD1467A))),
  ]);

  Widget _statCard(String label, String value, String sub, IconData icon, Color color) => Container(
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(6), border: Border.all(color: border)),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(color: color.withOpacity(.12), shape: BoxShape.circle),
          child: Icon(icon, size: 15, color: color),
        ),
        const SizedBox(width: 8),
        Expanded(
            child: Text(label,
                style: const TextStyle(fontSize: 9.5, fontWeight: FontWeight.w800, color: Color(0xFF748094), letterSpacing: .3))),
      ]),
      const SizedBox(height: 12),
      Text(value, style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: color)),
      const SizedBox(height: 4),
      Text(sub, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Color(0xFF9AA5B4))),
    ]),
  );

  Widget _searchAndDateFilter() => Row(children: [
    Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(border: Border.all(color: border), borderRadius: BorderRadius.circular(4)),
        child: Row(children: [
          const Icon(Icons.search, size: 16, color: Color(0xFF9AA5B4)),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: searchCtrl,
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(
                border: InputBorder.none,
                isDense: true,
                contentPadding: EdgeInsets.symmetric(vertical: 12),
                hintText: 'Filter by date (YYYY-MM-DD), procurement voucher ID or supplier profile name...',
                hintStyle: TextStyle(fontSize: 11.5, color: Color(0xFF9AA5B4)),
              ),
              style: const TextStyle(fontSize: 12),
            ),
          ),
        ]),
      ),
    ),
    const SizedBox(width: 12),
    InkWell(
      onTap: () async {
        final now = DateTime.now();
        final picked = await showDateRangePicker(
          context: context,
          firstDate: DateTime(now.year - 5),
          lastDate: DateTime(now.year + 1),
          initialDateRange: dateRange,
        );
        if (picked != null) setState(() => dateRange = picked);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        decoration: BoxDecoration(border: Border.all(color: border), borderRadius: BorderRadius.circular(4)),
        child: Row(children: [
          const Icon(Icons.calendar_today_outlined, size: 14, color: Color(0xFF748094)),
          const SizedBox(width: 8),
          Text(
            dateRange == null
                ? 'DATE FILTER'
                : '${_fmtDate(dateRange!.start.toIso8601String())} - ${_fmtDate(dateRange!.end.toIso8601String())}',
            style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, color: Color(0xFF748094)),
          ),
          if (dateRange != null) ...[
            const SizedBox(width: 6),
            InkWell(onTap: () => setState(() => dateRange = null), child: const Icon(Icons.close, size: 13)),
          ],
        ]),
      ),
    ),
  ]);

  // ---- Tab 1: Ledger View ----
  Widget _ledgerViewList() {
    final list = filteredVouchers;
    if (list.isEmpty) return _emptyState('No purchase vouchers match the current filters.');
    return Column(
      children: list.map((v) {
        final sid = v['supplier_id'] as int?;
        final paid = sid != null ? (paidBySupplier[sid] ?? 0) : 0.0;
        final status = '${v['status'] ?? 'POSTED'}';
        return Container(
          margin: const EdgeInsets.only(bottom: 1),
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 4),
          decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: border))),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Text('${v['party_name']}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800)),
                      const SizedBox(width: 8),
                      _badge('PURCHASE VOUCHER', const Color(0xFF748094)),
                      const SizedBox(width: 6),
                      _badge(status, status == 'POSTED' ? const Color(0xFF2E8B30) : const Color(0xFFB8860B)),
                    ]),
                    const SizedBox(height: 4),
                    Text(
                      'SERIAL NO: ${v['voucher_no']}  •  VOUCHER REF ID: ${v['supplier_invoice_no'] ?? 'PV-${v['voucher_no']}'}  •  BILL DATE: ${_fmtDate(v['voucher_date'] as String?)}',
                      style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Color(0xFFB8860B)),
                    ),
                  ],
                ),
              ),
              _amountColumn('PAID AMOUNT (DR)', '₹${paid.toStringAsFixed(0)}', const Color(0xFF2E6FDD)),
              const SizedBox(width: 24),
              _amountColumn('PROCUREMENT VALUE (CR)', '₹${((v['grand_total'] ?? 0) as num).toStringAsFixed(0)}',
                  const Color(0xFFDD3B3B)),
              const SizedBox(width: 16),
              OutlinedButton.icon(
                onPressed: () async {
                  final items = await db.purchaseVoucherItems(v['id'] as int);
                  await printPurchaseVoucherReprint(v, items);
                },
                icon: const Icon(Icons.print_outlined, size: 14),
                label: const Text('REPRINT', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800)),
                style: OutlinedButton.styleFrom(foregroundColor: navy, side: const BorderSide(color: border)),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _amountColumn(String label, String value, Color color) => Column(
    crossAxisAlignment: CrossAxisAlignment.end,
    children: [
      Text(label, style: const TextStyle(fontSize: 8.5, fontWeight: FontWeight.w800, color: Color(0xFF9AA5B4))),
      const SizedBox(height: 2),
      Text(value, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: color)),
    ],
  );

  Widget _badge(String text, Color color) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
    decoration: BoxDecoration(color: color.withOpacity(.12), borderRadius: BorderRadius.circular(3)),
    child: Text(text, style: TextStyle(fontSize: 8, fontWeight: FontWeight.w800, color: color)),
  );

  // ---- Tab 2: Audit Report ----
  Widget _auditReportTable() {
    if (vouchers.isEmpty) return _emptyState('No purchase vouchers recorded yet.');
    final byDate = <String, List<Map<String, dynamic>>>{};
    for (final v in vouchers) {
      final key = (v['voucher_date'] as String?) ?? '-';
      byDate.putIfAbsent(key, () => []).add(v);
    }
    final dates = byDate.keys.toList()..sort((a, b) => b.compareTo(a));

    double gTaxable = 0, gCgst = 0, gSgst = 0, gIgst = 0, gTotal = 0;
    final rows = <TableRow>[
      const TableRow(children: [
        _AuditHeaderCell('INV / BILL NO'),
        _AuditHeaderCell('PARTY NAME'),
        _AuditHeaderCell('TAXABLE'),
        _AuditHeaderCell('CGST'),
        _AuditHeaderCell('SGST'),
        _AuditHeaderCell('IGST'),
        _AuditHeaderCell('TOTAL'),
      ]),
    ];

    for (final date in dates) {
      final list = byDate[date]!;
      double taxable = 0, cgst = 0, sgst = 0, igst = 0, total = 0;
      rows.add(TableRow(children: [
        Padding(
          padding: const EdgeInsets.only(top: 14, bottom: 4),
          child: Text(_fmtDate(date), style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800)),
        ),
        const SizedBox(), const SizedBox(), const SizedBox(), const SizedBox(), const SizedBox(), const SizedBox(),
      ]));
      for (final v in list) {
        taxable += ((v['taxable_total'] ?? 0) as num).toDouble();
        cgst += ((v['cgst_total'] ?? 0) as num).toDouble();
        sgst += ((v['sgst_total'] ?? 0) as num).toDouble();
        igst += ((v['igst_total'] ?? 0) as num).toDouble();
        total += ((v['grand_total'] ?? 0) as num).toDouble();
        rows.add(TableRow(children: [
          _AuditCell('${v['supplier_invoice_no'] ?? 'PV-${v['voucher_no']}'}'),
          _AuditCell('${v['party_name']}'),
          _AuditCell(((v['taxable_total'] ?? 0) as num).toStringAsFixed(2)),
          _AuditCell(((v['cgst_total'] ?? 0) as num).toStringAsFixed(2)),
          _AuditCell(((v['sgst_total'] ?? 0) as num).toStringAsFixed(2)),
          _AuditCell(((v['igst_total'] ?? 0) as num).toStringAsFixed(2)),
          _AuditCell(((v['grand_total'] ?? 0) as num).toStringAsFixed(2), bold: true),
        ]));
      }
      rows.add(TableRow(children: [
        const SizedBox(),
        const SizedBox(),
        _AuditCell(taxable.toStringAsFixed(2), muted: true),
        _AuditCell(cgst.toStringAsFixed(2), muted: true),
        _AuditCell(sgst.toStringAsFixed(2), muted: true),
        _AuditCell(igst.toStringAsFixed(2), muted: true),
        _AuditCell(total.toStringAsFixed(2), muted: true),
      ]));
      gTaxable += taxable; gCgst += cgst; gSgst += sgst; gIgst += igst; gTotal += total;
    }

    return Column(children: [
      Table(
        columnWidths: const {
          0: FlexColumnWidth(2),
          1: FlexColumnWidth(3),
          2: FlexColumnWidth(1.4),
          3: FlexColumnWidth(1.4),
          4: FlexColumnWidth(1.4),
          5: FlexColumnWidth(1.4),
          6: FlexColumnWidth(1.6),
        },
        children: rows,
      ),
      const SizedBox(height: 12),
      Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(color: const Color(0xFFF0F2F5), border: Border.all(color: border)),
        child: Row(children: [
          const Text('GRAND TOTALS:', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900)),
          const Spacer(),
          Text('${gTaxable.toStringAsFixed(2)}   ${gCgst.toStringAsFixed(2)}   ${gSgst.toStringAsFixed(2)}   ${gIgst.toStringAsFixed(2)}   ',
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
          Text(gTotal.toStringAsFixed(2),
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: Color(0xFFDD3B3B))),
        ]),
      ),
    ]);
  }

  // ---- Tab 3: View Ledger Wise ----
  Future<_LedgerWiseData> _computeLedgerWise(int supplierId) async {
    final supplier = await db.supplierById(supplierId) ?? {};
    final sVouchers = await db.purchaseVouchersForSupplier(supplierId);
    final sPayments = await db.paymentsForSupplier(supplierId);

    final opening = ((supplier['opening_balance_dr'] ?? 0) as num).toDouble() -
        ((supplier['opening_balance_cr'] ?? 0) as num).toDouble();

    final entries = <Map<String, dynamic>>[];
    for (final v in sVouchers) {
      entries.add({
        'date': v['voucher_date'],
        'type': 'PURCHASE',
        'ref': 'PV-${v['voucher_no']}',
        'narration': v['supplier_invoice_no'] ?? '-',
        'debit': 0.0,
        'credit': ((v['grand_total'] ?? 0) as num).toDouble(),
      });
    }
    for (final p in sPayments) {
      entries.add({
        'date': p['payment_date'],
        'type': 'PAYMENT',
        'ref': p['reference_no'] ?? '-',
        'narration': p['narration'] ?? '-',
        'debit': ((p['amount'] ?? 0) as num).toDouble(),
        'credit': 0.0,
      });
    }
    entries.sort((a, b) => '${a['date']}'.compareTo('${b['date']}'));

    double running = opening;
    double totalDebit = 0, totalCredit = 0;
    final rows = <Map<String, dynamic>>[];
    for (final e in entries) {
      final debit = e['debit'] as double;
      final credit = e['credit'] as double;
      running = running + debit - credit;
      totalDebit += debit;
      totalCredit += credit;
      rows.add({...e, 'balance': running});
    }

    return _LedgerWiseData(
      supplier: supplier,
      rows: rows,
      opening: opening,
      totalDebit: totalDebit,
      totalCredit: totalCredit,
      closing: running,
    );
  }

  _LedgerWiseData? _cachedLedgerWise;

  Future<void> _printLedgerWiseStatement() async {
    final data = _cachedLedgerWise;
    if (data == null) return;
    await printVendorLedgerStatement(
      supplier: data.supplier,
      rows: data.rows,
      openingBalance: data.opening,
      totalDebit: data.totalDebit,
      totalCredit: data.totalCredit,
      closingBalance: data.closing,
    );
  }

  Widget _ledgerWiseView() {
    if (suppliers.isEmpty) return _emptyState('No suppliers recorded yet.');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
          decoration: BoxDecoration(border: Border.all(color: border), borderRadius: BorderRadius.circular(4)),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<int>(
              isExpanded: true,
              value: selectedSupplierId,
              items: suppliers
                  .map((s) => DropdownMenuItem<int>(
                value: s['id'] as int,
                child: Text('${s['id']} - ${s['supplier_name']}', style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700)),
              ))
                  .toList(),
              onChanged: (v) => setState(() {
                selectedSupplierId = v;
                if (v != null) _ledgerWiseFuture = _computeLedgerWise(v);
              }),
            ),
          ),
        ),
        const SizedBox(height: 16),
        if (selectedSupplierId != null && _ledgerWiseFuture != null)
          FutureBuilder<_LedgerWiseData>(
            future: _ledgerWiseFuture,
            builder: (context, snap) {
              if (!snap.hasData) return const Padding(padding: EdgeInsets.all(24), child: CircularProgressIndicator());
              final data = snap.data!;
              _cachedLedgerWise = data;
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Expanded(child: _ledgerStat('OPENING BALANCE', data.opening)),
                    const SizedBox(width: 16),
                    Expanded(child: _ledgerStat('TOTAL PURCHASES (CR)', data.totalCredit)),
                    const SizedBox(width: 16),
                    Expanded(child: _ledgerStat('TOTAL PAYMENTS (DR)', data.totalDebit)),
                    const SizedBox(width: 16),
                    Expanded(child: _ledgerStat('NET PAYABLE CLOSING', data.closing)),
                  ]),
                  const SizedBox(height: 16),
                  if (data.rows.isEmpty)
                    _emptyState('No financial ledger logs recorded for selected timeframe parameters.')
                  else
                    Table(
                      columnWidths: const {
                        0: FlexColumnWidth(1.4),
                        1: FlexColumnWidth(1.4),
                        2: FlexColumnWidth(1.6),
                        3: FlexColumnWidth(2.6),
                        4: FlexColumnWidth(1.4),
                        5: FlexColumnWidth(1.4),
                        6: FlexColumnWidth(1.6),
                      },
                      children: [
                        const TableRow(children: [
                          _AuditHeaderCell('DATE'),
                          _AuditHeaderCell('TXN TYPE'),
                          _AuditHeaderCell('REF / VOUCHER'),
                          _AuditHeaderCell('PARTICULARS / NARRATION'),
                          _AuditHeaderCell('DEBIT (DR)'),
                          _AuditHeaderCell('CREDIT (CR)'),
                          _AuditHeaderCell('BALANCE'),
                        ]),
                        for (final r in data.rows)
                          TableRow(children: [
                            _AuditCell(_fmtDate(r['date'] as String?)),
                            _AuditCell('${r['type']}'),
                            _AuditCell('${r['ref']}'),
                            _AuditCell('${r['narration']}'),
                            _AuditCell((r['debit'] as double) == 0 ? '-' : (r['debit'] as double).toStringAsFixed(2)),
                            _AuditCell((r['credit'] as double) == 0 ? '-' : (r['credit'] as double).toStringAsFixed(2)),
                            _AuditCell((r['balance'] as double).toStringAsFixed(2), bold: true),
                          ]),
                      ],
                    ),
                ],
              );
            },
          ),
      ],
    );
  }

  Widget _ledgerStat(String label, double value) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(color: const Color(0xFFF7F8FA), border: Border.all(color: border), borderRadius: BorderRadius.circular(4)),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: Color(0xFF9AA5B4))),
      const SizedBox(height: 6),
      Text('₹${value.toStringAsFixed(2)}',
          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: value < 0 ? const Color(0xFFDD3B3B) : navy)),
    ]),
  );

  Widget _emptyState(String msg) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(24),
    decoration: BoxDecoration(color: const Color(0xFFF7F8FA), borderRadius: BorderRadius.circular(4), border: Border.all(color: border)),
    child: Text(msg, style: const TextStyle(color: Color(0xFF748094), fontSize: 12, fontWeight: FontWeight.w600)),
  );
}

class _LedgerWiseData {
  final Map<String, dynamic> supplier;
  final List<Map<String, dynamic>> rows;
  final double opening;
  final double totalDebit;
  final double totalCredit;
  final double closing;
  _LedgerWiseData({
    required this.supplier,
    required this.rows,
    required this.opening,
    required this.totalDebit,
    required this.totalCredit,
    required this.closing,
  });
}

class _AuditHeaderCell extends StatelessWidget {
  final String text;
  const _AuditHeaderCell(this.text);
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
    decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: border, width: 1.2))),
    child: Text(text, style: const TextStyle(fontSize: 9.5, fontWeight: FontWeight.w800, color: Color(0xFF748094))),
  );
}

class _AuditCell extends StatelessWidget {
  final String text;
  final bool bold;
  final bool muted;
  const _AuditCell(this.text, {this.bold = false, this.muted = false});
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
    child: Text(text,
        style: TextStyle(
          fontSize: 11,
          fontWeight: bold ? FontWeight.w800 : (muted ? FontWeight.w600 : FontWeight.w500),
          color: muted ? const Color(0xFF9AA5B4) : Colors.black87,
        )),
  );
}
