import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import 'auth_service.dart';
import 'file_manager/file_cache_entry.dart';
import 'file_manager/file_exceptions.dart';

class GoogleDriveFile {
  const GoogleDriveFile({
    required this.id,
    required this.name,
    required this.mimeType,
    this.modifiedTime,
    this.size,
    this.parents = const [],
    this.webViewLink,
    this.iconLink,
  });

  factory GoogleDriveFile.fromJson(Map<String, dynamic> json) {
    return GoogleDriveFile(
      id: (json['id'] ?? '').toString(),
      name: (json['name'] ?? '').toString(),
      mimeType: (json['mimeType'] ?? '').toString(),
      modifiedTime: json['modifiedTime']?.toString(),
      size: _parseNullableInt(json['size']),
      parents: (json['parents'] as List? ?? const [])
          .map((entry) => entry.toString())
          .toList(growable: false),
      webViewLink: json['webViewLink']?.toString(),
      iconLink: json['iconLink']?.toString(),
    );
  }

  static int? _parseNullableInt(dynamic value) {
    if (value is int) {
      return value;
    }

    if (value is String) {
      return int.tryParse(value);
    }

    return null;
  }

  final String id;
  final String name;
  final String mimeType;
  final String? modifiedTime;
  final int? size;
  final List<String> parents;
  final String? webViewLink;
  final String? iconLink;

  bool get isFolder => mimeType == GoogleDriveService.folderMimeType;

  bool get isShortcut => mimeType == GoogleDriveService.shortcutMimeType;

  bool get isGoogleWorkspaceDocument =>
      mimeType.startsWith('application/vnd.google-apps.') &&
      !isFolder &&
      !isShortcut;

  String get normalizedName {
    final trimmed = name.trim();
    if (trimmed.isNotEmpty) {
      return trimmed;
    }

    if (resolvedExtension.isEmpty) {
      return id;
    }

    return '$id.$resolvedExtension';
  }

  String get resolvedExtension {
    final exportExtension = exportFileExtension;
    if (exportExtension != null) {
      return exportExtension;
    }

    final lowerName = name.toLowerCase();
    final dotIndex = lowerName.lastIndexOf('.');
    if (dotIndex <= 0 || dotIndex == lowerName.length - 1) {
      return '';
    }

    return lowerName.substring(dotIndex + 1);
  }

  String get displayTitle {
    final lowerName = normalizedName.toLowerCase();
    final extension = resolvedExtension;
    if (extension.isEmpty || !lowerName.endsWith('.$extension')) {
      return normalizedName;
    }

    return normalizedName.substring(
      0,
      normalizedName.length - extension.length - 1,
    );
  }

  String? get exportMimeType {
    switch (mimeType) {
      case 'application/vnd.google-apps.document':
        return 'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
      case 'application/vnd.google-apps.spreadsheet':
        return 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';
      case 'application/vnd.google-apps.presentation':
        return 'application/vnd.openxmlformats-officedocument.presentationml.presentation';
      case 'application/vnd.google-apps.drawing':
        return 'application/pdf';
      case 'application/vnd.google-apps.script':
        return 'application/vnd.google-apps.script+json';
      case 'application/vnd.google-apps.form':
        return 'application/zip';
      default:
        return null;
    }
  }

  String? get exportFileExtension {
    switch (mimeType) {
      case 'application/vnd.google-apps.document':
        return 'docx';
      case 'application/vnd.google-apps.spreadsheet':
        return 'xlsx';
      case 'application/vnd.google-apps.presentation':
        return 'pptx';
      case 'application/vnd.google-apps.drawing':
        return 'pdf';
      case 'application/vnd.google-apps.script':
        return 'json';
      case 'application/vnd.google-apps.form':
        return 'zip';
      default:
        return null;
    }
  }

  FileCacheEntry toCacheEntry() {
    final normalizedExtension = resolvedExtension;
    final normalizedFileName = _withExtensionIfNeeded(
      baseName: name.trim().isEmpty ? id : name.trim(),
      extension: normalizedExtension,
    );

    return FileCacheEntry(
      fileId: id,
      name: normalizedFileName,
      extension: normalizedExtension,
      modifiedDate: modifiedTime ?? DateTime.now().toIso8601String(),
      size: size,
      mimeType: exportMimeType ?? mimeType,
    );
  }

  String _withExtensionIfNeeded({
    required String baseName,
    required String extension,
  }) {
    if (extension.isEmpty) {
      return baseName;
    }

    if (baseName.toLowerCase().endsWith('.$extension')) {
      return baseName;
    }

    return '$baseName.$extension';
  }
}

class GoogleDriveService {
  GoogleDriveService({required this.authService});

  static const String folderMimeType = 'application/vnd.google-apps.folder';
  static const String shortcutMimeType = 'application/vnd.google-apps.shortcut';

  final AuthService authService;

  Future<List<GoogleDriveFile>> listFolderChildren(String folderId) async {
    if (folderId.trim().isEmpty) {
      return const [];
    }

    final files = <GoogleDriveFile>[];
    String? pageToken;

    do {
      final response = await _sendAuthorizedRequest((token) {
        final uri = Uri.https('www.googleapis.com', '/drive/v3/files', {
          'q': "'$folderId' in parents and trashed = false",
          'spaces': 'drive',
          'supportsAllDrives': 'true',
          'includeItemsFromAllDrives': 'true',
          'pageSize': '1000',
          'fields':
              'nextPageToken,files(id,name,mimeType,modifiedTime,size,parents,webViewLink,iconLink)',
          if (pageToken?.isNotEmpty == true) 'pageToken': pageToken,
        });

        return http.get(uri, headers: _authorizedHeaders(token));
      });

      _ensureSuccess(
        response,
        fileId: folderId,
        operation: 'отримати список файлів папки',
      );

      final payload = jsonDecode(response.body) as Map<String, dynamic>;
      final items = (payload['files'] as List? ?? const [])
          .whereType<Map>()
          .map(
            (entry) =>
                GoogleDriveFile.fromJson(Map<String, dynamic>.from(entry)),
          )
          .toList(growable: false);

      files.addAll(items);
      pageToken = payload['nextPageToken']?.toString();
    } while (pageToken?.isNotEmpty == true);

    return files;
  }

  Future<GoogleDriveFile> getFile(String fileId) async {
    final response = await _sendAuthorizedRequest((token) {
      final uri = Uri.https('www.googleapis.com', '/drive/v3/files/$fileId', {
        'supportsAllDrives': 'true',
        'fields':
            'id,name,mimeType,modifiedTime,size,parents,webViewLink,iconLink',
      });

      return http.get(uri, headers: _authorizedHeaders(token));
    });

    _ensureSuccess(
      response,
      fileId: fileId,
      operation: 'отримати метадані файлу',
    );

    return GoogleDriveFile.fromJson(
      jsonDecode(response.body) as Map<String, dynamic>,
    );
  }

  Future<FileCacheEntry> getFileCacheEntry(String fileId) async {
    final file = await getFile(fileId);
    return file.toCacheEntry();
  }

  Future<Uint8List> downloadFileBytes(String fileId) async {
    final file = await getFile(fileId);

    if (file.isShortcut) {
      throw FileAccessException(
        'Google Drive shortcut не підтримується для прямого відкриття',
        fileId,
      );
    }

    if (file.isGoogleWorkspaceDocument) {
      final exportMimeType = file.exportMimeType;
      if (exportMimeType == null) {
        throw FileAccessException(
          'Для цього Google Workspace документа не визначено формат експорту',
          fileId,
        );
      }

      final response = await _sendAuthorizedRequest((token) {
        final uri = Uri.https(
          'www.googleapis.com',
          '/drive/v3/files/$fileId/export',
          {'mimeType': exportMimeType},
        );

        return http.get(uri, headers: _authorizedHeaders(token));
      });

      _ensureSuccess(
        response,
        fileId: fileId,
        operation: 'експортувати Google Workspace файл',
      );

      return response.bodyBytes;
    }

    final response = await _sendAuthorizedRequest((token) {
      final uri = Uri.https('www.googleapis.com', '/drive/v3/files/$fileId', {
        'alt': 'media',
        'supportsAllDrives': 'true',
      });

      return http.get(uri, headers: _authorizedHeaders(token));
    });

    _ensureSuccess(response, fileId: fileId, operation: 'завантажити файл');

    return response.bodyBytes;
  }

  Future<GoogleDriveFile> createFolder({
    required String parentFolderId,
    required String name,
  }) async {
    final response = await _sendAuthorizedRequest((token) {
      final uri = Uri.https('www.googleapis.com', '/drive/v3/files', {
        'supportsAllDrives': 'true',
      });

      final payload = jsonEncode({
        'name': name,
        'mimeType': folderMimeType,
        'parents': [parentFolderId],
      });

      return http.post(
        uri,
        headers: _authorizedHeaders(
          token,
          contentType: 'application/json; charset=UTF-8',
        ),
        body: payload,
      );
    }, writeOperation: true);

    _ensureSuccess(
      response,
      fileId: parentFolderId,
      operation: 'створити папку в Google Drive',
    );

    return GoogleDriveFile.fromJson(
      jsonDecode(response.body) as Map<String, dynamic>,
    );
  }

  Future<GoogleDriveFile> uploadFile({
    required String parentFolderId,
    required String fileName,
    required Uint8List bytes,
    required String mimeType,
  }) async {
    final response = await _sendAuthorizedRequest((token) {
      final uri = Uri.https('www.googleapis.com', '/upload/drive/v3/files', {
        'uploadType': 'multipart',
        'supportsAllDrives': 'true',
      });

      return http.post(
        uri,
        headers: _authorizedHeaders(
          token,
          contentType: 'multipart/related; boundary=$_boundary',
        ),
        body: _buildMultipartBody(
          metadata: {
            'name': fileName,
            'parents': [parentFolderId],
          },
          mimeType: mimeType,
          bytes: bytes,
        ),
      );
    }, writeOperation: true);

    _ensureSuccess(
      response,
      fileId: parentFolderId,
      operation: 'завантажити файл у Google Drive',
    );

    return GoogleDriveFile.fromJson(
      jsonDecode(response.body) as Map<String, dynamic>,
    );
  }

  Future<GoogleDriveFile> updateFileContent({
    required String fileId,
    required String fileName,
    required Uint8List bytes,
    required String mimeType,
  }) async {
    final response = await _sendAuthorizedRequest((token) {
      final uri = Uri.https(
        'www.googleapis.com',
        '/upload/drive/v3/files/$fileId',
        {'uploadType': 'multipart', 'supportsAllDrives': 'true'},
      );

      return http.patch(
        uri,
        headers: _authorizedHeaders(
          token,
          contentType: 'multipart/related; boundary=$_boundary',
        ),
        body: _buildMultipartBody(
          metadata: {'name': fileName},
          mimeType: mimeType,
          bytes: bytes,
        ),
      );
    }, writeOperation: true);

    _ensureSuccess(
      response,
      fileId: fileId,
      operation: 'оновити файл у Google Drive',
    );

    return GoogleDriveFile.fromJson(
      jsonDecode(response.body) as Map<String, dynamic>,
    );
  }

  Future<GoogleDriveFile> updateFileMetadata({
    required String fileId,
    String? name,
  }) async {
    final payload = <String, dynamic>{};
    if (name != null && name.trim().isNotEmpty) {
      payload['name'] = name.trim();
    }

    if (payload.isEmpty) {
      return getFile(fileId);
    }

    final response = await _sendAuthorizedRequest((token) {
      final uri = Uri.https('www.googleapis.com', '/drive/v3/files/$fileId', {
        'supportsAllDrives': 'true',
      });

      return http.patch(
        uri,
        headers: _authorizedHeaders(
          token,
          contentType: 'application/json; charset=UTF-8',
        ),
        body: jsonEncode(payload),
      );
    }, writeOperation: true);

    _ensureSuccess(
      response,
      fileId: fileId,
      operation: 'оновити метадані файлу в Google Drive',
    );

    return GoogleDriveFile.fromJson(
      jsonDecode(response.body) as Map<String, dynamic>,
    );
  }

  Future<void> deleteItem(String fileId) async {
    final response = await _sendAuthorizedRequest((token) {
      final uri = Uri.https('www.googleapis.com', '/drive/v3/files/$fileId', {
        'supportsAllDrives': 'true',
      });

      return http.delete(uri, headers: _authorizedHeaders(token));
    }, writeOperation: true);

    _ensureSuccess(
      response,
      fileId: fileId,
      operation: 'видалити файл з Google Drive',
      allowNoContent: true,
    );
  }

  String buildLegacyViewUrl(String fileId) =>
      'https://drive.google.com/file/d/$fileId/view';

  Map<String, String> _authorizedHeaders(String token, {String? contentType}) {
    final headers = <String, String>{'Authorization': 'Bearer $token'};

    if (contentType != null) {
      headers['Content-Type'] = contentType;
    }

    return headers;
  }

  Future<http.Response> _sendAuthorizedRequest(
    Future<http.Response> Function(String token) requestBuilder, {
    bool writeOperation = false,
  }) async {
    String? token = writeOperation
        ? await authService.getDriveWriteAccessToken()
        : await authService.getAccessToken();
    if (token == null) {
      throw MetadataException(
        'Не вдалося відновити Google Drive сесію. Спробуйте відкрити файл ще раз або повторно увійти в застосунок.',
      );
    }

    var response = await requestBuilder(token);
    if (response.statusCode == 401) {
      token = writeOperation
          ? await authService.forceRefreshDriveWriteAccessToken()
          : await authService.forceRefreshToken();
      if (token == null) {
        throw MetadataException(
          'Не вдалося оновити Google Drive сесію після повторної спроби. Потрібно повторно увійти в застосунок.',
        );
      }

      response = await requestBuilder(token);
    }

    return response;
  }

  void _ensureSuccess(
    http.Response response, {
    required String fileId,
    required String operation,
    bool allowNoContent = false,
  }) {
    final success =
        response.statusCode >= 200 &&
        response.statusCode < 300 &&
        (allowNoContent || response.statusCode != 204 || response.body.isEmpty);
    if (success) {
      return;
    }

    final message = _buildDriveErrorMessage(response, operation);
    throw WebDownloadException(message, fileId);
  }

  String _buildDriveErrorMessage(http.Response response, String operation) {
    switch (response.statusCode) {
      case 401:
        return 'Google Drive відхилив сесію під час спроби $operation. Спробуйте повторно увійти в застосунок.';
      case 403:
        return 'Google Drive заборонив $operation. Перевірте, чи файл або папка розшарені на цей акаунт.';
      case 404:
        return 'Файл або папку не знайдено в Google Drive. Можливо, елемент було видалено або доступ відкликано.';
      default:
        return 'Google Drive API не зміг $operation: ${response.statusCode} ${response.body}';
    }
  }

  Uint8List _buildMultipartBody({
    required Map<String, dynamic> metadata,
    required String mimeType,
    required Uint8List bytes,
  }) {
    final metadataHeader =
        '--$_boundary\r\n'
        'Content-Type: application/json; charset=UTF-8\r\n\r\n'
        '${jsonEncode(metadata)}\r\n';
    final mediaHeader =
        '--$_boundary\r\n'
        'Content-Type: $mimeType\r\n\r\n';
    final closingBoundary = '\r\n--$_boundary--';

    final builder = BytesBuilder(copy: false)
      ..add(utf8.encode(metadataHeader))
      ..add(utf8.encode(mediaHeader))
      ..add(bytes)
      ..add(utf8.encode(closingBoundary));

    return builder.toBytes();
  }
}

const String _boundary = 'itacs_drive_boundary';
