// report_templates_service.dart

import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:firebase_core/firebase_core.dart';

import '../globals.dart';
import '../models/report_template_model.dart';

class ReportTemplatesService {
  static const String _functionsRegion = 'us-central1';
  static final ReportTemplatesService _instance =
      ReportTemplatesService._internal();

  factory ReportTemplatesService() => _instance;

  ReportTemplatesService._internal();

  FirebaseFirestore get _firestore => FirebaseFirestore.instance;
  FirebaseFunctions get _functions => FirebaseFunctions.instance;

  String? get _currentGroupId => Globals.profileManager.currentGroupId;

  CollectionReference<Map<String, dynamic>> _templatesCollection(
    String groupId,
  ) {
    return _firestore
        .collection('groups')
        .doc(groupId)
        .collection('report_templates');
  }

  Future<void> ensureSeedTemplatesForCurrentGroup() async {
    final groupId = _currentGroupId;
    final currentUser = Globals.firebaseAuth.currentUser;
    final currentRole = Globals.profileManager.currentRole;

    if (groupId == null || currentUser == null || currentRole != 'admin') {
      return;
    }

    final existing = await _templatesCollection(groupId).limit(1).get();
    if (existing.docs.isNotEmpty) {
      return;
    }

    final seedTemplate = buildSeedLessonsListReportTemplate(
      groupId: groupId,
      userId: currentUser.uid,
      now: DateTime.now(),
    );
    await _templatesCollection(groupId).add(seedTemplate.toFirestore());
  }

  Future<List<ReportTemplate>> getTemplates({bool seedIfEmpty = true}) async {
    final groupId = _currentGroupId;
    if (groupId == null) return [];

    if (seedIfEmpty) {
      await ensureSeedTemplatesForCurrentGroup();
    }

    final snapshot = await _templatesCollection(
      groupId,
    ).orderBy('updatedAt', descending: true).get();

    return snapshot.docs.map(ReportTemplate.fromFirestore).toList();
  }

  Future<ReportTemplate?> getTemplateById(String templateId) async {
    final groupId = _currentGroupId;
    if (groupId == null || templateId.trim().isEmpty) return null;

    final doc = await _templatesCollection(groupId).doc(templateId).get();
    if (!doc.exists) return null;
    return ReportTemplate.fromFirestore(doc);
  }

  Future<List<ReportTemplate>> getAccessibleActiveTemplates() async {
    final templates = await getTemplates(seedIfEmpty: true);
    final currentRole = Globals.profileManager.currentRole ?? 'viewer';

    return templates.where((template) {
        if (!template.isActive || template.activeConfig == null) {
          return false;
        }
        return _hasRequiredRole(currentRole, template.allowedRoles);
      }).toList()
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
  }

  Future<bool> saveTemplate(ReportTemplate template) async {
    try {
      final groupId = _currentGroupId;
      final currentUser = Globals.firebaseAuth.currentUser;
      final currentRole = Globals.profileManager.currentRole;
      if (groupId == null || currentUser == null) {
        throw Exception('Немає активної групи або авторизації');
      }
      if (currentRole != 'admin') {
        throw Exception('Недостатньо прав для збереження шаблону звіту');
      }

      final now = DateTime.now();
      if (template.id.trim().isEmpty) {
        final newTemplate = template.copyWith(
          groupId: groupId,
          createdBy: currentUser.uid,
          updatedBy: currentUser.uid,
          createdAt: now,
          updatedAt: now,
          draftVersion: 1,
          activeVersion: template.activeVersion,
        );
        await _templatesCollection(groupId).add(newTemplate.toFirestore());
        return true;
      }

      final currentTemplate = await getTemplateById(template.id);
      final nextDraftVersion = (currentTemplate?.draftVersion ?? 0) + 1;
      final updatedTemplate = template.copyWith(
        groupId: groupId,
        updatedBy: currentUser.uid,
        updatedAt: now,
        draftVersion: nextDraftVersion,
      );

      await _templatesCollection(
        groupId,
      ).doc(template.id).update(updatedTemplate.toFirestore());
      return true;
    } catch (e) {
      debugPrint('ReportTemplatesService.saveTemplate error: $e');
      return false;
    }
  }

  Future<bool> deleteTemplate(String templateId) async {
    try {
      final groupId = _currentGroupId;
      final currentRole = Globals.profileManager.currentRole;
      if (groupId == null || templateId.trim().isEmpty) {
        return false;
      }
      if (currentRole != 'admin') {
        throw Exception('Недостатньо прав для видалення шаблону звіту');
      }
      await _templatesCollection(groupId).doc(templateId).delete();
      return true;
    } catch (e) {
      debugPrint('ReportTemplatesService.deleteTemplate error: $e');
      return false;
    }
  }

  Future<ReportTemplatePreview> previewTemplate({
    required String templateId,
    required bool useDraft,
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    final groupId = _currentGroupId;
    if (groupId == null) {
      throw Exception('Немає активної групи');
    }

    final response =
        await _callReportTemplateFunction('previewReportTemplate', {
          'groupId': groupId,
          'templateId': templateId,
          'useDraft': useDraft,
          'startDate': startDate.toIso8601String(),
          'endDate': endDate.toIso8601String(),
        });

    return ReportTemplatePreview.fromMap(
      Map<String, dynamic>.from(response as Map),
    );
  }

  Future<ReportTemplate?> publishTemplate(String templateId) async {
    final groupId = _currentGroupId;
    if (groupId == null) {
      throw Exception('Немає активної групи');
    }

    await _callReportTemplateFunction('publishReportTemplate', {
      'groupId': groupId,
      'templateId': templateId,
    });
    return getTemplateById(templateId);
  }

  Future<GeneratedTemplateReport> generateTemplateReport({
    required String templateId,
    required bool useDraft,
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    final groupId = _currentGroupId;
    if (groupId == null) {
      throw Exception('Немає активної групи');
    }

    final response =
        await _callReportTemplateFunction('generateReportTemplate', {
          'groupId': groupId,
          'templateId': templateId,
          'useDraft': useDraft,
          'startDate': startDate.toIso8601String(),
          'endDate': endDate.toIso8601String(),
        });

    return GeneratedTemplateReport.fromMap(
      Map<String, dynamic>.from(response as Map),
    );
  }

  bool get _supportsNativeFunctions {
    if (kIsWeb) {
      return true;
    }

    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
      case TargetPlatform.iOS:
      case TargetPlatform.macOS:
        return true;
      case TargetPlatform.windows:
      case TargetPlatform.linux:
      default:
        return false;
    }
  }

  Future<dynamic> _callReportTemplateFunction(
    String functionName,
    Map<String, dynamic> payload,
  ) async {
    if (_supportsNativeFunctions) {
      try {
        return await _callFunctionViaPlugin(functionName, payload);
      } on MissingPluginException catch (_) {
        debugPrint(
          'ReportTemplatesService: cloud_functions plugin unavailable, falling back to HTTP for $functionName',
        );
      }
    }

    return _callFunctionViaHttp(functionName, payload);
  }

  Future<dynamic> _callFunctionViaPlugin(
    String functionName,
    Map<String, dynamic> payload,
  ) async {
    final callable = _functions.httpsCallable(functionName);
    final response = await callable.call(payload);
    return response.data;
  }

  Future<dynamic> _callFunctionViaHttp(
    String functionName,
    Map<String, dynamic> payload,
  ) async {
    final currentUser = Globals.firebaseAuth.currentUser;
    if (currentUser == null) {
      throw Exception('Потрібна авторизація для виклику функції $functionName');
    }

    final idToken = await currentUser.getIdToken();
    if (idToken == null || idToken.isEmpty) {
      throw Exception(
        'Не вдалося отримати токен авторизації для виклику функції $functionName',
      );
    }

    final projectId = Firebase.app().options.projectId;
    final uri = Uri.parse(
      'https://$_functionsRegion-$projectId.cloudfunctions.net/$functionName',
    );

    final response = await http.post(
      uri,
      headers: <String, String>{
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $idToken',
      },
      body: jsonEncode(<String, dynamic>{'data': payload}),
    );

    return _parseCallableHttpResponse(
      functionName: functionName,
      response: response,
    );
  }

  dynamic _parseCallableHttpResponse({
    required String functionName,
    required http.Response response,
  }) {
    Map<String, dynamic>? body;
    if (response.bodyBytes.isNotEmpty) {
      final decodedBody = utf8.decode(response.bodyBytes);
      final jsonBody = jsonDecode(decodedBody);
      body = jsonBody is Map<String, dynamic>
          ? jsonBody
          : Map<String, dynamic>.from(jsonBody as Map);
    }

    final error = body?['error'];
    if (error != null) {
      final errorMap = Map<String, dynamic>.from(error as Map);
      final message =
          (errorMap['message'] ?? 'Помилка виклику функції $functionName')
              .toString();
      throw Exception(message);
    }

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(
        'HTTP ${response.statusCode} під час виклику функції $functionName',
      );
    }

    if (body != null && body.containsKey('result')) {
      return body['result'];
    }

    if (body != null && body.containsKey('data')) {
      return body['data'];
    }

    throw Exception('Некоректна відповідь від функції $functionName');
  }

  bool _hasRequiredRole(String currentRole, List<String> allowedRoles) {
    const hierarchy = {'viewer': 1, 'editor': 2, 'admin': 3};
    final userLevel = hierarchy[currentRole] ?? 0;
    final minLevel = (allowedRoles.isEmpty ? const ['viewer'] : allowedRoles)
        .map((role) => hierarchy[role] ?? 0)
        .reduce((value, element) => value < element ? value : element);
    return userLevel >= minLevel;
  }
}
