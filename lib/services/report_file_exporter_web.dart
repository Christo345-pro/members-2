// ignore_for_file: deprecated_member_use, avoid_web_libraries_in_flutter

import 'dart:convert';
import 'dart:html' as html;

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
  final blob = html.Blob(
    [bytes],
    'application/vnd.ms-excel;charset=utf-8',
  );
  final url = html.Url.createObjectUrlFromBlob(blob);
  final anchor = html.AnchorElement(href: url)
    ..download = fileName
    ..style.display = 'none';

  html.document.body?.children.add(anchor);
  anchor.click();
  anchor.remove();
  html.Url.revokeObjectUrl(url);
  return null;
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
