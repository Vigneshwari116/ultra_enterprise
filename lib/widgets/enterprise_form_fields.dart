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
}) {
  return enterpriseInsetFieldShell(
    label: label,
    filled: filled,
    child: TextField(
      controller: controller,
      maxLines: maxLines,
      readOnly: readOnly,
      onTap: onTap,
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

/// Horizontally scrollable line-item matrix with fixed column widths (matches web portal).
Widget enterpriseMatrixScroller({required Table table, double minWidth = 640}) {
  return SingleChildScrollView(
    scrollDirection: Axis.horizontal,
    child: ConstrainedBox(
      constraints: BoxConstraints(minWidth: minWidth),
      child: table,
    ),
  );
}

/// Original portal layout: freight/fwd box above, full-width value-in-words bar below.
Widget enterpriseValueWordsFooter({
  required String valueInWords,
  String wordsLabel = 'VALUE IN WORDS',
  TextEditingController? chargeController,
  String chargeLabel = 'FWD CHARGE',
  ValueChanged<String>? onChargeChanged,
  Color wordsColor = Colors.white,
}) {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      if (chargeController != null)
        Align(
          alignment: Alignment.centerRight,
          child: Container(
            width: 118,
            padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
            decoration: BoxDecoration(
              color: const Color(0xFF19232C),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(chargeLabel, style: const TextStyle(color: Colors.white54, fontSize: 8, fontWeight: FontWeight.w700)),
                const SizedBox(height: 2),
                TextField(
                  controller: chargeController,
                  keyboardType: TextInputType.number,
                  onChanged: onChargeChanged,
                  style: const TextStyle(color: Color(0xFFF4D53A), fontWeight: FontWeight.w900, fontSize: 13),
                  decoration: enterpriseInsetInputDecoration(),
                ),
              ],
            ),
          ),
        ),
      if (chargeController != null) const SizedBox(height: 8),
      Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: const Color(0xFF19232C),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(
          '$wordsLabel: $valueInWords',
          style: TextStyle(color: wordsColor, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 0.3),
        ),
      ),
    ],
  );
}

/// Sales invoice / purchase order quantity matrix columns.
const Map<int, TableColumnWidth> enterpriseProductMatrixColumns = {
  0: FixedColumnWidth(24),
  1: FixedColumnWidth(128),
  2: FixedColumnWidth(42),
  3: FixedColumnWidth(46),
  4: FixedColumnWidth(40),
  5: FixedColumnWidth(44),
  6: FixedColumnWidth(36),
  7: FixedColumnWidth(36),
  8: FixedColumnWidth(36),
  9: FixedColumnWidth(54),
  10: FixedColumnWidth(28),
};

/// Delivery challan material matrix (non-proforma base columns).
Map<int, TableColumnWidth> deliveryChallanMatrixColumns({required bool proforma, required bool includeRemarks}) {
  final widths = <int, TableColumnWidth>{
    0: const FixedColumnWidth(28),
    1: const FixedColumnWidth(128),
    2: const FixedColumnWidth(44),
    3: const FixedColumnWidth(48),
    4: const FixedColumnWidth(40),
    5: const FixedColumnWidth(44),
  };
  var col = 6;
  if (proforma) {
    widths[col++] = const FixedColumnWidth(38);
    widths[col++] = const FixedColumnWidth(38);
    widths[col++] = const FixedColumnWidth(38);
  }
  widths[col++] = const FixedColumnWidth(52);
  if (includeRemarks) widths[col++] = const FixedColumnWidth(92);
  widths[col] = const FixedColumnWidth(28);
  return widths;
}

const Map<int, TableColumnWidth> quotationMatrixColumns = {
  0: FixedColumnWidth(28),
  1: FixedColumnWidth(136),
  2: FixedColumnWidth(48),
  3: FixedColumnWidth(52),
  4: FixedColumnWidth(52),
  5: FixedColumnWidth(58),
  6: FixedColumnWidth(28),
};
