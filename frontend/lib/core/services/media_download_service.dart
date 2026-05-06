import 'dart:typed_data';

import 'package:file_saver/file_saver.dart';
import 'package:http/http.dart' as http;

class MediaDownloadService {
  const MediaDownloadService();

  Future<void> downloadImage({
    required String url,
    String? suggestedFileName,
  }) async {
    final response = await http.get(Uri.parse(url));
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('Failed to download image.');
    }

    final uri = Uri.parse(url);
    final rawName = suggestedFileName ?? _fileNameFromUri(uri);
    final split = rawName.split('.');
    final name = split.length > 1
        ? split.sublist(0, split.length - 1).join('.')
        : rawName;
    final ext = split.length > 1 ? split.last : 'jpg';

    await FileSaver.instance.saveFile(
      name: name,
      bytes: Uint8List.fromList(response.bodyBytes),
      fileExtension: ext,
      mimeType: MimeType.jpeg,
    );
  }

  String _fileNameFromUri(Uri uri) {
    if (uri.pathSegments.isEmpty) {
      return 'chat-image.jpg';
    }

    final last = uri.pathSegments.last;
    return last.isEmpty ? 'chat-image.jpg' : last;
  }
}
