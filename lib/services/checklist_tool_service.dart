import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/checklist_tool/checklist_tool_models.dart';

class ChecklistToolService {
  FirebaseFirestore get _firestore => FirebaseFirestore.instance;

  static const String _configsKey = 'checklist_tool_configs';
  static const String _globalFieldsKey = 'checklist_global_fields';
  static const String _toolsCollection = 'tools_by_group';
  static const String _sharedConfigsParentId = '__checklist_builder__';
  static const String _sharedConfigType = 'checklist_builder_config';

  CollectionReference<Map<String, dynamic>> _configsRef(String groupId) {
    return _firestore
        .collection(_toolsCollection)
        .doc(groupId)
        .collection('items');
  }

  Stream<List<ChecklistToolConfig>> watchAllConfigs(String groupId) {
    return _configsRef(groupId)
        .where('parentId', isEqualTo: _sharedConfigsParentId)
        .snapshots()
        .map((snapshot) {
          final configs = snapshot.docs
              .map((doc) => _configFromStoredMap(doc.data()))
              .whereType<ChecklistToolConfig>()
              .where((config) => config.id.trim().isNotEmpty)
              .toList(growable: true);
          configs.sort(
            (a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()),
          );
          return configs;
        });
  }

  Future<List<ChecklistToolConfig>> loadAllConfigs(String groupId) async {
    await migrateLegacyConfigsToGroupIfNeeded(groupId);
    final snapshot = await _configsRef(
      groupId,
    ).where('parentId', isEqualTo: _sharedConfigsParentId).get();
    final configs = snapshot.docs
        .map((doc) => _configFromStoredMap(doc.data()))
        .whereType<ChecklistToolConfig>()
        .where((config) => config.id.trim().isNotEmpty)
        .toList(growable: true);
    configs.sort(
      (a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()),
    );
    return configs;
  }

  Future<ChecklistToolConfig?> loadConfigById(
    String groupId,
    String configId,
  ) async {
    await migrateLegacyConfigsToGroupIfNeeded(groupId);
    final doc = await _configsRef(
      groupId,
    ).doc(_sharedConfigDocId(configId)).get();
    final data = doc.data();
    if (!doc.exists || data == null) {
      return null;
    }
    return _configFromStoredMap(data);
  }

  Future<void> saveConfig(String groupId, ChecklistToolConfig config) async {
    await _configsRef(groupId).doc(_sharedConfigDocId(config.id)).set({
      ...config.toJson(),
      'type': _sharedConfigType,
      'parentId': _sharedConfigsParentId,
      'toolKey': 'checklist_builder',
      'modifiedAt': DateTime.now().toIso8601String(),
    });
  }

  Future<void> deleteConfig(String groupId, String id) async {
    final prefs = await SharedPreferences.getInstance();
    await _configsRef(groupId).doc(_sharedConfigDocId(id)).delete();
    await prefs.remove(_sessionKey(id));
  }

  Future<void> migrateLegacyConfigsToGroupIfNeeded(String groupId) async {
    final remoteSnapshot = await _configsRef(
      groupId,
    ).where('parentId', isEqualTo: _sharedConfigsParentId).limit(1).get();
    if (remoteSnapshot.docs.isNotEmpty) {
      return;
    }

    final legacyConfigs = await _loadLegacyConfigsFromPrefs();
    if (legacyConfigs.isEmpty) {
      return;
    }

    final batch = _firestore.batch();
    for (final config in legacyConfigs) {
      batch.set(_configsRef(groupId).doc(_sharedConfigDocId(config.id)), {
        ...config.toJson(),
        'type': _sharedConfigType,
        'parentId': _sharedConfigsParentId,
        'toolKey': 'checklist_builder',
        'modifiedAt': DateTime.now().toIso8601String(),
      });
    }
    await batch.commit();
  }

  Future<List<ChecklistToolConfig>> _loadLegacyConfigsFromPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_configsKey);
    if (raw == null || raw.trim().isEmpty) {
      return const [];
    }

    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) {
        return const [];
      }

      return decoded
          .whereType<Map>()
          .map(
            (item) =>
                ChecklistToolConfig.fromJson(Map<String, dynamic>.from(item)),
          )
          .toList(growable: false);
    } catch (_) {
      return const [];
    }
  }

  Future<ChecklistSessionState> loadSessionState(String configId) async {
    final prefs = await SharedPreferences.getInstance();
    final key = _sessionKey(configId);
    final todaySessionKey = buildSessionKey(configId);
    final raw = prefs.getString(key);

    if (raw == null || raw.trim().isEmpty) {
      return ChecklistSessionState(
        configId: configId,
        sessionKey: todaySessionKey,
      );
    }

    try {
      final decoded = jsonDecode(raw);
      final state = ChecklistSessionState.fromJson(
        Map<String, dynamic>.from(decoded as Map),
      );
      if (state.sessionKey != todaySessionKey) {
        final resetState = ChecklistSessionState(
          configId: configId,
          sessionKey: todaySessionKey,
        );
        await saveSessionState(resetState);
        return resetState;
      }
      return state;
    } catch (_) {
      final resetState = ChecklistSessionState(
        configId: configId,
        sessionKey: todaySessionKey,
      );
      await saveSessionState(resetState);
      return resetState;
    }
  }

  Future<void> saveSessionState(ChecklistSessionState state) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _sessionKey(state.configId),
      jsonEncode(state.toJson()),
    );
  }

  Future<void> resetSession(String configId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_sessionKey(configId));
  }

  Future<Map<String, String>> loadGlobalFieldValues() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_globalFieldsKey);
    if (raw == null || raw.trim().isEmpty) {
      return const {};
    }

    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) {
        return const {};
      }

      return Map<String, dynamic>.from(
        decoded,
      ).map((key, value) => MapEntry(key, value?.toString() ?? ''));
    } catch (_) {
      return const {};
    }
  }

  Future<void> saveGlobalFieldValue(String fieldId, String value) async {
    final prefs = await SharedPreferences.getInstance();
    final values = Map<String, String>.from(await loadGlobalFieldValues());
    if (value.trim().isEmpty) {
      values.remove(fieldId);
    } else {
      values[fieldId] = value;
    }
    await prefs.setString(_globalFieldsKey, jsonEncode(values));
  }

  String buildSessionKey(String configId, [DateTime? date]) {
    final normalizedDate = date ?? DateTime.now();
    return '${configId}_${DateFormat('yyyy-MM-dd').format(normalizedDate)}';
  }

  ChecklistToolConfig? _configFromStoredMap(Map<String, dynamic> data) {
    if ((data['type']?.toString() ?? '') != _sharedConfigType) {
      return null;
    }
    return ChecklistToolConfig.fromJson(data);
  }

  String _sharedConfigDocId(String configId) => 'checklist_cfg__$configId';

  String _sessionKey(String configId) => 'checklist_session_$configId';
}
