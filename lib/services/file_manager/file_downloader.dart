// file_downloader.dart

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'file_metadata_service.dart';
import 'file_exceptions.dart';
import '../auth_service.dart';

class FileDownloader {
  final FileMetadataService metadataService;
  final AuthService authService;

  FileDownloader({required this.metadataService, required this.authService});

  Future<Uint8List> downloadFile(String fileId) async {
    try {
      return await _downloadFileWithRetry(fileId);
    } catch (e) {
      debugPrint('FileDownloader: Остаточна помилка завантаження: $e');
      throw WebDownloadException(
        'Не вдалося завантажити файл через проксі',
        fileId,
      );
    }
  }

  /// Завантаження файлу з retry логікою
  Future<Uint8List> _downloadFileWithRetry(String fileId, {int maxRetries = 2}) async {
    for (int attempt = 0; attempt < maxRetries; attempt++) {
      try {
        final metadata = await metadataService.getFileMetadata(fileId);
        if (metadata == null) {
          throw WebDownloadException('Не вдалося отримати метадані для файлу', fileId);
        }

        final titleEncoded = Uri.encodeComponent(metadata.filename);
        final ext = metadata.extension;

        final proxyUrl =
            'https://itacs-webservice.onrender.com/proxy?fileId=$fileId&title=$titleEncoded&ext=$ext';

        debugPrint('FileDownloader: Завантаження через проксі (спроба ${attempt + 1}): $proxyUrl');
        final response = await http.get(Uri.parse(proxyUrl));

        if (response.statusCode == 200) {
          debugPrint('FileDownloader: Успішно отримано файл через проксі');
          return response.bodyBytes;
        } else if (response.statusCode == 401 || response.statusCode == 403) {
          // Токен можливо застарів
          debugPrint('FileDownloader: Токен застарів (${response.statusCode}), оновлюємо...');
          
          if (attempt < maxRetries - 1) {
            // Примусово оновлюємо токен
            await authService.forceRefreshToken();
            continue; // Спробуємо знову
          }
          
          throw WebDownloadException(
            'Проблема з авторизацією: ${response.statusCode}',
            fileId,
            proxyUrl,
          );
        } else {
          throw WebDownloadException(
            'Проксі повернув помилку: ${response.statusCode}',
            fileId,
            proxyUrl,
          );
        }
      } catch (e) {
        debugPrint('FileDownloader: Спроба ${attempt + 1} не вдалася: $e');
        
        if (attempt == maxRetries - 1) {
          // Остання спроба
          rethrow;
        }
        
        // Чекаємо трохи перед наступною спробою
        await Future.delayed(Duration(seconds: 1));
      }
    }
    
    throw WebDownloadException(
      'Не вдалося завантажити файл після $maxRetries спроб',
      fileId,
    );
  }
}