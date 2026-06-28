import 'exporter_io.dart' if (dart.library.html) 'exporter_web.dart' as impl;

/// Saves [csv] as a downloadable/shareable file named [filename].
/// On web this triggers a browser download; elsewhere it opens the share sheet.
Future<void> exportCsv(String filename, String csv) =>
    impl.exportCsv(filename, csv);
