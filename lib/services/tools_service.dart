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
      final docs = await Globals.firestoreManager.getDocumentsForGroup(
        groupId: groupId,
        collection: 'tools_by_group',
        whereEqual: {'parentId': parentId},
        orderBy: 'modifiedAt',
      );

      final items = docs
          .map(
            (doc) => {
              ...Map<String, dynamic>.from(doc.data() as Map<String, dynamic>),
              'id': doc.id,
            },
          )
          .toList(growable: false);

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
}
