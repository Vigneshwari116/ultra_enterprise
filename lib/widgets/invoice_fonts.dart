import 'package:pdf/widgets.dart' as pw;

/// Serif (Times) + sans (Helvetica) for consistent invoice typography.
class InvoiceFonts {
  final pw.Font serif;
  final pw.Font serifBold;
  final pw.Font sans;
  final pw.Font sansBold;

  const InvoiceFonts({
    required this.serif,
    required this.serifBold,
    required this.sans,
    required this.sansBold,
  });

  static InvoiceFonts? _cache;

  static Future<InvoiceFonts> load() async {
    if (_cache != null) return _cache!;
    _cache = InvoiceFonts(
      serif: pw.Font.times(),
      serifBold: pw.Font.timesBold(),
      sans: pw.Font.helvetica(),
      sansBold: pw.Font.helveticaBold(),
    );
    return _cache!;
  }
}
