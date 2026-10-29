import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

/// Words drawn on the PDF, in content-stream order.
///
/// The sales-bill painter emits one Tj/TJ run per word, so callers that need a
/// phrase should join these with spaces.
List<String> pdfShownText(Uint8List bytes) {
  final out = <String>[];
  final streamMark = ascii.encode('stream');
  final endMark = ascii.encode('endstream');
  var i = 0;
  while (i < bytes.length) {
    final start = _indexOf(bytes, streamMark, i);
    if (start < 0) break;
    var dataStart = start + streamMark.length;
    if (dataStart + 1 < bytes.length &&
        bytes[dataStart] == 0x0d &&
        bytes[dataStart + 1] == 0x0a) {
      dataStart += 2;
    } else if (dataStart < bytes.length &&
        (bytes[dataStart] == 0x0a || bytes[dataStart] == 0x0d)) {
      dataStart++;
    } else {
      i = start + streamMark.length;
      continue;
    }
    final end = _indexOf(bytes, endMark, dataStart);
    if (end < 0) break;
    var dataEnd = end;
    if (dataEnd > dataStart && bytes[dataEnd - 1] == 0x0a) dataEnd--;
    if (dataEnd > dataStart && bytes[dataEnd - 1] == 0x0d) dataEnd--;

    final objAt = _lastIndexOf(bytes, ascii.encode('obj'), start);
    final dictFrom = objAt < 0 ? (start - 200 < 0 ? 0 : start - 200) : objAt;
    final dict = latin1.decode(bytes.sublist(dictFrom, start));
    final isImage = dict.contains('/Image');
    if (!isImage) {
      final raw = bytes.sublist(dataStart, dataEnd);
      Uint8List decoded;
      try {
        decoded = Uint8List.fromList(zlib.decode(raw));
      } catch (_) {
        decoded = Uint8List.fromList(raw);
      }
      out.addAll(_shownStrings(latin1.decode(decoded)));
    }
    i = end + endMark.length;
  }
  return out;
}

/// Page text reconstructed in reading order. Word fragments are separated by
/// a single space, which matches how the bill painter splits phrases.
String pdfShownPlainText(Uint8List bytes) => pdfShownText(bytes).join(' ');

List<String> _shownStrings(String text) {
  final out = <String>[];
  final tjArray = RegExp(r'\[(.*?)\]\s*TJ');
  final inner = RegExp(r'\(((?:\\.|[^\\)])*)\)');
  for (final match in tjArray.allMatches(text)) {
    final parts = <String>[];
    for (final piece in inner.allMatches(match.group(1)!)) {
      parts.add(_unescape(piece.group(1)!));
    }
    if (parts.isNotEmpty) out.add(parts.join());
  }
  final tj = RegExp(r'\(((?:\\.|[^\\)])*)\)\s*Tj');
  if (out.isEmpty) {
    for (final match in tj.allMatches(text)) {
      out.add(_unescape(match.group(1)!));
    }
  }
  return out;
}

String _unescape(String raw) {
  final out = StringBuffer();
  for (var i = 0; i < raw.length; i++) {
    final c = raw[i];
    if (c != '\\' || i + 1 >= raw.length) {
      out.write(c);
      continue;
    }
    final n = raw[++i];
    switch (n) {
      case 'n':
        out.write('\n');
      case 'r':
        out.write('\r');
      case 't':
        out.write('\t');
      case 'b':
        out.write('\b');
      case 'f':
        out.write('\f');
      case '(':
      case ')':
      case '\\':
        out.write(n);
      default:
        if (n.compareTo('0') >= 0 && n.compareTo('7') <= 0) {
          var oct = n;
          var count = 1;
          while (count < 3 &&
              i + 1 < raw.length &&
              raw[i + 1].compareTo('0') >= 0 &&
              raw[i + 1].compareTo('7') <= 0) {
            oct = '$oct${raw[++i]}';
            count++;
          }
          out.writeCharCode(int.parse(oct, radix: 8));
        } else {
          out.write(n);
        }
    }
  }
  return out.toString();
}

int _indexOf(Uint8List haystack, List<int> needle, int from) {
  if (needle.isEmpty || from > haystack.length - needle.length) return -1;
  final last = haystack.length - needle.length;
  for (var i = from; i <= last; i++) {
    var found = true;
    for (var j = 0; j < needle.length; j++) {
      if (haystack[i + j] != needle[j]) {
        found = false;
        break;
      }
    }
    if (found) return i;
  }
  return -1;
}

int _lastIndexOf(Uint8List haystack, List<int> needle, int before) {
  final start = before - needle.length;
  if (start < 0) return -1;
  for (var i = start; i >= 0; i--) {
    var found = true;
    for (var j = 0; j < needle.length; j++) {
      if (haystack[i + j] != needle[j]) {
        found = false;
        break;
      }
    }
    if (found) return i;
  }
  return -1;
}
