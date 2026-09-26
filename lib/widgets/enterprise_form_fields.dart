import 'package:flutter/material.dart';

import 'enterprise_widgets.dart';

const enterpriseInsetLabelStyle = TextStyle(
  fontSize: 9,
  fontWeight: FontWeight.w700,
  color: Color(0xFF748094),
  letterSpacing: 0.2,
);

const enterpriseInsetValueStyle = TextStyle(
  fontSize: 11.5,
  fontWeight: FontWeight.w600,
  color: navy,
);

InputDecoration enterpriseInsetInputDecoration({Widget? suffixIcon, Widget? prefixIcon}) {
  return InputDecoration(
    isDense: true,
    border: InputBorder.none,
    enabledBorder: InputBorder.none,
    focusedBorder: InputBorder.none,
    contentPadding: EdgeInsets.zero,
    suffixIcon: suffixIcon,
    prefixIcon: prefixIcon,
  );
}

BoxDecoration enterpriseInsetBoxDecoration({bool filled = false, Color? borderColor}) {
  return BoxDecoration(
    color: filled ? const Color(0xFFF1F3F7) : Colors.white,
    border: Border.all(color: borderColor ?? border),
    borderRadius: BorderRadius.circular(4),
  );
}

Widget enterpriseInsetFieldShell({
  required String label,
  required Widget child,
  bool filled = false,
  Color? borderColor,
  EdgeInsets padding = const EdgeInsets.fromLTRB(10, 7, 10, 6),
}) {
  return Container(
    decoration: enterpriseInsetBoxDecoration(filled: filled, borderColor: borderColor),
    padding: padding,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label, style: enterpriseInsetLabelStyle),
        const SizedBox(height: 3),
        child,
      ],
    ),
  );
}

Widget enterpriseInsetTextField({
  required String label,
  TextEditingController? controller,
  int maxLines = 1,
  bool readOnly = false,
  bool filled = false,
  VoidCallback? onTap,
  TextStyle? style,
  Widget? suffixIcon,
  Widget? prefixIcon,
  TextInputType? keyboardType,
  ValueChanged<String>? onChanged,
}) {
  return enterpriseInsetFieldShell(
    label: label,
    filled: filled,
    child: TextField(
      controller: controller,
      maxLines: maxLines,
      readOnly: readOnly,
      onTap: onTap,
      keyboardType: keyboardType,
      onChanged: onChanged,
      style: style ?? enterpriseInsetValueStyle,
      decoration: enterpriseInsetInputDecoration(suffixIcon: suffixIcon, prefixIcon: prefixIcon),
    ),
  );
}

Widget enterpriseInsetDropdown<T>({
  required String label,
  required T? value,
  required List<DropdownMenuItem<T>> items,
  required ValueChanged<T?>? onChanged,
  Widget? hint,
  Color? borderColor,
}) {
  return Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: enterpriseInsetFieldShell(
      label: label,
      borderColor: borderColor,
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          isExpanded: true,
          isDense: true,
          value: value,
          hint: hint,
          items: items,
          onChanged: onChanged,
        ),
      ),
    ),
  );
}

/// Horizontally scrollable line-item matrix; stretches to full row width on wide layouts.
Widget enterpriseMatrixScroller({required Table table, double minWidth = 640}) {
  return LayoutBuilder(
    builder: (context, constraints) {
      var width = constraints.maxWidth;
      if (!width.isFinite || width <= 0) {
        width = minWidth;
      }
      final tableWidth = width < minWidth ? minWidth : width;
      final content = SizedBox(width: tableWidth, child: table);
      if (tableWidth > width + 1 && width.isFinite) {
        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: content,
        );
      }
      return content;
    },
  );
}

/// Original portal layout: value-in-words bar with charge panel on the right (same row).
Widget enterpriseValueWordsFooter({
  required String valueInWords,
  String wordsLabel = 'VALUE IN WORDS',
  TextEditingController? chargeController,
  String chargeLabel = 'FWD CHARGE',
  ValueChanged<String>? onChargeChanged,
  Color wordsColor = Colors.white,
}) {
  final wordsBar = Container(
    width: double.infinity,
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
    decoration: BoxDecoration(
      color: const Color(0xFF19232C),
      borderRadius: BorderRadius.circular(4),
    ),
    child: Text(
      '$wordsLabel: $valueInWords',
      style: TextStyle(color: wordsColor, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 0.3),
    ),
  );

  if (chargeController == null) {
    return wordsBar;
  }

  return IntrinsicHeight(
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(child: wordsBar),
        const SizedBox(width: 12),
        SizedBox(
          width: 220,
          child: Container(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
            decoration: BoxDecoration(
              color: const Color(0xFF19232C),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  chargeLabel,
                  style: const TextStyle(color: Colors.white54, fontSize: 8.5, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 6),
                TextField(
                  controller: chargeController,
                  keyboardType: TextInputType.number,
                  onChanged: onChargeChanged,
                  textAlign: TextAlign.right,
                  style: const TextStyle(color: Color(0xFFF4D53A), fontWeight: FontWeight.w900, fontSize: 16),
                  decoration: enterpriseInsetInputDecoration(),
                ),
              ],
            ),
          ),
        ),
      ],
    ),
  );
}

/// Sales invoice / purchase order quantity matrix columns (flex = full-width grid).
const Map<int, TableColumnWidth> enterpriseProductMatrixColumns = {
  0: FlexColumnWidth(0.55),
  1: FlexColumnWidth(2.85),
  2: FlexColumnWidth(0.9),
  3: FlexColumnWidth(1.0),
  4: FlexColumnWidth(0.85),
  5: FlexColumnWidth(0.95),
  6: FlexColumnWidth(0.75),
  7: FlexColumnWidth(0.75),
  8: FlexColumnWidth(0.75),
  9: FlexColumnWidth(1.15),
  10: FlexColumnWidth(0.55),
};

/// Delivery challan material matrix (non-proforma base columns).
Map<int, TableColumnWidth> deliveryChallanMatrixColumns({required bool proforma, required bool includeRemarks}) {
  final flex = <double>[0.55, 2.65, 0.9, 1.0, 0.85, 0.95];
  if (proforma) {
    flex.addAll([0.75, 0.75, 0.75]);
  }
  flex.add(1.1);
  if (includeRemarks) flex.add(2.0);
  flex.add(0.55);
  return {for (var i = 0; i < flex.length; i++) i: FlexColumnWidth(flex[i])};
}

const Map<int, TableColumnWidth> quotationMatrixColumns = {
  0: FlexColumnWidth(0.55),
  1: FlexColumnWidth(2.75),
  2: FlexColumnWidth(0.95),
  3: FlexColumnWidth(1.0),
  4: FlexColumnWidth(1.0),
  5: FlexColumnWidth(1.15),
  6: FlexColumnWidth(0.55),
};

/// Debit/credit note reversal line matrix (matches sales invoice grid).
const Map<int, TableColumnWidth> adjustmentNoteMatrixColumns = {
  0: FlexColumnWidth(0.55),
  1: FlexColumnWidth(2.85),
  2: FlexColumnWidth(0.9),
  3: FlexColumnWidth(1.0),
  4: FlexColumnWidth(0.85),
  5: FlexColumnWidth(0.95),
  6: FlexColumnWidth(0.75),
  7: FlexColumnWidth(0.75),
  8: FlexColumnWidth(0.75),
  9: FlexColumnWidth(1.15),
  10: FlexColumnWidth(0.55),
};

const TextStyle enterpriseMatrixHeadStyle = TextStyle(
  color: Colors.white,
  fontWeight: FontWeight.w800,
  fontSize: 7.5,
  height: 1.15,
);

const TextStyle enterpriseMatrixCellStyle = TextStyle(
  fontSize: 9.5,
  fontWeight: FontWeight.w600,
  color: navy,
);

final InputDecoration enterpriseMatrixInputDecoration = InputDecoration(
  isDense: true,
  contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
  border: OutlineInputBorder(borderRadius: BorderRadius.circular(3)),
  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(3), borderSide: const BorderSide(color: border)),
);

Widget enterpriseMatrixHeadCell(String label) {
  return Padding(
    padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 7),
    child: Text(label, style: enterpriseMatrixHeadStyle, maxLines: 2, overflow: TextOverflow.ellipsis),
  );
}
