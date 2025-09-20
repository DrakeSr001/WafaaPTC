import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';

/// Saves text to a file and opens the share sheet.
Future<void> saveAndShareTextFile(String filename, String content) async {
  final dir = await getApplicationDocumentsDirectory();
  final file = File('${dir.path}/$filename');
  await file.writeAsString(content, flush: true);
  await Share.shareXFiles([XFile(file.path)], text: filename);
}
