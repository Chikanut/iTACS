import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_application_1/globals.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:share_plus/share_plus.dart';
import 'package:file_selector/file_selector.dart';
import 'package:open_filex/open_filex.dart';

// Для web-специфічного функціоналу
import 'dart:html' as html show Blob, Url, AnchorElement, window, document, IFrameElement, MessageEvent;
import 'dart:html' if (dart.library.io) 'dart:io' as platform;

/// Спеціальний виняток для Web завантажень
class WebDownloadException implements Exception {
  final String message;
  final String fileId;
  final String? downloadUrl;

  WebDownloadException(this.message, this.fileId, [this.downloadUrl]);

  @override
  String toString() => 'WebDownloadException: $message';
}

/// Модель метаданих файлу
class FileMetadata {
  final String title;
  final String fileId;
  final String version;
  final List<String> tags;
  final String type;
  final String groupId;
  final DateTime? lastModified;

  FileMetadata({
    required this.title,
    required this.fileId,
    required this.version,
    required this.tags,
    required this.type,
    required this.groupId,
    this.lastModified,
  });

  factory FileMetadata.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return FileMetadata(
      title: data['title'] ?? '',
      fileId: data['fileId'] ?? '',
      version: data['version'] ?? '',
      tags: List<String>.from(data['tags'] ?? []),
      type: data['type'] ?? '',
      groupId: data['groupId'] ?? '',
      lastModified: (data['lastModified'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toJson() => {
    'title': title,
    'fileId': fileId,
    'version': version,
    'tags': tags,
    'type': type,
    'groupId': groupId,
    'lastModified': lastModified?.toIso8601String(),
  };
}

/// Кешовані дані файлу
class CachedFileData {
  final Uint8List data;
  final String version;
  final DateTime cachedAt;

  CachedFileData({
    required this.data,
    required this.version,
    required this.cachedAt,
  });

  Map<String, dynamic> toJson() => {
    'data': base64Encode(data),
    'version': version,
    'cachedAt': cachedAt.toIso8601String(),
  };

  factory CachedFileData.fromJson(Map<String, dynamic> json) {
    return CachedFileData(
      data: base64Decode(json['data']),
      version: json['version'],
      cachedAt: DateTime.parse(json['cachedAt']),
    );
  }
}

/// Інформація про версію файлу
class FileVersionInfo {
  
  final String fileId;
  final String? currentVersion;
  final String latestVersion;
  final bool isCached;
  final bool hasUpdate;
  final DateTime? cachedAt;
  final DateTime? lastModified;

  FileVersionInfo({
    required this.fileId,
    this.currentVersion,
    required this.latestVersion,
    required this.isCached,
    required this.hasUpdate,
    this.cachedAt,
    this.lastModified,
  });

  @override
  String toString() {
    return 'FileVersionInfo(fileId: $fileId, current: $currentVersion, latest: $latestVersion, hasUpdate: $hasUpdate)';
  }
}

class FileWithName {
  final String filename;
  final Uint8List bytes;

  FileWithName(this.filename, this.bytes);
}
/// Центральний менеджер файлів
class FileManager {
  static final FileManager _instance = FileManager._internal();
  factory FileManager() => _instance;
  FileManager._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final String _baseGoogleDriveUrl = 'https://drive.google.com/uc?id=';
  
  // Кеш в пам'яті для швидкого доступу
  final Map<String, CachedFileData> _memoryCache = {};

  String? extractFileId(String url) {
    final regExp = RegExp(r'd/([a-zA-Z0-9_-]{25,})');
    final match = regExp.firstMatch(url);
    return match?.group(1);
  }
  
  /// Завантаження файлу з Google Drive
  Future<Uint8List> downloadFile(String fileId) async {
    try {
      debugPrint('FileManager: Завантажую файл $fileId');
      
      // Перевіряємо кеш в пам'яті
      if (_memoryCache.containsKey(fileId)) {
        debugPrint('FileManager: Файл знайдено в кеші пам\'яті');
        return _memoryCache[fileId]!.data;
      }

      // Перевіряємо локальний кеш
      final cachedData = await _getCachedData(fileId);
      if (cachedData != null) {
        _memoryCache[fileId] = cachedData;
        debugPrint('FileManager: Файл знайдено в локальному кеші');
        return cachedData.data;
      }

      Uint8List data;
      
      if (kIsWeb) {
        // Для Web використовуємо альтернативний підхід
        data = await _downloadFileForWeb(fileId);
      } else {
        // Для мобільних/десктопних платформ використовуємо HTTP
        data = await _downloadFileWithHttp(fileId);
      }
      
      // Зберігаємо в кеш
      await _saveToCache(fileId, data, 'downloaded');
      
      debugPrint('FileManager: Файл успішно завантажено (${data.length} bytes)');
      return data;
    } catch (e) {
      debugPrint('FileManager: Помилка завантаження файлу $fileId: $e');
      rethrow;
    }
  }

  /// Завантаження файлу через HTTP (для мобільних/десктопних платформ)
  Future<Uint8List> _downloadFileWithHttp(String fileId) async {
    final url = '$_baseGoogleDriveUrl$fileId&export=download';
    final response = await http.get(Uri.parse(url));

    if (response.statusCode == 200) {
      return response.bodyBytes;
    } else {
      throw Exception('Помилка завантаження файлу: ${response.statusCode}');
    }
  }

  /// Завантаження файлу для Web-платформи (обходимо CORS)
  Future<Uint8List> _downloadFileForWeb(String fileId) async {
    try {
      final metadata = await getFileMetadata(fileId);
      if (metadata == null) {
        throw WebDownloadException('Не вдалося отримати метадані для файлу', fileId);
      }

      final titleEncoded = Uri.encodeComponent(metadata.title);
      final ext = metadata.type;

      final proxyUrl =
          'https://itacs-webservice.onrender.com/proxy?fileId=$fileId&title=$titleEncoded&ext=$ext';

      final response = await http.get(Uri.parse(proxyUrl));

      if (response.statusCode == 200) {
        debugPrint('FileManager: Успішно отримано файл через проксі');
        return response.bodyBytes;
      } else {
        throw WebDownloadException(
          'Проксі повернув помилку: ${response.statusCode}',
          fileId,
          proxyUrl,
        );
      }
    } catch (e) {
      debugPrint('FileManager: Проксі-завантаження не вдалося: $e');
      throw WebDownloadException(
        'Не вдалося завантажити файл через проксі',
        fileId,
      );
    }
  }


  /// Спроба завантаження через Fetch API з no-cors
  Future<Uint8List> _downloadWithFetch(String fileId) async {
    if (!kIsWeb) {
      throw Exception('Fetch API доступний лише для Web');
    }

    try {
      final url = '$_baseGoogleDriveUrl$fileId&export=download';
      
      // Використовуємо fetch з no-cors режимом
      final response = await html.window.fetch(url, {
        'mode': 'no-cors',
        'credentials': 'omit',
      });

      if (response.ok) {
        final arrayBuffer = await response.arrayBuffer();
        return Uint8List.view(arrayBuffer);
      } else {
        throw Exception('Fetch failed with status: ${response.status}');
      }
    } catch (e) {
      debugPrint('FileManager: Fetch API failed: $e');
      rethrow;
    }
  }

  /// Отримання локального файлу (якщо кешований)
  Future<File?> getLocalFile(String fileId) async {
    try {
      if (kIsWeb) {
        // На web не можемо повертати File об'єкт
        return null;
      }

      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/cached_files/$fileId');
      
      if (await file.exists()) {
        return file;
      }
      
      return null;
    } catch (e) {
      debugPrint('FileManager: Помилка отримання локального файлу: $e');
      return null;
    }
  }

  /// Оновлення файлу при потребі
  Future<void> updateFileIfNeeded(String fileId, String latestVersion) async {
    try {
      final cachedData = await _getCachedData(fileId);
      
      if (cachedData == null || cachedData.version != latestVersion) {
        debugPrint('FileManager: Оновлюю файл $fileId до версії $latestVersion');
        
        // Завантажуємо нову версію
        final newData = await downloadFile(fileId);
        
        // Оновлюємо кеш з новою версією
        await _saveToCache(fileId, newData, latestVersion);
        
        debugPrint('FileManager: Файл $fileId оновлено успішно');
      } else {
        debugPrint('FileManager: Файл $fileId вже має актуальну версію');
      }
    } catch (e) {
      debugPrint('FileManager: Помилка оновлення файлу $fileId: $e');
      rethrow;
    }
  }

  /// Очищення кешу
  Future<void> clearCache() async {
    try {
      _memoryCache.clear();
      
      if (kIsWeb) {
        // Очищаємо SharedPreferences для web
        final prefs = await SharedPreferences.getInstance();
        final keys = prefs.getKeys().where((key) => key.startsWith('cached_file_'));
        for (final key in keys) {
          await prefs.remove(key);
        }
      } else {
        // Очищаємо файли на мобільних/десктопних платформах
        final dir = await getApplicationDocumentsDirectory();
        final cacheDir = Directory('${dir.path}/cached_files');
        if (await cacheDir.exists()) {
          await cacheDir.delete(recursive: true);
        }
      }
      
      debugPrint('FileManager: Кеш очищено');
    } catch (e) {
      debugPrint('FileManager: Помилка очищення кешу: $e');
    }
  }

  /// Перевірка чи файл закешований
  bool isFileCached(String fileId) {
    return _memoryCache.containsKey(fileId);
  }

  /// Поширити файл або завантажити локально
  Future<void> shareOrDownloadFile(String fileId) async {
    try {
      // Спочатку отримуємо дані файлу
      final data = await downloadFile(fileId);
      final metadata = await getFileMetadata(fileId);
      
      if (metadata == null) {
        throw Exception('Не вдалося отримати метадані файлу');
      }

      final fileName = '${metadata.title}.${metadata.type}';
      
      if (kIsWeb) {
        // Web: завантажуємо в папку Downloads
        await _downloadForWeb(data, fileName);
      } else if (Platform.isAndroid || Platform.isIOS) {
        // Mobile: викликаємо меню поширення
        await _shareOnMobile(data, fileName);
      } else {
        // Desktop: діалог збереження
        await _saveOnDesktop(data, fileName);
      }
    } catch (e) {
      debugPrint('FileManager: Помилка поширення файлу $fileId: $e');
      rethrow;
    }
  }

  /// Відкрити файл
  Future<void> openFile(String fileId) async {
    try {
      final data = await downloadFile(fileId);


      if (kIsWeb) {
        // На web відкриваємо файл у новій вкладці
        await _openFileOnWeb(data);
      } else {
        // На мобільних та десктопних платформах
        final metadata = await getFileMetadata(fileId);
      
        if (metadata == null) {
          throw Exception('Не вдалося отримати метадані файлу');
        }
        final file = await _saveTempFile(data, metadata);
        await OpenFilex.open(file.path);
      }
    } catch (e) {
      debugPrint('FileManager: Помилка відкриття файлу $fileId: $e');
      rethrow;
    }
  }

  /// Перевірка наявності оновлення для файлу
  Future<bool> checkForUpdate(String fileId) async {
    try {
      // Отримуємо актуальні метадані з Firestore
      final latestMetadata = await getFileMetadata(fileId);
      if (latestMetadata == null) {
        debugPrint('FileManager: Не вдалося отримати метадані для перевірки оновлення $fileId');
        return false;
      }

      // Отримуємо кешовані дані
      final cachedData = await _getCachedData(fileId);
      if (cachedData == null) {
        // Файл не кешований, потрібно завантажити
        debugPrint('FileManager: Файл $fileId не кешований, потрібно завантажити');
        return true;
      }

      // Порівнюємо версії
      final hasUpdate = cachedData.version != latestMetadata.version;
      
      if (hasUpdate) {
        debugPrint('FileManager: Знайдено оновлення для файлу $fileId: ${cachedData.version} -> ${latestMetadata.version}');
      } else {
        debugPrint('FileManager: Файл $fileId має актуальну версію');
      }

      return hasUpdate;
    } catch (e) {
      debugPrint('FileManager: Помилка перевірки оновлення файлу $fileId: $e');
      return false;
    }
  }

  /// Перевірка оновлень для списку файлів
  Future<Map<String, bool>> checkForUpdates(List<String> fileIds) async {
    final Map<String, bool> results = {};
    
    try {
      // Виконуємо перевірки паралельно для кращої продуктивності
      final futures = fileIds.map((fileId) => 
        checkForUpdate(fileId).then((hasUpdate) => 
          MapEntry(fileId, hasUpdate)));
      
      final entries = await Future.wait(futures);
      
      for (final entry in entries) {
        results[entry.key] = entry.value;
      }
      
      final updatesCount = results.values.where((hasUpdate) => hasUpdate).length;
      debugPrint('FileManager: Перевірено ${fileIds.length} файлів, знайдено $updatesCount оновлень');
      
    } catch (e) {
      debugPrint('FileManager: Помилка перевірки оновлень: $e');
    }
    
    return results;
  }

  /// Отримання інформації про версію файлу
  Future<FileVersionInfo?> getFileVersionInfo(String fileId) async {
    try {
      final metadata = await getFileMetadata(fileId);
      final cachedData = await _getCachedData(fileId);
      
      if (metadata == null) return null;
      
      return FileVersionInfo(
        fileId: fileId,
        currentVersion: cachedData?.version,
        latestVersion: metadata.version,
        isCached: cachedData != null,
        hasUpdate: cachedData?.version != metadata.version,
        cachedAt: cachedData?.cachedAt,
        lastModified: metadata.lastModified,
      );
    } catch (e) {
      debugPrint('FileManager: Помилка отримання інформації про версію $fileId: $e');
      return null;
    }
  }

  /// Примусове оновлення файлу
  Future<void> forceRefreshFile(String fileId) async {
    try {
      // Видаляємо з кешу
      _memoryCache.remove(fileId);
      await removeCachedData(fileId);
      
      // Завантажуємо знову
      await downloadFile(fileId);
      
      debugPrint('FileManager: Примусове оновлення файлу $fileId завершено');
    } catch (e) {
      debugPrint('FileManager: Помилка примусового оновлення $fileId: $e');
      rethrow;
    }
  }

  /// Отримання метаданих файлу з Firestore
/// Отримання метаданих файлу з Firestore або Google Drive API
Future<FileMetadata?> getFileMetadata(String fileId) async {
  try {
    final user = _auth.currentUser;
    if (user == null) return null;

    // 1. Спроба зчитати з Firestore
    final querySnapshot = await _firestore
        .collection('files')
        .where('fileId', isEqualTo: fileId)
        .limit(1)
        .get();

    if (querySnapshot.docs.isNotEmpty) {
      debugPrint('FileManager: Метадані знайдено в Firestore');
      return FileMetadata.fromFirestore(querySnapshot.docs.first);
    }

    // 2. Якщо не знайшли в Firestore — пробуємо отримати через Google Drive API
    final token = await Globals.authService.getAccessToken();
    if (token == null) {
      debugPrint('FileManager: Немає access token для Google Drive API');
      return null;
    }

    final url = Uri.parse(
      'https://itacs-webservice.onrender.com/filemeta?fileId=$fileId&access_token=$token',
    );

    debugPrint('FileManager: Отримання метаданих через проксі: $url');

    final response = await http.get(url, headers: {
      'Accept': 'application/json',
      'Content-Type': 'application/json',
    });

    debugPrint('FileManager: Відповідь проксі - статус: ${response.statusCode}');
    debugPrint('FileManager: Відповідь проксі - тіло: ${response.body}');

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final name = data['name'] ?? 'file';
      final modified = data['modifiedTime'];
      final mimeType = data['mimeType'] ?? 'application/octet-stream';

      final parts = name.split('.');
      final title = parts.length > 1 ? parts.sublist(0, parts.length - 1).join('.') : name;
      final type = parts.length > 1 ? parts.last : _getExtensionFromMimeType(mimeType);

      return FileMetadata(
        title: title,
        fileId: fileId,
        version: modified ?? DateTime.now().millisecondsSinceEpoch.toString(),
        tags: [],
        type: type,
        groupId: 'drive',
        lastModified: modified != null ? DateTime.tryParse(modified) : null,
      );
    } else {
      debugPrint('FileManager: Проксі повернув помилку ${response.statusCode}: ${response.body}');
    }
  } catch (e) {
    debugPrint('FileManager: Помилка отримання метаданих: $e');
  }

  return null;
}

/// Допоміжний метод для отримання розширення з MIME типу
String _getExtensionFromMimeType(String mimeType) {
  switch (mimeType) {
    case 'application/pdf':
      return 'pdf';
    case 'image/jpeg':
      return 'jpg';
    case 'image/png':
      return 'png';
    case 'application/vnd.openxmlformats-officedocument.wordprocessingml.document':
      return 'docx';
    case 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet':
      return 'xlsx';
    case 'text/plain':
      return 'txt';
    default:
      return 'bin';
  }
}


  /// Збереження в кеш
  Future<void> _saveToCache(String fileId, Uint8List data, String version) async {
    final cachedData = CachedFileData(
      data: data,
      version: version,
      cachedAt: DateTime.now(),
    );

    // Зберігаємо в кеш пам'яті
    _memoryCache[fileId] = cachedData;

    if (kIsWeb) {
      // На web використовуємо SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('cached_file_$fileId', jsonEncode(cachedData.toJson()));
    } else {
      // На мобільних/десктопних платформах зберігаємо файл
      final dir = await getApplicationDocumentsDirectory();
      final cacheDir = Directory('${dir.path}/cached_files');
      if (!await cacheDir.exists()) {
        await cacheDir.create(recursive: true);
      }
      
      final file = File('${cacheDir.path}/$fileId');
      await file.writeAsBytes(data);
      
      // Зберігаємо метадані окремо
      final metaFile = File('${cacheDir.path}/$fileId.meta');
      await metaFile.writeAsString(jsonEncode({
        'version': version,
        'cachedAt': DateTime.now().toIso8601String(),
      }));
    }
  }

  /// Отримання кешованих даних
  Future<CachedFileData?> _getCachedData(String fileId) async {
    try {
      // Перевіряємо кеш в пам'яті
      if (_memoryCache.containsKey(fileId)) {
        return _memoryCache[fileId];
      }

      if (kIsWeb) {
        // На web читаємо з SharedPreferences
        final prefs = await SharedPreferences.getInstance();
        final jsonString = prefs.getString('cached_file_$fileId');
        if (jsonString != null) {
          final data = CachedFileData.fromJson(jsonDecode(jsonString));
          _memoryCache[fileId] = data; // Додаємо в кеш пам'яті
          return data;
        }
      } else {
        // На мобільних/десктопних платформах читаємо файл
        final dir = await getApplicationDocumentsDirectory();
        final file = File('${dir.path}/cached_files/$fileId');
        final metaFile = File('${dir.path}/cached_files/$fileId.meta');
        
        if (await file.exists() && await metaFile.exists()) {
          final data = await file.readAsBytes();
          final metaJson = jsonDecode(await metaFile.readAsString());
          
          final cachedData = CachedFileData(
            data: data,
            version: metaJson['version'],
            cachedAt: DateTime.parse(metaJson['cachedAt']),
          );
          
          _memoryCache[fileId] = cachedData; // Додаємо в кеш пам'яті
          return cachedData;
        }
      }
      
      return null;
    } catch (e) {
      debugPrint('FileManager: Помилка отримання кешованих даних: $e');
      return null;
    }
  }

  /// Видалення кешованих даних
  Future<void> removeCachedData(String fileId) async {
    try {
      if (kIsWeb) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove('cached_file_$fileId');
      } else {
        final dir = await getApplicationDocumentsDirectory();
        final file = File('${dir.path}/cached_files/$fileId');
        final metaFile = File('${dir.path}/cached_files/$fileId.meta');
        
        if (await file.exists()) await file.delete();
        if (await metaFile.exists()) await metaFile.delete();
      }
      _memoryCache.remove(fileId); // Очищаємо кеш в пам'яті
      debugPrint('FileManager: Кешовані дані для $fileId видалено');
    } catch (e) {
      debugPrint('FileManager: Помилка видалення кешованих даних: $e');
    }
  }

  /// Завантаження для web
  Future<void> _downloadForWeb(Uint8List data, String fileName) async {
    if (kIsWeb) {
      final blob = html.Blob([data]);
      final url = html.Url.createObjectUrlFromBlob(blob);
      final anchor = html.AnchorElement(href: url)
        ..setAttribute('download', fileName)
        ..click();
      html.Url.revokeObjectUrl(url);
      debugPrint('FileManager: Файл завантажено для web: $fileName');
    }
  }

  /// Поширення на мобільних платформах
  Future<void> _shareOnMobile(Uint8List data, String fileName) async {
    if (Platform.isAndroid || Platform.isIOS) {
      final tempFile = await _saveTempFile(data, FileMetadata(
        title: fileName.split('.').first,
        fileId: '',
        version: '',
        tags: [],
        type: fileName.split('.').last,
        groupId: '',
      ));
      
      await Share.shareXFiles([XFile(tempFile.path)], text: 'Ось файл: $fileName');
      debugPrint('FileManager: Файл поширено на мобільному пристрої: $fileName');
    }
  }

  /// Збереження на десктопі
  Future<void> _saveOnDesktop(Uint8List data, String fileName) async {
    if (Platform.isWindows || Platform.isMacOS || Platform.isLinux) {
      final targetPath = await getSavePath(suggestedName: fileName);
      if (targetPath != null) {
        final file = File(targetPath);
        await file.writeAsBytes(data);
        debugPrint('FileManager: Файл збережено на десктопі: $targetPath');
      }
    }
  }

  /// Відкриття файлу на web
  Future<void> _openFileOnWeb(Uint8List data) async {
    if (kIsWeb) {
      final blob = html.Blob([data], 'text/html');
      final url = html.Url.createObjectUrlFromBlob(blob);
      html.window.open(url, '_blank');
      html.Url.revokeObjectUrl(url);
      debugPrint('FileManager: Файл відкрито на web');
    }
  }

  /// Збереження тимчасового файлу
  Future<File> _saveTempFile(Uint8List data, FileMetadata metadata) async {
    final tempDir = await getTemporaryDirectory();
    final fileName = '${metadata.title}.${metadata.type}';
    final file = File('${tempDir.path}/$fileName');
    await file.writeAsBytes(data);
    return file;
  }
}

/// Віджет для відображення файлу
class FileCard extends StatefulWidget {
  final FileMetadata metadata;
  final VoidCallback? onRefresh;

  const FileCard({
    super.key,
    required this.metadata,
    this.onRefresh,
  });

  @override
  State<FileCard> createState() => _FileCardState();
}

class _FileCardState extends State<FileCard> {
  final FileManager _fileManager = FileManager();
  bool _isLoading = false;
  bool _hasUpdate = false;

  @override
  void initState() {
    super.initState();
    _checkForUpdate();
  }

  Future<void> _checkForUpdate() async {
    final hasUpdate = await _fileManager.checkForUpdate(widget.metadata.fileId);
    if (mounted) {
      setState(() => _hasUpdate = hasUpdate);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isCached = _fileManager.isFileCached(widget.metadata.fileId);
    
    return Card(
      margin: const EdgeInsets.all(8.0),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    widget.metadata.title,
                    style: Theme.of(context).textTheme.titleMedium,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                // Індикатор статусу файлу
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_hasUpdate)
                      Container(
                        margin: const EdgeInsets.only(right: 4),
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.orange.shade100,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.orange.shade300),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.update,
                              size: 12,
                              color: Colors.orange.shade700,
                            ),
                            const SizedBox(width: 2),
                            Text(
                              'Оновлення',
                              style: TextStyle(
                                fontSize: 10,
                                color: Colors.orange.shade700,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    Icon(
                      isCached ? Icons.offline_bolt : Icons.cloud_download,
                      color: isCached ? Colors.green : Colors.grey,
                      size: 20,
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 8),
            
            // Теги
            if (widget.metadata.tags.isNotEmpty)
              Wrap(
                spacing: 4,
                children: widget.metadata.tags.map((tag) {
                  return Chip(
                    label: Text(tag),
                    backgroundColor: Colors.blue.shade100,
                  );
                }).toList(),
              ),
            
            const SizedBox(height: 8),
            
            // Інформація
            Text(
              'Тип: ${widget.metadata.type.toUpperCase()} • Версія: ${widget.metadata.version}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            
            const SizedBox(height: 16),
            
            // Кнопки дій
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildActionButton(
                  icon: Icons.open_in_new,
                  label: 'Відкрити',
                  onPressed: _isLoading ? null : () => _openFile(),
                ),
                _buildActionButton(
                  icon: Icons.share,
                  label: 'Поширити',
                  onPressed: _isLoading ? null : () => _shareFile(),
                ),
                _buildActionButton(
                  icon: Icons.refresh,
                  label: 'Оновити',
                  onPressed: _isLoading ? null : () => _refreshFile(),
                ),
              ],
            ),
            
            if (_isLoading)
              const Padding(
                padding: EdgeInsets.only(top: 8.0),
                child: LinearProgressIndicator(),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required VoidCallback? onPressed,
  }) {
    return TextButton.icon(
      icon: Icon(icon),
      label: Text(label),
      onPressed: onPressed,
    );
  }

  /// Показати діалог з поясненням для ручного завантаження
  Future<void> _showManualDownloadDialog(BuildContext context, String fileId) async {
    final url = 'https://drive.google.com/uc?id=$fileId&export=download';
    
    return showDialog<void>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Ручне завантаження'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Через обмеження браузера, файл потрібно завантажити вручну:',
                style: TextStyle(fontSize: 14),
              ),
              const SizedBox(height: 12),
              const Text(
                '1. Натисніть на посилання нижче',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
              const Text(
                '2. Файл завантажиться автоматично',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: SelectableText(
                  url,
                  style: const TextStyle(fontSize: 12),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Закрити'),
            ),
            ElevatedButton(
              onPressed: () {
                html.window.open(url, '_blank');
                Navigator.of(context).pop();
              },
              child: const Text('Завантажити'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _openFile() async {
    setState(() => _isLoading = true);
    try {
      await _fileManager.openFile(widget.metadata.fileId);
    } catch (e) {
      if (mounted) {
        if (e is WebDownloadException && kIsWeb) {
          await _showManualDownloadDialog(context, widget.metadata.fileId);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Помилка відкриття файлу: $e')),
          );
        }
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _shareFile() async {
    setState(() => _isLoading = true);
    try {
      await _fileManager.shareOrDownloadFile(widget.metadata.fileId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Файл успішно поширено')),
        );
      }
    } catch (e) {
      if (mounted) {
        if (e is WebDownloadException && kIsWeb) {
          await _showManualDownloadDialog(context, widget.metadata.fileId);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Помилка поширення файлу: $e')),
          );
        }
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _refreshFile() async {
    setState(() => _isLoading = true);
    try {
      await _fileManager.forceRefreshFile(widget.metadata.fileId);
      await _checkForUpdate(); // Перевіряємо оновлення після refresh
      widget.onRefresh?.call();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Файл оновлено')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Помилка оновлення файлу: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }
}