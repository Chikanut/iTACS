// file_downloader.dart

import 'package:flutter/foundation.dart';
import 'file_metadata_service.dart';
import 'file_exceptions.dart';
import '../auth_service.dart';
import '../google_drive_service.dart';

class FileDownloader {
  final FileMetadataService metadataService;
  final GoogleDriveService _driveService;

  FileDownloader({
    required this.metadataService,
    required AuthService authService,
  }) : _driveService = GoogleDriveService(authService: authService);

  Future<Uint8List> downloadFile(String fileId) async {
    try {
      return await _downloadFileWithRetry(fileId);
    } on MetadataException {
      rethrow;
    } on WebDownloadException {
      rethrow;
    } catch (e) {
      debugPrint('FileDownloader: Остаточна помилка завантаження: $e');
      throw WebDownloadException(
        'Не вдалося завантажити файл напряму з Google Drive',
        fileId,
      );
    }
  }

  /// Завантаження файлу з retry логікою
  Future<Uint8List> _downloadFileWithRetry(
    String fileId, {
    int maxRetries = 2,
  }) async {
    for (int attempt = 0; attempt < maxRetries; attempt++) {
      try {
        final metadata = await metadataService.getFileMetadata(fileId);
        if (metadata == null) {
          throw WebDownloadException(
            'Не вдалося отримати метадані для файлу',
            fileId,
          );
        }

        debugPrint(
          'FileDownloader: Завантаження напряму з Google Drive (спроба ${attempt + 1}) для ${metadata.filename}',
        );
        final bytes = await _driveService.downloadFileBytes(fileId);
        debugPrint(
          'FileDownloader: Успішно отримано файл напряму з Google Drive',
        );
        return bytes;
      } catch (e) {
        debugPrint('FileDownloader: Спроба ${attempt + 1} не вдалася: $e');

        if (attempt == maxRetries - 1) {
          // Остання спроба
          rethrow;
        }
        await Future.delayed(Duration(seconds: 1));
      }
    }

    throw WebDownloadException(
      'Не вдалося завантажити файл після $maxRetries спроб',
      fileId,
    );
  }
}
