import 'package:flutter/material.dart';

import 'enterprise_widgets.dart';

const masterFieldPadding = EdgeInsets.symmetric(horizontal: 10, vertical: 7);

const _ledgerGroupOptions = ['SALES', 'PURCHASE', 'SUNDRY DEBTOR'];
List<String> get masterLedgerGroupOptions => _ledgerGroupOptions;

InputDecoration masterCompactDecoration({String? hintText, String? errorText}) {
  return InputDecoration(
    isDense: true,
    hintText: hintText,
    hintStyle: const TextStyle(fontSize: 11, color: Color(0xFF9AA5B4)),
    contentPadding: masterFieldPadding,
    errorText: errorText,
  );
}

/// Compact text field with Enter-to-next focus chain.
class MasterTextField extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final FocusNode? nextFocus;
  final String? hintText;
  final TextStyle? style;
  final TextInputType? keyboardType;
  final TextCapitalization textCapitalization;
  final int? maxLines;
  final VoidCallback? onDone;

  const MasterTextField({
    super.key,
    required this.controller,
    required this.focusNode,
    this.nextFocus,
    this.hintText,
    this.style,
    this.keyboardType,
    this.textCapitalization = TextCapitalization.none,
    this.maxLines = 1,
    this.onDone,
  });

  void _submit(BuildContext context) {
    if (nextFocus != null) {
      FocusScope.of(context).requestFocus(nextFocus);
      return;
    }
    onDone?.call();
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      focusNode: focusNode,
      style: style ?? const TextStyle(fontSize: 12),
      keyboardType: keyboardType,
      textCapitalization: textCapitalization,
      maxLines: maxLines,
      textInputAction: nextFocus != null ? TextInputAction.next : TextInputAction.done,
      onSubmitted: (_) => _submit(context),
      decoration: masterCompactDecoration(hintText: hintText),
    );
  }
}

Widget masterRow3(BuildContext context, Widget a, Widget b, Widget c) {
  final narrow = MediaQuery.sizeOf(context).width < 960;
  if (narrow) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [a, const SizedBox(height: 8), b, const SizedBox(height: 8), c],
    );
  }
  return Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Expanded(child: a),
      const SizedBox(width: 10),
      Expanded(child: b),
      const SizedBox(width: 10),
      Expanded(child: c),
    ],
  );
}

Widget masterRow2(BuildContext context, Widget a, Widget b) {
  final narrow = MediaQuery.sizeOf(context).width < 960;
  if (narrow) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [a, const SizedBox(height: 8), b],
    );
  }
  return Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [Expanded(child: a), const SizedBox(width: 10), Expanded(child: b)],
  );
}

double masterDirectoryWidth(BuildContext context) {
  final w = MediaQuery.sizeOf(context).width;
  if (w < 720) return 220;
  if (w < 1100) return 250;
  return 268;
}

EdgeInsets masterFormPadding(BuildContext context) {
  final w = MediaQuery.sizeOf(context).width;
  return EdgeInsets.all(w < 720 ? 12 : 16);
}

bool matchesMasterSearch(String query, Map<String, dynamic> row, List<String> keys) {
  final q = query.trim().toLowerCase();
  if (q.isEmpty) return true;
  for (final key in keys) {
    final v = '${row[key] ?? ''}'.toLowerCase();
    if (v.contains(q)) return true;
  }
  return false;
}

class MasterDropdown extends StatelessWidget {
  final String? value;
  final String hintText;
  final List<String> items;
  final ValueChanged<String?> onChanged;

  const MasterDropdown({
    super.key,
    required this.value,
    required this.hintText,
    required this.items,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<String>(
      value: value,
      isDense: true,
      isExpanded: true,
      decoration: masterCompactDecoration(hintText: hintText),
      items: items
          .map((g) => DropdownMenuItem(
                value: g,
                child: Text(g, style: const TextStyle(fontSize: 11.5)),
              ))
          .toList(),
      onChanged: onChanged,
    );
  }
}

InputDecoration masterSearchDecoration(String hint) {
  return masterCompactDecoration(hintText: hint).copyWith(
    filled: true,
    fillColor: Colors.white,
    prefixIcon: const Icon(Icons.search, size: 16),
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(3), borderSide: BorderSide.none),
    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(3), borderSide: BorderSide.none),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(3),
      borderSide: const BorderSide(color: border, width: 1),
    ),
  );
}
