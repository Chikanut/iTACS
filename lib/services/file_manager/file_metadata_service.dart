// file_metadata_service.dart

import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../auth_service.dart';
import 'package:http/http.dart' as http;
import 'file_exceptions.dart';
import 'file_cache_entry.dart';

class FileMetadataService {
  
  final AuthService authService;

  FileMetadataService({required this.authService});

  Future<FileCacheEntry?> getFileMetadata(String fileId) async {
    // Спробуємо з поточним токеном
    try {
      return await _getFileMetadataWithRetry(fileId);
    } catch (e) {
      debugPrint('FileMetadata: Остаточна помилка отримання метаданих: $e');
      throw MetadataException('Не вдалося отримати метадані', fileId);
    }
  }

  /// Отримання метаданих з retry логікою
  Future<FileCacheEntry?> _getFileMetadataWithRetry(String fileId, {int maxRetries = 2}) async {
    for (int attempt = 0; attempt < maxRetries; attempt++) {
      try {
        final token = await authService.getAccessToken();

        if (token == null) {
          throw MetadataException('Не вдалося отримати токен для метаданих', fileId);
        }

        final uri = Uri.parse(
          'https://itacs-webservice.onrender.com/filemeta?fileId=$fileId&access_token=$token',
        );

        debugPrint('FileMetadata: Отримання метаданих через проксі (спроба ${attempt + 1}): $uri');
        final response = await http.get(uri);

        debugPrint('FileMetadata: Відповідь проксі - статус: ${response.statusCode}');

        if (response.statusCode == 200) {
          final jsonData = json.decode(response.body);
          debugPrint('FileMetadata: Відповідь проксі - тіло: $jsonData');
          
          // Конвертуємо JSON в FileCacheEntry
          return _jsonToFileCacheEntry(fileId, jsonData);
        } else if (response.statusCode == 401 || response.statusCode == 403) {
          // Токен можливо застарів, спробуємо оновити
          debugPrint('FileMetadata: Токен застарів (${response.statusCode}), оновлюємо...');
          
          if (attempt < maxRetries - 1) {
            // Примусово оновлюємо токен
            await authService.forceRefreshToken();
            continue; // Спробуємо знову
          }
          
          throw MetadataException('Проблема з авторизацією: ${response.statusCode}', fileId);
        } else {
          throw MetadataException('Проксі повернув помилку: ${response.statusCode}', fileId);
        }
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
    
    throw MetadataException('Не вдалося отримати метадані після $maxRetries спроб', fileId);
  }

  /// Конвертує JSON відповідь в FileCacheEntry
  FileCacheEntry _jsonToFileCacheEntry(String fileId, Map<String, dynamic> jsonData) {
    // Адаптуємо до структури JSON, що повертає API
    
    final name = jsonData['name'] as String? ?? '';
    final extension = _extractExtensionFromName(name);
    final modifiedDate = jsonData['modifiedTime'] as String? ?? DateTime.now().toIso8601String();
    final mimeType = jsonData['mimeType'] as String?;
    
    // Безпечно конвертуємо size в int
    int? size;
    final sizeValue = jsonData['size'];
    if (sizeValue != null) {
      if (sizeValue is int) {
        size = sizeValue;
      } else if (sizeValue is String) {
        size = int.tryParse(sizeValue);
      }
    }

    return FileCacheEntry(
      fileId: fileId,
      name: name,
      extension: extension,
      modifiedDate: modifiedDate,
      size: size,
      mimeType: mimeType,
    );
  }

  /// Витягує розширення з назви файлу
  String _extractExtensionFromName(String name) {
    if (name.contains('.')) {
      return name.split('.').last.toLowerCase();
    }
    return '';
  }
}