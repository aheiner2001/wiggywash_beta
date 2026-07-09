import 'dart:convert';
import 'dart:typed_data';
// ignore: deprecated_member_use, avoid_web_libraries_in_flutter
import 'dart:html' as html;

/// Web: download the CSV via a temporary blob URL + anchor click.
Future<void> exportCsv(String filename, String csv) async {
  await exportBytes(
    filename,
    Uint8List.fromList(utf8.encode(csv)),
    mimeType: 'text/csv',
  );
}

/// Web: download arbitrary bytes (e.g. `.xlsx`).
Future<void> exportBytes(
  String filename,
  Uint8List bytes, {
  String mimeType = 'application/octet-stream',
}) async {
  final blob = html.Blob(<dynamic>[bytes], mimeType);
  final url = html.Url.createObjectUrlFromBlob(blob);
  final anchor = html.AnchorElement(href: url)
    ..download = filename
    ..style.display = 'none';
  html.document.body!.append(anchor);
  anchor.click();
  anchor.remove();
  html.Url.revokeObjectUrl(url);
}
