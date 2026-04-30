import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

Future<String?> exportTableAsExcel({
  required String fileName,
  required String worksheetName,
  required List<List<String>> rows,
}) async {
  final content = _buildExcelHtml(
    worksheetName: worksheetName,
    rows: rows,
  );
  final bytes = utf8.encode(content);
  final directory =
      await getDownloadsDirectory() ?? await getApplicationDocumentsDirectory();
  final file = File(path.join(directory.path, fileName));
  await file.writeAsBytes(bytes, flush: true);
  return file.path;
}

String _buildExcelHtml({
  required String worksheetName,
  required List<List<String>> rows,
}) {
  final buffer = StringBuffer()
    ..writeln('<html xmlns:o="urn:schemas-microsoft-com:office:office" '
        'xmlns:x="urn:schemas-microsoft-com:office:excel" '
        'xmlns="http://www.w3.org/TR/REC-html40">')
    ..writeln('<head>')
    ..writeln('<meta charset="utf-8">')
    ..writeln(
      '<!--[if gte mso 9]><xml><x:ExcelWorkbook><x:ExcelWorksheets><x:ExcelWorksheet>'
      '<x:Name>${_escapeHtml(worksheetName)}</x:Name>'
      '<x:WorksheetOptions><x:DisplayGridlines/></x:WorksheetOptions>'
      '</x:ExcelWorksheet></x:ExcelWorksheets></x:ExcelWorkbook></xml><![endif]-->',
    )
    ..writeln('</head><body><table>');

  for (var rowIndex = 0; rowIndex < rows.length; rowIndex++) {
    final row = rows[rowIndex];
    buffer.writeln('<tr>');
    for (final cell in row) {
      final tag = rowIndex == 0 ? 'th' : 'td';
      buffer.writeln('<$tag>${_escapeHtml(cell)}</$tag>');
    }
    buffer.writeln('</tr>');
  }

  buffer.writeln('</table></body></html>');
  return buffer.toString();
}

String _escapeHtml(String value) {
  return value
      .replaceAll('&', '&amp;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;')
      .replaceAll('"', '&quot;')
      .replaceAll("'", '&#39;');
}
