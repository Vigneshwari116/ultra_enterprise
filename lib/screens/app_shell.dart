import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:ultra_enterprise/screens/purchase_reports_Screen.dart';
import '../widgets/enterprise_widgets.dart';
import 'home_screen.dart';
import 'login_screen.dart';
import 'master_screens.dart';
import 'delivery_challan_screen.dart';
import 'quotation_screen.dart';
import 'sales_invoice_screen.dart';
import 'purchase_order_screen.dart';
import 'purchase_voucher_screen.dart';
import 'reports_screen.dart';
import 'transactions_host_screen.dart';
import 'job_work_host_screen.dart';

class _NavLeaf {
  final String label;
  final int pageIndex;
  const _NavLeaf(this.label, this.pageIndex);
}

class _NavGroup {
  final String title;
  final IconData icon;
  final List<_NavLeaf> children;
  const _NavGroup(this.title, this.icon, this.children);
}

class AppShell extends StatefulWidget {
  const AppShell({super.key});
  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int index = 0;
  bool sidebarOpen = true;
  bool _sidebarDefaultSet = false;
  final Set<String> expandedGroups = {
    'Account Master',
    'Delivery Challan',
    'Quotation',
    'Sales',
    'Purchase',
    'Transactions',
    'Job Work',
    'Reports Center',
  };

  static const _sidebarWidth = 238.0;
  static const _navOverlayBreakpoint = 900.0;

  bool _useNavOverlay(BuildContext context) =>
      MediaQuery.sizeOf(context).width < _navOverlayBreakpoint;

  void _toggleSidebar() => setState(() => sidebarOpen = !sidebarOpen);

  void _closeSidebar() {
    if (!sidebarOpen) return;
    setState(() => sidebarOpen = false);
  }

  late final List<Widget> pages = [
    const HomeScreen(),
    const CustomerMasterScreen(),
    const SupplierMasterScreen(),
    const UnitMasterScreen(),
    const LedgerMasterScreen(),
    DeliveryChallanScreen(key: deliveryChallanScreenKey),
    const QuotationScreen(),
    SalesInvoiceScreen(key: salesInvoiceCatalogKey),
    SalesReportsScreen(key: reportsCenterKey),
    const PurchaseOrderScreen(),
    const PurchaseVoucherScreen(),
    const PurchaseReportsScreen(),
    TransactionsHostScreen(key: transactionsHostKey),
    JobWorkHostScreen(key: jobWorkHostKey),
  ];

  static const _groups = [
    _NavGroup('Account Master', Icons.account_balance_outlined, [
      _NavLeaf('Customer Master', 1),
      _NavLeaf('Supplier Master', 2),
      _NavLeaf('Unit Master', 3),
      _NavLeaf('Ledger Master', 4),
    ]),
    _NavGroup('Delivery Challan', Icons.local_shipping_outlined, [
      _NavLeaf('Delivery Challan', 5),
      _NavLeaf('DC History', 5),
    ]),
    _NavGroup('Quotation', Icons.request_quote_outlined, [
      _NavLeaf('Quotation Entry', 6),
    ]),
    _NavGroup('Sales', Icons.point_of_sale_outlined, [
      _NavLeaf('Sales Invoice', 7),
      _NavLeaf('Sales Reports', 8),
    ]),
    _NavGroup('Purchase', Icons.shopping_cart_outlined, [
      _NavLeaf('Purchase Order', 9),
      _NavLeaf('Purchase Voucher', 10),
      _NavLeaf('Purchase Reports', 11),
    ]),
    _NavGroup('Transactions', Icons.swap_horiz_outlined, [
      _NavLeaf('Adjustment & Return', 12),
      _NavLeaf('Cash Book', 12),
      _NavLeaf('Journal Entry', 12),
    ]),
    _NavGroup('Job Work', Icons.precision_manufacturing_outlined, [
      _NavLeaf('Material Type Master', 13),
      _NavLeaf('Material Master', 13),
    ]),
    _NavGroup('Reports Center', Icons.assessment_outlined, [
      _NavLeaf('Journal Summary', 8),
      _NavLeaf('Debit / Credit Note History', 8),
    ]),
  ];

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_sidebarDefaultSet) {
      _sidebarDefaultSet = true;
      final overlay = _useNavOverlay(context);
      if (overlay && sidebarOpen) {
        setState(() => sidebarOpen = false);
      }
    }
  }

  String _headerDate() {
    return DateFormat('EEEE, d MMMM yyyy').format(DateTime.now()).toUpperCase();
  }

  void _selectPage(int pageIndex, {String? leafLabel}) {
    setState(() {
      index = pageIndex;
      if (_useNavOverlay(context)) {
        sidebarOpen = false;
      }
    });
    if (pageIndex == 5) {
      if (leafLabel == 'DC History') {
        deliveryChallanScreenKey.currentState?.openHistory();
      } else {
        deliveryChallanScreenKey.currentState?.openEntry();
      }
    }
    if (pageIndex == 12) {
      switch (leafLabel) {
        case 'Cash Book':
          transactionsHostKey.currentState?.showCashBook();
          break;
        case 'Journal Entry':
          transactionsHostKey.currentState?.showJournal();
          break;
        default:
          transactionsHostKey.currentState?.showAdjustment();
      }
    }
    if (pageIndex == 13) {
      if (leafLabel == 'Material Master') {
        jobWorkHostKey.currentState?.showMaterialMaster();
      } else {
        jobWorkHostKey.currentState?.showMaterialType();
      }
    }
    if (pageIndex == 8) {
      switch (leafLabel) {
        case 'Journal Summary':
          reportsCenterKey.currentState?.showJournalSummary();
          break;
        case 'Debit / Credit Note History':
          reportsCenterKey.currentState?.showDebitCreditHistory();
          break;
        default:
          reportsCenterKey.currentState?.showSalesReports();
      }
    }
    if (pageIndex == 7) {
      salesInvoiceCatalogKey.currentState?.refreshCatalog();
    }
  }

  void _toggleGroup(String title) {
    setState(() {
      if (expandedGroups.contains(title)) {
        expandedGroups.remove(title);
      } else {
        expandedGroups.add(title);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final overlay = _useNavOverlay(context);
    final main = _buildMainColumn(context);

    if (overlay) {
      return Scaffold(
        body: Stack(
          children: [
            main,
            if (sidebarOpen) ...[
              Positioned.fill(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: _closeSidebar,
                  child: ColoredBox(color: Colors.black.withOpacity(0.45)),
                ),
              ),
              Positioned(
                left: 0,
                top: 0,
                bottom: 0,
                child: Material(
                  elevation: 12,
                  color: sidebarBg,
                  child: _buildSidebarPanel(context, showCloseControl: true),
                ),
              ),
            ],
          ],
        ),
      );
    }

    return Scaffold(
      body: Row(
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeInOut,
            width: sidebarOpen ? _sidebarWidth : 0,
            clipBehavior: Clip.hardEdge,
            decoration: const BoxDecoration(color: sidebarBg),
            child: IgnorePointer(
              ignoring: !sidebarOpen,
              child: SizedBox(
                width: _sidebarWidth,
                child: _buildSidebarPanel(context, showCloseControl: true),
              ),
            ),
          ),
          Expanded(child: main),
        ],
      ),
    );
  }

  Widget _buildMainColumn(BuildContext context) {
    return Column(
      children: [
        Container(
          height: MediaQuery.sizeOf(context).width < 720 ? 58 : 66,
          padding: EdgeInsets.symmetric(horizontal: MediaQuery.sizeOf(context).width < 720 ? 10 : 20),
          decoration: const BoxDecoration(
            color: Colors.white,
            border: Border(bottom: BorderSide(color: border)),
          ),
          child: Row(
            children: [
              IconButton(
                tooltip: sidebarOpen ? 'Close navigation' : 'Open navigation',
                onPressed: _toggleSidebar,
                icon: Icon(
                  sidebarOpen ? Icons.close : Icons.grid_view_rounded,
                  color: navy,
                  size: 22,
                ),
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'COMMERCIAL ENTERPRISE PLATFORM ENGINE',
                      style: TextStyle(
                        color: navy,
                        fontSize: MediaQuery.sizeOf(context).width < 720 ? 12 : 14,
                        fontWeight: FontWeight.w900,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 3),
                    Text(
                      _headerDate(),
                      style: const TextStyle(
                        color: Color(0xFF748094),
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              if (MediaQuery.sizeOf(context).width >= 520) ...[
                const Text(
                  'ULTRA ENGINEERING',
                  style: TextStyle(
                    color: navy,
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(width: 10),
              ],
              const Text(
                'SUPERUSER',
                style: TextStyle(
                  color: teal,
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(width: 10),
              CircleAvatar(
                radius: 17,
                backgroundColor: navy,
                child: const Icon(Icons.person, size: 17, color: Colors.white),
              ),
            ],
          ),
        ),
        Expanded(child: IndexedStack(index: index, children: pages)),
      ],
    );
  }

  Widget _buildSidebarPanel(BuildContext context, {required bool showCloseControl}) {
    return SizedBox(
      width: _sidebarWidth,
      child: Column(
        children: [
          const SizedBox(height: 22),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18),
            child: InkWell(
              onTap: _toggleSidebar,
              borderRadius: BorderRadius.circular(4),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    const Icon(Icons.grid_view_rounded, color: teal, size: 15),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'NAVIGATION MATRIX',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w900,
                          letterSpacing: .8,
                        ),
                      ),
                    ),
                    if (showCloseControl)
                      Icon(
                        sidebarOpen ? Icons.close : Icons.keyboard_arrow_right,
                        color: Colors.white54,
                        size: 18,
                      ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 18),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.only(bottom: 8),
              children: [
                _dashboardItem(),
                ..._groups.map(_groupSection),
              ],
            ),
          ),
          const Divider(color: Color(0xFF31445F), height: 1),
          InkWell(
            onTap: () => Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (_) => const LoginScreen()),
            ),
            child: Container(
              margin: const EdgeInsets.fromLTRB(12, 10, 12, 12),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
              decoration: BoxDecoration(
                color: red.withOpacity(.12),
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: red.withOpacity(.35)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: const [
                  Icon(Icons.logout, color: red, size: 16),
                  SizedBox(width: 8),
                  Text(
                    'SIGN OUT ENGINE',
                    style: TextStyle(
                      color: red,
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      letterSpacing: .3,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _dashboardItem() {
    final selected = index == 0;
    return InkWell(
      onTap: () => _selectPage(0),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 9, vertical: 2),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 11),
        decoration: BoxDecoration(
          color: selected ? sidebarActiveBg : Colors.transparent,
          borderRadius: BorderRadius.circular(3),
        ),
        child: Row(
          children: [
            Icon(
              Icons.dashboard_outlined,
              size: 16,
              color: selected ? tealDark : Colors.white70,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Dashboard',
                style: TextStyle(
                  color: selected ? tealDark : Colors.white70,
                  fontSize: 10.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _groupSection(_NavGroup group) {
    final expanded = expandedGroups.contains(group.title);
    final childSelected = group.children.any((c) => c.pageIndex == index);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        InkWell(
          onTap: () => _toggleGroup(group.title),
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 9, vertical: 2),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 11),
            decoration: BoxDecoration(
              color: childSelected && !expanded ? Colors.white.withOpacity(.06) : Colors.transparent,
              borderRadius: BorderRadius.circular(3),
            ),
            child: Row(
              children: [
                Icon(group.icon, size: 16, color: Colors.white70),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    group.title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                Icon(
                  expanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                  size: 18,
                  color: Colors.white54,
                ),
              ],
            ),
          ),
        ),
        if (expanded)
          ...group.children.map((leaf) {
            final highlight = index == leaf.pageIndex;
            return InkWell(
              onTap: () => _selectPage(leaf.pageIndex, leafLabel: leaf.label),
              child: Padding(
                padding: const EdgeInsets.only(left: 28, right: 12, top: 2, bottom: 2),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(top: 5),
                      child: Container(
                        width: 4,
                        height: 4,
                        decoration: BoxDecoration(
                          color: highlight ? sidebarActiveBg : Colors.white38,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        child: Text(
                          leaf.label,
                          style: TextStyle(
                            color: highlight ? sidebarActiveBg : Colors.white60,
                            fontSize: 10,
                            fontWeight: highlight ? FontWeight.w800 : FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
      ],
    );
  }
}
