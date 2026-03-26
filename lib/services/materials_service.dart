import 'package:flutter/foundation.dart';

import '../globals.dart';

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
      final docs = await Globals.firestoreManager.getDocumentsForGroup(
        groupId: groupId,
        collection: 'materials',
      );
      final materials = docs
          .map((doc) {
            final data = Map<String, dynamic>.from(
              doc.data() as Map<String, dynamic>,
            );
            data['id'] = doc.id;
            return data;
          })
          .toList(growable: false);

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
}
