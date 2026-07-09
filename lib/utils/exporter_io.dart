import 'dart:convert';
import 'dart:typed_data';

import 'package:share_plus/share_plus.dart';

/// Native (iOS/Android/desktop): hand the CSV to the OS share sheet as a file.
Future<void> exportCsv(String filename, String csv) async {
  final bytes = Uint8List.fromList(utf8.encode(csv));
  await Share.shareXFiles([
    XFile.fromData(bytes, mimeType: 'text/csv', name: filename),
  ]);
}

/// Share or save a binary file (e.g. `.xlsx`).
Future<void> exportBytes(
  String filename,
  Uint8List bytes, {
  String mimeType = 'application/octet-stream',
}) async {
  await Share.shareXFiles([
    XFile.fromData(bytes, mimeType: mimeType, name: filename),
  ]);
}
