// file_opener.dart

import 'package:flutter/foundation.dart';
import 'file_metadata.dart';

// Умовний імпорт - тільки для веб
import '../html_stub.dart'
    if (dart.library.html) 'dart:html' as html;

import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import 'file_cache_entry.dart';
import 'dart:io';
import 'package:path/path.dart' as p;

class FileOpener {
  FileOpener();

  Future<void> openFile(String fileId, Uint8List data, FileCacheEntry metadata) async {
    try {
      final fileName = metadata.filename;
      debugPrint('FileOpener: Відкриваємо файл $fileId з іменем "$fileName"');

      if (kIsWeb) {
        await _openFileWeb(fileId, data, metadata);
      } else {
        await _openFileMobile(fileId, data, metadata);
      }
    } catch (e) {
      debugPrint('FileOpener: Помилка при відкритті файлу $fileId: $e');
    }
  }

  Future<void> _openFileWeb(String fileId, Uint8List data, FileCacheEntry metadata) async {
    if (!kIsWeb) return;
    
    final fileName = metadata.filename;
    final mimeType = _getMimeType(metadata.extension);
    debugPrint('FileOpener: Тип MIME визначено як "$mimeType"');

    final blob = html.Blob([data], mimeType);
    debugPrint('FileOpener: Створено blob з ${data.length} байт, типом "$mimeType"');

    final url = html.Url.createObjectUrlFromBlob(blob);
    debugPrint('FileOpener: Створено Object URL: $url');

    if (mimeType == 'text/html' || mimeType == 'application/pdf') {
      html.window.open(url, '_blank');
    } else {
      final anchor = html.AnchorElement(href: url)
        ..target = '_blank'
        ..download = fileName;
      html.document.body!.append(anchor);
      anchor.click();
      anchor.remove();
    }

    html.Url.revokeObjectUrl(url);
    debugPrint('FileOpener: Object URL звільнено');
  }

  Future<void> _openFileMobile(String fileId, Uint8List data, FileCacheEntry metadata) async {
    final fileName = metadata.filename;
    final tempDir = await getTemporaryDirectory();
    final filePath = p.join(tempDir.path, fileName);
    final file = File(filePath);
    await file.writeAsBytes(data);
    debugPrint('FileOpener: Файл записано до тимчасового каталогу: $filePath');

    final result = await OpenFilex.open(filePath);
    debugPrint('FileOpener: OpenFilex результат: ${result.type}');
  }

  String? _getMimeType(String extension) {
    switch (extension.toLowerCase()) {
      case 'pdf':
        return 'application/pdf';
      case 'doc':
        return 'application/msword';
      case 'docx':
        return 'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
      case 'xls':
        return 'application/vnd.ms-excel';
      case 'xlsx':
        return 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';
      case 'ppt':
        return 'application/vnd.ms-powerpoint';
      case 'pptx':
        return 'application/vnd.openxmlformats-officedocument.presentationml.presentation';
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'png':
        return 'image/png';
      case 'gif':
        return 'image/gif';
      case 'txt':
        return 'text/plain';
      case 'html':
        return 'text/html';
      case 'zip':
        return 'application/zip';
      case 'rar':
        return 'application/x-rar-compressed';
      default:
        return 'application/octet-stream';
    }
  }
}