import 'dart:convert';

import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/checklist_tool/checklist_tool_models.dart';

class ChecklistToolService {
  static const String _configsKey = 'checklist_tool_configs';
  static const String _globalFieldsKey = 'checklist_global_fields';

  Future<List<ChecklistToolConfig>> loadAllConfigs() async {
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

  Future<void> saveConfig(ChecklistToolConfig config) async {
    final configs = (await loadAllConfigs()).toList(growable: true);
    final index = configs.indexWhere((item) => item.id == config.id);
    if (index >= 0) {
      configs[index] = config;
    } else {
      configs.add(config);
    }
    await _saveAllConfigs(configs);
  }

  Future<void> deleteConfig(String id) async {
    final prefs = await SharedPreferences.getInstance();
    final configs = (await loadAllConfigs())
        .where((item) => item.id != id)
        .toList(growable: false);
    await _saveAllConfigs(configs);
    await prefs.remove(_sessionKey(id));
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

  Future<void> _saveAllConfigs(List<ChecklistToolConfig> configs) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _configsKey,
      jsonEncode(configs.map((item) => item.toJson()).toList()),
    );
  }

  String _sessionKey(String configId) => 'checklist_session_$configId';
}
