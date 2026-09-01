// lib/pages/calendar_page/services/calendar_service.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/custom_field_model.dart';
import '../models/lesson_model.dart';
import '../models/lesson_progress_reminder.dart';
import '../globals.dart';
import '../pages/calendar_page/calendar_utils.dart';

class CalendarService {
  static final CalendarService _instance = CalendarService._internal();
  static const Set<String> _acknowledgementResetFields = {
    'startTime',
    'endTime',
    'unit',
  };

  factory CalendarService() => _instance;
  CalendarService._internal();

  FirebaseFirestore get _firestore => FirebaseFirestore.instance;

  List<LessonModel> getCachedLessonsForPeriod({
    required DateTime startDate,
    required DateTime endDate,
    String? groupId,
  }) {
    final currentGroupId = groupId ?? Globals.profileManager.currentGroupId;
    if (currentGroupId == null) {
      return const [];
    }

    final effectiveEndDate = _normalizeInclusiveEndDate(endDate);
    final snapshot = Globals.appSnapshotStore.getCachedSnapshot(
      _cacheKeyForPeriod(currentGroupId, startDate, effectiveEndDate),
    );
    final data = snapshot?.data;
    if (data is! List) {
      return const [];
    }

    return data
        .map((item) => LessonModel.fromMap(Map<String, dynamic>.from(item)))
        .toList(growable: false);
  }

  /// Отримати заняття для поточної групи на вказаний період
  Future<List<LessonModel>> getLessonsForPeriod({
    required DateTime startDate,
    required DateTime endDate,
    String? groupId,
  }) async {
    final currentGroupId = groupId ?? Globals.profileManager.currentGroupId;
    if (currentGroupId == null) {
      debugPrint('CalendarService: Немає активної групи');
      return [];
    }

    final effectiveEndDate = _normalizeInclusiveEndDate(endDate);

    try {
      debugPrint(
        'CalendarService: Завантаження занять для групи $currentGroupId від $startDate до $effectiveEndDate',
      );

      // Запит до Firestore
      final querySnapshot = await _firestore
          .collection('lessons')
          .doc(currentGroupId)
          .collection('items')
          .where(
            'startTime',
            isGreaterThanOrEqualTo: Timestamp.fromDate(startDate),
          )
          .where(
            'startTime',
            isLessThanOrEqualTo: Timestamp.fromDate(effectiveEndDate),
          )
          .orderBy('startTime')
          .get();

      final lessons = querySnapshot.docs
          .map((doc) => LessonModel.fromFirestore(doc.data(), doc.id))
          .toList();

      await Globals.appSnapshotStore.saveCachedSnapshot(
        _cacheKeyForPeriod(currentGroupId, startDate, effectiveEndDate),
        lessons.map((lesson) => lesson.toMap()).toList(),
      );

      debugPrint('CalendarService: Знайдено ${lessons.length} занять');
      return lessons;
    } catch (e) {
      debugPrint('CalendarService: Помилка завантаження занять: $e');
      return getCachedLessonsForPeriod(
        startDate: startDate,
        endDate: endDate,
        groupId: currentGroupId,
      );
    }
  }

  Future<List<LessonModel>> getLessonsForPeriodByInstructor({
    required DateTime startDate,
    required DateTime endDate,
    String? instructorId,
  }) async {
    try {
      final normalizedInstructorId = _normalizeInstructorAssignmentId(
        instructorId ?? '',
      );
      if (normalizedInstructorId.isEmpty) {
        return [];
      }

      final lessons = await getLessonsForPeriod(
        startDate: startDate,
        endDate: endDate,
      );

      return lessons
          .where((lesson) => lesson.hasInstructorId(normalizedInstructorId))
          .toList();
    } catch (e) {
      debugPrint('CalendarService: Помилка завантаження занять: $e');
      return [];
    }
  }

  /// Отримати заняття для тижня
  Future<List<LessonModel>> getLessonsForWeek(DateTime selectedDate) async {
    final startOfWeek = CalendarUtils.getStartOfWeek(selectedDate);
    final endOfWeek = CalendarUtils.getEndOfWeek(selectedDate);

    return await getLessonsForPeriod(
      startDate: startOfWeek,
      endDate: endOfWeek,
    );
  }

  /// Отримати заняття для дня
  Future<List<LessonModel>> getLessonsForDay(DateTime selectedDate) async {
    final startOfDay = CalendarUtils.startOfDay(selectedDate);
    final endOfDay = CalendarUtils.endOfDay(selectedDate);

    return await getLessonsForPeriod(startDate: startOfDay, endDate: endOfDay);
  }

  /// Створити нове заняття
  Future<String?> createLesson(LessonModel lesson) async {
    if (_isReadOnlyOfflineMode) {
      debugPrint('CalendarService: createLesson blocked in read-only offline');
      return null;
    }

    try {
      final currentGroupId = Globals.profileManager.currentGroupId;
      if (currentGroupId == null) {
        throw Exception('Немає активної групи для створення заняття');
      }

      final currentUser = Globals.firebaseAuth.currentUser;
      if (currentUser == null) {
        throw Exception('Користувач не авторизований');
      }

      final lessonData = {
        'title': lesson.title,
        'description': lesson.description,
        'startTime': Timestamp.fromDate(lesson.startTime),
        'endTime': Timestamp.fromDate(lesson.endTime),
        'groupId': currentGroupId,
        'groupName': lesson.groupName,
        'type': lesson.typeId,
        'templateId': lesson.templateId,
        'linkedSetId': lesson.linkedSetId,
        'mainLessonId': lesson.mainLessonId,
        'linkedLessonRole': lesson.linkedLessonRole,
        'unit': lesson.unit,
        'instructorName': lesson.hasInstructors
            ? lesson.instructorName
            : 'Не призначено',
        'instructorId': lesson.instructorId,
        'instructorIds': lesson.instructorIds,
        'instructorNames': lesson.instructorNames,
        'externalInstructorNames': lesson.externalInstructorNames,
        'location': lesson.location,
        'maxParticipants': lesson.maxParticipants,
        'currentParticipants': 0,
        'participants': <String>[],
        'status': 'scheduled',
        'tags': lesson.tags,
        'createdBy': currentUser.uid,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'acknowledgementResetAt': FieldValue.serverTimestamp(),
        'instructorAcknowledgements': <String, dynamic>{},
        'customFieldDefinitions': lesson.customFieldDefinitions
            .map((definition) => definition.toFirestore())
            .toList(),
        'customFieldValues': lesson.customFieldValues.map(
          (key, value) => MapEntry(key, value.toFirestore()),
        ),
        'progressReminders': LessonProgressReminder.toFirestoreList(
          lesson.progressReminders,
        ),
        'recurrence': lesson.recurrence != null
            ? {
                'type': lesson.recurrence!.type,
                'interval': lesson.recurrence!.interval,
                'endDate': Timestamp.fromDate(lesson.recurrence!.endDate),
              }
            : null,
      };

      final docRef = await _firestore
          .collection('lessons')
          .doc(currentGroupId)
          .collection('items')
          .add(lessonData);

      debugPrint('CalendarService: Заняття створено з ID: ${docRef.id}');
      return docRef.id;
    } catch (e) {
      debugPrint('CalendarService: Помилка створення заняття: $e');
      return null;
    }
  }

  /// Створює головне заняття та вибрані навчальні точки одним batch-записом.
  Future<String?> createLessonSet(
    LessonModel mainLesson,
    List<LessonModel> learningPoints,
  ) async {
    if (learningPoints.isEmpty) {
      return createLesson(mainLesson);
    }
    if (_isReadOnlyOfflineMode) return null;

    try {
      final groupId = Globals.profileManager.currentGroupId;
      final currentUser = Globals.firebaseAuth.currentUser;
      if (groupId == null || currentUser == null) {
        throw Exception('Немає активної групи або користувача');
      }

      final itemsRef = _firestore
          .collection('lessons')
          .doc(groupId)
          .collection('items');
      final mainRef = itemsRef.doc();
      final batch = _firestore.batch();

      batch.set(
        mainRef,
        _lessonCreateData(
          mainLesson,
          groupId: groupId,
          createdBy: currentUser.uid,
          linkedSetId: mainRef.id,
          mainLessonId: mainRef.id,
          linkedLessonRole: 'main',
        ),
      );

      for (final point in learningPoints) {
        final pointRef = itemsRef.doc();
        batch.set(
          pointRef,
          _lessonCreateData(
            point,
            groupId: groupId,
            createdBy: currentUser.uid,
            linkedSetId: mainRef.id,
            mainLessonId: mainRef.id,
            linkedLessonRole: 'learningPoint',
          ),
        );
      }

      await batch.commit();
      return mainRef.id;
    } catch (e) {
      debugPrint('CalendarService: Помилка створення комплекту занять: $e');
      return null;
    }
  }

  Map<String, dynamic> _lessonCreateData(
    LessonModel lesson, {
    required String groupId,
    required String createdBy,
    required String linkedSetId,
    required String mainLessonId,
    required String linkedLessonRole,
  }) {
    return {
      ...lesson.toFirestore(),
      'groupId': groupId,
      'linkedSetId': linkedSetId,
      'mainLessonId': mainLessonId,
      'linkedLessonRole': linkedLessonRole,
      'createdBy': createdBy,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
      'acknowledgementResetAt': FieldValue.serverTimestamp(),
      'instructorAcknowledgements': <String, dynamic>{},
      'currentParticipants': 0,
      'participants': <String>[],
      'status': 'scheduled',
    };
  }

  Future<List<LessonModel>> getLinkedLessons(String linkedSetId) async {
    final groupId = Globals.profileManager.currentGroupId;
    if (groupId == null || linkedSetId.trim().isEmpty) return const [];
    try {
      final snapshot = await _firestore
          .collection('lessons')
          .doc(groupId)
          .collection('items')
          .where('linkedSetId', isEqualTo: linkedSetId)
          .get();
      final lessons = snapshot.docs
          .map((doc) => LessonModel.fromFirestore(doc.data(), doc.id))
          .toList();
      lessons.sort((a, b) {
        if (a.isMainLinkedLesson != b.isMainLinkedLesson) {
          return a.isMainLinkedLesson ? -1 : 1;
        }
        return a.startTime.compareTo(b.startTime);
      });
      return lessons;
    } catch (e) {
      debugPrint('CalendarService: Помилка завантаження комплекту: $e');
      return const [];
    }
  }

  /// Оновлює незалежні поля поточного заняття. Для головного заняття також
  /// переносить дату та підрозділ усіх навчальних точок.
  Future<bool> updateLessonRespectingLinks(
    LessonModel lesson,
    Map<String, dynamic> updates,
  ) async {
    if (!lesson.isLinkedLesson) {
      return updateLesson(lesson.id, updates);
    }

    if (lesson.isLearningPoint) {
      final nextStart = _dateTimeFromUpdate(updates['startTime']);
      final nextEnd = _dateTimeFromUpdate(updates['endTime']);
      if (nextStart != null) {
        updates['startTime'] = moveLessonTimeToDate(
          nextStart,
          lesson.startTime,
        );
      }
      if (nextEnd != null) {
        updates['endTime'] = moveLessonTimeToDate(nextEnd, lesson.endTime);
      }
      updates.remove('unit');
      if (updates.containsKey('customFieldDefinitions') ||
          updates.containsKey('customFieldValues')) {
        final mainLesson = await getLessonById(lesson.mainLessonId);
        if (mainLesson == null) return false;
        final pointDefinitions = updates.containsKey('customFieldDefinitions')
            ? LessonCustomFieldDefinition.parseDefinitions(
                updates['customFieldDefinitions'],
              )
            : lesson.customFieldDefinitions;
        final pointValues = updates.containsKey('customFieldValues')
            ? LessonCustomFieldValue.parseValues(updates['customFieldValues'])
            : lesson.customFieldValues;
        final synchronizedValues = synchronizeLearningPointCustomValues(
          mainDefinitions: mainLesson.customFieldDefinitions,
          mainValues: mainLesson.customFieldValues,
          pointDefinitions: pointDefinitions,
          pointValues: pointValues,
        );
        updates['customFieldValues'] = synchronizedValues.map(
          (key, value) => MapEntry(key, value.toFirestore()),
        );
      }
      return updateLesson(lesson.id, updates);
    }

    if (!lesson.isMainLinkedLesson) {
      return updateLesson(lesson.id, updates);
    }

    try {
      final groupId = Globals.profileManager.currentGroupId;
      if (groupId == null) return false;
      final linkedLessons = await getLinkedLessons(lesson.linkedSetId);
      if (linkedLessons.isEmpty) return false;

      final targetStart = _dateTimeFromUpdate(updates['startTime']);
      final targetUnit = updates['unit']?.toString();
      final dateChanged =
          targetStart != null && !_isSameDate(targetStart, lesson.startTime);
      final unitChanged = targetUnit != null && targetUnit != lesson.unit;
      final shouldSyncCustomFields =
          updates.containsKey('customFieldDefinitions') ||
          updates.containsKey('customFieldValues');
      final mainDefinitions = updates.containsKey('customFieldDefinitions')
          ? LessonCustomFieldDefinition.parseDefinitions(
              updates['customFieldDefinitions'],
            )
          : lesson.customFieldDefinitions;
      final mainValues = updates.containsKey('customFieldValues')
          ? LessonCustomFieldValue.parseValues(updates['customFieldValues'])
          : lesson.customFieldValues;
      final batch = _firestore.batch();
      final itemsRef = _firestore
          .collection('lessons')
          .doc(groupId)
          .collection('items');

      for (final member in linkedLessons) {
        final memberUpdates = member.id == lesson.id
            ? Map<String, dynamic>.from(updates)
            : <String, dynamic>{};
        if (dateChanged && member.id != lesson.id) {
          memberUpdates['startTime'] = moveLessonTimeToDate(
            member.startTime,
            targetStart,
          );
          memberUpdates['endTime'] = moveLessonTimeToDate(
            member.endTime,
            targetStart,
          );
        }
        if (unitChanged) {
          memberUpdates['unit'] = targetUnit;
        }
        if (shouldSyncCustomFields && member.isLearningPoint) {
          final synchronizedValues = synchronizeLearningPointCustomValues(
            mainDefinitions: mainDefinitions,
            mainValues: mainValues,
            pointDefinitions: member.customFieldDefinitions,
            pointValues: member.customFieldValues,
          );
          memberUpdates['customFieldValues'] = synchronizedValues.map(
            (key, value) => MapEntry(key, value.toFirestore()),
          );
        }
        if (memberUpdates.isEmpty) continue;
        memberUpdates['updatedAt'] = FieldValue.serverTimestamp();
        if (dateChanged || unitChanged) {
          memberUpdates['acknowledgementResetAt'] =
              FieldValue.serverTimestamp();
        }
        batch.update(itemsRef.doc(member.id), memberUpdates);
      }

      await batch.commit();
      return true;
    } catch (e) {
      debugPrint('CalendarService: Помилка оновлення комплекту: $e');
      return false;
    }
  }

  Future<bool> addLearningPointFromTemplate(
    LessonModel mainLesson,
    LessonModel point,
  ) async {
    try {
      final groupId = Globals.profileManager.currentGroupId;
      final currentUser = Globals.firebaseAuth.currentUser;
      if (groupId == null || currentUser == null) return false;
      final ref = _firestore
          .collection('lessons')
          .doc(groupId)
          .collection('items')
          .doc();
      final batch = _firestore.batch();
      final linkedSetId = mainLesson.isMainLinkedLesson
          ? mainLesson.linkedSetId
          : mainLesson.id;
      if (!mainLesson.isMainLinkedLesson) {
        final mainRef = ref.parent.doc(mainLesson.id);
        batch.update(mainRef, {
          'linkedSetId': linkedSetId,
          'mainLessonId': mainLesson.id,
          'linkedLessonRole': 'main',
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }
      batch.set(
        ref,
        _lessonCreateData(
          point,
          groupId: groupId,
          createdBy: currentUser.uid,
          linkedSetId: linkedSetId,
          mainLessonId: mainLesson.id,
          linkedLessonRole: 'learningPoint',
        ),
      );
      await batch.commit();
      return true;
    } catch (e) {
      debugPrint('CalendarService: Помилка додавання навчальної точки: $e');
      return false;
    }
  }

  Future<List<LessonModel>> getUnlinkedFutureLessons({
    String excludeId = '',
  }) async {
    final groupId = Globals.profileManager.currentGroupId;
    if (groupId == null) return const [];
    try {
      final snapshot = await _firestore
          .collection('lessons')
          .doc(groupId)
          .collection('items')
          .where('startTime', isGreaterThanOrEqualTo: Timestamp.now())
          .get();
      return snapshot.docs
          .map((doc) => LessonModel.fromFirestore(doc.data(), doc.id))
          .where((lesson) => !lesson.isLinkedLesson && lesson.id != excludeId)
          .toList()
        ..sort((a, b) => a.startTime.compareTo(b.startTime));
    } catch (e) {
      debugPrint('CalendarService: Помилка пошуку занять для лінкування: $e');
      return const [];
    }
  }

  Future<bool> linkExistingLearningPoint(
    LessonModel mainLesson,
    LessonModel learningPoint,
  ) async {
    if (learningPoint.isLinkedLesson || mainLesson.id == learningPoint.id) {
      return false;
    }
    try {
      final groupId = Globals.profileManager.currentGroupId;
      if (groupId == null) return false;
      final itemsRef = _firestore
          .collection('lessons')
          .doc(groupId)
          .collection('items');
      final batch = _firestore.batch();
      final linkedSetId = mainLesson.isMainLinkedLesson
          ? mainLesson.linkedSetId
          : mainLesson.id;
      if (!mainLesson.isMainLinkedLesson) {
        batch.update(itemsRef.doc(mainLesson.id), {
          'linkedSetId': linkedSetId,
          'mainLessonId': mainLesson.id,
          'linkedLessonRole': 'main',
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }
      batch.update(itemsRef.doc(learningPoint.id), {
        'linkedSetId': linkedSetId,
        'mainLessonId': mainLesson.id,
        'linkedLessonRole': 'learningPoint',
        'startTime': moveLessonTimeToDate(
          learningPoint.startTime,
          mainLesson.startTime,
        ),
        'endTime': moveLessonTimeToDate(
          learningPoint.endTime,
          mainLesson.startTime,
        ),
        'unit': mainLesson.unit,
        'customFieldValues': synchronizeLearningPointCustomValues(
          mainDefinitions: mainLesson.customFieldDefinitions,
          mainValues: mainLesson.customFieldValues,
          pointDefinitions: learningPoint.customFieldDefinitions,
          pointValues: learningPoint.customFieldValues,
        ).map((key, value) => MapEntry(key, value.toFirestore())),
        'updatedAt': FieldValue.serverTimestamp(),
        'acknowledgementResetAt': FieldValue.serverTimestamp(),
      });
      await batch.commit();
      return true;
    } catch (e) {
      debugPrint('CalendarService: Помилка лінкування навчальної точки: $e');
      return false;
    }
  }

  Future<bool> removeLearningPoint(
    LessonModel point, {
    required bool deleteLesson,
  }) async {
    if (!point.isLearningPoint) return false;
    try {
      final groupId = Globals.profileManager.currentGroupId;
      if (groupId == null) return false;
      final itemsRef = _firestore
          .collection('lessons')
          .doc(groupId)
          .collection('items');
      final linked = await getLinkedLessons(point.linkedSetId);
      final batch = _firestore.batch();
      if (deleteLesson) {
        batch.delete(itemsRef.doc(point.id));
      } else {
        batch.update(itemsRef.doc(point.id), {
          'linkedSetId': FieldValue.delete(),
          'mainLessonId': FieldValue.delete(),
          'linkedLessonRole': FieldValue.delete(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }
      final remainingPoints = linked
          .where((item) => item.isLearningPoint && item.id != point.id)
          .length;
      if (remainingPoints == 0) {
        LessonModel? main;
        for (final item in linked) {
          if (item.isMainLinkedLesson) {
            main = item;
            break;
          }
        }
        if (main != null) {
          batch.update(itemsRef.doc(main.id), {
            'linkedSetId': FieldValue.delete(),
            'mainLessonId': FieldValue.delete(),
            'linkedLessonRole': FieldValue.delete(),
            'updatedAt': FieldValue.serverTimestamp(),
          });
        }
      }
      await batch.commit();
      return true;
    } catch (e) {
      debugPrint('CalendarService: Помилка вилучення навчальної точки: $e');
      return false;
    }
  }

  Future<bool> deleteMainLesson(
    LessonModel mainLesson, {
    required bool deleteLearningPoints,
  }) async {
    if (!mainLesson.isMainLinkedLesson) {
      return deleteLesson(mainLesson.id);
    }
    try {
      final groupId = Globals.profileManager.currentGroupId;
      if (groupId == null) return false;
      final linked = await getLinkedLessons(mainLesson.linkedSetId);
      final itemsRef = _firestore
          .collection('lessons')
          .doc(groupId)
          .collection('items');
      final batch = _firestore.batch();
      for (final lesson in linked) {
        final ref = itemsRef.doc(lesson.id);
        if (lesson.id == mainLesson.id || deleteLearningPoints) {
          batch.delete(ref);
        } else {
          batch.update(ref, {
            'linkedSetId': FieldValue.delete(),
            'mainLessonId': FieldValue.delete(),
            'linkedLessonRole': FieldValue.delete(),
            'updatedAt': FieldValue.serverTimestamp(),
          });
        }
      }
      await batch.commit();
      return true;
    } catch (e) {
      debugPrint('CalendarService: Помилка видалення головного заняття: $e');
      return false;
    }
  }

  Future<bool> detachLearningPoint(String lessonId) async {
    return updateLesson(lessonId, {
      'linkedSetId': FieldValue.delete(),
      'mainLessonId': FieldValue.delete(),
      'linkedLessonRole': FieldValue.delete(),
    });
  }

  DateTime? _dateTimeFromUpdate(dynamic value) {
    if (value is DateTime) return value;
    if (value is Timestamp) return value.toDate();
    return null;
  }

  @visibleForTesting
  static DateTime moveLessonTimeToDate(
    DateTime valueWithTime,
    DateTime valueWithDate,
  ) {
    return DateTime(
      valueWithDate.year,
      valueWithDate.month,
      valueWithDate.day,
      valueWithTime.hour,
      valueWithTime.minute,
      valueWithTime.second,
      valueWithTime.millisecond,
      valueWithTime.microsecond,
    );
  }

  static Map<String, LessonCustomFieldValue>
  synchronizeLearningPointCustomValues({
    required List<LessonCustomFieldDefinition> mainDefinitions,
    required Map<String, LessonCustomFieldValue> mainValues,
    required List<LessonCustomFieldDefinition> pointDefinitions,
    required Map<String, LessonCustomFieldValue> pointValues,
  }) {
    final mainDefinitionsByCode = {
      for (final definition in mainDefinitions) definition.code: definition,
    };
    final synchronized = LessonCustomFieldValue.retainCompatibleValues(
      definitions: pointDefinitions,
      currentValues: pointValues,
    );

    for (final pointDefinition in pointDefinitions) {
      final mainDefinition = mainDefinitionsByCode[pointDefinition.code];
      if (mainDefinition == null ||
          mainDefinition.type != pointDefinition.type) {
        continue;
      }
      final mainValue = mainValues[pointDefinition.code];
      if (mainValue == null ||
          mainValue.type != pointDefinition.type ||
          mainValue.isEmpty) {
        synchronized.remove(pointDefinition.code);
      } else {
        synchronized[pointDefinition.code] = mainValue;
      }
    }
    return synchronized;
  }

  Future<LessonModel?> getLessonById(String lessonId, {String? groupId}) async {
    final currentGroupId = groupId ?? Globals.profileManager.currentGroupId;
    if (currentGroupId == null) return null;

    try {
      final lessonDoc = await _firestore
          .collection('lessons')
          .doc(currentGroupId)
          .collection('items')
          .doc(lessonId)
          .get();

      final data = lessonDoc.data();
      if (!lessonDoc.exists || data == null) {
        return null;
      }

      return LessonModel.fromFirestore(data, lessonDoc.id);
    } catch (e) {
      debugPrint('CalendarService: Помилка отримання заняття: $e');
      return _findCachedLessonById(currentGroupId, lessonId);
    }
  }

  /// Оновити заняття
  Future<bool> updateLesson(
    String lessonId,
    Map<String, dynamic> updates,
  ) async {
    if (_isReadOnlyOfflineMode) {
      debugPrint('CalendarService: updateLesson blocked in read-only offline');
      return false;
    }

    try {
      final currentGroupId = Globals.profileManager.currentGroupId;
      if (currentGroupId == null) return false;

      if (CalendarService.shouldResetAcknowledgementsForFields(updates.keys)) {
        final lesson = await getLessonById(lessonId, groupId: currentGroupId);
        if (lesson == null) {
          debugPrint(
            'CalendarService: Не вдалося перевірити зміни для скидання ознайомлень у занятті $lessonId',
          );
          return false;
        }
        if (CalendarService.shouldResetAcknowledgements(lesson, updates)) {
          updates['acknowledgementResetAt'] = FieldValue.serverTimestamp();
        }
      }
      updates['updatedAt'] = FieldValue.serverTimestamp();

      await _firestore
          .collection('lessons')
          .doc(currentGroupId)
          .collection('items')
          .doc(lessonId)
          .update(updates);

      debugPrint('CalendarService: Заняття $lessonId оновлено');
      return true;
    } catch (e) {
      debugPrint('CalendarService: Помилка оновлення заняття: $e');
      return false;
    }
  }

  /// Видалити заняття
  Future<bool> deleteLesson(String lessonId) async {
    if (_isReadOnlyOfflineMode) {
      debugPrint('CalendarService: deleteLesson blocked in read-only offline');
      return false;
    }

    try {
      final currentGroupId = Globals.profileManager.currentGroupId;
      if (currentGroupId == null) return false;

      await _firestore
          .collection('lessons')
          .doc(currentGroupId)
          .collection('items')
          .doc(lessonId)
          .delete();

      debugPrint('CalendarService: Заняття $lessonId видалено');
      return true;
    } catch (e) {
      debugPrint('CalendarService: Помилка видалення заняття: $e');
      return false;
    }
  }

  /// Зареєструватися на заняття
  Future<bool> registerForLesson(String lessonId) async {
    if (_isReadOnlyOfflineMode) {
      debugPrint(
        'CalendarService: registerForLesson blocked in read-only offline',
      );
      return false;
    }

    try {
      final currentGroupId = Globals.profileManager.currentGroupId;
      final currentUser = Globals.firebaseAuth.currentUser;

      if (currentGroupId == null || currentUser == null) return false;

      final lessonRef = _firestore
          .collection('lessons')
          .doc(currentGroupId)
          .collection('items')
          .doc(lessonId);

      await _firestore.runTransaction((transaction) async {
        final lessonDoc = await transaction.get(lessonRef);

        if (!lessonDoc.exists) {
          throw Exception('Заняття не знайдено');
        }

        final data = lessonDoc.data()!;
        final participants = List<String>.from(data['participants'] ?? []);
        final maxParticipants = data['maxParticipants'] ?? 0;

        if (participants.contains(currentUser.uid)) {
          throw Exception('Вже зареєстровано на це заняття');
        }

        if (participants.length >= maxParticipants) {
          throw Exception('Заняття заповнене');
        }

        participants.add(currentUser.uid);

        transaction.update(lessonRef, {
          'participants': participants,
          'currentParticipants': participants.length,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      });

      debugPrint('CalendarService: Успішно зареєстровано на заняття $lessonId');
      return true;
    } catch (e) {
      debugPrint('CalendarService: Помилка реєстрації на заняття: $e');
      return false;
    }
  }

  /// Скасувати реєстрацію на заняття
  Future<bool> unregisterFromLesson(String lessonId) async {
    if (_isReadOnlyOfflineMode) {
      debugPrint(
        'CalendarService: unregisterFromLesson blocked in read-only offline',
      );
      return false;
    }

    try {
      final currentGroupId = Globals.profileManager.currentGroupId;
      final currentUser = Globals.firebaseAuth.currentUser;

      if (currentGroupId == null || currentUser == null) return false;

      final lessonRef = _firestore
          .collection('lessons')
          .doc(currentGroupId)
          .collection('items')
          .doc(lessonId);

      await _firestore.runTransaction((transaction) async {
        final lessonDoc = await transaction.get(lessonRef);

        if (!lessonDoc.exists) {
          throw Exception('Заняття не знайдено');
        }

        final data = lessonDoc.data()!;
        final participants = List<String>.from(data['participants'] ?? []);

        if (!participants.contains(currentUser.uid)) {
          throw Exception('Не зареєстровано на це заняття');
        }

        participants.remove(currentUser.uid);

        transaction.update(lessonRef, {
          'participants': participants,
          'currentParticipants': participants.length,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      });

      debugPrint(
        'CalendarService: Успішно скасовано реєстрацію на заняття $lessonId',
      );
      return true;
    } catch (e) {
      debugPrint('CalendarService: Помилка скасування реєстрації: $e');
      return false;
    }
  }

  /// Перевірити чи користувач зареєстрований на заняття
  bool isUserRegisteredForLesson(LessonModel lesson) {
    final currentUser = Globals.firebaseAuth.currentUser;
    if (currentUser == null) return false;

    return lesson.participants.contains(currentUser.uid);
  }

  /// Отримати заняття за фільтрами
  Future<List<LessonModel>> getLessonsWithFilters({
    required DateTime startDate,
    required DateTime endDate,
    List<String>? tags,
    List<String>? instructors,
    String? status,
  }) async {
    try {
      final currentGroupId = Globals.profileManager.currentGroupId;
      if (currentGroupId == null) return [];
      final effectiveEndDate = _normalizeInclusiveEndDate(endDate);

      Query query = _firestore
          .collection('lessons')
          .doc(currentGroupId)
          .collection('items')
          .where(
            'startTime',
            isGreaterThanOrEqualTo: Timestamp.fromDate(startDate),
          )
          .where(
            'startTime',
            isLessThanOrEqualTo: Timestamp.fromDate(effectiveEndDate),
          );

      if (status != null) {
        query = query.where('status', isEqualTo: status);
      }

      final querySnapshot = await query.orderBy('startTime').get();

      var lessons = querySnapshot.docs
          .map(
            (doc) => LessonModel.fromFirestore(
              doc.data() as Map<String, dynamic>,
              doc.id,
            ),
          )
          .toList();

      // Клієнтська фільтрація для tags та instructors
      if (tags != null && tags.isNotEmpty) {
        lessons = lessons
            .where((lesson) => lesson.tags.any((tag) => tags.contains(tag)))
            .toList();
      }

      if (instructors != null && instructors.isNotEmpty) {
        final normalizedInstructors = instructors
            .map(_normalizeInstructorAssignmentId)
            .where((value) => value.isNotEmpty)
            .toSet();
        lessons = lessons
            .where(
              (lesson) => lesson.instructorIds.any(
                (instructorId) => normalizedInstructors.contains(instructorId),
              ),
            )
            .toList();
      }

      return lessons;
    } catch (e) {
      debugPrint('CalendarService: Помилка фільтрації занять: $e');
      return [];
    }
  }

  /// Отримати Stream занять для real-time оновлень
  Stream<List<LessonModel>> getLessonsStream({
    required DateTime startDate,
    required DateTime endDate,
  }) {
    final currentGroupId = Globals.profileManager.currentGroupId;
    if (currentGroupId == null) {
      return Stream.value([]);
    }

    final effectiveEndDate = _normalizeInclusiveEndDate(endDate);

    return _firestore
        .collection('lessons')
        .doc(currentGroupId)
        .collection('items')
        .where(
          'startTime',
          isGreaterThanOrEqualTo: Timestamp.fromDate(startDate),
        )
        .where(
          'startTime',
          isLessThanOrEqualTo: Timestamp.fromDate(effectiveEndDate),
        )
        .orderBy('startTime')
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => LessonModel.fromFirestore(doc.data(), doc.id))
              .toList(),
        );
  }

  /// Отримати статистику занять
  Future<Map<String, dynamic>> getLessonsStatistics({
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    final lessons = await getLessonsForPeriod(
      startDate: startDate,
      endDate: endDate,
    );

    final totalLessons = lessons.length;
    final completedLessons = lessons
        .where((l) => l.status == 'completed')
        .length;
    final scheduledLessons = lessons
        .where((l) => l.status == 'scheduled')
        .length;
    final cancelledLessons = lessons
        .where((l) => l.status == 'cancelled')
        .length;

    final totalCapacity = lessons.fold<int>(
      0,
      (total, lesson) => total + lesson.maxParticipants,
    );

    return {
      'totalLessons': totalLessons,
      'completedLessons': completedLessons,
      'scheduledLessons': scheduledLessons,
      'cancelledLessons': cancelledLessons,
      'totalCapacity': totalCapacity,
    };
  }

  /// Взяти заняття на себе (як інструктор)
  Future<bool> takeLesson(String lessonId) async {
    debugPrint(
      'CalendarService: takeLesson вимкнено. Призначення викладачів доступне лише editor/admin.',
    );
    return false;
  }

  Future<bool> assignLessonInstructor(
    String lessonId, {
    required String instructorId,
    required String instructorName,
  }) async {
    return assignLessonInstructors(
      lessonId,
      instructorIds: [instructorId],
      instructorNames: [instructorName],
    );
  }

  Future<bool> assignLessonInstructors(
    String lessonId, {
    required List<String> instructorIds,
    required List<String> instructorNames,
    List<String> externalInstructorNames = const [],
  }) async {
    try {
      if (!Globals.profileManager.isCurrentGroupEditor) {
        debugPrint(
          'CalendarService: Недостатньо прав для призначення викладачів',
        );
        return false;
      }

      final normalizedInstructorIds = <String>[];
      for (final instructorId in instructorIds) {
        final normalizedInstructorId = _normalizeInstructorAssignmentId(
          instructorId,
        );
        if (normalizedInstructorId.isEmpty ||
            normalizedInstructorIds.contains(normalizedInstructorId)) {
          continue;
        }
        normalizedInstructorIds.add(normalizedInstructorId);
      }

      final normalizedInstructorNames = <String>[];
      for (final instructorName in instructorNames) {
        final normalizedInstructorName = instructorName.trim();
        if (normalizedInstructorName.isEmpty ||
            normalizedInstructorNames.contains(normalizedInstructorName)) {
          continue;
        }
        normalizedInstructorNames.add(normalizedInstructorName);
      }

      final normalizedExternalInstructorNames = <String>[];
      for (final instructorName in externalInstructorNames) {
        final normalizedInstructorName = instructorName.trim();
        if (normalizedInstructorName.isEmpty ||
            normalizedExternalInstructorNames.contains(
              normalizedInstructorName,
            )) {
          continue;
        }
        normalizedExternalInstructorNames.add(normalizedInstructorName);
      }

      return await updateLesson(lessonId, {
        'instructorId': normalizedInstructorIds.isNotEmpty
            ? normalizedInstructorIds.first
            : '',
        'instructorName': normalizedInstructorNames.isNotEmpty
            ? normalizedInstructorNames.first
            : '',
        'instructorIds': normalizedInstructorIds,
        'instructorNames': normalizedInstructorNames,
        'externalInstructorNames': normalizedExternalInstructorNames,
      });
    } catch (e) {
      debugPrint('CalendarService: Помилка призначення викладачів: $e');
      return false;
    }
  }

  /// Відмовитися від заняття (як інструктор)
  Future<bool> releaseLesson(String lessonId) async {
    debugPrint(
      'CalendarService: releaseLesson вимкнено. Призначення викладачів доступне лише editor/admin.',
    );
    return false;
  }

  Future<bool> unassignLessonInstructor(String lessonId) async {
    try {
      return await assignLessonInstructors(
        lessonId,
        instructorIds: const [],
        instructorNames: const [],
      );
    } catch (e) {
      debugPrint('CalendarService: Помилка зняття викладача: $e');
      return false;
    }
  }

  /// Перевірити чи користувач веде це заняття
  bool isUserInstructorForLesson(LessonModel lesson) {
    final currentUser = Globals.firebaseAuth.currentUser;
    if (currentUser == null) return false;

    final currentUserEmail = currentUser.email?.trim() ?? '';
    final currentUserName = Globals.profileManager.currentUserName.trim();

    return lesson.hasInstructorId(currentUser.uid) ||
        lesson.hasInstructorId(currentUserEmail) ||
        lesson.hasInstructorName(currentUserEmail) ||
        lesson.hasInstructorName(currentUserName);
  }

  String? getCurrentUserPrimaryAssignmentId() {
    final currentUser = Globals.firebaseAuth.currentUser;
    if (currentUser == null) return null;

    final normalizedUid = _normalizeInstructorAssignmentId(currentUser.uid);
    if (normalizedUid.isNotEmpty) {
      return normalizedUid;
    }

    final normalizedEmail = _normalizeInstructorAssignmentId(
      currentUser.email ?? '',
    );
    return normalizedEmail.isNotEmpty ? normalizedEmail : null;
  }

  List<String> getCurrentUserAssignmentCandidates() {
    final currentUser = Globals.firebaseAuth.currentUser;
    if (currentUser == null) return const [];

    final candidates = <String>[];
    final normalizedUid = _normalizeInstructorAssignmentId(currentUser.uid);
    if (normalizedUid.isNotEmpty) {
      candidates.add(normalizedUid);
    }

    final normalizedEmail = _normalizeInstructorAssignmentId(
      currentUser.email ?? '',
    );
    if (normalizedEmail.isNotEmpty && !candidates.contains(normalizedEmail)) {
      candidates.add(normalizedEmail);
    }

    return candidates;
  }

  String? getCurrentUserAssignmentIdForLesson(LessonModel lesson) {
    for (final candidate in getCurrentUserAssignmentCandidates()) {
      if (lesson.hasInstructorId(candidate)) {
        return candidate;
      }
    }
    return null;
  }

  bool isLessonCreatedByCurrentUser(LessonModel lesson) {
    final currentUser = Globals.firebaseAuth.currentUser;
    return currentUser != null && lesson.createdBy.trim() == currentUser.uid;
  }

  Future<bool> acknowledgeLesson(String lessonId) async {
    if (_isReadOnlyOfflineMode) {
      debugPrint(
        'CalendarService: acknowledgeLesson blocked in read-only offline',
      );
      return false;
    }

    try {
      final currentGroupId = Globals.profileManager.currentGroupId;
      final currentUser = Globals.firebaseAuth.currentUser;
      if (currentGroupId == null || currentUser == null) return false;

      final lesson = await getLessonById(lessonId);
      if (lesson == null) return false;

      final assignmentId = getCurrentUserAssignmentIdForLesson(lesson);
      if (assignmentId == null || !lesson.hasInstructorId(assignmentId)) {
        return false;
      }

      final updatedAcknowledgements = lesson.instructorAcknowledgements.map(
        (key, value) => MapEntry(key, value.toFirestore()),
      );
      final acknowledgedByName = Globals.profileManager.currentUserName.trim();
      final fallbackName = currentUser.email?.trim() ?? 'Викладач';

      updatedAcknowledgements[assignmentId] = {
        'acknowledgedAt': FieldValue.serverTimestamp(),
        'acknowledgedByUid': currentUser.uid,
        'acknowledgedByName': acknowledgedByName.isNotEmpty
            ? acknowledgedByName
            : fallbackName,
      };

      final updates = <String, dynamic>{
        'instructorAcknowledgements': updatedAcknowledgements,
      };

      if (lesson.acknowledgementResetAt == null) {
        updates['acknowledgementResetAt'] = Timestamp.fromDate(
          lesson.effectiveAcknowledgementResetAt,
        );
      }

      return await updateLesson(lessonId, updates);
    } catch (e) {
      debugPrint('CalendarService: Помилка підтвердження ознайомлення: $e');
      return false;
    }
  }

  /// Перевірити чи заняття потребує інструктора
  bool doesLessonNeedInstructor(LessonModel lesson) {
    return !lesson.hasInstructors;
  }

  @visibleForTesting
  static bool shouldResetAcknowledgementsForFields(Iterable<String> fields) {
    for (final field in fields) {
      if (_acknowledgementResetFields.contains(field)) {
        return true;
      }
    }
    return false;
  }

  @visibleForTesting
  static bool shouldResetAcknowledgements(
    LessonModel lesson,
    Map<String, dynamic> updates,
  ) {
    if (_isUnitChanged(lesson, updates['unit'])) {
      return true;
    }

    return _isLessonDateChanged(lesson, updates);
  }

  static bool _isUnitChanged(LessonModel lesson, dynamic updatedUnit) {
    if (updatedUnit == null) {
      return false;
    }

    return lesson.unit.trim() != updatedUnit.toString().trim();
  }

  static bool _isLessonDateChanged(
    LessonModel lesson,
    Map<String, dynamic> updates,
  ) {
    final updatedStartTime = _extractUpdatedDateTime(updates['startTime']);
    if (updatedStartTime != null &&
        !_isSameDate(lesson.startTime, updatedStartTime)) {
      return true;
    }

    final updatedEndTime = _extractUpdatedDateTime(updates['endTime']);
    if (updatedEndTime != null &&
        !_isSameDate(lesson.endTime, updatedEndTime)) {
      return true;
    }

    return false;
  }

  static DateTime? _extractUpdatedDateTime(dynamic value) {
    if (value == null) {
      return null;
    }
    if (value is Timestamp) {
      return value.toDate();
    }
    if (value is DateTime) {
      return value;
    }
    return null;
  }

  static bool _isSameDate(DateTime left, DateTime right) {
    return left.year == right.year &&
        left.month == right.month &&
        left.day == right.day;
  }

  String _normalizeInstructorAssignmentId(String instructorId) {
    return LessonModel.normalizeInstructorAssignmentId(instructorId);
  }

  LessonModel? _findCachedLessonById(String groupId, String lessonId) {
    final cachePrefix = 'cache::calendar::$groupId::';
    for (final key in Globals.appSnapshotStore.keysWithPrefix(cachePrefix)) {
      final snapshot = Globals.appSnapshotStore.getCachedSnapshot(key);
      final data = snapshot?.data;
      if (data is! List) {
        continue;
      }

      for (final item in data) {
        final lesson = LessonModel.fromMap(Map<String, dynamic>.from(item));
        if (lesson.id == lessonId) {
          return lesson;
        }
      }
    }

    return null;
  }

  String _cacheKeyForPeriod(
    String groupId,
    DateTime startDate,
    DateTime endDate,
  ) {
    return 'cache::calendar::$groupId::'
        '${startDate.toIso8601String()}::${endDate.toIso8601String()}';
  }

  DateTime _normalizeInclusiveEndDate(DateTime endDate) {
    if (CalendarUtils.isStartOfDay(endDate)) {
      return CalendarUtils.endOfDay(endDate);
    }
    return endDate;
  }

  bool get _isReadOnlyOfflineMode => Globals.appRuntimeState.isReadOnlyOffline;
}
