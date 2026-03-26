// file_metadata_service.dart

import 'package:flutter/foundation.dart';
import '../auth_service.dart';
import 'file_exceptions.dart';
import 'file_cache_entry.dart';
import '../google_drive_service.dart';

class FileMetadataService {
  FileMetadataService({required AuthService authService})
    : _driveService = GoogleDriveService(authService: authService);

  final GoogleDriveService _driveService;

  Future<FileCacheEntry?> getFileMetadata(String fileId) async {
    // Спробуємо з поточним токеном
    try {
      return await _getFileMetadataWithRetry(fileId);
    } on MetadataException {
      rethrow;
    } on WebDownloadException catch (e) {
      debugPrint('FileMetadata: Drive API повернув помилку: $e');
      throw MetadataException(e.message, fileId);
    } catch (e) {
      debugPrint('FileMetadata: Остаточна помилка отримання метаданих: $e');
      throw MetadataException('Не вдалося отримати метадані', fileId);
    }
  }

  /// Отримання метаданих з retry логікою
  Future<FileCacheEntry?> _getFileMetadataWithRetry(
    String fileId, {
    int maxRetries = 2,
  }) async {
    for (int attempt = 0; attempt < maxRetries; attempt++) {
      try {
        final metadata = await _driveService.getFileCacheEntry(fileId);
        debugPrint(
          'FileMetadata: Метадані отримано напряму з Google Drive для $fileId',
        );
        return metadata;
      } catch (e) {
        debugPrint('FileMetadata: Спроба ${attempt + 1} не вдалася: $e');

        if (attempt == maxRetries - 1) {
          // Остання спроба
          rethrow;
        }

        // Чекаємо трохи перед наступною спробою
        await Future.delayed(Duration(seconds: 1));
      }
    }

    throw MetadataException(
      'Не вдалося отримати метадані після $maxRetries спроб',
      fileId,
    );
  }
}
