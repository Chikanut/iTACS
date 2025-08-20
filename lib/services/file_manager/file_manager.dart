// file_manager.dart

import 'package:flutter/foundation.dart';
import 'package:flutter_application_1/services/file_manager/file_metadata_service.dart';
import 'dart:convert';

import '../auth_service.dart';
import '../../globals.dart';

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

      if (metadata.extension.toLowerCase() == 'html') {
        debugPrint('FileManager: Інжектування даних користувача в HTML файл $fileId');
        // Інжектувати дані користувача
        fileBytes = _injectUserDataIntoHtml(fileBytes);
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

  Future<bool> shouldRefreshFile(String fileId) async {
    try {
      // Отримуємо метадані
      final metadata = await _metadataService.getFileMetadata(fileId);
      if (metadata == null) {
        throw FileMetadataException('Не вдалося отримати метадані для файлу', fileId);
      }

      // Перевіряємо, чи файл актуальний
      return _cacheService.shouldUpdateFile(
        fileId, 
        metadata.modifiedDate ?? DateTime.now().toIso8601String()
      );
    } catch (e) {
      debugPrint('FileManager: Помилка перевірки актуальності файлу $fileId: $e');
      return false;
    }
  }

  /// Перевіряє актуальність файлу та оновлює при необхідності
  Future<bool> refreshFileIfNeeded(String fileId) async {
    try {
      final shouldUpdate = await shouldRefreshFile(fileId);

      final metadata = await _metadataService.getFileMetadata(fileId);
      if (metadata == null) {
        throw FileMetadataException('Не вдалося отримати метадані для файлу', fileId);
      }

      if (shouldUpdate) {
        debugPrint('FileManager: Оновлюємо файл $fileId');
        final fileBytes = await _downloaderService.downloadFile(fileId);
        
        await _cacheService.updateCachedFile(
          fileId: fileId,
          modifiedDate: metadata.modifiedDate ?? DateTime.now().toIso8601String(),
          data: fileBytes,
          mimeType: _getMimeType(metadata.extension),
        );
        return true;
            }

      return false;
    } catch (e) {
      debugPrint('FileManager: Помилка оновлення файлу $fileId: $e');
      return false;
    }
  }

  /// Примусово оновлює файл з Google Drive
  Future<bool> forceRefreshFile(String fileId) async {
    try {
      debugPrint('FileManager: Примусове оновлення файлу $fileId');
      
      // Отримуємо метадані
      final metadata = await _metadataService.getFileMetadata(fileId);
      if (metadata == null) {
        throw FileMetadataException('Не вдалося отримати метадані для файлу', fileId);
      }
      
      // Завантажуємо файл
      final fileBytes = await _downloaderService.downloadFile(fileId);
      
      // Оновлюємо кеш
      await _cacheService.updateCachedFile(
        fileId: fileId,
        modifiedDate: metadata.modifiedDate ?? DateTime.now().toIso8601String(),
        data: fileBytes,
        mimeType: _getMimeType(metadata.extension),
      );
      
      debugPrint('FileManager: Файл $fileId примусово оновлено');
      return true;
      
    } catch (e) {
      debugPrint('FileManager: Помилка примусового оновлення файлу $fileId: $e');
      rethrow;
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

  Future<Map<String, dynamic>> getFileStatus(String fileId) async {
    try {
      final isCached = await this.isCached(fileId);
      final metadata = _cacheService.getFileMetadata(fileId);
      final shouldRefresh = await shouldRefreshFile(fileId);
      
      return {
        'isCached': isCached,
        'shouldRefresh': shouldRefresh,
        'cachedAt': metadata?.modifiedDate,
        'size': metadata?.size,
        'humanReadableSize': metadata?.humanReadableSize,
        'extension': metadata?.extension,
        'mimeType': metadata?.mimeType,
      };
    } catch (e) {
      debugPrint('FileManager: Помилка отримання статусу файлу $fileId: $e');
      return {
        'isCached': false,
        'shouldRefresh': true,
        'error': e.toString(),
      };
    }
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

  /// Поділитися файлом безпосередньо по даті та імені
  Future<void> shareFileByData(String fileName, Uint8List data) async {
    await FileSharer().shareFile(data, fileName);
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

  Uint8List _injectUserDataIntoHtml(Uint8List htmlBytes) {
  try {
    // Конвертуємо bytes в string
    String htmlContent = utf8.decode(htmlBytes);
    
    // Отримуємо дані користувача
    final userProfile = Globals.profileManager.profile.toMap();
    userProfile['unit'] = Globals.profileManager.currentGroupName;

    // 🔍 DEBUG: Логуємо дані користувача
    debugPrint('🔍 HTML Injection Debug:');
    debugPrint('  User Profile: $userProfile');
    
    // Формуємо повну назву посади для поля userFullName
    String fullUserTitle = '';
    final position = userProfile['position']?.toString() ?? '';
    final unit = userProfile['unit']?.toString() ?? '';
    final rank = userProfile['rank']?.toString() ?? '';
    final firstName = userProfile['firstName']?.toString() ?? '';
    final lastName = userProfile['lastName']?.toString() ?? '';
    final fullName = '$firstName $lastName'.trim();
    
    // Формуємо як в прикладі: "сержант-інструктор ГСПП молодший сержант Войтович Євген"
    List<String> titleParts = [];
    if (position.isNotEmpty) titleParts.add(position);
    if (unit.isNotEmpty) titleParts.add(unit);
    if (rank.isNotEmpty) titleParts.add(rank);
    if (fullName.isNotEmpty) titleParts.add(fullName);
    fullUserTitle = titleParts.join(' ');
    
    // 🔍 DEBUG: Логуємо сформований титул
    debugPrint('  Full User Title: "$fullUserTitle"');
    debugPrint('  Position: "$position"');
    debugPrint('  Unit: "$unit"');
    debugPrint('  Rank: "$rank"');
    debugPrint('  Full Name: "$fullName"');
    
    // Замінюємо плейсхолдери в тексті
    final replacements = {
      '{{USER_NAME}}': fullName,
      '{{USER_EMAIL}}': userProfile['email']?.toString() ?? '',
      '{{USER_RANK}}': rank,
      '{{USER_POSITION}}': position,
      '{{USER_UNIT}}': unit,
      '{{USER_FULL_TITLE}}': fullUserTitle,
      '{{CURRENT_DATE}}': DateTime.now().toLocal().toString().split(' ')[0],
      '{{CURRENT_TIME}}': DateTime.now().toLocal().toString().split(' ')[1].split('.')[0],
      '{{CURRENT_DATETIME}}': DateTime.now().toLocal().toString().split('.')[0],
    };

    replacements.forEach((placeholder, value) {
      if (htmlContent.contains(placeholder)) {
        debugPrint('  ✅ Замінено $placeholder на "$value"');
        htmlContent = htmlContent.replaceAll(placeholder, value);
      }
    });

    // Додаємо JavaScript з розширеним дебагом
    final jsScript = '''
<script>
// 🔍 DEBUG MODE ВКЛЮЧЕНО
console.log('🚀 HTML Injection Script завантажено');

// Дані профілю користувача
window.USER_PROFILE = ${jsonEncode(userProfile)};
console.log('👤 USER_PROFILE завантажено:', window.USER_PROFILE);

// Функція для формування повного титулу
function getFullUserTitle() {
  const profile = window.USER_PROFILE;
  if (!profile) {
    console.error('❌ Профіль користувача не знайдено');
    return '';
  }
  
  const position = profile.position || '';
  const unit = profile.unit || '';
  const rank = profile.rank || '';
  const firstName = profile.firstName || '';
  const lastName = profile.lastName || '';
  const fullName = (firstName + ' ' + lastName).trim();
  
  const titleParts = [];
  if (position) titleParts.push(position);
  if (unit) titleParts.push(unit);
  if (rank) titleParts.push(rank);
  if (fullName) titleParts.push(fullName);
  
  const result = titleParts.join(' ');
  console.log('🏷️ Сформований титул:', result);
  console.log('  - Position:', position);
  console.log('  - Unit:', unit);
  console.log('  - Rank:', rank);
  console.log('  - Full Name:', fullName);
  
  return result;
}

// Основна функція заповнення даних
function fillUserData() {
  console.log('🔄 Початок заповнення даних користувача...');
  
  const profile = window.USER_PROFILE;
  if (!profile) {
    console.error('❌ Профіль користувача не доступний');
    return;
  }
  
  const fullUserTitle = getFullUserTitle();
  console.log('📝 Буде заповнено титул:', fullUserTitle);
  
  // Заповнення специфічних полів
  const specificFields = {
    'userFullName': fullUserTitle,
    'userEmail': profile.email || '',
    'userRank': profile.rank || '',
    'userPosition': profile.position || '',
    'userUnit': profile.unit || '',
    'userName': (profile.firstName + ' ' + profile.lastName).trim() || profile.displayName || profile.name || '',
  };
  
  console.log('🎯 Поля для заповнення:', specificFields);
  
  // Заповнюємо поля за ID
  Object.entries(specificFields).forEach(([fieldId, value]) => {
    const element = document.getElementById(fieldId);
    if (element) {
      console.log(\`✅ Знайдено поле \${fieldId}, заповнюємо значенням: "\${value}"\`);
      
      if (element.tagName === 'INPUT' || element.tagName === 'TEXTAREA') {
        element.value = value;
        console.log(\`  📝 Встановлено value для \${fieldId}\`);
        
        // Викликаємо подію input для збереження в localStorage якщо є така функція
        if (typeof element.oninput === 'function') {
          console.log(\`  🔄 Викликаємо oninput для \${fieldId}\`);
          element.oninput();
        }
        // Або викликаємо подію input
        element.dispatchEvent(new Event('input', { bubbles: true }));
        console.log(\`  📡 Відправлено input event для \${fieldId}\`);
      } else {
        element.textContent = value;
        console.log(\`  📝 Встановлено textContent для \${fieldId}\`);
      }
    } else {
      console.warn(\`⚠️ Поле з ID "\${fieldId}" не знайдено в DOM\`);
    }
  });
  
  // Заповнення за атрибутами data-user-field
  const dataFieldElements = document.querySelectorAll('[data-user-field]');
  console.log(\`🔍 Знайдено \${dataFieldElements.length} елементів з data-user-field\`);
  
  dataFieldElements.forEach(el => {
    const field = el.getAttribute('data-user-field');
    let value = '';
    
    switch(field) {
      case 'fullTitle':
        value = fullUserTitle;
        break;
      case 'fullName':
        value = (profile.firstName + ' ' + profile.lastName).trim() || profile.displayName || profile.name || '';
        break;
      default:
        value = profile[field] || '';
        break;
    }
    
    if (value) {
      console.log(\`✅ data-user-field="\${field}" заповнено: "\${value}"\`);
      if (el.tagName === 'INPUT' || el.tagName === 'TEXTAREA') {
        el.value = value;
        el.dispatchEvent(new Event('input', { bubbles: true }));
      } else {
        el.textContent = value;
      }
    }
  });
  
  // Заповнення за CSS класами
  const mappings = {
    '.user-name': (profile.firstName + ' ' + profile.lastName).trim() || profile.displayName || profile.name,
    '.user-full-name': (profile.firstName + ' ' + profile.lastName).trim() || profile.displayName || profile.name,
    '.user-full-title': fullUserTitle,
    '.user-email': profile.email,
    '.user-rank': profile.rank,
    '.user-position': profile.position,
    '.user-unit': profile.unit,
    '.current-date': new Date().toLocaleDateString('uk-UA'),
    '.current-time': new Date().toLocaleTimeString('uk-UA'),
    '.current-datetime': new Date().toLocaleString('uk-UA'),
  };
  
  Object.entries(mappings).forEach(([selector, value]) => {
    const elements = document.querySelectorAll(selector);
    if (elements.length > 0) {
      console.log(\`✅ Знайдено \${elements.length} елементів з селектором "\${selector}"\`);
      if (value) {
        elements.forEach(el => {
          if (el.tagName === 'INPUT' || el.tagName === 'TEXTAREA') {
            el.value = value;
            el.dispatchEvent(new Event('input', { bubbles: true }));
          } else {
            el.textContent = value;
          }
        });
        console.log(\`  📝 Заповнено значенням: "\${value}"\`);
      }
    }
  });
  
  // Заповнення елементів з id що містять "userFullNameDisplay"
  const displayElements = document.querySelectorAll('[id*="userFullNameDisplay"]');
  console.log(\`🔍 Знайдено \${displayElements.length} елементів з "userFullNameDisplay" в ID\`);
  
  displayElements.forEach(el => {
    if (fullUserTitle) {
      el.textContent = fullUserTitle;
      console.log(\`✅ Оновлено \${el.id} з титулом: "\${fullUserTitle}"\`);
    }
  });
  
  console.log('✅ Заповнення даних користувача завершено!');
}

// Функція для оновлення відображення імені користувача (для сумісності з існуючими скриптами)
function updateUserNameDisplay(name) {
  console.log('🔄 updateUserNameDisplay викликано з іменем:', name);
  const elements = document.querySelectorAll('#userFullNameDisplay, #userFullNameDisplay2, [id*="userFullNameDisplay"]');
  console.log(\`🔍 Знайдено \${elements.length} елементів для оновлення\`);
  
  elements.forEach(el => {
    const finalName = name || getFullUserTitle() || '[ВАШЕ ІМ\\'Я]';
    el.textContent = finalName;
    console.log(\`✅ Оновлено \${el.id || el.className} з: "\${finalName}"\`);
  });
}

// Перевизначаємо функцію saveUserName якщо вона існує
if (typeof window.saveUserName === 'function') {
  console.log('🔄 Перевизначаємо існуючу функцію saveUserName');
  const originalSaveUserName = window.saveUserName;
  window.saveUserName = function() {
    console.log('💾 saveUserName викликано (перевизначена версія)');
    originalSaveUserName();
    const name = document.getElementById('userFullName')?.value || getFullUserTitle();
    updateUserNameDisplay(name);
  };
} else {
  console.log('ℹ️ Функція saveUserName не знайдена, створюємо нову');
  window.saveUserName = function() {
    console.log('💾 saveUserName викликано (нова версія)');
    const name = document.getElementById('userFullName')?.value || getFullUserTitle();
    updateUserNameDisplay(name);
  };
}

// Автозапуск заповнення даних
console.log('📋 Document readyState:', document.readyState);

if (document.readyState === 'loading') {
  console.log('⏳ Документ ще завантажується, чекаємо DOMContentLoaded');
  document.addEventListener('DOMContentLoaded', function() {
    console.log('🚀 DOMContentLoaded подія отримана');
    fillUserData();
  });
} else {
  console.log('✅ Документ вже завантажений, запускаємо заповнення');
  fillUserData();
}

// Додаткова перевірка через 100мс для впевненості
setTimeout(function() {
  console.log('🔄 Додаткова перевірка через 100мс');
  fillUserData();
}, 100);

// Глобальна функція для ручного дебагу
window.debugUserData = function() {
  console.log('🔍 === MANUAL DEBUG ===');
  console.log('USER_PROFILE:', window.USER_PROFILE);
  console.log('getFullUserTitle():', getFullUserTitle());
  
  const userFullNameElement = document.getElementById('userFullName');
  console.log('userFullName element:', userFullNameElement);
  if (userFullNameElement) {
    console.log('  value:', userFullNameElement.value);
    console.log('  oninput:', userFullNameElement.oninput);
  }
  
  fillUserData();
};

console.log('🎉 JavaScript інжекція завершена! Викличте debugUserData() в консолі для ручного дебагу');
</script>
''';

    // 🔍 DEBUG: Перевіряємо чи знайшли місце для вставки скрипта
    if (htmlContent.contains('</head>')) {
      debugPrint('  ✅ Вставляємо JavaScript перед </head>');
      htmlContent = htmlContent.replaceFirst('</head>', '$jsScript</head>');
    } else if (htmlContent.contains('<body>')) {
      debugPrint('  ✅ Вставляємо JavaScript в початок <body>');
      htmlContent = htmlContent.replaceFirst('<body>', '<body>$jsScript');
    } else {
      debugPrint('  ⚠️ Не знайдено </head> або <body>, вставляємо на початок файлу');
      htmlContent = '$jsScript\n$htmlContent';
    }

    // 🔍 DEBUG: Логуємо розмір результату
    final resultBytes = utf8.encode(htmlContent);
    debugPrint('  📊 Розмір оригінального HTML: ${htmlBytes.length} bytes');
    debugPrint('  📊 Розмір після інжекції: ${resultBytes.length} bytes');
    debugPrint('  📊 Додано: ${resultBytes.length - htmlBytes.length} bytes');
    
    return resultBytes;
    
  } catch (e) {
    debugPrint('❌ FileManager: Помилка інжекції даних в HTML: $e');
    // Повертаємо оригінальний файл при помилці
    return htmlBytes;
  }
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
