import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'enterprise_widgets.dart';

String formatDisplayDate(DateTime? date) {
  if (date == null) return '—';
  return DateFormat('dd-MM-yyyy').format(date);
}

String formatIsoDate(DateTime date) => DateFormat('yyyy-MM-dd').format(date);

/// Compact calendar inside a dialog (not full-screen route).
Future<DateTime?> pickCompactDate(
  BuildContext context, {
  required DateTime initialDate,
  DateTime? firstDate,
  DateTime? lastDate,
}) async {
  final now = DateTime.now();
  final first = firstDate ?? DateTime(now.year - 5);
  final last = lastDate ?? DateTime(now.year + 1);
  var selected = initialDate;

  return showDialog<DateTime>(
    context: context,
    builder: (ctx) {
      return Dialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 360),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 8, 0),
                child: Row(
                  children: [
                    const Text(
                      'SELECT DATE',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: navy,
                        letterSpacing: .4,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      visualDensity: VisualDensity.compact,
                      onPressed: () => Navigator.pop(ctx),
                      icon: const Icon(Icons.close, size: 18, color: Color(0xFF748094)),
                    ),
                  ],
                ),
              ),
              SizedBox(
                height: 320,
                child: CalendarDatePicker(
                  initialDate: initialDate.isBefore(first)
                      ? first
                      : (initialDate.isAfter(last) ? last : initialDate),
                  firstDate: first,
                  lastDate: last,
                  onDateChanged: (d) => selected = d,
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: () => Navigator.pop(ctx, selected),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: navy,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                      ),
                      child: const Text('OK'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}

/// Inline FROM / TO date range control (compact, not full-screen).
class CompactDateRangeBar extends StatelessWidget {
  final DateTime? from;
  final DateTime? to;
  final ValueChanged<DateTime> onFromChanged;
  final ValueChanged<DateTime> onToChanged;
  final VoidCallback? onClear;
  final String fromLabel;
  final String toLabel;

  const CompactDateRangeBar({
    super.key,
    this.from,
    this.to,
    required this.onFromChanged,
    required this.onToChanged,
    this.onClear,
    this.fromLabel = 'FROM',
    this.toLabel = 'TO',
  });

  Future<void> _pick(BuildContext context, bool isFrom) async {
    final now = DateTime.now();
    final initial = isFrom
        ? (from ?? now)
        : (to ?? from ?? now);
    final picked = await pickCompactDate(
      context,
      initialDate: initial,
      firstDate: DateTime(now.year - 10),
      lastDate: DateTime(now.year + 2),
    );
    if (picked == null) return;
    if (isFrom) {
      onFromChanged(picked);
      if (to != null && to!.isBefore(picked)) {
        onToChanged(picked);
      }
    } else {
      onToChanged(picked.isBefore(from ?? picked) ? (from ?? picked) : picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: border),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.calendar_today_outlined, size: 14, color: Color(0xFF748094)),
          const SizedBox(width: 8),
          _chip(context, fromLabel, from, () => _pick(context, true)),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6),
            child: Text('—', style: TextStyle(color: Colors.grey.shade500, fontWeight: FontWeight.w700)),
          ),
          _chip(context, toLabel, to, () => _pick(context, false)),
          if (onClear != null && (from != null || to != null)) ...[
            const SizedBox(width: 4),
            InkWell(
              onTap: onClear,
              child: const Padding(
                padding: EdgeInsets.all(4),
                child: Icon(Icons.close, size: 14, color: Color(0xFF748094)),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _chip(BuildContext context, String label, DateTime? value, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(3),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: const TextStyle(fontSize: 8, fontWeight: FontWeight.w800, color: Color(0xFF9AA5B4)),
            ),
            Text(
              value == null ? 'Select' : formatDisplayDate(value),
              style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, color: navy),
            ),
          ],
        ),
      ),
    );
  }
}

/// Opens a small dialog to pick both ends of a range with FROM/TO fields.
Future<DateTimeRange?> pickCompactDateRange(
  BuildContext context, {
  DateTimeRange? initial,
}) async {
  final now = DateTime.now();
  var from = initial?.start ?? now.subtract(const Duration(days: 30));
  var to = initial?.end ?? now;

  return showDialog<DateTimeRange>(
    context: context,
    builder: (ctx) {
      return StatefulBuilder(
        builder: (ctx, setLocal) {
          Future<void> pick(bool isFrom) async {
            final picked = await pickCompactDate(
              ctx,
              initialDate: isFrom ? from : to,
            );
            if (picked == null) return;
            setLocal(() {
              if (isFrom) {
                from = picked;
                if (to.isBefore(from)) to = from;
              } else {
                to = picked.isBefore(from) ? from : picked;
              }
            });
          }

          return Dialog(
            insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 380),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      'DATE RANGE',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: navy),
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => pick(true),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
                              side: const BorderSide(color: border),
                            ),
                            child: Column(
                              children: [
                                const Text('FROM', style: TextStyle(fontSize: 8, fontWeight: FontWeight.w800, color: Color(0xFF9AA5B4))),
                                Text(formatDisplayDate(from), style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: navy)),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => pick(false),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
                              side: const BorderSide(color: border),
                            ),
                            child: Column(
                              children: [
                                const Text('TO', style: TextStyle(fontSize: 8, fontWeight: FontWeight.w800, color: Color(0xFF9AA5B4))),
                                Text(formatDisplayDate(to), style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: navy)),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
                        const SizedBox(width: 8),
                        ElevatedButton(
                          onPressed: () => Navigator.pop(ctx, DateTimeRange(start: from, end: to)),
                          style: ElevatedButton.styleFrom(backgroundColor: navy, foregroundColor: Colors.white),
                          child: const Text('Apply'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      );
    },
  );
}
