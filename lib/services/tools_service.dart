import 'package:flutter/foundation.dart';

import '../globals.dart';

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
    bool forceRefresh = false,
  }) async {
    try {
      final items = await _getOverlayItems(
        groupId: groupId,
        parentId: parentId,
      );
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
          if ((data['type'] ?? '').toString() != 'embedded') {
            return null;
          }

          return {
            ...data,
            'id': doc.id,
            'overlayId': doc.id,
            'type': 'embedded',
            'isOverlayBacked': true,
          };
        })
        .whereType<Map<String, dynamic>>()
        .toList(growable: false);
  }
}
