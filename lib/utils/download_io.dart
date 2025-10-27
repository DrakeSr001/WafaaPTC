import 'dart:io';
import 'dart:typed_data';

import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

/// Saves text to a file and opens the share sheet.
Future<void> saveAndShareTextFile(String filename, String content) async {
  final dir = await getApplicationDocumentsDirectory();
  final file = File('${dir.path}/$filename');
  await file.writeAsString(content, flush: true);
  await SharePlus.instance.share(
    ShareParams(
      files: [XFile(file.path)],
      text: filename,
    ),
  );
}

/// Saves binary data to a file (e.g., XLSX) and opens the share sheet.
Future<void> saveAndShareBinaryFile(String filename, List<int> bytes) async {
  final dir = await getApplicationDocumentsDirectory();
  final file = File('${dir.path}/$filename');
  await file.writeAsBytes(Uint8List.fromList(bytes), flush: true);
  await SharePlus.instance.share(
    ShareParams(
      files: [XFile(file.path)],
      text: filename,
    ),
  );
}

