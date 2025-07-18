import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/lesson_model.dart';
import '../pages/calendar_page/calendar_utils.dart';
import '../globals.dart';

/// Моделі даних для дашборду
class UserStats {
  final int conductedLessons;
  final int totalLessons;
  final int thisWeekLessons;
  final int thisMonthLessons;
  final int incompleteCount; // Кількість незаповнених занять
  final double completionRate;

  const UserStats({
    required this.conductedLessons,
    required this.totalLessons,
    required this.thisWeekLessons,
    required this.thisMonthLessons,
    required this.incompleteCount, // За замовчуванням 0
    required this.completionRate,
  });

  static const empty = UserStats(
    conductedLessons: 0,
    totalLessons: 0,
    thisWeekLessons: 0,
    thisMonthLessons: 0,
    incompleteCount: 0,
    completionRate: 0.0,
  );
}

class DashboardFeed {
  final List<LessonModel> currentLessons;
  final List<LessonModel> todayWithoutInstructor;
  final List<LessonModel> tomorrowWithoutInstructor;
  final UserStats userStats;
  final DateTime lastUpdated;

  const DashboardFeed({
    required this.currentLessons,
    required this.todayWithoutInstructor,
    required this.tomorrowWithoutInstructor,
    required this.userStats,
    required this.lastUpdated,
  });

  static final empty = DashboardFeed(
    currentLessons: const [],
    todayWithoutInstructor: const [],
    tomorrowWithoutInstructor: const [],
    userStats: UserStats.empty,
    lastUpdated: DateTime(1970),
  );
}

enum StatsPeriod { week, month, quarter, year }

class DashboardService {
  static const String _cacheKey = 'dashboard_cache';
  static const Duration _cacheTimeout = Duration(minutes: 5);
  
  DashboardFeed? _cachedFeed;
  DateTime? _lastCacheTime;

  /// Отримати поточні заняття користувача (сьогодні)
  Future<List<LessonModel>> getCurrentUserLessons() async {
    try {
      final currentUser = Globals.firebaseAuth.currentUser;
      if (currentUser == null) return [];

      final today = DateTime.now();
      final tomorrow = today.add(const Duration(days: 1));
      final startOfDay = DateTime(today.year, today.month, today.day);
      final endOfDay = DateTime(tomorrow.year, tomorrow.month, tomorrow.day, 23, 59, 59);

      final currentGroupId = Globals.profileManager.currentGroupId;
      if (currentGroupId == null) return [];

      final querySnapshot = await FirebaseFirestore.instance
          .collection('lessons')
          .doc(currentGroupId)              
          .collection('items') 
          .where('startTime', isGreaterThanOrEqualTo: startOfDay)
          .where('startTime', isLessThanOrEqualTo: endOfDay)
          .where('instructorId', isEqualTo: currentUser.uid)
          .orderBy('startTime')
          .get();

      final lessons = querySnapshot.docs.map((doc) {
        final data = doc.data();
        return LessonModel.fromFirestore(data, doc.id);
      }).toList();

      return lessons;
    } catch (e) {
      if (kDebugMode) {
        print('Помилка отримання поточних занять: $e');
      }
      return [];
    }
  }

  /// Отримати заняття без викладача на певну дату
  Future<List<LessonModel>> getLessonsWithoutInstructor(DateTime date) async {
    try {
      final startOfDay = DateTime(date.year, date.month, date.day);
      final endOfDay = DateTime(date.year, date.month, date.day, 23, 59, 59);

      final currentGroupId = Globals.profileManager.currentGroupId;
      if (currentGroupId == null) return [];

      final querySnapshot = await FirebaseFirestore.instance
          .collection('lessons')
          .doc(currentGroupId)              
          .collection('items')
          .where('startTime', isGreaterThanOrEqualTo: startOfDay)
          .where('startTime', isLessThanOrEqualTo: endOfDay)
          .orderBy('startTime')
          .get();

      final lessons = querySnapshot.docs.map((doc) {
        final data = doc.data();
        return LessonModel.fromFirestore(data, doc.id);
      }).where((lesson) {
        // Заняття без викладача або з пустим викладачем
        return lesson.instructorId.isEmpty || 
               lesson.instructorId.trim().isEmpty ||
               lesson.instructorId == 'Не призначено';
      }).toList();

      return lessons;
    } catch (e) {
      if (kDebugMode) {
        print('Помилка отримання занять без викладача: $e');
      }
      return [];
    }
  }

  /// Отримати статистику користувача за період
  Future<UserStats> getUserStatistics(StatsPeriod period) async {
    try {
      final currentUser = Globals.firebaseAuth.currentUser;
      if (currentUser == null) return UserStats.empty;

      final currentGroupId = Globals.profileManager.currentGroupId;
      if (currentGroupId == null) return UserStats.empty;

      final now = DateTime.now();
      DateTime startDate;
      
      switch (period) {
        case StatsPeriod.week:
          startDate = CalendarUtils.getStartOfWeek(now);
          break;
        case StatsPeriod.month:
          startDate = CalendarUtils.getStartOfMonth(now);
          break;
        case StatsPeriod.quarter:
          final quarter = ((now.month - 1) ~/ 3) + 1;
          startDate = DateTime(now.year, (quarter - 1) * 3 + 1, 1);
          break;
        case StatsPeriod.year:
          startDate = DateTime(now.year, 1, 1);
          break;
      }

      // Всі заняття користувача за період
      final allLessonsQuery = await FirebaseFirestore.instance
          .collection('lessons')
          .doc(currentGroupId)              
          .collection('items')
          .where('instructorId', isEqualTo: currentUser.uid)
          .where('startTime', isGreaterThanOrEqualTo: startDate)
          .where('startTime', isLessThanOrEqualTo: now)
          .get();

      final allLessons = allLessonsQuery.docs.map((doc) {
        final data = doc.data();
        return LessonModel.fromFirestore(data, doc.id);
      }).toList();

      // Проведені заняття (в минулому)
      final conductedLessons = allLessons.where((lesson) {
        return lesson.endTime.isBefore(now);
      }).length;

      final incompleteCount = allLessons.where((lesson) {
        return !LessonStatusUtils.areCriticalFieldsFilled(lesson);
      }).length;

      // Статистика по типах занять
      final Map<String, int> lessonsByType = {};
      for (final lesson in allLessons) {
        final type = lesson.type.isNotEmpty ? lesson.type : 'Без типу';
        lessonsByType[type] = (lessonsByType[type] ?? 0) + 1;
      }

      // Статистика за тиждень
      final startOfWeek = CalendarUtils.getStartOfWeek(now);
      final weekLessons = allLessons.where((lesson) {
        return lesson.startTime.isAfter(startOfWeek);
      }).length;

      // Статистика за місяць
      final startOfMonth = CalendarUtils.getStartOfMonth(now);
      final monthLessons = allLessons.where((lesson) {
        return lesson.startTime.isAfter(startOfMonth);
      }).length;

      // Відсоток завершення
      final completionRate = allLessons.isNotEmpty 
          ? (conductedLessons / allLessons.length) * 100 
          : 0.0;

      return UserStats(
        conductedLessons: conductedLessons,
        totalLessons: allLessons.length,
        thisWeekLessons: weekLessons,
        thisMonthLessons: monthLessons,
        incompleteCount: incompleteCount,
        completionRate: completionRate,
      );
    } catch (e) {
      if (kDebugMode) {
        print('Помилка отримання статистики: $e');
      }
      return UserStats.empty;
    }
  }

  /// Отримати агрегований фід для головної сторінки
  Future<DashboardFeed> getDashboardFeed({bool forceRefresh = false}) async {
    // Перевіряємо кеш
    if (!forceRefresh && _cachedFeed != null && _lastCacheTime != null) {
      final timeSinceCache = DateTime.now().difference(_lastCacheTime!);
      if (timeSinceCache < _cacheTimeout) {
        return _cachedFeed!;
      }
    }

    try {
      final today = DateTime.now();
      final tomorrow = today.add(const Duration(days: 1));

      // Паралельно отримуємо всі дані
      final results = await Future.wait([
        getCurrentUserLessons(),
        getLessonsWithoutInstructor(today),
        getLessonsWithoutInstructor(tomorrow),
        getUserStatistics(StatsPeriod.month),
      ]);

      final feed = DashboardFeed(
        currentLessons: results[0] as List<LessonModel>,
        todayWithoutInstructor: results[1] as List<LessonModel>,
        tomorrowWithoutInstructor: results[2] as List<LessonModel>,
        userStats: results[3] as UserStats,
        lastUpdated: DateTime.now(),
      );

      // Кешуємо результат
      _cachedFeed = feed;
      _lastCacheTime = DateTime.now();

      return feed;
    } catch (e) {
      if (kDebugMode) {
        print('Помилка отримання фіду дашборду: $e');
      }
      return DashboardFeed.empty;
    }
  }

  /// Очистити кеш дашборду
  void clearCache() {
    _cachedFeed = null;
    _lastCacheTime = null;
  }

  /// Отримати заняття за певний період для звітів
  Future<List<LessonModel>> getLessonsForPeriod({
    required DateTime startDate,
    required DateTime endDate,
    String? instructorId,
  }) async {
    try {
      final currentGroupId = Globals.profileManager.currentGroupId;
      if (currentGroupId == null) return [];

      Query query = FirebaseFirestore.instance
          .collection('lessons')
          .doc(currentGroupId)              
          .collection('items')
          .where('startTime', isGreaterThanOrEqualTo: startDate)
          .where('startTime', isLessThanOrEqualTo: endDate);

      if (instructorId != null) {
        query = query.where('instructorId', isEqualTo: instructorId);
      }

      final querySnapshot = await query.orderBy('startTime').get();

      return querySnapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        return LessonModel.fromFirestore(data, doc.id);
      }).toList();
    } catch (e) {
      if (kDebugMode) {
        print('Помилка отримання занять за період: $e');
      }
      return [];
    }
  }

  /// Отримати статистику по всіх інструкторах (для admin)
  Future<Map<String, UserStats>> getInstructorsStatistics({
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    try {
      final currentGroupId = Globals.profileManager.currentGroupId;
      if (currentGroupId == null) return {};

      final querySnapshot = await FirebaseFirestore.instance
          .collection('lessons')
          .doc(currentGroupId)              
          .collection('items')
          .where('startTime', isGreaterThanOrEqualTo: startDate)
          .where('startTime', isLessThanOrEqualTo: endDate)
          .orderBy('startTime')
          .get();

      final allLessons = querySnapshot.docs.map((doc) {
        final data = doc.data();
        return LessonModel.fromFirestore(data, doc.id);
      }).toList();

      // Групуємо по інструкторах
      final Map<String, List<LessonModel>> lessonsByInstructor = {};
      for (final lesson in allLessons) {
        final instructor = lesson.instructorId.isEmpty 
            ? 'Без викладача' 
            : lesson.instructorName;
        lessonsByInstructor.putIfAbsent(instructor, () => []).add(lesson);
      }

      // Створюємо статистику для кожного інструктора
      final Map<String, UserStats> instructorStats = {};
      final now = DateTime.now();

      for (final entry in lessonsByInstructor.entries) {
        final instructor = entry.key;
        final lessons = entry.value;

        final conductedLessons = lessons.where((lesson) {
          return lesson.endTime.isBefore(now);
        }).length;

    
        final completionRate = lessons.isNotEmpty 
            ? (conductedLessons / lessons.length) * 100 
            : 0.0;

        instructorStats[instructor] = UserStats(
          conductedLessons: conductedLessons,
          totalLessons: lessons.length,
          thisWeekLessons: 0, // Не потрібно для звітів
          thisMonthLessons: 0, // Не потрібно для звітів
          incompleteCount: 0,
          completionRate: completionRate,
        );
      }

      return instructorStats;
    } catch (e) {
      if (kDebugMode) {
        print('Помилка отримання статистики інструкторів: $e');
      }
      return {};
    }
  }
}