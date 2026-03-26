import 'package:cloud_firestore/cloud_firestore.dart';

class DriveCatalogConfig {
  const DriveCatalogConfig({this.materialsFolderId, this.toolsRootFolderId});

  factory DriveCatalogConfig.fromMap(Map<String, dynamic> map) {
    String? normalizeId(dynamic value) {
      final normalized = value?.toString().trim();
      return normalized == null || normalized.isEmpty ? null : normalized;
    }

    return DriveCatalogConfig(
      materialsFolderId: normalizeId(map['materialsFolderId']),
      toolsRootFolderId: normalizeId(map['toolsRootFolderId']),
    );
  }

  final String? materialsFolderId;
  final String? toolsRootFolderId;

  bool get hasMaterialsFolder =>
      materialsFolderId != null && materialsFolderId!.isNotEmpty;

  bool get hasToolsRootFolder =>
      toolsRootFolderId != null && toolsRootFolderId!.isNotEmpty;
}

class DriveCatalogService {
  FirebaseFirestore get _firestore => FirebaseFirestore.instance;

  Future<DriveCatalogConfig?> getConfig(String groupId) async {
    final normalizedGroupId = groupId.trim();
    if (normalizedGroupId.isEmpty) {
      return null;
    }

    final snapshot = await _firestore
        .collection('drive_catalog_by_group')
        .doc(normalizedGroupId)
        .get();

    if (!snapshot.exists) {
      return null;
    }

    return DriveCatalogConfig.fromMap(snapshot.data() ?? const {});
  }
}
