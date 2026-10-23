import 'package:flutter/material.dart';
import '../services/ultra_repository.dart';
import '../utils/api_errors.dart';
import '../utils/party_directory.dart';
import '../widgets/adjustment_note_document.dart';
import '../widgets/compact_date_picker.dart';
import '../widgets/enterprise_widgets.dart';
import '../widgets/journal_summary_report.dart';
import '../utils/sales_invoice_display.dart';
import '../widgets/financial_reports.dart';
import '../widgets/sales_report.dart';
import '../utils/voucher_display.dart';

final reportsCenterKey = GlobalKey<SalesReportsScreenState>();

enum ReportsCenterMode {
  sales,
  journalSummary,
  noteHistory,
  partyLedger,
  trialBalance,
  cashBankBook,
}

abstract class SalesReportsScreenState extends State<SalesReportsScreen> {
  void showSalesReports();
  void showJournalSummary();
  void showDebitCreditHistory();
  void showPartyLedger();
  void showTrialBalance();
  void showCashBankBook();
}

const _navy = Color(0xFF122746);
const _pageBg = Color(0xFFF1F4F8);
const _border = Color(0xFFD8DEE7);
const _green = Color(0xFF2FAE55);
const _teal = Color(0xFF11B9B5);

class SalesReportsScreen extends StatefulWidget {
  const SalesReportsScreen({super.key});

  @override
  State<SalesReportsScreen> createState() => _SalesReportsScreenState();
}

class _SalesReportsScreenState extends SalesReportsScreenState {
  ReportsCenterMode centerMode = ReportsCenterMode.sales;
  int tab = 0;
  List<Map<String, dynamic>> invoices = [];
  List<Map<String, dynamic>> customers = [];
  List<Map<String, dynamic>> journalLines = [];
  List<Map<String, dynamic>> adjustmentNotes = [];
  List<Map<String, dynamic>> partyLedgerLines = [];
  List<Map<String, dynamic>> trialBalanceRows = [];
  List<Map<String, dynamic>> cashBankLines = [];
  List<Map<String, dynamic>> reportCustomers = [];
  List<Map<String, dynamic>> reportSuppliers = [];
  String? selectedCustomer;
  String? noteTypeFilter;
  String partyLedgerKind = 'CUSTOMER';
  int? partyLedgerPartyId;
  String cashBankFilter = 'CASH';
  String? partyLedgerTitle;
  bool loading = true;
  bool showAllTrialLedgers = false;
  bool partyMastersLoading = false;
  final searchCtrl = TextEditingController();
  final journalSearchCtrl = TextEditingController();
  final noteSearchCtrl = TextEditingController();
  DateTime? fromDate;
  DateTime? toDate;

  @override
  void showSalesReports() => setState(() => centerMode = ReportsCenterMode.sales);
  @override
  void showJournalSummary() {
    setState(() => centerMode = ReportsCenterMode.journalSummary);
    _loadJournal();
  }
  @override
  void showDebitCreditHistory() {
    setState(() => centerMode = ReportsCenterMode.noteHistory);
    _loadNotes();
  }

  @override
  void showPartyLedger() {
    setState(() => centerMode = ReportsCenterMode.partyLedger);
    _loadPartyLedgerMasters();
  }

  @override
  void showTrialBalance() {
    setState(() => centerMode = ReportsCenterMode.trialBalance);
    _loadTrialBalance();
  }

  @override
  void showCashBankBook() {
    setState(() => centerMode = ReportsCenterMode.cashBankBook);
    _loadCashBankBook();
  }

  Future<void> _loadPartyLedgerMasters() async {
    setState(() => loading = true);
    try {
      partyMastersLoading = true;
      if (mounted) setState(() {});
      reportCustomers = await loadCustomersDirectory(
        UltraRepository.instance,
        snackbarContext: context,
      );
      reportSuppliers = await loadSuppliersDirectory(
        UltraRepository.instance,
        snackbarContext: context,
      );
      partyMastersLoading = false;
      if (partyLedgerPartyId == null) {
        if (partyLedgerKind == 'CUSTOMER' && reportCustomers.isNotEmpty) {
          partyLedgerPartyId = parseApiInt(reportCustomers.first['id']);
        } else if (partyLedgerKind == 'SUPPLIER' && reportSuppliers.isNotEmpty) {
          partyLedgerPartyId = parseApiInt(reportSuppliers.first['id']);
        }
      }
      await _loadPartyLedger();
    } catch (e) {
      if (mounted) showReadableErrorSnackBar(context, e);
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> _loadPartyLedger() async {
    if (partyLedgerPartyId == null) {
      if (mounted) setState(() => loading = false);
      return;
    }
    setState(() => loading = true);
    try {
      final from = fromDate == null ? null : _iso(fromDate!);
      final to = toDate == null ? null : _iso(toDate!);
      final data = await UltraRepository.instance.reportPartyLedger(
        partyKind: partyLedgerKind,
        partyId: partyLedgerPartyId!,
        from: from,
        to: to,
      );
      partyLedgerLines = (data['lines'] as List?)
              ?.map((e) => Map<String, dynamic>.from(e as Map))
              .toList() ??
          [];
      partyLedgerTitle = '${data['ledger_name'] ?? ''}';
    } catch (e) {
      if (mounted) showReadableErrorSnackBar(context, e);
      partyLedgerLines = [];
    }
    if (mounted) setState(() => loading = false);
  }

  Future<void> _loadTrialBalance() async {
    setState(() => loading = true);
    try {
      final from = fromDate == null ? null : _iso(fromDate!);
      final to = toDate == null ? null : _iso(toDate!);
      final data = await UltraRepository.instance.reportTrialBalance(from: from, to: to);
      trialBalanceRows = (data['rows'] as List?)
              ?.map((e) => Map<String, dynamic>.from(e as Map))
              .toList() ??
          [];
    } catch (e) {
      if (mounted) showReadableErrorSnackBar(context, e);
      trialBalanceRows = [];
    }
    if (mounted) setState(() => loading = false);
  }

  Future<void> _loadCashBankBook() async {
    setState(() => loading = true);
    try {
      final from = fromDate == null ? null : _iso(fromDate!);
      final to = toDate == null ? null : _iso(toDate!);
      final data = await UltraRepository.instance.reportCashBankBook(
        cashBank: cashBankFilter,
        from: from,
        to: to,
      );
      cashBankLines = (data['lines'] as List?)
              ?.map((e) => Map<String, dynamic>.from(e as Map))
              .toList() ??
          [];
    } catch (e) {
      if (mounted) showReadableErrorSnackBar(context, e);
      cashBankLines = [];
    }
    if (mounted) setState(() => loading = false);
  }

  String _iso(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    searchCtrl.dispose();
    journalSearchCtrl.dispose();
    noteSearchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadJournal() async {
    setState(() => loading = true);
    try {
      journalLines = await UltraRepository.instance.journalSummaryLines();
    } catch (e) {
      if (mounted) showReadableErrorSnackBar(context, e);
    }
    if (mounted) setState(() => loading = false);
  }

  Future<void> _loadNotes() async {
    setState(() => loading = true);
    try {
      adjustmentNotes = await UltraRepository.instance.adjustmentNotesWithParty();
    } catch (e) {
      if (mounted) showReadableErrorSnackBar(context, e);
    }
    if (mounted) setState(() => loading = false);
  }

  Future<void> _load() async {
    setState(() => loading = true);
    try {
      final rows = await UltraRepository.instance.salesInvoicesWithParty();
      final cs = await UltraRepository.instance.customers();
      if (!mounted) return;
      setState(() {
        invoices = rows;
        customers = cs;
      });
    } catch (e) {
      if (mounted) showReadableErrorSnackBar(context, e);
    }
    if (mounted) setState(() => loading = false);
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
          '${r['voucher_no_display']}'.toLowerCase().contains(q) ||
          salesInvoiceDisplayNo(r).toLowerCase().contains(q) ||
          '${r['customer_name']}'.toLowerCase().contains(q) ||
          '${r['uuid']}'.toLowerCase().contains(q);
    }).toList();
  }

  static double _asDouble(dynamic value) {
    if (value == null) return 0;
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0;
    return 0;
  }

  static int _asInt(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value) ?? 0;
    return 0;
  }

  double _sum(String key) => filteredInvoices.fold<double>(0, (v, r) => v + _asDouble(r[key]));

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
          Expanded(
            child: loading &&
                    centerMode != ReportsCenterMode.sales &&
                    centerMode != ReportsCenterMode.partyLedger
                ? const Center(child: CircularProgressIndicator())
                : _body(),
          ),
        ],
      ),
    );
  }

  EdgeInsets _headerPadding() {
    final narrow = AppBreakpoints.isNarrow(context);
    return EdgeInsets.fromLTRB(
      narrow ? 12 : 20,
      narrow ? 10 : 14,
      narrow ? 12 : 20,
      narrow ? 8 : 10,
    );
  }

  Widget _topHeader() {
    final narrow = AppBreakpoints.isNarrow(context);
    if (centerMode == ReportsCenterMode.journalSummary) {
      return Container(
        color: Colors.white,
        padding: _headerPadding(),
        child: Row(
          children: [
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('JOURNAL SUMMARY REGISTER', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: _navy)),
                  SizedBox(height: 3),
                  Text('DOUBLE ENTRY FINANCIAL ADJUSTMENT INTERCEPTOR JOURNAL DIRECTORY',
                      style: TextStyle(fontSize: 8.5, color: Color(0xFF748094), fontWeight: FontWeight.w600)),
                ],
              ),
            ),
            OutlinedButton.icon(
              onPressed: () => printJournalSummaryReport(_filteredJournalLines),
              icon: const Icon(Icons.picture_as_pdf_outlined, size: 14),
              label: const Text('PRINT SUMMARY', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w800)),
            ),
          ],
        ),
      );
    }
    if (centerMode == ReportsCenterMode.noteHistory) {
      return Container(
        color: Colors.white,
        padding: _headerPadding(),
        child: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('DEBIT / CREDIT NOTE HISTORY', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: _navy)),
            SizedBox(height: 3),
            Text('ACCOUNT REVERSAL NOTE REGISTER & COMMERCIAL CREDIT/DEBIT AUDIT TRAIL',
                style: TextStyle(fontSize: 8.5, color: Color(0xFF748094), fontWeight: FontWeight.w600)),
          ],
        ),
      );
    }
    if (centerMode == ReportsCenterMode.partyLedger) {
      return Container(
        color: Colors.white,
        padding: _headerPadding(),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('PARTY LEDGER', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: _navy)),
                  const SizedBox(height: 3),
                  Text(
                    partyLedgerTitle?.trim().isNotEmpty == true ? partyLedgerTitle! : 'CUSTOMER & SUPPLIER ACCOUNT STATEMENT',
                    style: const TextStyle(fontSize: 8.5, color: Color(0xFF748094), fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
            OutlinedButton.icon(
              onPressed: partyLedgerLines.isEmpty
                  ? null
                  : () => printLedgerLinesReport(
                        title: 'PARTY LEDGER',
                        subtitle: partyLedgerTitle,
                        lines: partyLedgerLines,
                      ),
              icon: const Icon(Icons.picture_as_pdf_outlined, size: 14),
              label: const Text('PRINT', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w800)),
            ),
          ],
        ),
      );
    }
    if (centerMode == ReportsCenterMode.trialBalance) {
      return Container(
        color: Colors.white,
        padding: _headerPadding(),
        child: Row(
          children: [
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('TRIAL BALANCE', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: _navy)),
                  SizedBox(height: 3),
                  Text('LEDGER OPENING, PERIOD MOVEMENTS & CLOSING BALANCES',
                      style: TextStyle(fontSize: 8.5, color: Color(0xFF748094), fontWeight: FontWeight.w600)),
                ],
              ),
            ),
            OutlinedButton.icon(
              onPressed: trialBalanceRows.isEmpty
                  ? null
                  : () => printTrialBalanceReport(rows: _visibleTrialBalanceRows),
              icon: const Icon(Icons.picture_as_pdf_outlined, size: 14),
              label: const Text('PRINT', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w800)),
            ),
          ],
        ),
      );
    }
    if (centerMode == ReportsCenterMode.cashBankBook) {
      return Container(
        color: Colors.white,
        padding: _headerPadding(),
        child: Row(
          children: [
            Expanded(
              child: Wrap(
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 8,
                children: [
                  const Text('CASH / BANK BOOK', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: _navy)),
                  DropdownButton<String>(
                    value: cashBankFilter,
                    items: const [
                      DropdownMenuItem(value: 'CASH', child: Text('Cash')),
                      DropdownMenuItem(value: 'BANK', child: Text('Bank')),
                    ],
                    onChanged: (v) {
                      if (v == null) return;
                      setState(() => cashBankFilter = v);
                      _loadCashBankBook();
                    },
                  ),
                ],
              ),
            ),
            OutlinedButton.icon(
              onPressed: cashBankLines.isEmpty
                  ? null
                  : () => printLedgerLinesReport(
                        title: 'CASH / BANK BOOK ($cashBankFilter)',
                        lines: cashBankLines,
                      ),
              icon: const Icon(Icons.picture_as_pdf_outlined, size: 14),
              label: const Text('PRINT', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w800)),
            ),
          ],
        ),
      );
    }
    final titleBlock = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'SALES LEDGER AUDIT REPORT',
          style: TextStyle(
            fontSize: narrow ? 13 : 14,
            fontWeight: FontWeight.w800,
            color: _navy,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          'REAL-TIME REVENUE MONITORING & RECIPIENT LEDGER ENTRIES DIRECTORY',
          style: TextStyle(
            fontSize: narrow ? 8 : 8.5,
            color: const Color(0xFF748094),
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
    final tabs = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _tab('LEDGER VIEW', 0),
        _tab('AUDIT REPORT', 1),
        _tab('VIEW LEDGER WISE', 2),
      ],
    );
    return Container(
      color: Colors.white,
      padding: _headerPadding(),
      child: narrow
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                titleBlock,
                const SizedBox(height: 8),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: tabs,
                ),
              ],
            )
          : Row(
              children: [
                Expanded(child: titleBlock),
                tabs,
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
    if (centerMode == ReportsCenterMode.journalSummary) return _journalSummaryView();
    if (centerMode == ReportsCenterMode.noteHistory) return _noteHistoryView();
    if (centerMode == ReportsCenterMode.partyLedger) return _partyLedgerView();
    if (centerMode == ReportsCenterMode.trialBalance) return _trialBalanceView();
    if (centerMode == ReportsCenterMode.cashBankBook) return _cashBankBookView();
    if (loading) return const Center(child: CircularProgressIndicator());
    if (tab == 0) return _ledgerView();
    if (tab == 1) return _auditView();
    return _ledgerWiseView();
  }

  List<Map<String, dynamic>> get _filteredJournalLines {
    final q = journalSearchCtrl.text.trim().toLowerCase();
    if (q.isEmpty) return journalLines;
    return journalLines.where((r) {
      final hay = '${r['narration']} ${r['dr_account_label']} ${r['cr_account_label']} ${r['voucher_date']}'.toLowerCase();
      return hay.contains(q);
    }).toList();
  }

  List<Map<String, dynamic>> get _filteredNotes {
    final q = noteSearchCtrl.text.trim().toLowerCase();
    return adjustmentNotes.where((r) {
      if (noteTypeFilter != null && '${r['note_type']}' != noteTypeFilter) return false;
      if (q.isEmpty) return true;
      final hay = '${r['party_name']} ${r['note_no']} ${r['note_bill_no']} ${r['reversal_reason']}'.toLowerCase();
      return hay.contains(q);
    }).toList();
  }

  Widget _journalSummaryView() {
    final rows = _filteredJournalLines;
    final total = rows.fold<double>(0, (s, r) => s + _asDouble(r['amount']));
    return SingleChildScrollView(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
            child: TextField(
              controller: journalSearchCtrl,
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search, size: 16, color: _teal),
                hintText: 'FILTER BY DATE, NARRATION, DEBIT OR CREDIT ACCOUNT...',
                hintStyle: TextStyle(fontSize: 9),
                filled: true,
                fillColor: Colors.white,
                isDense: true,
              ),
            ),
          ),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: AppBreakpoints.pagePadding(context)),
            child: responsiveHorizontalTable(
              context,
              Container(
                color: Colors.white,
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
                      decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: _border))),
                      child: const Row(children: [
                        Expanded(flex: 1, child: Text('VOUCHER DATE', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: _navy))),
                        Expanded(flex: 2, child: Text('VOUCHER NARRATION', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: _navy))),
                        Expanded(flex: 2, child: Text('DEBIT (TO) ACCOUNT', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: _navy))),
                        Expanded(flex: 2, child: Text('CREDIT (BY) ACCOUNT', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: _navy))),
                        Expanded(child: Text('AMOUNT', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: _navy))),
                      ]),
                    ),
                    if (rows.isEmpty)
                      const Padding(padding: EdgeInsets.all(32), child: Text('No journal entries posted yet.', style: TextStyle(fontSize: 11, color: Color(0xFF748094))))
                    else
                      ...rows.map(_journalRow),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
                      color: const Color(0xFFE1E7F0),
                      child: Row(children: [
                        const Expanded(flex: 7, child: Text('TOTAL VOUCHER SUMMARY VALUE:', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: _navy))),
                        Expanded(child: Text('₹ ${total.toStringAsFixed(2)}', style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: _green))),
                      ]),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _journalRow(Map<String, dynamic> r) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Color(0xFFE7EBF0)))),
      child: Row(
        children: [
          Expanded(flex: 1, child: Text(_date(r['voucher_date']), style: const TextStyle(fontSize: 9))),
          Expanded(flex: 2, child: Text('${r['narration'] ?? ''}', style: const TextStyle(fontSize: 9))),
          Expanded(flex: 2, child: Text('${r['dr_account_label'] ?? ''}', style: const TextStyle(fontSize: 9, color: Color(0xFF2B8ED2)))),
          Expanded(flex: 2, child: Text('${r['cr_account_label'] ?? ''}', style: const TextStyle(fontSize: 9, color: _green))),
          Expanded(child: Text('₹${_asDouble(r['amount']).toStringAsFixed(2)}', style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w800))),
        ],
      ),
    );
  }

  Widget _noteHistoryView() {
    final rows = _filteredNotes;
    return SingleChildScrollView(
      child: Column(
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(AppBreakpoints.pagePadding(context), 12, AppBreakpoints.pagePadding(context), 8),
            child: AppBreakpoints.isNarrow(context)
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      TextField(
                        controller: noteSearchCtrl,
                        onChanged: (_) => setState(() {}),
                        decoration: const InputDecoration(
                          prefixIcon: Icon(Icons.search, size: 16, color: _teal),
                          hintText: 'FILTER BY NOTE NO, PARTY NAME, REASON OR DATE...',
                          hintStyle: TextStyle(fontSize: 9),
                          filled: true,
                          fillColor: Colors.white,
                          isDense: true,
                        ),
                      ),
                      const SizedBox(height: 8),
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            _noteFilterChip('ALL', null),
                            const SizedBox(width: 4),
                            _noteFilterChip('DEBIT', 'DEBIT'),
                            const SizedBox(width: 4),
                            _noteFilterChip('CREDIT', 'CREDIT'),
                          ],
                        ),
                      ),
                    ],
                  )
                : Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: noteSearchCtrl,
                          onChanged: (_) => setState(() {}),
                          decoration: const InputDecoration(
                            prefixIcon: Icon(Icons.search, size: 16, color: _teal),
                            hintText: 'FILTER BY NOTE NO, PARTY NAME, REASON OR DATE...',
                            hintStyle: TextStyle(fontSize: 9),
                            filled: true,
                            fillColor: Colors.white,
                            isDense: true,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      _noteFilterChip('ALL', null),
                      const SizedBox(width: 4),
                      _noteFilterChip('DEBIT', 'DEBIT'),
                      const SizedBox(width: 4),
                      _noteFilterChip('CREDIT', 'CREDIT'),
                    ],
                  ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Column(
              children: rows.isEmpty
                  ? [const Padding(padding: EdgeInsets.all(32), child: Text('No debit/credit notes posted yet.', style: TextStyle(fontSize: 11, color: Color(0xFF748094))))]
                  : rows.map(_noteRow).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _noteFilterChip(String label, String? type) {
    final active = noteTypeFilter == type;
    return OutlinedButton(
      onPressed: () => setState(() => noteTypeFilter = type),
      style: OutlinedButton.styleFrom(
        backgroundColor: active ? _navy : Colors.white,
        foregroundColor: active ? Colors.white : _navy,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      ),
      child: Text(label, style: const TextStyle(fontSize: 8, fontWeight: FontWeight.w800)),
    );
  }

  String _noteBillNo(Map<String, dynamic> r) {
    final stored = '${r['note_bill_no'] ?? ''}'.trim();
    if (stored.isNotEmpty) return stored;
    final uuid = '${r['uuid'] ?? ''}';
    final year = DateTime.tryParse('${r['issue_date']}')?.year ?? DateTime.now().year;
    final prefix = '${r['note_type']}' == 'DEBIT' ? 'DN' : 'CN';
    if (uuid.length >= 6) return '$prefix-$year-${uuid.replaceAll('-', '').substring(0, 6).toUpperCase()}';
    return '$prefix-$year-${r['note_no']}';
  }

  Widget _noteRow(Map<String, dynamic> r) {
    final id = r['id'] as int;
    final isCredit = '${r['note_type']}' == 'CREDIT';
    final total = _asDouble(r['grand_total']);
    final accent = isCredit ? _green : const Color(0xFFB33A3A);
    return Container(
      height: 58,
      margin: const EdgeInsets.only(bottom: 4),
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(color: Colors.white, border: Border.all(color: _border)),
      child: Row(
        children: [
          Container(width: 3, height: 38, color: accent),
          const SizedBox(width: 10),
          Expanded(
            flex: 4,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Row(
                  children: [
                    Text('${r['party_name']}', style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, color: _navy)),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      color: accent.withOpacity(.15),
                      child: Text('${r['note_type']}', style: TextStyle(fontSize: 7.5, fontWeight: FontWeight.w800, color: accent)),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  'NOTE NO: ${_noteBillNo(r)}  •  SERIAL: ${r['note_no']}  •  DATE: ${_date(r['issue_date'])}  •  REASON: ${r['reversal_reason']}',
                  style: const TextStyle(fontSize: 8, color: Color(0xFF748094)),
                ),
              ],
            ),
          ),
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              const Text('REVERSAL VALUE', style: TextStyle(fontSize: 7.5, color: Color(0xFF748094))),
              Text('₹${total.toStringAsFixed(2)}', style: TextStyle(fontSize: 12, color: accent, fontWeight: FontWeight.w800)),
            ],
          ),
          const SizedBox(width: 12),
          OutlinedButton.icon(
            onPressed: () => reprintAdjustmentNote(id),
            icon: const Icon(Icons.print, size: 12),
            label: const Text('REPRINT', style: TextStyle(fontSize: 8, fontWeight: FontWeight.w800)),
            style: OutlinedButton.styleFrom(foregroundColor: _navy, side: const BorderSide(color: _border), padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 8)),
          ),
        ],
      ),
    );
  }

  Widget _summaryCards() {
    final gross = _sum('grand_total');
    final received = 0.0;
    final net = gross;
    final horizontalPad = AppBreakpoints.isNarrow(context) ? 12.0 : 14.0;
    return Padding(
      padding: EdgeInsets.fromLTRB(horizontalPad, 10, horizontalPad, 8),
      child: responsiveRowOrColumn(
        context,
        [
          _summary('GROSS SALES (DR)', gross, Icons.show_chart, const Color(0xFF3B9ED8)),
          _summary('TOTAL RECEIPTS (CR)', received, Icons.account_balance, _green),
          _summary('NET BALANCES REVENUE', net, Icons.account_balance_wallet_outlined, const Color(0xFFF0A72E)),
        ],
        spacing: 8,
      ),
    );
  }

  Widget _summary(String title, double value, IconData icon, Color iconColor) {
    return Container(
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
    );
  }

  Widget _filters() {
    final narrow = AppBreakpoints.isNarrow(context);
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
    final total = _asDouble(r['grand_total']);
    final narrow = AppBreakpoints.isNarrow(context);
    final reprintBtn = OutlinedButton.icon(
      onPressed: () => reprintSalesInvoice(r['id'] as int),
      icon: const Icon(Icons.print, size: 12),
      label: const Text('REPRINT', style: TextStyle(fontSize: 8, fontWeight: FontWeight.w800)),
      style: OutlinedButton.styleFrom(foregroundColor: _navy, side: const BorderSide(color: _border), padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 8)),
    );
    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(color: Colors.white, border: Border.all(color: _border)),
      child: narrow
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${r['customer_name']}', style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, color: _navy)),
                const SizedBox(height: 4),
                Text(
                  'SERIAL NO: ${salesInvoiceDisplayNo(r)}  •  RECORDING DATE: ${_date(r['transaction_date'])}',
                  style: const TextStyle(fontSize: 8, color: Color(0xFF748094)),
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('DEBIT ₹${total.toStringAsFixed(0)}', style: const TextStyle(fontSize: 12, color: Color(0xFF2B65B0), fontWeight: FontWeight.w800)),
                    Text('CREDIT ₹0', style: const TextStyle(fontSize: 12, color: Color(0xFFB93636), fontWeight: FontWeight.w800)),
                  ],
                ),
                const SizedBox(height: 8),
                reprintBtn,
              ],
            )
          : Row(children: [
              Container(width: 3, height: 38, color: _navy),
              const SizedBox(width: 10),
              Expanded(
                flex: 4,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text('${r['customer_name']}', style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, color: _navy)),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Text('SERIAL NO: ${salesInvoiceDisplayNo(r)}', style: const TextStyle(fontSize: 8.5, color: _teal, fontWeight: FontWeight.w700)),
                        const SizedBox(width: 8),
                        Text('•  RECORDING DATE: ${_date(r['transaction_date'])}', style: const TextStyle(fontSize: 8, color: Color(0xFF748094))),
                      ],
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    const Text('DEBIT VAL (REV)', style: TextStyle(fontSize: 7.5, color: Color(0xFF748094))),
                    Text('₹${total.toStringAsFixed(0)}', style: const TextStyle(fontSize: 12, color: Color(0xFF2B65B0), fontWeight: FontWeight.w800)),
                  ],
                ),
              ),
              const SizedBox(width: 18),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    const Text('CREDIT VAL (REC)', style: TextStyle(fontSize: 7.5, color: Color(0xFF748094))),
                    const Text('₹0', style: TextStyle(fontSize: 12, color: Color(0xFFB93636), fontWeight: FontWeight.w800)),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              reprintBtn,
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
      return _asInt(b['invoice_no']).compareTo(_asInt(a['invoice_no']));
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
          padding: EdgeInsets.symmetric(horizontal: AppBreakpoints.pagePadding(context)),
          child: responsiveHorizontalTable(
            context,
            Container(
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
        ),
      ]),
    );
  }

  Widget _auditRow(Map<String, dynamic> r) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Color(0xFFE7EBF0)))),
      child: Row(children: [
        Expanded(flex: 1, child: Text(salesInvoiceDisplayNo(r), style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w700))),
        Expanded(flex: 1, child: Text(_date(r['transaction_date']), style: const TextStyle(fontSize: 9))),
        Expanded(flex: 4, child: Text('${r['customer_name']}', style: const TextStyle(fontSize: 9))),
        Expanded(child: Text('${_asDouble(r['taxable_total']).toStringAsFixed(2)}', style: const TextStyle(fontSize: 9))),
        Expanded(child: Text('${_asDouble(r['cgst_total']).toStringAsFixed(2)}', style: const TextStyle(fontSize: 9))),
        Expanded(child: Text('${_asDouble(r['sgst_total']).toStringAsFixed(2)}', style: const TextStyle(fontSize: 9))),
        Expanded(child: Text('${_asDouble(r['igst_total']).toStringAsFixed(2)}', style: const TextStyle(fontSize: 9))),
        Expanded(child: Text('${_asDouble(r['grand_total']).toStringAsFixed(2)}', style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w700))),
      ]),
    );
  }

  Widget _accountingDateBar({required VoidCallback onApply}) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 0),
      child: CompactDateRangeBar(
        from: fromDate,
        to: toDate,
        onFromChanged: (d) {
          _setFrom(d);
          onApply();
        },
        onToChanged: (d) {
          _setTo(d);
          onApply();
        },
        onClear: () {
          setState(() {
            fromDate = null;
            toDate = null;
          });
          onApply();
        },
      ),
    );
  }

  Widget _partyLedgerView() {
    final parties = partyLedgerKind == 'CUSTOMER' ? reportCustomers : reportSuppliers;
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 0),
            child: Text('PARTY LEDGER — ${partyLedgerTitle ?? ''}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: _navy)),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 8, 14, 0),
            child: Wrap(
              spacing: 8,
              children: [
                DropdownButton<String>(
                  value: partyLedgerKind,
                  items: const [
                    DropdownMenuItem(value: 'CUSTOMER', child: Text('Customer')),
                    DropdownMenuItem(value: 'SUPPLIER', child: Text('Supplier')),
                  ],
                  onChanged: (v) {
                    if (v == null) return;
                    setState(() {
                      partyLedgerKind = v;
                      partyLedgerPartyId = null;
                    });
                    _loadPartyLedgerMasters();
                  },
                ),
                DropdownButton<int>(
                  value: partyLedgerPartyId,
                  hint: const Text('Select party'),
                  items: parties
                      .map((p) => DropdownMenuItem(
                            value: parseApiInt(p['id']),
                            child: Text('${partyLedgerKind == 'CUSTOMER' ? p['customer_name'] : p['supplier_name']}'),
                          ))
                      .whereType<DropdownMenuItem<int>>()
                      .toList(),
                  onChanged: partyMastersLoading
                      ? null
                      : (v) {
                    setState(() => partyLedgerPartyId = v);
                    _loadPartyLedger();
                  },
                ),
                partyDirectoryStatus(
                  loading: partyMastersLoading,
                  isCustomer: partyLedgerKind == 'CUSTOMER',
                  itemCount: parties.length,
                ),
              ],
            ),
          ),
          _accountingDateBar(onApply: _loadPartyLedger),
          if (loading)
            const Padding(padding: EdgeInsets.all(40), child: Center(child: CircularProgressIndicator()))
          else if (partyLedgerLines.isEmpty)
            _emptyAccounting('No ledger lines in this period.')
          else
            _ledgerLinesTable(partyLedgerLines),
        ],
      ),
    );
  }

  bool _trialRowAllZero(Map<String, dynamic> r) {
    final keys = [
      'opening_debit',
      'opening_credit',
      'period_debit',
      'period_credit',
      'closing_debit',
      'closing_credit',
    ];
    return keys.every((k) => parseApiAmount(r[k]) == 0);
  }

  List<Map<String, dynamic>> get _visibleTrialBalanceRows {
    if (showAllTrialLedgers) return trialBalanceRows;
    return trialBalanceRows.where((r) => !_trialRowAllZero(r)).toList();
  }

  Widget _trialBalanceView() {
    final rows = _visibleTrialBalanceRows;
    final totalOpenDr = rows.fold<double>(0, (s, r) => s + parseApiAmount(r['opening_debit']));
    final totalOpenCr = rows.fold<double>(0, (s, r) => s + parseApiAmount(r['opening_credit']));
    final totalPerDr = rows.fold<double>(0, (s, r) => s + parseApiAmount(r['period_debit']));
    final totalPerCr = rows.fold<double>(0, (s, r) => s + parseApiAmount(r['period_credit']));
    final totalCloseDr = rows.fold<double>(0, (s, r) => s + parseApiAmount(r['closing_debit']));
    final totalCloseCr = rows.fold<double>(0, (s, r) => s + parseApiAmount(r['closing_credit']));
    return SingleChildScrollView(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 0),
            child: Row(
              children: [
                Checkbox(
                  value: showAllTrialLedgers,
                  onChanged: (v) => setState(() => showAllTrialLedgers = v ?? false),
                ),
                const Expanded(
                  child: Text('Show all ledgers', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600)),
                ),
              ],
            ),
          ),
          _accountingDateBar(onApply: _loadTrialBalance),
          if (loading)
            const Padding(padding: EdgeInsets.all(40), child: Center(child: CircularProgressIndicator()))
          else if (rows.isEmpty)
            _emptyAccounting('No trial balance rows.')
          else
            Padding(
              padding: const EdgeInsets.all(14),
              child: responsiveHorizontalTable(
                context,
                Container(
                  color: Colors.white,
                  child: Column(
                    children: [
                      const Padding(
                        padding: EdgeInsets.all(8),
                        child: Row(children: [
                          Expanded(flex: 2, child: Text('LEDGER', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w800))),
                          Expanded(child: Text('OPEN DR', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w800))),
                          Expanded(child: Text('OPEN CR', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w800))),
                          Expanded(child: Text('PER DR', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w800))),
                          Expanded(child: Text('PER CR', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w800))),
                          Expanded(child: Text('CLOSE DR', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w800))),
                          Expanded(child: Text('CLOSE CR', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w800))),
                        ]),
                      ),
                      ...rows.map(
                        (r) => Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                          child: Row(children: [
                            Expanded(flex: 2, child: Text('${r['ledger_name']}', style: const TextStyle(fontSize: 9))),
                            Expanded(child: Text(parseApiAmount(r['opening_debit']).toStringAsFixed(2), style: const TextStyle(fontSize: 9))),
                            Expanded(child: Text(parseApiAmount(r['opening_credit']).toStringAsFixed(2), style: const TextStyle(fontSize: 9))),
                            Expanded(child: Text(parseApiAmount(r['period_debit']).toStringAsFixed(2), style: const TextStyle(fontSize: 9))),
                            Expanded(child: Text(parseApiAmount(r['period_credit']).toStringAsFixed(2), style: const TextStyle(fontSize: 9))),
                            Expanded(child: Text(parseApiAmount(r['closing_debit']).toStringAsFixed(2), style: const TextStyle(fontSize: 9))),
                            Expanded(child: Text(parseApiAmount(r['closing_credit']).toStringAsFixed(2), style: const TextStyle(fontSize: 9))),
                          ]),
                        ),
                      ),
                      Container(
                        color: const Color(0xFFE1E7F0),
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                        child: Row(children: [
                          const Expanded(flex: 2, child: Text('TOTALS', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900))),
                          Expanded(child: Text(totalOpenDr.toStringAsFixed(2), style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w900))),
                          Expanded(child: Text(totalOpenCr.toStringAsFixed(2), style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w900))),
                          Expanded(child: Text(totalPerDr.toStringAsFixed(2), style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w900))),
                          Expanded(child: Text(totalPerCr.toStringAsFixed(2), style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w900))),
                          Expanded(child: Text(totalCloseDr.toStringAsFixed(2), style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w900))),
                          Expanded(child: Text(totalCloseCr.toStringAsFixed(2), style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w900))),
                        ]),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _cashBankBookView() {
    return SingleChildScrollView(
      child: Column(
        children: [
          _accountingDateBar(onApply: _loadCashBankBook),
          if (loading)
            const Padding(padding: EdgeInsets.all(40), child: Center(child: CircularProgressIndicator()))
          else if (cashBankLines.isEmpty)
            _emptyAccounting('No cash/bank movements in this period.')
          else
            _ledgerLinesTable(cashBankLines),
        ],
      ),
    );
  }

  Widget _ledgerLinesTable(List<Map<String, dynamic>> lines) {
    return Padding(
      padding: const EdgeInsets.all(14),
      child: responsiveHorizontalTable(
        context,
        Container(
          color: Colors.white,
          child: Column(
            children: [
              const Padding(
                padding: EdgeInsets.all(8),
                child: Row(children: [
                  Expanded(child: Text('DATE', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w800))),
                  Expanded(child: Text('VOUCHER', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w800))),
                  Expanded(flex: 2, child: Text('NARRATION', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w800))),
                  Expanded(child: Text('DEBIT', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w800))),
                  Expanded(child: Text('CREDIT', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w800))),
                  Expanded(child: Text('BALANCE', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w800))),
                ]),
              ),
              ...lines.map(
                (r) => Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                  child: Row(children: [
                    Expanded(child: Text(_date(r['date']), style: const TextStyle(fontSize: 9))),
                    Expanded(child: Text(voucherDisplayNo(r), style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w700))),
                    Expanded(flex: 2, child: Text('${r['narration'] ?? ''}', style: const TextStyle(fontSize: 9))),
                    Expanded(child: Text(parseApiAmount(r['debit']).toStringAsFixed(2), style: const TextStyle(fontSize: 9))),
                    Expanded(child: Text(parseApiAmount(r['credit']).toStringAsFixed(2), style: const TextStyle(fontSize: 9))),
                    Expanded(child: Text(parseApiAmount(r['running_balance']).toStringAsFixed(2), style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w800))),
                  ]),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _emptyAccounting(String msg) =>
      Padding(padding: const EdgeInsets.all(40), child: Center(child: Text(msg, style: const TextStyle(fontSize: 11, color: Color(0xFF748094)))));

  Widget _ledgerWiseView() {
    final name = selectedCustomer;
    final rows = name == null ? <Map<String, dynamic>>[] : filteredInvoices.where((r) => r['customer_name'] == name).toList();
    final gross = rows.fold<double>(0, (v, r) => v + (_asDouble(r['grand_total'])));
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
            responsiveRowOrColumn(
              context,
              [
                _ledgerCard('OPENING BALANCE', 0, _navy),
                _ledgerCard('GROSS SALES BILLING (DR)', gross, const Color(0xFF2B8ED2)),
                _ledgerCard('TOTAL RECEIVED (CR)', 0, _green),
                _ledgerCard('NET OUTSTANDING DUE', -gross, _navy),
              ],
              spacing: 8,
            ),
            const SizedBox(height: 14),
            responsiveHorizontalTable(
              context,
              Container(
                color: Colors.white,
                child: Column(children: [
                  Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9), child: const Row(children: [Expanded(child: Text('DATE', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: _navy))), Expanded(child: Text('TXN TYPE', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: _navy))), Expanded(child: Text('REF / INVOICE ID', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: _navy))), Expanded(flex: 3, child: Text('PARTICULARS / NARRATION ENTRY', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: _navy))), Expanded(child: Text('DEBIT (DR) [+]', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: Color(0xFF2B8ED2)))), Expanded(child: Text('CREDIT (CR) [-]', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: _green))), Expanded(child: Text('BALANCE (₹)', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: _navy)))])),
                  ...rows.map((r) => Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10), decoration: const BoxDecoration(border: Border(top: BorderSide(color: Color(0xFFE7EBF0)))), child: Row(children: [Expanded(child: Text(_date(r['transaction_date']), style: const TextStyle(fontSize: 9))), Expanded(child: Container(alignment: Alignment.centerLeft, child: const Text('SALES', style: TextStyle(fontSize: 8, color: _green, fontWeight: FontWeight.w700)))), Expanded(child: Text(salesInvoiceDisplayNo(r), style: const TextStyle(fontSize: 9))), Expanded(flex: 3, child: Text('SALES INVOICE FOR ${r['customer_name']}', style: const TextStyle(fontSize: 9))), Expanded(child: Text('₹${(_asDouble(r['grand_total'])).toStringAsFixed(2)}', style: const TextStyle(fontSize: 9, color: Color(0xFF2B8ED2)))), Expanded(child: const Text('-', style: TextStyle(fontSize: 9))), Expanded(child: Text('₹${(_asDouble(r['grand_total'])).toStringAsFixed(2)}', style: const TextStyle(fontSize: 9)))]))),
                ]),
              ),
            ),
          ] else
            const SizedBox(height: 190, child: Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.supervisor_account_outlined, size: 34, color: Color(0xFF607789)), SizedBox(height: 10), Text('Select a customer client database line row item to view accounts directory tracks.', style: TextStyle(fontSize: 11, color: Color(0xFF7A8595)))]))),
        ]),
      ),
    );
  }

  Widget _ledgerCard(String title, double value, Color color) {
    return Container(
      height: 54,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(color: Colors.white, border: Border.all(color: _border)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(title, style: const TextStyle(fontSize: 7.5, color: Color(0xFF748094))),
          const SizedBox(height: 3),
          Text('₹ ${value.toStringAsFixed(2)}', style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w800)),
        ],
      ),
    );
  }

  Widget _empty() => const Padding(padding: EdgeInsets.all(40), child: Center(child: Text('No sales records found.', style: TextStyle(fontSize: 11, color: Color(0xFF748094)))));
}
