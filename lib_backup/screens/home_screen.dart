import 'package:flutter/material.dart';
import '../widgets/enterprise_widgets.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});
  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Text('REAL-TIME ERP MASTER ANALYTICS ENGINE',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: navy)),
                  SizedBox(height: 4),
                  Text('LIVE DATA CONNECTION • 22 SEPTEMBER 2026',
                      style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: teal)),
                ],
              ),
            ),
            IconButton(
              onPressed: () {},
              icon: const Icon(Icons.refresh, size: 18, color: Color(0xFF748094)),
            ),
          ],
        ),
        const SizedBox(height: 16),
        const Row(children: [
          MetricCard(
              label: 'RUNNING PROJECTS',
              value: '1 ACTIVE',
              sublabel: 'LIVE PIPELINE',
              icon: Icons.flag_outlined,
              accent: teal),
          SizedBox(width: 12),
          MetricCard(
              label: 'PENDING PURCHASE ORDERS',
              value: '3 ORDERS',
              sublabel: 'PROCUREMENT STATUS',
              icon: Icons.cloud_outlined,
              accent: amber),
          SizedBox(width: 12),
          MetricCard(
              label: 'CUSTOMER OUTSTANDING',
              value: '₹2,73,430.00',
              sublabel: 'ACCOUNTS RECEIVABLE TOTAL',
              icon: Icons.credit_card_outlined,
              accent: green),
          SizedBox(width: 12),
          MetricCard(
              label: 'SUPPLIER OUTSTANDING',
              value: '₹79,587.00',
              sublabel: 'VENDORS PAYABLE LIABILITY',
              icon: Icons.credit_card_outlined,
              accent: red),
          SizedBox(width: 12),
          MetricCard(
              label: 'MONTHLY EXPENSES',
              value: '₹.00',
              sublabel: 'FACTORY RUNNING OVERHEADS',
              icon: Icons.bar_chart_outlined,
              accent: purple),
        ]),
        const SizedBox(height: 20),
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 3,
                child: _Panel(
                  icon: Icons.watch_later_outlined,
                  iconColor: amber,
                  title: 'PROJECT DEADLINE TRACKING MONITOR',
                  child: const EnterpriseTable(
                    columns: ['PROJECT NO', 'CLIENT PARTY REGISTRY', "QUANTITY'S", 'RUNNING DAYS', 'SCHEDULER STATE'],
                    rows: [
                      ['N/A', 'K . KM', '1', '60 Days', 'ACTIVE'],
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                flex: 2,
                child: _Panel(
                  icon: Icons.shield_outlined,
                  iconColor: red,
                  title: 'CRITICAL PROJECT DISPATCH DEADLINES',
                  child: Column(
                    children: const [
                      _DeadlineRow(name: 'DEMO PROJECT1', date: '2026-07-31 TIMELINE'),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ]),
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
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: border),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(icon, size: 14, color: iconColor),
            const SizedBox(width: 8),
            Text(title,
                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: navy, letterSpacing: .3)),
          ]),
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
