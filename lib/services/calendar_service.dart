// lib/pages/calendar_page/services/calendar_service.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/lesson_model.dart';
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

    final snapshot = Globals.appSnapshotStore.getCachedSnapshot(
      _cacheKeyForPeriod(currentGroupId, startDate, endDate),
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

    try {
      debugPrint(
        'CalendarService: Завантаження занять для групи $currentGroupId від $startDate до $endDate',
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
          .where('startTime', isLessThanOrEqualTo: Timestamp.fromDate(endDate))
          .orderBy('startTime')
          .get();

      final lessons = querySnapshot.docs
          .map((doc) => LessonModel.fromFirestore(doc.data(), doc.id))
          .toList();

      await Globals.appSnapshotStore.saveCachedSnapshot(
        _cacheKeyForPeriod(currentGroupId, startDate, endDate),
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

    debugPrint('📅 getLessonsForWeek:');
    debugPrint(
      '  Selected: ${selectedDate.day}.${selectedDate.month}.${selectedDate.year}',
    );
    debugPrint(
      '  Week: ${startOfWeek.day}.${startOfWeek.month} - ${endOfWeek.day}.${endOfWeek.month}',
    );

    return await getLessonsForPeriod(
      startDate: startOfWeek,
      endDate: endOfWeek,
    );
  }

  /// Отримати заняття для дня
  Future<List<LessonModel>> getLessonsForDay(DateTime selectedDate) async {
    final startOfDay = DateTime(
      selectedDate.year,
      selectedDate.month,
      selectedDate.day,
    );
    final endOfDay = startOfDay.add(const Duration(hours: 23, minutes: 59));

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
        'unit': lesson.unit,
        'instructorName': lesson.hasInstructors
            ? lesson.instructorName
            : 'Не призначено',
        'instructorId': lesson.instructorId,
        'instructorIds': lesson.instructorIds,
        'instructorNames': lesson.instructorNames,
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

      Query query = _firestore
          .collection('lessons')
          .doc(currentGroupId)
          .collection('items')
          .where(
            'startTime',
            isGreaterThanOrEqualTo: Timestamp.fromDate(startDate),
          )
          .where('startTime', isLessThanOrEqualTo: Timestamp.fromDate(endDate));

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

    return _firestore
        .collection('lessons')
        .doc(currentGroupId)
        .collection('items')
        .where(
          'startTime',
          isGreaterThanOrEqualTo: Timestamp.fromDate(startDate),
        )
        .where('startTime', isLessThanOrEqualTo: Timestamp.fromDate(endDate))
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

      return await updateLesson(lessonId, {
        'instructorId': normalizedInstructorIds.isNotEmpty
            ? normalizedInstructorIds.first
            : '',
        'instructorName': normalizedInstructorNames.isNotEmpty
            ? normalizedInstructorNames.first
            : '',
        'instructorIds': normalizedInstructorIds,
        'instructorNames': normalizedInstructorNames,
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

  bool get _isReadOnlyOfflineMode => Globals.appRuntimeState.isReadOnlyOffline;
}
