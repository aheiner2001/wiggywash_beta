import 'dart:convert';
// ignore: deprecated_member_use, avoid_web_libraries_in_flutter
import 'dart:html' as html;

/// Web: download the CSV via a temporary blob URL + anchor click.
Future<void> exportCsv(String filename, String csv) async {
  final bytes = utf8.encode(csv);
  final blob = html.Blob(<dynamic>[bytes], 'text/csv');
  final url = html.Url.createObjectUrlFromBlob(blob);
  final anchor = html.AnchorElement(href: url)
    ..download = filename
    ..style.display = 'none';
  html.document.body!.append(anchor);
  anchor.click();
  anchor.remove();
  html.Url.revokeObjectUrl(url);
}
