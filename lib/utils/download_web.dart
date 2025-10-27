import 'dart:convert';

import 'package:web/web.dart' as web;

/// Triggers a browser download of the text content (no saving to disk path).
Future<void> saveAndShareTextFile(String filename, String content) async {
  final url = Uri.dataFromString(
    content,
    mimeType: 'text/csv',
    encoding: utf8,
  ).toString();
  _triggerDownload(filename, url);
}

Future<void> saveAndShareBinaryFile(String filename, List<int> bytes) async {
  final url = Uri.dataFromBytes(
    bytes,
    mimeType: 'application/octet-stream',
  ).toString();
  _triggerDownload(filename, url);
}

void _triggerDownload(String filename, String url) {
  final anchor = web.HTMLAnchorElement()
    ..href = url
    ..download = filename
    ..style.display = 'none';
  web.document.body?.append(anchor);
  anchor.click();
  anchor.remove();
}


