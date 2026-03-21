// report_templates_service.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';

import '../globals.dart';
import '../models/report_template_model.dart';

class ReportTemplatesService {
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
      if (groupId == null || currentUser == null) {
        throw Exception('Немає активної групи або авторизації');
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
      if (groupId == null || templateId.trim().isEmpty) {
        return false;
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

    final callable = _functions.httpsCallable('previewReportTemplate');
    final response = await callable.call({
      'groupId': groupId,
      'templateId': templateId,
      'useDraft': useDraft,
      'startDate': startDate.toIso8601String(),
      'endDate': endDate.toIso8601String(),
    });

    return ReportTemplatePreview.fromMap(
      Map<String, dynamic>.from(response.data as Map),
    );
  }

  Future<ReportTemplate?> publishTemplate(String templateId) async {
    final groupId = _currentGroupId;
    if (groupId == null) {
      throw Exception('Немає активної групи');
    }

    final callable = _functions.httpsCallable('publishReportTemplate');
    await callable.call({'groupId': groupId, 'templateId': templateId});
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

    final callable = _functions.httpsCallable('generateReportTemplate');
    final response = await callable.call({
      'groupId': groupId,
      'templateId': templateId,
      'useDraft': useDraft,
      'startDate': startDate.toIso8601String(),
      'endDate': endDate.toIso8601String(),
    });

    return GeneratedTemplateReport.fromMap(
      Map<String, dynamic>.from(response.data as Map),
    );
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
