import 'package:flutter/foundation.dart';

import '../globals.dart';
import 'google_drive_service.dart';

class MaterialsService {
  List<Map<String, dynamic>> getCachedMaterials({required String groupId}) {
    final snapshot = Globals.appSnapshotStore.getCachedSnapshot(
      _materialsCacheKey(groupId),
    );
    final data = snapshot?.data;
    if (data is! List) {
      return const [];
    }

    return data
        .map((item) => Map<String, dynamic>.from(item as Map))
        .toList(growable: false);
  }

  Future<List<Map<String, dynamic>>> getMaterials({
    required String groupId,
    bool forceRefresh = false,
  }) async {
    try {
      final overlayMaterials = await _getOverlayMaterials(groupId: groupId);
      final config = await Globals.driveCatalogService.getConfig(groupId);

      final materials = config?.hasMaterialsFolder == true
          ? _mergeDriveFilesWithOverlay(
              driveFiles: await Globals.googleDriveService.listFolderChildren(
                config!.materialsFolderId!,
              ),
              overlayMaterials: overlayMaterials,
            )
          : overlayMaterials;

      await Globals.appSnapshotStore.saveCachedSnapshot(
        _materialsCacheKey(groupId),
        materials,
      );
      return materials;
    } catch (e) {
      debugPrint('MaterialsService: fallback to cache due to $e');
      final cached = getCachedMaterials(groupId: groupId);
      if (cached.isNotEmpty || !forceRefresh) {
        return cached;
      }
      rethrow;
    }
  }

  String _materialsCacheKey(String groupId) => 'cache::materials::$groupId';

  Future<List<Map<String, dynamic>>> _getOverlayMaterials({
    required String groupId,
  }) async {
    final docs = await Globals.firestoreManager.getDocumentsForGroup(
      groupId: groupId,
      collection: 'materials',
    );

    return docs
        .map((doc) {
          final data = Map<String, dynamic>.from(
            doc.data() as Map<String, dynamic>,
          );
          final fileId = (data['fileId'] as String?)?.trim().isNotEmpty == true
              ? (data['fileId'] as String).trim()
              : Globals.fileManager.extractFileId(
                  (data['url'] ?? '').toString(),
                );

          return {
            ...data,
            'id': doc.id,
            'overlayId': doc.id,
            'fileId': fileId,
            'url': fileId == null
                ? data['url']
                : (data['url'] ??
                      Globals.googleDriveService.buildLegacyViewUrl(fileId)),
            'tags': List<String>.from(data['tags'] as List? ?? const []),
            'isOverlayBacked': true,
          };
        })
        .toList(growable: false);
  }

  List<Map<String, dynamic>> _mergeDriveFilesWithOverlay({
    required List<GoogleDriveFile> driveFiles,
    required List<Map<String, dynamic>> overlayMaterials,
  }) {
    final overlayByFileId = <String, Map<String, dynamic>>{};
    for (final material in overlayMaterials) {
      final fileId = material['fileId']?.toString().trim();
      if (fileId == null || fileId.isEmpty) {
        continue;
      }
      overlayByFileId[fileId] = material;
    }

    final materials = driveFiles
        .where((file) => !file.isFolder && !file.isShortcut)
        .map((file) {
          final overlay = overlayByFileId[file.id];

          return {
            ...?overlay,
            'id': overlay?['id'] ?? 'drive_material::${file.id}',
            'overlayId': overlay?['overlayId'],
            'fileId': file.id,
            'url':
                overlay?['url'] ??
                Globals.googleDriveService.buildLegacyViewUrl(file.id),
            'title': overlay?['title'] ?? file.displayTitle,
            'tags': List<String>.from(overlay?['tags'] as List? ?? const []),
            'modifiedAt':
                file.modifiedTime ??
                overlay?['modifiedAt'] ??
                DateTime.now().toIso8601String(),
            'driveName': file.normalizedName,
            'mimeType': file.exportMimeType ?? file.mimeType,
            'size': file.size,
            'isOverlayBacked': overlay != null,
          };
        })
        .toList(growable: false);

    materials.sort((left, right) {
      final leftDate = DateTime.tryParse((left['modifiedAt'] ?? '').toString());
      final rightDate = DateTime.tryParse(
        (right['modifiedAt'] ?? '').toString(),
      );
      if (leftDate != null && rightDate != null) {
        return rightDate.compareTo(leftDate);
      }

      final leftTitle = (left['title'] ?? '').toString().toLowerCase();
      final rightTitle = (right['title'] ?? '').toString().toLowerCase();
      return leftTitle.compareTo(rightTitle);
    });

    return materials;
  }
}
