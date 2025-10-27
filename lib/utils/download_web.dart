import 'dart:html' as html;

/// Triggers a browser download of the text content (no saving to disk path).
Future<void> saveAndShareTextFile(String filename, String content) async {
  final encoded = Uri.encodeComponent(content);
  final url = 'data:text/csv;charset=utf-8,$encoded';
  final anchor = html.AnchorElement()
    ..href = url
    ..download = filename
    ..style.display = 'none';
  html.document.body?.append(anchor);
  anchor.click();
  anchor.remove();
}

Future<void> saveAndShareBinaryFile(String filename, List<int> bytes) async {
  final blob = html.Blob([bytes], 'application/octet-stream');
  final url = html.Url.createObjectUrlFromBlob(blob);
  final anchor = html.AnchorElement()
    ..href = url
    ..download = filename
    ..style.display = 'none';
  html.document.body?.append(anchor);
  anchor.click();
  anchor.remove();
  html.Url.revokeObjectUrl(url);
}


