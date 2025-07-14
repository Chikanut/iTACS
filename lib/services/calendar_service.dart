// lib/pages/calendar_page/services/calendar_service.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../pages/calendar_page/models/lesson_model.dart';
import '../../../globals.dart';

class CalendarService {
  static final CalendarService _instance = CalendarService._internal();
  factory CalendarService() => _instance;
  CalendarService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Отримати заняття для поточної групи на вказаний період
  Future<List<LessonModel>> getLessonsForPeriod({
    required DateTime startDate,
    required DateTime endDate,
    String? groupId,
  }) async {
    try {
      final currentGroupId = groupId ?? Globals.profileManager.currentGroupId;
      if (currentGroupId == null) {
        debugPrint('CalendarService: Немає активної групи');
        return [];
      }

      debugPrint('CalendarService: Завантаження занять для групи $currentGroupId від $startDate до $endDate');

      // Запит до Firestore
      final querySnapshot = await _firestore
          .collection('lessons')
          .doc(currentGroupId)
          .collection('items')
          .where('startTime', isGreaterThanOrEqualTo: Timestamp.fromDate(startDate))
          .where('startTime', isLessThanOrEqualTo: Timestamp.fromDate(endDate))
          .orderBy('startTime')
          .get();

      final lessons = querySnapshot.docs
          .map((doc) => LessonModel.fromMap(doc.id, doc.data()))
          .toList();

      debugPrint('CalendarService: Знайдено ${lessons.length} занять');
      return lessons;
    } catch (e) {
      debugPrint('CalendarService: Помилка завантаження занять: $e');
      return [];
    }
  }

  /// Отримати заняття для тижня
  Future<List<LessonModel>> getLessonsForWeek(DateTime selectedDate) async {
    final startOfWeek = selectedDate.subtract(Duration(days: selectedDate.weekday - 1));
    final endOfWeek = startOfWeek.add(const Duration(days: 6, hours: 23, minutes: 59));
    
    return await getLessonsForPeriod(
      startDate: startOfWeek,
      endDate: endOfWeek,
    );
  }

  /// Отримати заняття для дня
  Future<List<LessonModel>> getLessonsForDay(DateTime selectedDate) async {
    final startOfDay = DateTime(selectedDate.year, selectedDate.month, selectedDate.day);
    final endOfDay = startOfDay.add(const Duration(hours: 23, minutes: 59));
    
    return await getLessonsForPeriod(
      startDate: startOfDay,
      endDate: endOfDay,
    );
  }

  /// Створити нове заняття
  Future<String?> createLesson(LessonModel lesson) async {
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
        'unit': lesson.unit,
        'instructor': lesson.instructor,
        'location': lesson.location,
        'maxParticipants': lesson.maxParticipants,
        'currentParticipants': 0,
        'participants': <String>[],
        'status': 'scheduled',
        'tags': lesson.tags,
        'createdBy': currentUser.uid,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'recurrence': lesson.recurrence != null ? {
          'type': lesson.recurrence!.type,
          'interval': lesson.recurrence!.interval,
          'endDate': Timestamp.fromDate(lesson.recurrence!.endDate),
        } : null,
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

  /// Оновити заняття
  Future<bool> updateLesson(String lessonId, Map<String, dynamic> updates) async {
    try {
      final currentGroupId = Globals.profileManager.currentGroupId;
      if (currentGroupId == null) return false;

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

      debugPrint('CalendarService: Успішно скасовано реєстрацію на заняття $lessonId');
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
          .where('startTime', isGreaterThanOrEqualTo: Timestamp.fromDate(startDate))
          .where('startTime', isLessThanOrEqualTo: Timestamp.fromDate(endDate));

      if (status != null) {
        query = query.where('status', isEqualTo: status);
      }

      final querySnapshot = await query.orderBy('startTime').get();

      var lessons = querySnapshot.docs
          .map((doc) => LessonModel.fromMap(doc.id, doc.data() as Map<String, dynamic>))
          .toList();

      // Клієнтська фільтрація для tags та instructors
      if (tags != null && tags.isNotEmpty) {
        lessons = lessons.where((lesson) =>
            lesson.tags.any((tag) => tags.contains(tag))).toList();
      }

      if (instructors != null && instructors.isNotEmpty) {
        lessons = lessons.where((lesson) =>
            instructors.contains(lesson.instructor)).toList();
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
        .where('startTime', isGreaterThanOrEqualTo: Timestamp.fromDate(startDate))
        .where('startTime', isLessThanOrEqualTo: Timestamp.fromDate(endDate))
        .orderBy('startTime')
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => LessonModel.fromMap(doc.id, doc.data()))
            .toList());
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
    final completedLessons = lessons.where((l) => l.status == 'completed').length;
    final scheduledLessons = lessons.where((l) => l.status == 'scheduled').length;
    final cancelledLessons = lessons.where((l) => l.status == 'cancelled').length;

    final totalParticipants = lessons.fold<int>(0, (sum, lesson) => sum + lesson.currentParticipants);
    final totalCapacity = lessons.fold<int>(0, (sum, lesson) => sum + lesson.maxParticipants);
    final occupancyRate = totalCapacity > 0 ? totalParticipants / totalCapacity : 0.0;

    return {
      'totalLessons': totalLessons,
      'completedLessons': completedLessons,
      'scheduledLessons': scheduledLessons,
      'cancelledLessons': cancelledLessons,
      'totalParticipants': totalParticipants,
      'totalCapacity': totalCapacity,
      'occupancyRate': occupancyRate,
    };
  }
}