import 'package:web/web.dart' as web;

/// Triggers a browser download of the text content (no saving to disk path).
Future<void> saveAndShareTextFile(String filename, String content) async {
  final encoded = Uri.encodeComponent(content);
  final url = 'data:text/csv;charset=utf-8,$encoded';
  final anchor = web.HTMLAnchorElement()
    ..href = url
    ..download = filename
    ..style.display = 'none';
  web.document.body?.append(anchor);
  anchor.click();
  anchor.remove();
}
