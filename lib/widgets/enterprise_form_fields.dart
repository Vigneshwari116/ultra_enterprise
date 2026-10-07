import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'enterprise_widgets.dart';

/// Shared transaction-form typography (all commercial entry screens).
const enterpriseInsetLabelStyle = TextStyle(
  fontSize: 12,
  fontWeight: FontWeight.w700,
  color: Color(0xFF748094),
  letterSpacing: 0.2,
);

const enterpriseInsetValueStyle = TextStyle(
  fontSize: 15,
  fontWeight: FontWeight.w600,
  color: navy,
);

const enterpriseSectionTitleStyle = TextStyle(
  fontSize: 14,
  fontWeight: FontWeight.w800,
  color: navy,
  letterSpacing: 0.3,
);

const enterpriseTerminalStatLabelStyle = TextStyle(
  color: Colors.white54,
  fontSize: 10.5,
  fontWeight: FontWeight.w700,
);

const enterpriseTerminalStatValueStyle = TextStyle(
  color: Colors.white,
  fontSize: 14,
  fontWeight: FontWeight.w800,
);

/// Tighter inset boxes for metadata sections (sections 1 & 2).
const enterpriseCompactFieldPadding = EdgeInsets.fromLTRB(8, 4, 8, 5);

const double enterpriseFormRowGap = 3;
const double enterpriseFormColumnGap = 8;

InputDecoration enterpriseInsetInputDecoration({
  Widget? suffixIcon,
  Widget? prefixIcon,
  bool multiline = false,
  bool onDarkPanel = false,
}) {
  return InputDecoration(
    isDense: true,
    filled: false,
    fillColor: Colors.transparent,
    border: InputBorder.none,
    enabledBorder: InputBorder.none,
    focusedBorder: InputBorder.none,
    contentPadding: EdgeInsets.zero,
    constraints: multiline ? null : const BoxConstraints(minHeight: 0),
    isCollapsed: !multiline,
    suffixIcon: suffixIcon,
    prefixIcon: prefixIcon,
    hoverColor: onDarkPanel ? Colors.transparent : null,
  );
}

BoxDecoration enterpriseInsetBoxDecoration({bool filled = false, Color? borderColor}) {
  return BoxDecoration(
    color: filled ? const Color(0xFFF1F3F7) : Colors.white,
    border: Border.all(color: borderColor ?? border),
    borderRadius: BorderRadius.circular(4),
  );
}

/// Moves keyboard focus to the next field (Enter / Next).
void enterpriseAdvanceFocus(BuildContext context) {
  FocusScope.of(context).nextFocus();
}

Widget enterpriseInsetFieldShell({
  required String label,
  required Widget child,
  bool filled = false,
  Color? borderColor,
  EdgeInsets padding = enterpriseCompactFieldPadding,
}) {
  return Container(
    decoration: enterpriseInsetBoxDecoration(filled: filled, borderColor: borderColor),
    padding: padding,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label, style: enterpriseInsetLabelStyle),
        const SizedBox(height: 1),
        child,
      ],
    ),
  );
}

/// Section 1 / 2 block title with divider (compact spacing).
Widget enterprisePlainSection({
  required String title,
  required List<Widget> children,
}) {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(title, style: enterpriseSectionTitleStyle),
      const SizedBox(height: 3),
      Container(height: 1, color: border),
      const SizedBox(height: 6),
      ...children,
    ],
  );
}

/// Two fields on one row with reduced gap.
Widget enterpriseFormPair(Widget left, Widget right) {
  return Padding(
    padding: const EdgeInsets.only(bottom: enterpriseFormRowGap),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: left),
        const SizedBox(width: enterpriseFormColumnGap),
        Expanded(child: right),
      ],
    ),
  );
}

/// Wraps a single inset field with compact row spacing.
Widget enterpriseFormField(Widget field) {
  return Padding(
    padding: const EdgeInsets.only(bottom: enterpriseFormRowGap),
    child: field,
  );
}

Widget enterpriseStatMini(String label, String value) {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(label, style: enterpriseTerminalStatLabelStyle),
      const SizedBox(height: 2),
      Text(value, style: enterpriseTerminalStatValueStyle),
    ],
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
  bool advanceFocusOnSubmit = true,
  bool autofocus = false,
}) {
  return enterpriseInsetFieldShell(
    label: label,
    filled: filled,
    child: Builder(
      builder: (ctx) {
        final multiline = maxLines > 1;
        return TextField(
          controller: controller,
          maxLines: maxLines,
          minLines: multiline ? 1 : 1,
          readOnly: readOnly,
          autofocus: autofocus,
          onTap: onTap,
          keyboardType: keyboardType,
          onChanged: onChanged,
          style: style ?? enterpriseInsetValueStyle,
          textAlignVertical: multiline ? TextAlignVertical.top : TextAlignVertical.center,
          textInputAction: advanceFocusOnSubmit ? TextInputAction.next : TextInputAction.done,
          onSubmitted: advanceFocusOnSubmit ? (_) => enterpriseAdvanceFocus(ctx) : null,
          decoration: enterpriseInsetInputDecoration(
            suffixIcon: suffixIcon,
            prefixIcon: prefixIcon,
            multiline: multiline,
          ),
          scrollPadding: EdgeInsets.zero,
        );
      },
    ),
  );
}

/// Tappable date row: value left, calendar right (no wide empty TextField gap).
Widget enterpriseInsetDateField({
  required String label,
  required String isoDate,
  required VoidCallback onTap,
  bool filled = false,
}) {
  final parsed = DateTime.tryParse(isoDate);
  final display = parsed == null ? isoDate : DateFormat('dd-MM-yyyy').format(parsed);
  return enterpriseInsetFieldShell(
    label: label,
    filled: filled,
    child: InkWell(
      onTap: onTap,
      child: Padding(
        padding: EdgeInsets.zero,
        child: Row(
          children: [
            Text(display, style: enterpriseInsetValueStyle),
            const Spacer(),
            const Icon(Icons.calendar_today_outlined, size: 18, color: Color(0xFF748094)),
          ],
        ),
      ),
    ),
  );
}

/// [SingleChildScrollView] child: forces full viewport width for matrices/footers.
Widget enterpriseScrollColumn({required List<Widget> children}) {
  return LayoutBuilder(
    builder: (context, constraints) {
      final minW = constraints.maxWidth.isFinite && constraints.maxWidth > 0
          ? constraints.maxWidth
          : MediaQuery.sizeOf(context).width;
      return ConstrainedBox(
        constraints: BoxConstraints(minWidth: minW),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: children,
        ),
      );
    },
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
    padding: const EdgeInsets.only(bottom: enterpriseFormRowGap),
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
          style: enterpriseInsetValueStyle,
        ),
      ),
    ),
  );
}

/// Horizontally scrollable line-item matrix; stretches to full row width on wide layouts.
Widget enterpriseMatrixScroller({required Table table, double minWidth = 960}) {
  return LayoutBuilder(
    builder: (context, constraints) {
      var width = constraints.maxWidth;
      if (!width.isFinite || width <= 0) {
        width = MediaQuery.sizeOf(context).width;
      }
      final tableWidth = width < minWidth ? minWidth : width;
      final content = SizedBox(width: tableWidth, child: table);
      if (tableWidth > width + 1 && width.isFinite && width > 0) {
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
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
    decoration: BoxDecoration(
      color: const Color(0xFF19232C),
      borderRadius: BorderRadius.circular(4),
    ),
    child: Text(
      '$wordsLabel: $valueInWords',
      style: TextStyle(color: wordsColor, fontSize: 14, fontWeight: FontWeight.w700, letterSpacing: 0.3),
    ),
  );

  if (chargeController == null) {
    return wordsBar;
  }

  return Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Expanded(child: wordsBar),
      const SizedBox(width: 10),
      SizedBox(
        width: 200,
        child: Container(
          padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
          decoration: BoxDecoration(
            color: const Color(0xFF19232C),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                chargeLabel,
                style: const TextStyle(color: Colors.white54, fontSize: 10.5, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 4),
              TextField(
                controller: chargeController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                onChanged: onChargeChanged,
                textAlign: TextAlign.right,
                textInputAction: TextInputAction.done,
                minLines: 1,
                maxLines: 1,
                style: const TextStyle(color: Color(0xFFF4D53A), fontWeight: FontWeight.w900, fontSize: 15, height: 1.2),
                decoration: enterpriseInsetInputDecoration(onDarkPanel: true, multiline: true),
              ),
            ],
          ),
        ),
      ),
    ],
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
Map<int, TableColumnWidth> deliveryChallanMatrixColumns({
  required bool proforma,
  required bool includeRemarks,
}) {
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
  fontSize: 10,
  height: 1.2,
);

const TextStyle enterpriseMatrixCellStyle = TextStyle(
  fontSize: 13.5,
  fontWeight: FontWeight.w600,
  color: navy,
);

const TextStyle enterpriseMatrixHintStyle = TextStyle(
  fontSize: 13.5,
  color: Color(0xFF9AA5B4),
);

final InputDecoration enterpriseMatrixInputDecoration = InputDecoration(
  isDense: true,
  contentPadding: const EdgeInsets.symmetric(horizontal: 6, vertical: 7),
  border: OutlineInputBorder(borderRadius: BorderRadius.circular(3)),
  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(3), borderSide: const BorderSide(color: border)),
);

/// Bordered shell for matrix dropdowns (product, UOM).
Widget enterpriseMatrixDropdownShell({required Widget child}) {
  return Padding(
    padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 3),
    child: Container(
      width: double.infinity,
      decoration: BoxDecoration(
        border: Border.all(color: border),
        borderRadius: BorderRadius.circular(3),
        color: Colors.white,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      child: child,
    ),
  );
}

/// Bordered read-only matrix cell (SL, HSN, totals).
Widget enterpriseMatrixBoxedCell({
  required Widget child,
  EdgeInsets padding = const EdgeInsets.symmetric(horizontal: 2, vertical: 3),
  bool alignRight = false,
}) {
  return Padding(
    padding: padding,
    child: Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 7),
      decoration: BoxDecoration(
        border: Border.all(color: border),
        borderRadius: BorderRadius.circular(3),
        color: Colors.white,
      ),
      alignment: alignRight ? Alignment.centerRight : Alignment.centerLeft,
      child: child,
    ),
  );
}

Widget enterpriseMatrixBoxedText(
  String text, {
  TextStyle? style,
  bool alignRight = false,
  FontWeight? fontWeight,
}) {
  return enterpriseMatrixBoxedCell(
    alignRight: alignRight,
    child: Text(
      text,
      style: (style ?? enterpriseMatrixCellStyle).copyWith(fontWeight: fontWeight),
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
    ),
  );
}

Widget enterpriseMatrixTextField({
  required BuildContext context,
  Key? key,
  TextEditingController? controller,
  TextStyle? style,
  TextInputType? keyboardType,
  ValueChanged<String>? onChanged,
}) {
  return TextField(
    key: key,
    controller: controller,
    keyboardType: keyboardType,
    onChanged: onChanged,
    style: style ?? enterpriseMatrixCellStyle,
    textInputAction: TextInputAction.next,
    onSubmitted: (_) => enterpriseAdvanceFocus(context),
    decoration: enterpriseMatrixInputDecoration,
  );
}

Widget enterpriseMatrixHeadCell(String label) {
  return Padding(
    padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 7),
    child: Text(label, style: enterpriseMatrixHeadStyle, maxLines: 2, overflow: TextOverflow.ellipsis),
  );
}
