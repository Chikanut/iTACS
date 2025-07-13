// file_manager.dart

import 'package:flutter/foundation.dart';
import 'package:flutter_application_1/services/file_manager/file_metadata_service.dart';

import '../auth_service.dart';

import 'file_cache_service.dart';
import 'file_metadata.dart';
import 'file_downloader.dart';
import 'file_opener.dart';
import 'file_sharer.dart';
import 'file_exceptions.dart';
import 'file_cache_entry.dart';

class FileManager {

  late final FileMetadataService _metadataService;
  late final FileCacheService _cacheService;
  late final FileDownloader _downloaderService;
  late final FileOpener _fileOpenerService;
  late final FileSharer _fileSharerService;

static FileManager? _instance;

  static Future<FileManager> create({required AuthService authService}) async {
    final manager = FileManager._internal(authService: authService);
    await manager._cacheService.init();
    _instance = manager;
    return manager;
  }

  factory FileManager({required AuthService authService}) {
    if (_instance != null) {
      return _instance!;
    }
    throw Exception('FileManager must be initialized using FileManager.create()');
  }

  FileManager._internal({required AuthService authService}) {
    _metadataService = FileMetadataService(authService: authService);
    _cacheService = FileCacheService();
    _downloaderService = FileDownloader(metadataService: _metadataService, authService: authService);
    _fileOpenerService = FileOpener();
    _fileSharerService = FileSharer();

    cleanupCache();
  }

  /// Головна функція відкриття файлу
  Future<void> openFile(String fileId) async {
    try {
      debugPrint('FileManager: Відкриття файлу $fileId');

      var metadata = _cacheService.getFileMetadata(fileId);
      if (metadata == null) {
        metadata = await _metadataService.getFileMetadata(fileId);
        if (metadata == null) {
          throw FileMetadataException('Не вдалося отримати метадані для файлу', fileId);
        }
      }
      var fileBytes = await cacheFile(fileId);
      
      if (fileBytes == null) {
        throw FileAccessException('Файл не знайдено після завантаження або кешування', fileId);
      }

      await _fileOpenerService.openFile(fileId,fileBytes, metadata);
    } catch (e) {
      debugPrint('FileManager: Помилка відкриття файлу $fileId: $e');
      rethrow;
    }
  }

  Future<Uint8List?> cacheFile(String fileId) async {
    try {
      debugPrint('FileManager: Кешування файлу $fileId');

      // Отримуємо метадані з сервера
      var metadata = _cacheService.getFileMetadata(fileId);
      if (metadata == null) {
        metadata = await _metadataService.getFileMetadata(fileId);
        if (metadata == null) {
          throw FileMetadataException('Не вдалося отримати метадані для файлу', fileId);
        }
      }

      // Перевіряємо, чи потрібно оновлювати файл
      final shouldUpdate = _cacheService.shouldUpdateFile(
        fileId, 
        metadata.modifiedDate ?? DateTime.now().toIso8601String()
      );

      Uint8List? fileBytes;

      if (await _cacheService.isCached(fileId) && !shouldUpdate) {
        // Файл актуальний, беремо з кешу
        debugPrint('FileManager: Завантажуємо файл з кешу: $fileId');
        final (cachedData, fileName) = await _cacheService.getCachedFile(fileId);
        fileBytes = cachedData;
        
        if (fileBytes != null) {
          debugPrint('FileManager: Файл успішно завантажено з кешу: $fileName (${fileBytes.length} байт)');
        }
      } else {
        // Завантажуємо файл з сервера
        debugPrint('FileManager: Завантажуємо файл з сервера: $fileId');
        fileBytes = await _downloaderService.downloadFile(fileId);
        
        if (fileBytes != null) {
          // Зберігаємо в кеш з додатковими метаданими
          await _cacheService.cacheFile(
            fileId: fileId,
            name: metadata.filename,
            extension: metadata.extension,
            modifiedDate: metadata.modifiedDate ?? DateTime.now().toIso8601String(),
            data: fileBytes,
            mimeType: _getMimeType(metadata.extension), // Додаємо MIME тип
          );
          
          debugPrint('FileManager: Файл збережено в кеш: ${metadata.filename} (${fileBytes.length} байт)');
        }
      }

      if (fileBytes == null) {
        throw FileAccessException('Файл не знайдено після завантаження або кешування', fileId);
      }

      return fileBytes;
    } catch (e) {
      debugPrint('FileManager: Помилка кешування файлу $fileId: $e');
      rethrow;
    }
  }

  /// Завантажує файл з оптимізованою логікою
  Future<Uint8List?> loadFile(String fileId) async {
    try {
      // Спочатку перевіряємо кеш
      if (await _cacheService.isCached(fileId)) {
        final (cachedData, fileName) = await _cacheService.getCachedFile(fileId);
        if (cachedData != null) {
          debugPrint('FileManager: Файл завантажено з кешу: $fileName');
          return cachedData;
        }
      }

      // Якщо файлу немає в кеші, кешуємо його
      return await cacheFile(fileId);
    } catch (e) {
      debugPrint('FileManager: Помилка завантаження файлу $fileId: $e');
      rethrow;
    }
  }

  /// Перевіряє актуальність файлу та оновлює при необхідності
  Future<bool> refreshFileIfNeeded(String fileId) async {
    try {
      var metadata = _cacheService.getFileMetadata(fileId);
      if (metadata == null) {
          metadata = await _metadataService.getFileMetadata(fileId);
          if (metadata == null) {
            throw FileMetadataException('Не вдалося отримати метадані для файлу', fileId);
          }
        }
      if (metadata == null) return false;

      final shouldUpdate = _cacheService.shouldUpdateFile(
        fileId, 
        metadata.modifiedDate ?? DateTime.now().toIso8601String()
      );

      if (shouldUpdate) {
        debugPrint('FileManager: Оновлюємо файл $fileId');
        final fileBytes = await _downloaderService.downloadFile(fileId);
        
        if (fileBytes != null) {
          await _cacheService.updateCachedFile(
            fileId: fileId,
            modifiedDate: metadata.modifiedDate ?? DateTime.now().toIso8601String(),
            data: fileBytes,
            mimeType: _getMimeType(metadata.extension),
          );
          return true;
        }
      }

      return false;
    } catch (e) {
      debugPrint('FileManager: Помилка оновлення файлу $fileId: $e');
      return false;
    }
  }

  /// Пакетне кешування файлів
  Future<List<String>> cacheMultipleFiles(List<String> fileIds) async {
    final successfullycached = <String>[];
    
    for (final fileId in fileIds) {
      try {
        await cacheFile(fileId);
        successfullycached.add(fileId);
      } catch (e) {
        debugPrint('FileManager: Помилка кешування файлу $fileId: $e');
        // Продовжуємо з наступним файлом
      }
    }

    debugPrint('FileManager: Успішно закешовано ${successfullycached.length} з ${fileIds.length} файлів');
    return successfullycached;
  }

  /// Попереднє завантаження файлів
  Future<void> preloadFiles(List<String> fileIds) async {
    debugPrint('FileManager: Починаємо попереднє завантаження ${fileIds.length} файлів');
    
    // Фільтруємо файли, які вже є в кеші та актуальні
    final filesToPreload = <String>[];
    
    for (final fileId in fileIds) {
      try {
        var metadata = _cacheService.getFileMetadata(fileId);
        if (metadata == null) {
          metadata = await _metadataService.getFileMetadata(fileId);
          if (metadata == null) {
            throw FileMetadataException('Не вдалося отримати метадані для файлу', fileId);
          }
        }
        if (metadata == null) continue;
        
        final shouldUpdate = _cacheService.shouldUpdateFile(
          fileId, 
          metadata.modifiedDate ?? DateTime.now().toIso8601String()
        );
        
        if (!await _cacheService.isCached(fileId) || shouldUpdate) {
          filesToPreload.add(fileId);
        }
      } catch (e) {
        debugPrint('FileManager: Помилка перевірки файлу $fileId для preload: $e');
      }
    }
    
    debugPrint('FileManager: Потрібно завантажити ${filesToPreload.length} файлів');
    
    // Завантажуємо файли пакетами по 3 одночасно
    const batchSize = 3;
    for (int i = 0; i < filesToPreload.length; i += batchSize) {
      final batch = filesToPreload.skip(i).take(batchSize).toList();
      
      await Future.wait(
        batch.map((fileId) => cacheFile(fileId).catchError((e) {
          debugPrint('FileManager: Помилка preload файлу $fileId: $e');
        })),
      );
    }
  }

  /// Отримує інформацію про файл без завантаження
  FileCacheEntry? getFileInfo(String fileId) {
    return _cacheService.getFileMetadata(fileId);
  }

  /// Перевіряє, чи файл доступний локально
  Future<bool> isFileAvailable(String fileId) async {
    return await _cacheService.isCached(fileId);
  }

  /// Видаляє файл з кешу
  Future<void> removeFileFromCache(String fileId) async {
    await _cacheService.removeCachedFile(fileId);
    debugPrint('FileManager: Файл $fileId видалено з кешу');
  }

  /// Очищає кеш із збереженням важливих файлів
  Future<void> cleanupCache({
    Duration maxAge = const Duration(days: 30),
    int maxSizeBytes = 100 * 1024 * 1024, // 100MB
    List<String> importantFileIds = const [],
  }) async {
    debugPrint('FileManager: Починаємо очищення кешу');
    
    // Спочатку видаляємо старі файли, крім важливих
    final oldFiles = _cacheService.getCachedFilesList()
        .where((entry) {
          if (importantFileIds.contains(entry.fileId)) return false;
          final modifiedDate = entry.modifiedDateTime;
          return modifiedDate != null && 
                 modifiedDate.isBefore(DateTime.now().subtract(maxAge));
        })
        .map((entry) => entry.fileId)
        .toList();
    
    for (final fileId in oldFiles) {
      await _cacheService.removeCachedFile(fileId);
    }
    
    // Якщо кеш все ще занадто великий, видаляємо найбільші файли
    if (_cacheService.getCacheSize() > maxSizeBytes) {
      final largeFiles = _cacheService.getCachedFilesList()
          .where((entry) => !importantFileIds.contains(entry.fileId))
          .toList()
        ..sort((a, b) => (b.size ?? 0).compareTo(a.size ?? 0));
      
      int currentSize = _cacheService.getCacheSize();
      for (final entry in largeFiles) {
        if (currentSize <= maxSizeBytes) break;
        await _cacheService.removeCachedFile(entry.fileId);
        currentSize -= entry.size ?? 0;
      }
    }
    
    debugPrint('FileManager: Очищення кешу завершено');
  }

  /// Отримує статистику використання кешу
  Map<String, dynamic> getCacheStatistics() {
    return _cacheService.getCacheStatistics();
  }
   Future<FileCacheEntry> getFileMetadata(String fileId) async {
      var metadata = _cacheService.getFileMetadata(fileId);
      if (metadata == null) {
        metadata = await _metadataService.getFileMetadata(fileId);
        if (metadata == null) {
          throw FileMetadataException('Не вдалося отримати метадані для файлу', fileId);
        }
      }
    return metadata;
  }

  /// Поділитися файлом
  Future<void> shareFile(String fileId) async {
    final (bytes, name) = await _cacheService.getCachedFile(fileId);
    if (bytes == null || name == null) {
      throw FileAccessException('Немає кешованого файлу для надсилання', fileId);
    }
    await FileSharer().shareFile(bytes, name);
  }

  /// Перевірка наявності файлу в кеші
  Future<bool> isCached(String fileId) async => await _cacheService.isCached(fileId);

  /// Очищення кешу
  Future<void> clearCache() async => await _cacheService.clearCache();

  /// Видалення одного файлу з кешу
  Future<void> removeFromCache(String fileId) async => await _cacheService.removeCachedFile(fileId);

   String? extractFileId(String url) {
    final RegExp pattern = RegExp(
      r'd(?:/|rive/folders/|/file/d/|/open\?id=|/uc\?id=)([a-zA-Z0-9_-]{10,})',
    );

    final match = pattern.firstMatch(url);
    if (match != null && match.groupCount >= 1) {
      return match.group(1);
    }

    return null;
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
