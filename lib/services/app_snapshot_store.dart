import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';

class SessionSnapshot {
  const SessionSnapshot({
    required this.wasSignedIn,
    required this.accessGranted,
    required this.userScopeId,
    required this.userEmail,
    required this.userUid,
    required this.groupNames,
    this.lastSuccessfulSyncAt,
  });

  final bool wasSignedIn;
  final bool accessGranted;
  final String userScopeId;
  final String userEmail;
  final String userUid;
  final Map<String, String> groupNames;
  final DateTime? lastSuccessfulSyncAt;

  bool get canOpenOfflineShell =>
      wasSignedIn && accessGranted && groupNames.isNotEmpty;

  Map<String, dynamic> toMap() {
    return {
      'wasSignedIn': wasSignedIn,
      'accessGranted': accessGranted,
      'userScopeId': userScopeId,
      'userEmail': userEmail,
      'userUid': userUid,
      'groupNames': groupNames,
      'lastSuccessfulSyncAt': lastSuccessfulSyncAt?.toIso8601String(),
    };
  }

  factory SessionSnapshot.fromMap(Map<String, dynamic> map) {
    return SessionSnapshot(
      wasSignedIn: map['wasSignedIn'] == true,
      accessGranted: map['accessGranted'] == true,
      userScopeId: (map['userScopeId'] ?? '').toString(),
      userEmail: (map['userEmail'] ?? '').toString(),
      userUid: (map['userUid'] ?? '').toString(),
      groupNames: Map<String, String>.from(map['groupNames'] ?? const {}),
      lastSuccessfulSyncAt: _parseDateTime(map['lastSuccessfulSyncAt']),
    );
  }

  static DateTime? _parseDateTime(dynamic value) {
    if (value is DateTime) return value;
    if (value is String && value.trim().isNotEmpty) {
      return DateTime.tryParse(value);
    }
    return null;
  }
}

class CachedSnapshot {
  const CachedSnapshot({required this.data, required this.cachedAt});

  final dynamic data;
  final DateTime cachedAt;

  factory CachedSnapshot.fromMap(Map<String, dynamic> map) {
    return CachedSnapshot(
      data: map['data'],
      cachedAt:
          SessionSnapshot._parseDateTime(map['cachedAt']) ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {'data': data, 'cachedAt': cachedAt.toIso8601String()};
  }
}

class AppSnapshotStore {
  static const String _boxName = 'app_snapshots';
  static const String _sessionKey = 'session_snapshot';
  static const String _profileKey = 'profile_data';
  static const String _currentGroupKey = 'current_group_data';

  Box<dynamic>? _box;

  bool get isInitialized => _box != null;

  Future<void> initialize() async {
    if (_box != null) {
      return;
    }

    _box = Hive.isBoxOpen(_boxName)
        ? Hive.box<dynamic>(_boxName)
        : await Hive.openBox<dynamic>(_boxName);
  }

  SessionSnapshot? getSessionSnapshot() {
    final raw = _box?.get(_sessionKey);
    if (raw is Map) {
      return SessionSnapshot.fromMap(Map<String, dynamic>.from(raw));
    }
    return null;
  }

  Future<void> saveSessionSnapshot(SessionSnapshot snapshot) async {
    await initialize();
    await _box!.put(_sessionKey, snapshot.toMap());
  }

  Future<void> clearSessionSnapshot() async {
    await initialize();
    await _box!.delete(_sessionKey);
  }

  Map<String, dynamic>? getProfileMap() {
    final raw = _box?.get(_profileKey);
    if (raw is Map) {
      return _restoreDynamicMap(Map<String, dynamic>.from(raw));
    }
    return null;
  }

  Future<void> saveProfileMap(Map<String, dynamic> profile) async {
    await initialize();
    await _box!.put(_profileKey, _normalizeForStorage(profile));
  }

  Future<void> clearProfileMap() async {
    await initialize();
    await _box!.delete(_profileKey);
  }

  Map<String, dynamic>? getCurrentGroupMap() {
    final raw = _box?.get(_currentGroupKey);
    if (raw is Map) {
      return _restoreDynamicMap(Map<String, dynamic>.from(raw));
    }
    return null;
  }

  Future<void> saveCurrentGroupMap(Map<String, dynamic> currentGroup) async {
    await initialize();
    await _box!.put(_currentGroupKey, _normalizeForStorage(currentGroup));
  }

  Future<void> clearCurrentGroupMap() async {
    await initialize();
    await _box!.delete(_currentGroupKey);
  }

  CachedSnapshot? getCachedSnapshot(String key) {
    final raw = _box?.get(key);
    if (raw is! Map) {
      return null;
    }

    final restored = _restoreDynamicMap(Map<String, dynamic>.from(raw));
    return CachedSnapshot.fromMap(restored);
  }

  Future<void> saveCachedSnapshot(
    String key,
    dynamic data, {
    DateTime? cachedAt,
  }) async {
    await initialize();
    final snapshot = CachedSnapshot(
      data: _normalizeForStorage(data),
      cachedAt: cachedAt ?? DateTime.now(),
    );
    await _box!.put(key, snapshot.toMap());
  }

  Iterable<String> keysWithPrefix(String prefix) {
    final box = _box;
    if (box == null) {
      return const <String>[];
    }

    return box.keys
        .whereType<String>()
        .where((key) => key.startsWith(prefix))
        .toList(growable: false);
  }

  Future<void> clearByPrefix(String prefix) async {
    await initialize();
    final keys = keysWithPrefix(prefix).toList(growable: false);
    if (keys.isEmpty) {
      return;
    }
    await _box!.deleteAll(keys);
  }

  Future<void> clearAllSnapshots() async {
    await initialize();
    await _box!.clear();
  }

  static dynamic _normalizeForStorage(dynamic value) {
    if (value is Timestamp) {
      return {'__type': 'timestamp', 'value': value.toDate().toIso8601String()};
    }
    if (value is DateTime) {
      return {'__type': 'datetime', 'value': value.toIso8601String()};
    }
    if (value is Map) {
      return value.map(
        (key, entryValue) =>
            MapEntry(key.toString(), _normalizeForStorage(entryValue)),
      );
    }
    if (value is Iterable) {
      return value.map(_normalizeForStorage).toList(growable: false);
    }
    return value;
  }

  static Map<String, dynamic> _restoreDynamicMap(Map<String, dynamic> map) {
    return map.map((key, value) => MapEntry(key, _restoreFromStorage(value)));
  }

  static dynamic _restoreFromStorage(dynamic value) {
    if (value is Map) {
      final typedMap = Map<String, dynamic>.from(value);
      final type = typedMap['__type'];
      if (type == 'timestamp') {
        final parsed = SessionSnapshot._parseDateTime(typedMap['value']);
        return parsed != null ? Timestamp.fromDate(parsed) : null;
      }
      if (type == 'datetime') {
        return SessionSnapshot._parseDateTime(typedMap['value']);
      }
      return _restoreDynamicMap(typedMap);
    }
    if (value is List) {
      return value.map(_restoreFromStorage).toList(growable: false);
    }
    return value;
  }
}
