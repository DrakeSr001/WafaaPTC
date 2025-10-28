// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use

import 'dart:convert';
import 'dart:html' as html;
import 'dart:typed_data';

/// Triggers a browser download of the text content (no saving to disk path).
Future<void> saveAndShareTextFile(String filename, String content) async {
  final blob = html.Blob(
    [utf8.encode('\uFEFF$content')],
    'text/csv; charset=utf-8',
  );
  final url = html.Url.createObjectUrlFromBlob(blob);
  try {
    _triggerDownload(filename, url);
  } finally {
    html.Url.revokeObjectUrl(url);
  }
}

Future<void> saveAndShareBinaryFile(String filename, List<int> bytes) async {
  final blob = html.Blob(
    [Uint8List.fromList(bytes)],
    'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
  );
  final url = html.Url.createObjectUrlFromBlob(blob);
  try {
    _triggerDownload(filename, url);
  } finally {
    html.Url.revokeObjectUrl(url);
  }
}

void _triggerDownload(String filename, String url) {
  final anchor = html.AnchorElement(href: url)
    ..href = url
    ..download = filename
    ..style.display = 'none';
  html.document.body?.append(anchor);
  anchor.click();
  anchor.remove();
}


