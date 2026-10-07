import '../widgets/purchase_order_document.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/ultra_repository.dart';
import '../widgets/compact_date_picker.dart';
import '../widgets/enterprise_widgets.dart';
import '../widgets/purchase_Report.dart';

class PurchaseReportsScreen extends StatefulWidget {
  const PurchaseReportsScreen({super.key});
  @override
  State<PurchaseReportsScreen> createState() => _PurchaseReportsScreenState();
}

class _PurchaseReportsScreenState extends State<PurchaseReportsScreen> {
  final repo = UltraRepository.instance;
  bool loading = true;
  List<Map<String, dynamic>> vouchers = [];
  List<Map<String, dynamic>> purchaseOrders = [];
  List<Map<String, dynamic>> payments = [];
  List<Map<String, dynamic>> suppliers = [];

  int tabIndex = 0; // 0 = Ledger View, 1 = Audit Report, 2 = View Ledger Wise
  final searchCtrl = TextEditingController();
  DateTimeRange? dateRange;
  int? selectedSupplierId;

  double _numValue(dynamic value) {
    if (value is num) return value.toDouble();

    if (value is String) {
      return double.tryParse(value.trim()) ?? 0.0;
    }

    return 0.0;
  }

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    setState(() => loading = true);
    vouchers = await repo.purchaseVouchersWithParty();
    purchaseOrders = await repo.purchaseOrdersWithParty();
    payments = await repo.allPayments();
    suppliers = await repo.suppliers();

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
  double get totalPurchaseCr {
    return vouchers.fold(
      0.0,
      (s, v) => s + _numValue(v['grand_total']),
    );
  }

  double get totalPurchaseOrderValue {
    return purchaseOrders.fold(
      0.0,
      (s, po) => s + _numValue(po['grand_total']),
    );
  }

  double get totalPaidDr {
    return payments.fold(
      0.0,
      (s, p) => s + _numValue(p['amount']),
    );
  }

  double get netOpeningPayable {
    return suppliers.fold(
      0.0,
      (s, sup) =>
          s +
          _numValue(sup['opening_balance_cr']) -
          _numValue(sup['opening_balance_dr']),
    );
  }

  double get outstandingBalance =>
      netOpeningPayable + totalPurchaseCr - totalPaidDr;

  String _supplierName(dynamic supplierId) {
    final id =
        supplierId is num ? supplierId.toInt() : int.tryParse('$supplierId');

    if (id == null) return 'Supplier -';

    for (final supplier in suppliers) {
      final supplierIdValue = supplier['id'] is num
          ? (supplier['id'] as num).toInt()
          : int.tryParse('${supplier['id']}');

      if (supplierIdValue == id) {
        return '${supplier['supplier_name'] ?? 'Supplier #$id'}';
      }
    }

    return 'Supplier #$id';
  }

  List<Map<String, dynamic>> get filteredPurchaseRecords {
    final list = <Map<String, dynamic>>[];

    // Purchase Orders
    for (final po in purchaseOrders) {
      list.add({
        ...po,
        '_record_type': 'PURCHASE ORDER',
        '_display_no': po['po_bill_no'] ?? 'PO-${po['po_no'] ?? po['id']}',
        '_display_date': po['po_date'],
        '_display_party': _supplierName(po['supplier_id']),
      });
    }

    // Purchase Vouchers
    for (final v in vouchers) {
      list.add({
        ...v,
        '_record_type': 'PURCHASE VOUCHER',
        '_display_no':
            v['supplier_invoice_no'] ?? 'PV-${v['voucher_no'] ?? v['id']}',
        '_display_date': v['voucher_date'],
        '_display_party': v['party_name'] ?? '-',
      });
    }

    var result = list;

    final q = searchCtrl.text.trim().toLowerCase();

    if (q.isNotEmpty) {
      result = result.where((v) {
        return '${v['_display_party']}'.toLowerCase().contains(q) ||
            '${v['_display_no']}'.toLowerCase().contains(q) ||
            '${v['po_no'] ?? ''}'.toLowerCase().contains(q) ||
            '${v['voucher_no'] ?? ''}'.toLowerCase().contains(q) ||
            '${v['_display_date'] ?? ''}'.toLowerCase().contains(q) ||
            '${v['status'] ?? ''}'.toLowerCase().contains(q);
      }).toList();
    }

    if (dateRange != null) {
      result = result.where((v) {
        final d = DateTime.tryParse('${v['_display_date'] ?? ''}');
        if (d == null) return false;

        final start = DateTime(
          dateRange!.start.year,
          dateRange!.start.month,
          dateRange!.start.day,
        );

        final end = DateTime(
          dateRange!.end.year,
          dateRange!.end.month,
          dateRange!.end.day,
          23,
          59,
          59,
        );

        return !d.isBefore(start) && !d.isAfter(end);
      }).toList();
    }

    result.sort(
      (a, b) => '${b['_display_date'] ?? ''}'
          .compareTo('${a['_display_date'] ?? ''}'),
    );

    return result;
  }

  String _fmtDate(String? iso) {
    final d = DateTime.tryParse(iso ?? '');
    return d == null ? (iso ?? '-') : DateFormat('dd-MM-yyyy').format(d);
  }

  @override
  void dispose() {
    searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (loading)
      return const Center(
          child: Padding(
              padding: EdgeInsets.all(40), child: CircularProgressIndicator()));
    final pagePad = AppBreakpoints.pagePadding(context);
    return SingleChildScrollView(
      padding: EdgeInsets.all(pagePad),
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
    final narrow = AppBreakpoints.isNarrow(context);
    final titles = [
      'REAL-TIME PROCUREMENT MONITORING & SUPPLIER LEDGER ENTRIES DIRECTORY',
      'REAL-TIME PROCUREMENT MONITORING & SUPPLIER LEDGER ENTRIES DIRECTORY',
      'INDIVIDUAL SUPPLIER DETAILED ACCOUNT LEDGER BOOK STATEMENT',
    ];
    final titleBlock = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'PURCHASE LEDGER AUDIT SYSTEM',
          style: TextStyle(
            fontSize: narrow ? 16 : 20,
            fontWeight: FontWeight.w900,
            color: navy,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          titles[tabIndex],
          style: TextStyle(
            fontSize: narrow ? 9 : 10,
            fontWeight: FontWeight.w700,
            color: const Color(0xFF748094),
          ),
        ),
      ],
    );
    final actions = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _tabSelector(),
        if (tabIndex != 0) ...[
          const SizedBox(width: 10),
          _printButton(),
        ],
      ],
    );
    if (narrow) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          titleBlock,
          const SizedBox(height: 10),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: actions,
          ),
        ],
      );
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: titleBlock),
        actions,
      ],
    );
  }

  Widget _tabSelector() {
    final labels = ['LEDGER VIEW', 'AUDIT REPORT', 'VIEW LEDGER WISE'];
    return Container(
      decoration: BoxDecoration(
          border: Border.all(color: border),
          borderRadius: BorderRadius.circular(4)),
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
                      color:
                          selected ? Colors.white : const Color(0xFF748094))),
            ),
          );
        }),
      ),
    );
  }

  Widget _printButton() => InkWell(
        onTap: () async {
          if (tabIndex == 1) {
            await printPurchaseAuditReport(
              vouchers,
              purchaseOrders,
            );
          } else if (tabIndex == 2 && selectedSupplierId != null) {
            await _printLedgerWiseStatement();
          }
        },
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            border: Border.all(color: border),
            borderRadius: BorderRadius.circular(4),
          ),
          child: const Icon(
            Icons.print_outlined,
            size: 18,
            color: Color(0xFFB8860B),
          ),
        ),
      );

  Widget _statCardsRow() => responsiveRowOrColumn(
        context,
        [
          _statCard(
            'TOTAL PURCHASE (CR)',
            '₹${totalPurchaseCr.toStringAsFixed(2)}',
            '${vouchers.length} purchase vouchers',
            Icons.shopping_cart_outlined,
            const Color(0xFFDD7A29),
          ),
          _statCard(
            'TOTAL PAID (DR)',
            '₹${totalPaidDr.toStringAsFixed(2)}',
            '${payments.length} payments',
            Icons.credit_card_outlined,
            const Color(0xFF2E6FDD),
          ),
          _statCard(
            'OUTSTANDING BALANCE',
            '₹${outstandingBalance.toStringAsFixed(2)}',
            'net payable to suppliers',
            Icons.account_balance_wallet_outlined,
            const Color(0xFFD1467A),
          ),
        ],
        spacing: 12,
      );

  Widget _statCard(
          String label, String value, String sub, IconData icon, Color color) =>
      Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: border)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                  color: color.withOpacity(.12), shape: BoxShape.circle),
              child: Icon(icon, size: 15, color: color),
            ),
            const SizedBox(width: 8),
            Expanded(
                child: Text(label,
                    style: const TextStyle(
                        fontSize: 9.5,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF748094),
                        letterSpacing: .3))),
          ]),
          const SizedBox(height: 12),
          Text(value,
              style: TextStyle(
                  fontSize: 20, fontWeight: FontWeight.w900, color: color)),
          const SizedBox(height: 4),
          Text(sub,
              style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF9AA5B4))),
        ]),
      );

  Widget _searchAndDateFilter() {
    final searchField = Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        border: Border.all(color: border),
        borderRadius: BorderRadius.circular(4),
      ),
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
              hintText:
                  'Filter by date (YYYY-MM-DD), procurement voucher ID or supplier profile name...',
              hintStyle: TextStyle(fontSize: 11.5, color: Color(0xFF9AA5B4)),
            ),
            style: const TextStyle(fontSize: 12),
          ),
        ),
      ]),
    );
    final dateBar = CompactDateRangeBar(
      from: dateRange?.start,
      to: dateRange?.end,
      onFromChanged: (d) => setState(() {
        final end = dateRange?.end ?? d;
        dateRange = DateTimeRange(start: d, end: end.isBefore(d) ? d : end);
      }),
      onToChanged: (d) => setState(() {
        final start = dateRange?.start ?? d;
        dateRange = DateTimeRange(start: start, end: d);
      }),
      onClear: () => setState(() => dateRange = null),
    );
    if (AppBreakpoints.isNarrow(context)) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          searchField,
          const SizedBox(height: 8),
          Align(alignment: Alignment.centerLeft, child: dateBar),
        ],
      );
    }
    return Row(children: [
      Expanded(child: searchField),
      const SizedBox(width: 12),
      dateBar,
    ]);
  }

  // ---- Tab 0: Ledger View ----
  Widget _ledgerViewList() {
    final list = filteredPurchaseRecords;

    if (list.isEmpty) {
      return _emptyState('No purchase records match the current filters.');
    }

    return Column(
      children: list.map((v) {
        final type = '${v['_record_type']}';
        final isPo = type == 'PURCHASE ORDER';

        final status = '${v['status'] ?? (isPo ? 'PENDING' : 'POSTED')}';

        final total = _numValue(v['grand_total']);

        final party = '${v['_display_party']}';
        final displayNo = '${v['_display_no']}';
        final displayDate = '${v['_display_date'] ?? ''}';

        final narrow = AppBreakpoints.isNarrow(context);
        final amountCol = _amountColumn(
          isPo ? 'ORDER VALUE' : 'PROCUREMENT VALUE (CR)',
          '₹${total.toStringAsFixed(0)}',
          isPo ? const Color(0xFF2E6FDD) : const Color(0xFFDD3B3B),
        );
        final details = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 8,
              runSpacing: 6,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(party, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800)),
                _badge(type, isPo ? const Color(0xFF2E6FDD) : const Color(0xFF748094)),
                _badge(status, status == 'POSTED' || status == 'RECEIVED' ? const Color(0xFF2E8B30) : const Color(0xFFB8860B)),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              '${isPo ? 'PO NO' : 'VOUCHER NO'}: '
              '${isPo ? (v['po_no'] ?? '-') : (v['voucher_no'] ?? '-')}'
              '  •  REF: $displayNo'
              '  •  DATE: ${_fmtDate(displayDate)}',
              style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Color(0xFFB8860B)),
            ),
          ],
        );
        return Container(
          margin: const EdgeInsets.only(bottom: 1),
          padding: const EdgeInsets.symmetric(
            vertical: 14,
            horizontal: 4,
          ),
          decoration: const BoxDecoration(
            border: Border(
              bottom: BorderSide(color: border),
            ),
          ),
          child: narrow
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    details,
                    const SizedBox(height: 8),
                    amountCol,
                    if (isPo) ...[
                      const SizedBox(height: 8),
                      OutlinedButton.icon(
                        onPressed: () async {
                          final id = v['id'] as int?;
                          if (id == null) return;
                          await reprintPurchaseOrder(id);
                        },
                        icon: const Icon(Icons.print_outlined, size: 14),
                        label: const Text('REPRINT', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800)),
                        style: OutlinedButton.styleFrom(foregroundColor: navy, side: const BorderSide(color: border)),
                      ),
                    ] else ...[
                      const SizedBox(height: 8),
                      OutlinedButton.icon(
                        onPressed: () async {
                          final id = v['id'] as int?;
                          if (id == null) return;
                          await printPurchaseVoucherReprint(v);
                        },
                        icon: const Icon(Icons.print_outlined, size: 14),
                        label: const Text('REPRINT', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800)),
                        style: OutlinedButton.styleFrom(foregroundColor: navy, side: const BorderSide(color: border)),
                      ),
                    ],
                  ],
                )
              : Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(child: details),
              if (!isPo) const SizedBox(width: 24),
              amountCol,
              const SizedBox(width: 16),
              if (isPo)
                OutlinedButton.icon(
                  onPressed: () async {
                    final id = v['id'] as int?;
                    if (id == null) return;

                    final bundle = await repo.purchaseOrderPrintBundle(id);

                    if (bundle == null) return;

                    await reprintPurchaseOrder(id);
                  },
                  icon: const Icon(
                    Icons.print_outlined,
                    size: 14,
                  ),
                  label: const Text(
                    'REPRINT PO',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: navy,
                    side: const BorderSide(color: border),
                  ),
                )
              else
                OutlinedButton.icon(
                  onPressed: () async {
                    final id = v['id'] as int?;
                    if (id == null) return;

                    await printPurchaseVoucherReprint(v);
                  },
                  icon: const Icon(
                    Icons.print_outlined,
                    size: 14,
                  ),
                  label: const Text(
                    'REPRINT',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: navy,
                    side: const BorderSide(color: border),
                  ),
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
          Text(label,
              style: const TextStyle(
                  fontSize: 8.5,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF9AA5B4))),
          const SizedBox(height: 2),
          Text(value,
              style: TextStyle(
                  fontSize: 13, fontWeight: FontWeight.w800, color: color)),
        ],
      );

  Widget _badge(String text, Color color) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
            color: color.withOpacity(.12),
            borderRadius: BorderRadius.circular(3)),
        child: Text(text,
            style: TextStyle(
                fontSize: 8, fontWeight: FontWeight.w800, color: color)),
      );

  // ---- Tab 1: Audit Report ----
  Widget _auditReportTable() {
    if (purchaseOrders.isEmpty && vouchers.isEmpty) {
      return _emptyState('No purchase records recorded yet.');
    }

    final byDate = <String, List<Map<String, dynamic>>>{};

    // ---------------- PURCHASE ORDERS ----------------
    for (final po in purchaseOrders) {
      final date = '${po['po_date'] ?? '-'}';

      byDate.putIfAbsent(date, () => []).add({
        ...po,
        '_record_type': 'PURCHASE ORDER',
        '_display_no': po['po_bill_no'] ?? 'PO-${po['po_no'] ?? po['id']}',
        '_display_party': _supplierName(po['supplier_id']),
      });
    }

    // ---------------- PURCHASE VOUCHERS ----------------
    for (final v in vouchers) {
      final date = '${v['voucher_date'] ?? '-'}';

      byDate.putIfAbsent(date, () => []).add({
        ...v,
        '_record_type': 'PURCHASE VOUCHER',
        '_display_no':
            v['supplier_invoice_no'] ?? 'PV-${v['voucher_no'] ?? v['id']}',
        '_display_party': v['party_name'] ?? '-',
      });
    }

    final dates = byDate.keys.toList()..sort((a, b) => b.compareTo(a));

    double gTaxable = 0;
    double gCgst = 0;
    double gSgst = 0;
    double gIgst = 0;
    double gTotal = 0;

    double poTotal = 0;
    double voucherTotal = 0;

    final rows = <TableRow>[
      const TableRow(
        children: [
          _AuditHeaderCell('TYPE'),
          _AuditHeaderCell('INV / BILL NO'),
          _AuditHeaderCell('PARTY NAME'),
          _AuditHeaderCell('TAXABLE'),
          _AuditHeaderCell('CGST'),
          _AuditHeaderCell('SGST'),
          _AuditHeaderCell('IGST'),
          _AuditHeaderCell('TOTAL'),
        ],
      ),
    ];

    // ---------------- DATE GROUPS ----------------
    for (final date in dates) {
      final list = byDate[date]!;

      double taxable = 0;
      double cgst = 0;
      double sgst = 0;
      double igst = 0;
      double total = 0;

      rows.add(
        TableRow(
          children: [
            Padding(
              padding: const EdgeInsets.only(
                top: 14,
                bottom: 4,
              ),
              child: Text(
                _fmtDate(date),
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            const SizedBox(),
            const SizedBox(),
            const SizedBox(),
            const SizedBox(),
            const SizedBox(),
            const SizedBox(),
            const SizedBox(),
          ],
        ),
      );

      for (final record in list) {
        final type = '${record['_record_type']}';
        final isPo = type == 'PURCHASE ORDER';
        final recordTaxable = _numValue(record['taxable_total']);
        final recordCgst = _numValue(record['cgst_total']);
        final recordSgst = _numValue(record['sgst_total']);
        final recordIgst = _numValue(record['igst_total']);
        final recordTotal = _numValue(record['grand_total']);

        taxable += recordTaxable;
        cgst += recordCgst;
        sgst += recordSgst;
        igst += recordIgst;
        total += recordTotal;

        gTaxable += recordTaxable;
        gCgst += recordCgst;
        gSgst += recordSgst;
        gIgst += recordIgst;
        gTotal += recordTotal;

        if (isPo) {
          poTotal += recordTotal;
        } else {
          voucherTotal += recordTotal;
        }

        rows.add(
          TableRow(
            children: [
              _AuditCell(
                isPo ? 'PO' : 'VOUCHER',
                bold: true,
              ),
              _AuditCell(
                '${record['_display_no']}',
              ),
              _AuditCell(
                '${record['_display_party']}',
              ),
              _AuditCell(
                recordTaxable.toStringAsFixed(2),
              ),
              _AuditCell(
                recordCgst.toStringAsFixed(2),
              ),
              _AuditCell(
                recordSgst.toStringAsFixed(2),
              ),
              _AuditCell(
                recordIgst.toStringAsFixed(2),
              ),
              _AuditCell(
                recordTotal.toStringAsFixed(2),
                bold: true,
              ),
            ],
          ),
        );
      }

      // ---------------- DATE TOTAL ----------------
      rows.add(
        TableRow(
          children: [
            const SizedBox(),
            const SizedBox(),
            const SizedBox(),
            _AuditCell(
              taxable.toStringAsFixed(2),
              muted: true,
            ),
            _AuditCell(
              cgst.toStringAsFixed(2),
              muted: true,
            ),
            _AuditCell(
              sgst.toStringAsFixed(2),
              muted: true,
            ),
            _AuditCell(
              igst.toStringAsFixed(2),
              muted: true,
            ),
            _AuditCell(
              total.toStringAsFixed(2),
              muted: true,
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        responsiveHorizontalTable(
          context,
          Table(
            columnWidths: const {
              0: FlexColumnWidth(1.3),
              1: FlexColumnWidth(2.2),
              2: FlexColumnWidth(2.8),
              3: FlexColumnWidth(1.4),
              4: FlexColumnWidth(1.3),
              5: FlexColumnWidth(1.3),
              6: FlexColumnWidth(1.3),
              7: FlexColumnWidth(1.5),
            },
            children: rows,
          ),
        ),

        const SizedBox(height: 16),

        // ---------------- SUMMARY ----------------
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFFF7F8FA),
            border: Border.all(color: border),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'AUDIT SUMMARY',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                  color: navy,
                ),
              ),
              const SizedBox(height: 10),
              responsiveRowOrColumn(
                context,
                [
                  _auditSummaryItem('PURCHASE ORDER VALUE', poTotal),
                  _auditSummaryItem('PURCHASE VOUCHER VALUE', voucherTotal),
                  _auditSummaryItem('TOTAL RECORD VALUE', gTotal),
                ],
                spacing: 12,
              ),
              const SizedBox(height: 12),
              const Divider(),
              const SizedBox(height: 8),
              Row(
                children: [
                  const Text(
                    'TAXABLE',
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF748094),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Text(
                    gTaxable.toStringAsFixed(2),
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(width: 30),
                  const Text(
                    'CGST',
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF748094),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Text(
                    gCgst.toStringAsFixed(2),
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(width: 30),
                  const Text(
                    'SGST',
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF748094),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Text(
                    gSgst.toStringAsFixed(2),
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(width: 30),
                  const Text(
                    'IGST',
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF748094),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Text(
                    gIgst.toStringAsFixed(2),
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _auditSummaryItem(String label, double value) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: border),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 8.5,
              fontWeight: FontWeight.w800,
              color: Color(0xFF9AA5B4),
            ),
          ),
          const SizedBox(height: 5),
          Text(
            '₹${value.toStringAsFixed(2)}',
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w900,
              color: navy,
            ),
          ),
        ],
      ),
    );
  }

  // ---- Tab 2: View Ledger Wise ----
  Future<_LedgerWiseData> _computeLedgerWise(int supplierId) async {
    final supplier = await repo.supplierById(supplierId) ?? {};
    final sVouchers = await repo.purchaseVouchersForSupplier(supplierId);
    final sPayments = await repo.paymentsForSupplier(supplierId);

    final opening = _numValue(supplier['opening_balance_dr']) -
        _numValue(supplier['opening_balance_cr']);

    final entries = <Map<String, dynamic>>[];
    for (final v in sVouchers) {
      entries.add({
        'date': v['voucher_date'],
        'type': 'PURCHASE',
        'ref': 'PV-${v['voucher_no']}',
        'narration': v['supplier_invoice_no'] ?? '-',
        'debit': 0.0,
        'credit': _numValue(v['grand_total']),
      });
    }
    for (final p in sPayments) {
      entries.add({
        'date': p['payment_date'],
        'type': 'PAYMENT',
        'ref': p['reference_no'] ?? '-',
        'narration': p['narration'] ?? '-',
        'debit': _numValue(p['amount']),
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
          decoration: BoxDecoration(
              border: Border.all(color: border),
              borderRadius: BorderRadius.circular(4)),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<int>(
              isExpanded: true,
              value: selectedSupplierId,
              items: suppliers
                  .map((s) => DropdownMenuItem<int>(
                        value: s['id'] as int,
                        child: Text('${s['id']} - ${s['supplier_name']}',
                            style: const TextStyle(
                                fontSize: 12.5, fontWeight: FontWeight.w700)),
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
              if (!snap.hasData)
                return const Padding(
                    padding: EdgeInsets.all(24),
                    child: CircularProgressIndicator());
              final data = snap.data!;
              _cachedLedgerWise = data;
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  responsiveRowOrColumn(
                    context,
                    [
                      _ledgerStat('OPENING BALANCE', data.opening),
                      _ledgerStat('TOTAL PURCHASES (CR)', data.totalCredit),
                      _ledgerStat('TOTAL PAYMENTS (DR)', data.totalDebit),
                      _ledgerStat('NET PAYABLE CLOSING', data.closing),
                    ],
                    spacing: 12,
                  ),
                  const SizedBox(height: 16),
                  if (data.rows.isEmpty)
                    _emptyState(
                        'No financial ledger logs recorded for selected timeframe parameters.')
                  else
                    responsiveHorizontalTable(
                      context,
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
                            _AuditCell((r['debit'] as double) == 0
                                ? '-'
                                : (r['debit'] as double).toStringAsFixed(2)),
                            _AuditCell((r['credit'] as double) == 0
                                ? '-'
                                : (r['credit'] as double).toStringAsFixed(2)),
                            _AuditCell(
                                (r['balance'] as double).toStringAsFixed(2),
                                bold: true),
                          ]),
                      ],
                    ),
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
        decoration: BoxDecoration(
            color: const Color(0xFFF7F8FA),
            border: Border.all(color: border),
            borderRadius: BorderRadius.circular(4)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label,
              style: const TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF9AA5B4))),
          const SizedBox(height: 6),
          Text('₹${value.toStringAsFixed(2)}',
              style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w900,
                  color: value < 0 ? const Color(0xFFDD3B3B) : navy)),
        ]),
      );

  Widget _emptyState(String msg) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
            color: const Color(0xFFF7F8FA),
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: border)),
        child: Text(msg,
            style: const TextStyle(
                color: Color(0xFF748094),
                fontSize: 12,
                fontWeight: FontWeight.w600)),
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
        decoration: const BoxDecoration(
            border: Border(bottom: BorderSide(color: border, width: 1.2))),
        child: Text(text,
            style: const TextStyle(
                fontSize: 9.5,
                fontWeight: FontWeight.w800,
                color: Color(0xFF748094))),
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
              fontWeight: bold
                  ? FontWeight.w800
                  : (muted ? FontWeight.w600 : FontWeight.w500),
              color: muted ? const Color(0xFF9AA5B4) : Colors.black87,
            )),
      );
}
