import 'package:flutter/material.dart';

/// Full-width bordered grid. Columns share the available width by [flex].
class ExcelGrid extends StatelessWidget {
  const ExcelGrid({
    super.key,
    required this.headers,
    required this.rows,
    required this.flex,
  });

  final List<String> headers;
  final List<List<Widget>> rows;
  final List<double> flex;

  static const _line = Color(0xFFB8BEC8);
  static const _headerBg = Color(0xFFE9ECF1);
  static const _headerStyle = TextStyle(
    color: Color(0xFF4B5563),
    fontSize: 12,
    fontWeight: FontWeight.w700,
    height: 1.25,
  );
  static const _bodyStyle = TextStyle(
    color: Color(0xFF1F2937),
    fontSize: 12,
    fontWeight: FontWeight.w500,
    height: 1.25,
  );

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final table = Table(
          border: TableBorder.all(color: _line, width: 1),
          columnWidths: {
            for (var i = 0; i < flex.length; i++) i: FlexColumnWidth(flex[i]),
          },
          defaultVerticalAlignment: TableCellVerticalAlignment.middle,
          children: [
            TableRow(
              children: [
                for (final header in headers) _cell(Text(header), header: true),
              ],
            ),
            for (final row in rows)
              TableRow(
                children: [
                  for (final cell in row) _cell(cell),
                ],
              ),
          ],
        );
        final grid =
            width.isFinite ? SizedBox(width: width, child: table) : table;
        return SingleChildScrollView(child: grid);
      },
    );
  }

  Widget _cell(Widget child, {bool header = false}) {
    return Container(
      color: header ? _headerBg : Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
      alignment: Alignment.centerLeft,
      child: DefaultTextStyle(
        style: header ? _headerStyle : _bodyStyle,
        child: child,
      ),
    );
  }
}
