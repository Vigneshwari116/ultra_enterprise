import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';

/// Opens a native file picker restricted to .csv files and returns the
/// file's text content, or null if the user cancelled the dialog.
///
/// Handles both platforms that return the bytes directly (web, mobile) and
/// platforms that only return a path (most desktop targets).
Future<String?> pickCsvFileContent() async {
  final result = await FilePicker.platform.pickFiles(
    type: FileType.custom,
    allowedExtensions: ['csv'],
    withData: true,
  );
  if (result == null || result.files.isEmpty) return null;

  final picked = result.files.single;
  if (picked.bytes != null) {
    return utf8.decode(picked.bytes!, allowMalformed: true);
  }
  if (picked.path != null) {
    return File(picked.path!).readAsString();
  }
  return null;
}
