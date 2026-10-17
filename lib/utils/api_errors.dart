import 'package:flutter/material.dart';

import '../services/api_service.dart';

/// Plain-language text for dialogs and snackbars.
String readableApiError(Object error) {
  if (error is ApiException) return error.message;
  final text = error.toString();
  const apiPrefix = 'ApiException: ';
  const exPrefix = 'Exception: ';
  if (text.startsWith(apiPrefix)) return text.substring(apiPrefix.length);
  if (text.startsWith(exPrefix)) return text.substring(exPrefix.length);
  return text;
}

Future<void> showReadableErrorDialog(
  BuildContext context, {
  required String title,
  required Object error,
}) async {
  final message = readableApiError(error);
  if (!context.mounted) return;
  await showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: SingleChildScrollView(child: Text(message)),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(),
          child: const Text('OK'),
        ),
      ],
    ),
  );
}
