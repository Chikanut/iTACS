import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../globals.dart';
import 'google_drive_service.dart';

class ToolsService {
  List<Map<String, dynamic>> getCachedItems({
    required String groupId,
    required String parentId,
  }) {
    final snapshot = Globals.appSnapshotStore.getCachedSnapshot(
      _toolsCacheKey(groupId, parentId),
    );
    final data = snapshot?.data;
    if (data is! List) {
      return const [];
    }

    return data
        .map((item) => Map<String, dynamic>.from(item as Map))
        .toList(growable: false);
  }

  Future<List<Map<String, dynamic>>> getItems({
    required String groupId,
    required String parentId,
    String? driveFolderId,
    bool forceRefresh = false,
  }) async {
    try {
      final overlayItems = await _getOverlayItems(
        groupId: groupId,
        parentId: parentId,
      );

      List<Map<String, dynamic>> items;
      try {
        final currentDriveFolderId = await _resolveCurrentDriveFolderId(
          groupId: groupId,
          parentId: parentId,
          explicitDriveFolderId: driveFolderId,
        );
        items = currentDriveFolderId == null
            ? overlayItems
            : _mergeDriveFolderWithOverlay(
                driveFiles: await Globals.googleDriveService.listFolderChildren(
                  currentDriveFolderId,
                ),
                overlayItems: overlayItems,
                parentId: parentId,
              );
      } catch (driveError) {
        // Drive недоступний, але Firestore відпрацював —
        // показуємо overlay-only items (embedded, external_link тощо).
        debugPrint(
          'ToolsService: Drive unavailable, overlay-only: $driveError',
        );
        items = overlayItems;
      }

      await Globals.appSnapshotStore.saveCachedSnapshot(
        _toolsCacheKey(groupId, parentId),
        items,
      );
      return items;
    } catch (e) {
      debugPrint('ToolsService: fallback to cache due to $e');
      final cached = getCachedItems(groupId: groupId, parentId: parentId);
      if (cached.isNotEmpty || !forceRefresh) {
        return cached;
      }
      rethrow;
    }
  }

  String _toolsCacheKey(String groupId, String parentId) =>
      'cache::tools::$groupId::$parentId';

  Future<String?> getToolsRootFolderId(String groupId) async {
    final config = await Globals.driveCatalogService.getConfig(groupId);
    return config?.toolsRootFolderId;
  }

  Future<List<Map<String, dynamic>>> _getOverlayItems({
    required String groupId,
    required String parentId,
  }) async {
    final docs = await Globals.firestoreManager.getDocumentsForGroup(
      groupId: groupId,
      collection: 'tools_by_group',
      whereEqual: {'parentId': parentId},
      orderBy: 'modifiedAt',
    );

    return docs
        .map((doc) {
          final data = Map<String, dynamic>.from(
            doc.data() as Map<String, dynamic>,
          );
          final normalizedType = (data['type'] ?? 'tool').toString();
          final legacyUrl = (data['url'] ?? '').toString();
          final fileId = (data['fileId'] as String?)?.trim().isNotEmpty == true
              ? (data['fileId'] as String).trim()
              : Globals.fileManager.extractFileId(legacyUrl);

          return {
            ...data,
            'id': doc.id,
            'overlayId': doc.id,
            'type': normalizedType,
            'fileId': fileId,
            'url': normalizedType == 'external_link'
                ? legacyUrl
                : (fileId == null
                      ? legacyUrl
                      : (data['url'] ??
                            Globals.googleDriveService.buildLegacyViewUrl(
                              fileId,
                            ))),
            'isOverlayBacked': true,
          };
        })
        .toList(growable: false);
  }

  Future<String?> _resolveCurrentDriveFolderId({
    required String groupId,
    required String parentId,
    String? explicitDriveFolderId,
  }) async {
    final normalizedExplicit = explicitDriveFolderId?.trim();
    if (normalizedExplicit != null && normalizedExplicit.isNotEmpty) {
      return normalizedExplicit;
    }

    if (parentId == 'root') {
      return getToolsRootFolderId(groupId);
    }

    if (parentId.startsWith(_syntheticDriveParentPrefix)) {
      return parentId.substring(_syntheticDriveParentPrefix.length);
    }

    final snapshot = await FirebaseFirestore.instance
        .collection('tools_by_group')
        .doc(groupId)
        .collection('items')
        .doc(parentId)
        .get();

    if (!snapshot.exists) {
      return null;
    }

    final data = snapshot.data() ?? const {};
    final driveFolderId = data['driveFolderId']?.toString().trim();
    if (driveFolderId == null || driveFolderId.isEmpty) {
      return null;
    }

    return driveFolderId;
  }

  List<Map<String, dynamic>> _mergeDriveFolderWithOverlay({
    required List<GoogleDriveFile> driveFiles,
    required List<Map<String, dynamic>> overlayItems,
    required String parentId,
  }) {
    final folderOverlayByDriveId = <String, Map<String, dynamic>>{};
    final fileOverlayByDriveId = <String, Map<String, dynamic>>{};
    final externalLinks = <Map<String, dynamic>>[];
    final embeddedItems = <Map<String, dynamic>>[];

    for (final item in overlayItems) {
      final type = (item['type'] ?? 'tool').toString();
      if (type == 'external_link') {
        externalLinks.add(item);
        continue;
      }

      if (type == 'embedded') {
        embeddedItems.add(item);
        continue;
      }

      if (type == 'folder') {
        final driveFolderId = item['driveFolderId']?.toString().trim();
        if (driveFolderId != null && driveFolderId.isNotEmpty) {
          folderOverlayByDriveId[driveFolderId] = item;
        }
        continue;
      }

      final fileId = item['fileId']?.toString().trim();
      if (fileId != null && fileId.isNotEmpty) {
        fileOverlayByDriveId[fileId] = item;
      }
    }

    final mergedItems = <Map<String, dynamic>>[];

    for (final driveFile in driveFiles) {
      if (driveFile.isShortcut) {
        continue;
      }

      if (driveFile.isFolder) {
        final overlay = folderOverlayByDriveId[driveFile.id];
        mergedItems.add({
          ...?overlay,
          'id': overlay?['id'] ?? 'drive_folder::${driveFile.id}',
          'overlayId': overlay?['overlayId'],
          'type': 'folder',
          'title': overlay?['title'] ?? driveFile.displayTitle,
          'description': overlay?['description'],
          'driveFolderId': driveFile.id,
          'parentId': parentId,
          'modifiedAt':
              driveFile.modifiedTime ??
              overlay?['modifiedAt'] ??
              DateTime.now().toIso8601String(),
          'isOverlayBacked': overlay != null,
          'isSynthetic': overlay == null,
        });
        continue;
      }

      final overlay = fileOverlayByDriveId[driveFile.id];
      mergedItems.add({
        ...?overlay,
        'id': overlay?['id'] ?? 'drive_tool::${driveFile.id}',
        'overlayId': overlay?['overlayId'],
        'type': 'tool',
        'title': overlay?['title'] ?? driveFile.displayTitle,
        'description': overlay?['description'],
        'fileId': driveFile.id,
        'url':
            overlay?['url'] ??
            Globals.googleDriveService.buildLegacyViewUrl(driveFile.id),
        'parentId': parentId,
        'modifiedAt':
            driveFile.modifiedTime ??
            overlay?['modifiedAt'] ??
            DateTime.now().toIso8601String(),
        'mimeType': driveFile.exportMimeType ?? driveFile.mimeType,
        'size': driveFile.size,
        'isOverlayBacked': overlay != null,
        'isSynthetic': overlay == null,
      });
    }

    mergedItems.addAll(
      externalLinks.map(
        (item) => {
          ...item,
          'type': 'external_link',
          'isSynthetic': false,
          'isOverlayBacked': true,
        },
      ),
    );

    mergedItems.addAll(
      embeddedItems.map(
        (item) => {
          ...item,
          'type': 'embedded',
          'isSynthetic': false,
          'isOverlayBacked': true,
        },
      ),
    );

    mergedItems.sort((left, right) {
      final leftTypeRank = _typeSortRank((left['type'] ?? 'tool').toString());
      final rightTypeRank = _typeSortRank((right['type'] ?? 'tool').toString());
      if (leftTypeRank != rightTypeRank) {
        return leftTypeRank.compareTo(rightTypeRank);
      }

      final leftTitle = (left['title'] ?? '').toString().toLowerCase();
      final rightTitle = (right['title'] ?? '').toString().toLowerCase();
      return leftTitle.compareTo(rightTitle);
    });

    return mergedItems;
  }

  int _typeSortRank(String type) {
    switch (type) {
      case 'folder':
        return 0;
      case 'tool':
        return 1;
      case 'external_link':
        return 2;
      case 'embedded':
        return 3;
      default:
        return 4;
    }
  }
}

const String _syntheticDriveParentPrefix = '__drive__:';
