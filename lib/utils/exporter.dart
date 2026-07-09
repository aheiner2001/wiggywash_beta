import 'dart:typed_data';

import 'exporter_io.dart' if (dart.library.html) 'exporter_web.dart' as impl;

/// Saves [csv] as a downloadable/shareable file named [filename].
/// On web this triggers a browser download; elsewhere it opens the share sheet.
Future<void> exportCsv(String filename, String csv) =>
    impl.exportCsv(filename, csv);

/// Saves [bytes] as a downloadable/shareable file (e.g. `.xlsx`).
Future<void> exportBytes(
  String filename,
  Uint8List bytes, {
  String mimeType = 'application/octet-stream',
}) =>
    impl.exportBytes(filename, bytes, mimeType: mimeType);

const kXlsxMime =
    'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';

Future<void> exportXlsx(String filename, Uint8List bytes) =>
    exportBytes(filename, bytes, mimeType: kXlsxMime);
