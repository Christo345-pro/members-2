Future<String?> exportTableAsExcel({
  required String fileName,
  required String worksheetName,
  required List<List<String>> rows,
}) async {
  throw UnsupportedError('Excel export is not supported on this platform.');
}
