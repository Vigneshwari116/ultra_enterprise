import 'package:flutter/material.dart';
import '../widgets/enterprise_widgets.dart';
import 'home_screen.dart';
import 'master_screens.dart';
import 'sales_invoice_screen.dart';
import 'reports_screen.dart';
import 'transaction_screens.dart';
import 'stock_screen.dart';
import 'sync_screen.dart';

class AppShell extends StatefulWidget {
  const AppShell({super.key});
  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int index = 0;

  final pages = const [
    HomeScreen(),
    UnitMasterScreen(),
    LedgerMasterScreen(),
    CustomerMasterScreen(),
    ProductMasterScreen(),
    DeliveryChallanScreen(),
    QuotationScreen(),
    SalesInvoiceScreen(),
    SalesReportsScreen(),
    PurchaseOrderScreen(),
    PurchaseVoucherScreen(),
    PurchaseReportsScreen(),
    TransactionsScreen(),
    StockScreen(),
    SyncScreen(),
  ];

  final labels = const [
    'Dashboard',
    'Unit Master',
    'Ledger Master',
    'Customer Master',
    'Product / Material Master',
    'Delivery Challan',
    'Quotation',
    'Sales Invoice',
    'Sales Reports',
    'Purchase Order',
    'Purchase Voucher',
    'Purchase Reports',
    'Transactions',
    'Stock',
    'Sync Queue',
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Row(
        children: [
          Container(
            width: 238,
            color: sidebarBg,
            child: Column(
              children: [
                const SizedBox(height: 22),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 18),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Row(
                      children: [
                        Icon(Icons.grid_view_rounded, color: teal, size: 15),
                        SizedBox(width: 8),
                        Text('NAVIGATION MATRIX',
                            style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w900, letterSpacing: .8)),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                Expanded(
                  child: ListView.builder(
                    itemCount: labels.length,
                    itemBuilder: (_, i) => _navItem(i, labels[i]),
                  ),
                ),
                const Divider(color: Color(0xFF31445F)),
                ListTile(
                  leading: const Icon(Icons.logout, color: Colors.white70, size: 18),
                  title: const Text('SIGN OUT ENGINE', style: TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.w700)),
                  onTap: () => Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const HomeScreen())),
                ),
                const SizedBox(height: 12),
              ],
            ),
          ),
          Expanded(
            child: Column(
              children: [
                Container(
                  height: 66,
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  decoration: const BoxDecoration(color: Colors.white, border: Border(bottom: BorderSide(color: border))),
                  child: Row(
                    children: [
                      const Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('COMMERCIAL ENTERPRISE PLATFORM ENGINE',
                              style: TextStyle(color: navy, fontSize: 15, fontWeight: FontWeight.w900)),
                          SizedBox(height: 3),
                          Text('WEDNESDAY, 23 SEPTEMBER 2026',
                              style: TextStyle(color: Color(0xFF748094), fontSize: 10, fontWeight: FontWeight.w700)),
                        ],
                      ),
                      const Spacer(),
                      const Text('SUPERUSER',
                          style: TextStyle(color: teal, fontSize: 11, fontWeight: FontWeight.w800)),
                      const SizedBox(width: 10),
                      CircleAvatar(
                        radius: 17,
                        backgroundColor: navy,
                        child: const Icon(Icons.person, size: 17, color: Colors.white),
                      )
                    ],
                  ),
                ),
                Expanded(child: IndexedStack(index: index, children: pages)),
              ],
            ),
          )
        ],
      ),
    );
  }

  Widget _navItem(int i, String label) {
    final selected = index == i;
    return InkWell(
      onTap: () => setState(() => index = i),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 9, vertical: 2),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 11),
        decoration: BoxDecoration(
          color: selected ? sidebarActiveBg : Colors.transparent,
          borderRadius: BorderRadius.circular(3),
        ),
        child: Row(
          children: [
            Icon(_iconFor(i), size: 16, color: selected ? tealDark : Colors.white70),
            const SizedBox(width: 10),
            Expanded(child: Text(label,
                style: TextStyle(color: selected ? tealDark : Colors.white70, fontSize: 10.5, fontWeight: FontWeight.w700))),
          ],
        ),
      ),
    );
  }

  IconData _iconFor(int i) {
    const icons = [
      Icons.dashboard_outlined, Icons.straighten, Icons.account_balance_wallet_outlined,
      Icons.people_outline, Icons.inventory_2_outlined, Icons.local_shipping_outlined,
      Icons.request_quote_outlined, Icons.receipt_long_outlined, Icons.analytics_outlined,
      Icons.shopping_cart_outlined, Icons.receipt_outlined, Icons.assessment_outlined,
      Icons.swap_horiz, Icons.warehouse_outlined, Icons.sync_outlined
    ];
    return icons[i];
  }
}
