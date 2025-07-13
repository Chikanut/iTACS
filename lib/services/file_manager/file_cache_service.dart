// file_cache_service.dart (Hive для всіх платформ)

import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'file_cache_entry.dart';

class FileCacheService {
  static final FileCacheService _instance = FileCacheService._internal();

  factory FileCacheService() => _instance;

  late Box<FileCacheEntry> _metadataBox;
  late Box<String> _fileDataBox; // Файли зберігаються як Base64 на всіх платформах

  FileCacheService._internal();

  Future<void> init() async {
    await Hive.initFlutter();
    
    if (!Hive.isAdapterRegistered(0)) {
      Hive.registerAdapter(FileCacheEntryAdapter());
    }
    
    _metadataBox = await Hive.openBox<FileCacheEntry>('file_metadata');
    _fileDataBox = await Hive.openBox<String>('file_data');
    
    debugPrint('FileCacheService: Ініціалізовано для ${kIsWeb ? 'Web' : 'Native'} платформи');
  }

  Future<void> cacheFile({
    required String fileId,
    required String name,
    required String extension,
    required String modifiedDate,
    required Uint8List data,
    String? mimeType,
  }) async {
    try {
      final entry = FileCacheEntry(
        fileId: fileId,
        name: name,
        extension: extension,
        modifiedDate: modifiedDate,
        size: data.length,
        mimeType: mimeType,
      );

      // Зберігаємо файл як Base64
      final base64Data = base64Encode(data);
      await _fileDataBox.put(fileId, base64Data);
      await _metadataBox.put(fileId, entry);
      
      debugPrint('FileCacheService: Збережено файл: $fileId (${entry.humanReadableSize})');
    } catch (e) {
      debugPrint('FileCacheService: Помилка при збереженні файлу $fileId: $e');
      rethrow;
    }
  }

  Future<(Uint8List?, String?)> getCachedFile(String fileId) async {
    try {
      final entry = _metadataBox.get(fileId);
      if (entry == null) return (null, null);

      final base64Data = _fileDataBox.get(fileId);
      if (base64Data != null) {
        final bytes = base64Decode(base64Data);
        return (bytes, entry.name);
      }
    } catch (e) {
      debugPrint('FileCacheService: Помилка при читанні файлу $fileId: $e');
      // Видаляємо пошкоджений файл
      await _removeCachedFileInternal(fileId);
    }
    
    return (null, null);
  }

  Future<bool> isCached(String fileId) async {
    final entry = _metadataBox.get(fileId);
    if (entry == null) return false;
    
    return _fileDataBox.containsKey(fileId);
  }

  String? getFileModifiedDate(String fileId) {
    return _metadataBox.get(fileId)?.modifiedDate;
  }

  FileCacheEntry? getFileMetadata(String fileId) {
    return _metadataBox.get(fileId);
  }

  Future<void> updateCachedFile({
    required String fileId,
    required String modifiedDate,
    required Uint8List data,
    String? mimeType,
  }) async {
    try {
      final entry = _metadataBox.get(fileId);
      if (entry == null) return;

      final updatedEntry = FileCacheEntry(
        fileId: entry.fileId,
        name: entry.name,
        extension: entry.extension,
        modifiedDate: modifiedDate,
        size: data.length,
        mimeType: mimeType ?? entry.mimeType,
      );

      final base64Data = base64Encode(data);
      await _fileDataBox.put(fileId, base64Data);
      await _metadataBox.put(fileId, updatedEntry);
      
      debugPrint('FileCacheService: Оновлено файл: $fileId (${updatedEntry.humanReadableSize})');
    } catch (e) {
      debugPrint('FileCacheService: Помилка при оновленні файлу $fileId: $e');
      rethrow;
    }
  }

  Future<void> removeCachedFile(String fileId) async {
    await _removeCachedFileInternal(fileId);
    debugPrint('FileCacheService: Видалено файл: $fileId');
  }

  Future<void> _removeCachedFileInternal(String fileId) async {
    await _fileDataBox.delete(fileId);
    await _metadataBox.delete(fileId);
  }

  Future<void> clearCache() async {
    await _fileDataBox.clear();
    await _metadataBox.clear();
    debugPrint('FileCacheService: Очищено весь кеш');
  }

  // Методи для оптимізації

  /// Перевіряє, чи потрібно оновити файл на основі дати модифікації
  bool shouldUpdateFile(String fileId, String serverModifiedDate) {
    final cachedDate = getFileModifiedDate(fileId);
    if (cachedDate == null) return true;
    
    try {
      final cachedDateTime = DateTime.parse(cachedDate);
      final serverDateTime = DateTime.parse(serverModifiedDate);
      return serverDateTime.isAfter(cachedDateTime);
    } catch (e) {
      debugPrint('FileCacheService: Помилка при порівнянні дат: $e');
      return true;
    }
  }

  /// Отримує загальний розмір кешу в байтах
  int getCacheSize() {
    int totalSize = 0;
    for (final entry in _metadataBox.values) {
      totalSize += entry.size ?? 0;
    }
    return totalSize;
  }

  /// Отримує розмір кешу в Base64 (фактичний розмір у сховищі)
  int getCacheStorageSize() {
    int totalSize = 0;
    for (final key in _fileDataBox.keys) {
      final data = _fileDataBox.get(key);
      if (data != null) {
        totalSize += data.length;
      }
    }
    return totalSize;
  }

  /// Отримує список усіх кешованих файлів
  List<FileCacheEntry> getCachedFilesList() {
    return _metadataBox.values.toList();
  }

  /// Отримує кількість файлів у кеші
  int getCachedFilesCount() {
    return _metadataBox.length;
  }

  /// Видаляє файли старші за вказаний період
  Future<int> cleanOldFiles(Duration maxAge) async {
    final cutoffDate = DateTime.now().subtract(maxAge);
    final filesToRemove = <String>[];

    for (final entry in _metadataBox.values) {
      final modifiedDate = entry.modifiedDateTime;
      if (modifiedDate == null || modifiedDate.isBefore(cutoffDate)) {
        filesToRemove.add(entry.fileId);
      }
    }

    for (final fileId in filesToRemove) {
      await _removeCachedFileInternal(fileId);
    }

    debugPrint('FileCacheService: Видалено ${filesToRemove.length} старих файлів');
    return filesToRemove.length;
  }

  /// Видаляє найбільші файли до досягнення максимального розміру кешу
  Future<int> cleanLargeFiles(int maxCacheSizeBytes) async {
    final currentSize = getCacheSize();
    if (currentSize <= maxCacheSizeBytes) return 0;

    // Сортуємо файли за розміром (від найбільшого до найменшого)
    final sortedFiles = getCachedFilesList()
      ..sort((a, b) => (b.size ?? 0).compareTo(a.size ?? 0));

    int removedCount = 0;
    int currentCacheSize = currentSize;

    for (final entry in sortedFiles) {
      if (currentCacheSize <= maxCacheSizeBytes) break;
      
      await _removeCachedFileInternal(entry.fileId);
      currentCacheSize -= entry.size ?? 0;
      removedCount++;
    }

    debugPrint('FileCacheService: Видалено $removedCount великих файлів');
    return removedCount;
  }

  /// Видаляє файли за типом
  Future<int> cleanFilesByType(String extension) async {
    final filesToRemove = getCachedFilesList()
        .where((entry) => entry.extension.toLowerCase() == extension.toLowerCase())
        .map((entry) => entry.fileId)
        .toList();

    for (final fileId in filesToRemove) {
      await _removeCachedFileInternal(fileId);
    }

    debugPrint('FileCacheService: Видалено ${filesToRemove.length} файлів типу $extension');
    return filesToRemove.length;
  }

  /// Отримує статистику кешу
  Map<String, dynamic> getCacheStatistics() {
    final files = getCachedFilesList();
    final extensionStats = <String, int>{};
    final mimeTypeStats = <String, int>{};
    
    for (final entry in files) {
      extensionStats[entry.extension] = (extensionStats[entry.extension] ?? 0) + 1;
      if (entry.mimeType != null) {
        mimeTypeStats[entry.mimeType!] = (mimeTypeStats[entry.mimeType!] ?? 0) + 1;
      }
    }

    return {
      'totalFiles': files.length,
      'totalSize': getCacheSize(),
      'storageSize': getCacheStorageSize(),
      'extensionStats': extensionStats,
      'mimeTypeStats': mimeTypeStats,
      'oldestFile': files.isEmpty ? null : files
          .reduce((a, b) => (a.modifiedDateTime?.isBefore(b.modifiedDateTime ?? DateTime.now()) ?? false) ? a : b),
      'newestFile': files.isEmpty ? null : files
          .reduce((a, b) => (a.modifiedDateTime?.isAfter(b.modifiedDateTime ?? DateTime.now()) ?? false) ? a : b),
      'largestFile': files.isEmpty ? null : files
          .reduce((a, b) => (a.size ?? 0) > (b.size ?? 0) ? a : b),
    };
  }

  /// Перевіряє цілісність кешу
  Future<List<String>> validateCacheIntegrity() async {
    final corruptedFiles = <String>[];
    
    for (final entry in _metadataBox.values) {
      try {
        final base64Data = _fileDataBox.get(entry.fileId);
        if (base64Data == null) {
          corruptedFiles.add(entry.fileId);
          continue;
        }
        
        // Перевіряємо, чи можна декодувати Base64
        final bytes = base64Decode(base64Data);
        
        // Перевіряємо розмір
        if (entry.size != null && bytes.length != entry.size) {
          corruptedFiles.add(entry.fileId);
        }
      } catch (e) {
        corruptedFiles.add(entry.fileId);
      }
    }

    // Видаляємо пошкоджені файли
    for (final fileId in corruptedFiles) {
      await _removeCachedFileInternal(fileId);
    }

    debugPrint('FileCacheService: Знайдено і видалено ${corruptedFiles.length} пошкоджених файлів');
    return corruptedFiles;
  }

  /// Оптимізує кеш (видаляє старі файли, перевіряє цілісність)
  Future<Map<String, int>> optimizeCache({
    Duration maxAge = const Duration(days: 30),
    int maxSizeBytes = 100 * 1024 * 1024, // 100MB
  }) async {
    final corruptedFiles = await validateCacheIntegrity();
    final oldFiles = await cleanOldFiles(maxAge);
    final largeFiles = await cleanLargeFiles(maxSizeBytes);
    
    return {
      'corruptedFiles': corruptedFiles.length,
      'oldFiles': oldFiles,
      'largeFiles': largeFiles,
    };
  }
}