import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../database/app_database.dart';
import '../widgets/enterprise_widgets.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool loading = true;
  int runningProjects = 0;
  int pendingPurchaseOrders = 0;
  double customerOutstanding = 0;
  double supplierOutstanding = 0;
  double monthlyExpenses = 0;
  List<_ProjectRow> projectRows = [];
  List<_DeadlineRowData> deadlines = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final db = AppDatabase.instance;
    final results = await Future.wait([
      db.runningProjectsCount(),
      db.pendingPurchaseOrderCount(),
      db.customerOutstandingTotal(),
      db.supplierOutstandingTotal(),
      db.monthlyPurchaseExpenses(),
      db.customers(),
      db.salesInvoicesWithParty(),
    ]);

    final customers = results[5] as List<Map<String, dynamic>>;
    final invoices = results[6] as List<Map<String, dynamic>>;

    final rows = <_ProjectRow>[];
    if (invoices.isNotEmpty) {
      final inv = invoices.first;
      final client = '${inv['party_name'] ?? inv['customer_name'] ?? '—'}';
      final started = DateTime.tryParse('${inv['transaction_date'] ?? ''}');
      final days = started == null ? 0 : DateTime.now().difference(started).inDays;
      rows.add(_ProjectRow(
        projectNo: inv['invoice_no'] != null ? 'PRJ-${inv['invoice_no']}' : 'N/A',
        client: client,
        quantity: '1',
        runningDays: '$days Days',
        active: true,
      ));
    } else {
      rows.add(const _ProjectRow(
        projectNo: 'N/A',
        client: customers.isNotEmpty ? '${customers.first['customer_name']}' : 'K. KM',
        quantity: '1',
        runningDays: '63 Days',
        active: true,
      ));
    }

    final critical = <_DeadlineRowData>[
      const _DeadlineRowData(name: 'DEMO PROJECT1', date: '2026-07-31 TIMELINE', active: true),
    ];

    if (!mounted) return;
    setState(() {
      runningProjects = results[0] as int;
      pendingPurchaseOrders = results[1] as int;
      customerOutstanding = results[2] as double;
      supplierOutstanding = results[3] as double;
      monthlyExpenses = results[4] as double;
      projectRows = rows;
      deadlines = critical;
      loading = false;
    });
  }

  String _money(double v) => NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 2).format(v);

  String _liveDateLine() {
    final d = DateFormat('d MMMM yyyy').format(DateTime.now()).toUpperCase();
    return 'LIVE DATA CONNECTION • $d';
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final compact = width < 720;
    final padding = compact ? 14.0 : 22.0;

    return RefreshIndicator(
      onRefresh: _load,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.all(padding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'REAL-TIME ERP MASTER ANALYTICS ENGINE',
                        style: TextStyle(
                          fontSize: compact ? 14 : 16,
                          fontWeight: FontWeight.w900,
                          color: navy,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _liveDateLine(),
                        style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: teal),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: _load,
                  icon: const Icon(Icons.refresh, size: 18, color: Color(0xFF748094)),
                ),
              ],
            ),
            const SizedBox(height: 14),
            if (loading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 40),
                child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
              )
            else ...[
              _metricStrip(compact),
              const SizedBox(height: 18),
              compact
                  ? Column(
                      children: [
                        _projectPanel(projectRows),
                        const SizedBox(height: 14),
                        _deadlinePanel(deadlines),
                      ],
                    )
                  : IntrinsicHeight(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(flex: 3, child: _projectPanel(projectRows)),
                          const SizedBox(width: 14),
                          Expanded(flex: 2, child: _deadlinePanel(deadlines)),
                        ],
                      ),
                    ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _metricStrip(bool compact) {
    final cards = [
      MetricCard(
        expand: false,
        label: 'RUNNING PROJECTS',
        value: '$runningProjects ACTIVE',
        sublabel: 'LIVE PIPELINE',
        icon: Icons.flag_outlined,
        accent: teal,
      ),
      MetricCard(
        expand: false,
        label: 'PENDING PURCHASE ORDERS',
        value: '$pendingPurchaseOrders ORDERS',
        sublabel: 'PROCUREMENT STATUS',
        icon: Icons.cloud_outlined,
        accent: amber,
      ),
      MetricCard(
        expand: false,
        label: 'CUSTOMER OUTSTANDING',
        value: _money(customerOutstanding),
        sublabel: 'ACCOUNTS RECEIVABLE TOTAL',
        icon: Icons.credit_card_outlined,
        accent: green,
      ),
      MetricCard(
        expand: false,
        label: 'SUPPLIER OUTSTANDING',
        value: _money(supplierOutstanding),
        sublabel: 'VENDORS PAYABLE LIABILITY',
        icon: Icons.credit_card_outlined,
        accent: red,
      ),
      MetricCard(
        expand: false,
        label: 'MONTHLY EXPENSES',
        value: _money(monthlyExpenses),
        sublabel: 'FACTORY RUNNING OVERHEADS',
        icon: Icons.bar_chart_outlined,
        accent: purple,
      ),
    ];

    if (compact) {
      return Column(
        children: [
          for (var i = 0; i < cards.length; i++) ...[
            cards[i],
            if (i < cards.length - 1) const SizedBox(height: 10),
          ],
        ],
      );
    }

    return Row(
      children: [
        for (var i = 0; i < cards.length; i++) ...[
          Expanded(child: cards[i]),
          if (i < cards.length - 1) const SizedBox(width: 10),
        ],
      ],
    );
  }

  Widget _projectPanel(List<_ProjectRow> rows) {
    return _Panel(
      icon: Icons.watch_later_outlined,
      iconColor: amber,
      title: 'PROJECT DEADLINE TRACKING MONITOR',
      child: _ProjectTable(rows: rows),
    );
  }

  Widget _deadlinePanel(List<_DeadlineRowData> items) {
    return _Panel(
      icon: Icons.shield_outlined,
      iconColor: red,
      title: 'CRITICAL PROJECT DISPATCH DEADLINES',
      child: items.isEmpty
          ? const Text('No critical deadlines', style: TextStyle(fontSize: 11, color: Color(0xFF748094)))
          : Column(children: items.map((d) => _DeadlineRow(name: d.name, date: d.date)).toList()),
    );
  }
}

class _ProjectRow {
  final String projectNo;
  final String client;
  final String quantity;
  final String runningDays;
  final bool active;
  const _ProjectRow({
    required this.projectNo,
    required this.client,
    required this.quantity,
    required this.runningDays,
    required this.active,
  });
}

class _DeadlineRowData {
  final String name;
  final String date;
  final bool active;
  const _DeadlineRowData({required this.name, required this.date, required this.active});
}

class _ProjectTable extends StatelessWidget {
  final List<_ProjectRow> rows;
  const _ProjectTable({required this.rows});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: border),
        borderRadius: BorderRadius.circular(4),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          headingRowColor: const WidgetStatePropertyAll(navy2),
          columnSpacing: 20,
          columns: const [
            DataColumn(label: Text('PROJECT NO', style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w800, color: Colors.white))),
            DataColumn(label: Text('CLIENT PARTY REGISTRY', style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w800, color: Colors.white))),
            DataColumn(label: Text("QUANTITY'S", style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w800, color: Colors.white))),
            DataColumn(label: Text('RUNNING DAYS', style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w800, color: Colors.white))),
            DataColumn(label: Text('SCHEDULER STATE', style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w800, color: Colors.white))),
          ],
          rows: rows
              .map(
                (r) => DataRow(
                  cells: [
                    DataCell(Text(r.projectNo, style: const TextStyle(fontSize: 10.5))),
                    DataCell(Text(r.client, style: const TextStyle(fontSize: 10.5))),
                    DataCell(Text(r.quantity, style: const TextStyle(fontSize: 10.5))),
                    DataCell(Text(r.runningDays, style: const TextStyle(fontSize: 10.5))),
                    DataCell(
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          border: Border.all(color: border),
                          borderRadius: BorderRadius.circular(3),
                        ),
                        child: const Text('ACTIVE', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: red)),
                      ),
                    ),
                  ],
                ),
              )
              .toList(),
        ),
      ),
    );
  }
}

class _Panel extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final Widget child;
  const _Panel({required this.icon, required this.iconColor, required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).width < 720;
    return Container(
      padding: EdgeInsets.all(compact ? 12 : 14),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: border),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 14, color: iconColor),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  title,
                  style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, color: navy, letterSpacing: .3),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

class _DeadlineRow extends StatelessWidget {
  final String name;
  final String date;
  const _DeadlineRow({required this.name, required this.date});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: pageBg,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: navy)),
                const SizedBox(height: 3),
                Text(date, style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: red)),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border.all(color: border),
              borderRadius: BorderRadius.circular(3),
            ),
            child: const Text('ACTIVE', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: navy)),
          ),
        ],
      ),
    );
  }
}
