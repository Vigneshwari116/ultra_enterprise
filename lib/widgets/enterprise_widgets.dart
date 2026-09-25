import 'package:flutter/material.dart';

const navy = Color(0xFF10233F);
const navy2 = Color(0xFF17365D);
const sidebarBg = Color(0xFF1D2739);
const sidebarActiveBg = Color(0xFF99E8E9);
const teal = Color(0xFF14828A);
const tealDark = Color(0xFF3DB2B6);
const border = Color(0xFFD8DEE8);
const pageBg = Color(0xFFF4F7FB);
const green = Color(0xFF188B63);
const red = Color(0xFFB33A3A);
const amber = Color(0xFFC9862A);
const purple = Color(0xFF6E5CC7);

/// One metric tile for a dashboard, matching the accent-bar + icon layout.
class MetricCard extends StatelessWidget {
  final String label;
  final String value;
  final String sublabel;
  final IconData icon;
  final Color accent;
  final bool expand;
  const MetricCard({
    super.key,
    required this.label,
    required this.value,
    required this.sublabel,
    required this.icon,
    required this.accent,
    this.expand = true,
  });

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).width < 720;
    final card = Container(
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: border),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(height: 3, decoration: BoxDecoration(color: accent)),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(label,
                            style: const TextStyle(
                                fontSize: 9.5,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF748094),
                                letterSpacing: .3)),
                      ),
                      Icon(icon, size: 15, color: accent),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(value,
                      style: TextStyle(
                          fontSize: compact ? 15 : 17,
                          fontWeight: FontWeight.w900,
                          color: navy)),
                  const SizedBox(height: 4),
                  Text(sublabel,
                      style: TextStyle(
                          fontSize: 9, fontWeight: FontWeight.w700, color: accent)),
                ],
              ),
            ),
          ],
        ),
    );
    if (!expand) return card;
    return Expanded(child: card);
  }
}

class SectionHeader extends StatelessWidget {
  final String number;
  final String title;
  const SectionHeader({super.key, required this.number, required this.title});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      decoration: BoxDecoration(
        color: navy,
        borderRadius: BorderRadius.circular(3),
      ),
      child: Row(
        children: [
          Container(
            width: 28,
            height: 28,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(.12),
              borderRadius: BorderRadius.circular(3),
            ),
            child: Text(number,
                style: const TextStyle(
                    color: Colors.white, fontWeight: FontWeight.bold)),
          ),
          const SizedBox(width: 10),
          Text(title,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  letterSpacing: .5)),
        ],
      ),
    );
  }
}

class Field extends StatelessWidget {
  final String label;
  final Widget child;
  final bool requiredField;
  const Field({super.key, required this.label, required this.child, this.requiredField = false});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        RichText(
          text: TextSpan(
            text: label,
            style: const TextStyle(
              color: Color(0xFF39485A),
              fontSize: 10,
              fontWeight: FontWeight.w700,
            ),
            children: requiredField
                ? const [TextSpan(text: ' *', style: TextStyle(color: red))]
                : const [],
          ),
        ),
        const SizedBox(height: 4),
        child,
      ],
    );
  }
}

class DataCard extends StatelessWidget {
  final String label;
  final String value;
  const DataCard({super.key, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: border),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label,
                style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF748094))),
            const SizedBox(height: 6),
            Text(value,
                style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: navy)),
          ],
        ),
      ),
    );
  }
}

class EnterpriseTable extends StatelessWidget {
  final List<String> columns;
  final List<List<String>> rows;
  const EnterpriseTable({super.key, required this.columns, required this.rows});

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
          columns: columns
              .map((c) => DataColumn(
                    label: Text(c,
                        style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                            letterSpacing: .3)),
                  ))
              .toList(),
          rows: rows
              .map((r) => DataRow(
                    cells: r
                        .map((v) => DataCell(Text(v,
                            style: const TextStyle(fontSize: 11))))
                        .toList(),
                  ))
              .toList(),
        ),
      ),
    );
  }
}

class PrimaryButton extends StatelessWidget {
  final String label;
  final VoidCallback onPressed;
  final IconData? icon;
  const PrimaryButton({super.key, required this.label, required this.onPressed, this.icon});

  @override
  Widget build(BuildContext context) {
    return ElevatedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon ?? Icons.save_outlined, size: 16),
      label: Text(label),
      style: ElevatedButton.styleFrom(
        backgroundColor: navy,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(3)),
      ),
    );
  }
}
