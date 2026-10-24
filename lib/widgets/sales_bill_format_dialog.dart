import 'package:flutter/material.dart';

import 'invoice.dart';

/// Normal vs labour format for save-and-print or reprint (does not persist on reprint).
Future<UltraSalesBillType?> showSalesBillFormatDialog(
  BuildContext context, {
  UltraSalesBillType initial = UltraSalesBillType.normal,
}) async {
  var selected = initial;
  return showDialog<UltraSalesBillType>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setState) => AlertDialog(
        title: const Text('Select bill format'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            RadioListTile<UltraSalesBillType>(
              title: const Text('Normal Bill'),
              value: UltraSalesBillType.normal,
              groupValue: selected,
              onChanged: (v) => setState(() => selected = v!),
            ),
            RadioListTile<UltraSalesBillType>(
              title: const Text('Labour Bill'),
              value: UltraSalesBillType.labour,
              groupValue: selected,
              onChanged: (v) => setState(() => selected = v!),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, selected),
            child: const Text('OK'),
          ),
        ],
      ),
    ),
  );
}
