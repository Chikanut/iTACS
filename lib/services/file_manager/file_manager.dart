import 'dart:typed_data';

import 'file_sharer.dart';

class FileManager {
  final FileSharer _fileSharerService = FileSharer();

  Future<void> shareFileByData(String fileName, Uint8List data) async {
    await _fileSharerService.shareFile(data, fileName);
  }
}
