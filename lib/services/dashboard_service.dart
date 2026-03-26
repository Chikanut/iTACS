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

  Map<String, dynamic> toMap() {
    return {
      'conductedLessons': conductedLessons,
      'totalLessons': totalLessons,
      'thisWeekLessons': thisWeekLessons,
      'thisMonthLessons': thisMonthLessons,
      'incompleteCount': incompleteCount,
      'completionRate': completionRate,
    };
  }

  factory UserStats.fromMap(Map<String, dynamic> map) {
    return UserStats(
      conductedLessons: (map['conductedLessons'] ?? 0) as int,
      totalLessons: (map['totalLessons'] ?? 0) as int,
      thisWeekLessons: (map['thisWeekLessons'] ?? 0) as int,
      thisMonthLessons: (map['thisMonthLessons'] ?? 0) as int,
      incompleteCount: (map['incompleteCount'] ?? 0) as int,
      completionRate: (map['completionRate'] ?? 0).toDouble(),
    );
  }
}

class DashboardFeed {
  final LessonModel? nextLesson;
  final List<LessonModel> lessonsRequiringAcknowledgement;
  final List<LessonModel> todayWithoutInstructor;
  final List<LessonModel> tomorrowWithoutInstructor;
  final UserStats userStats;
  final DateTime lastUpdated;

  const DashboardFeed({
    required this.nextLesson,
    required this.lessonsRequiringAcknowledgement,
    required this.todayWithoutInstructor,
    required this.tomorrowWithoutInstructor,
    required this.userStats,
    required this.lastUpdated,
  });

  static final empty = DashboardFeed(
    nextLesson: null,
    lessonsRequiringAcknowledgement: const [],
    todayWithoutInstructor: const [],
    tomorrowWithoutInstructor: const [],
    userStats: UserStats.empty,
    lastUpdated: DateTime(1970),
  );

  Map<String, dynamic> toMap() {
    return {
      'nextLesson': nextLesson?.toMap(),
      'lessonsRequiringAcknowledgement': lessonsRequiringAcknowledgement
          .map((lesson) => lesson.toMap())
          .toList(),
      'todayWithoutInstructor': todayWithoutInstructor
          .map((lesson) => lesson.toMap())
          .toList(),
      'tomorrowWithoutInstructor': tomorrowWithoutInstructor
          .map((lesson) => lesson.toMap())
          .toList(),
      'userStats': userStats.toMap(),
      'lastUpdated': lastUpdated.toIso8601String(),
    };
  }

  factory DashboardFeed.fromMap(Map<String, dynamic> map) {
    return DashboardFeed(
      nextLesson: map['nextLesson'] is Map
          ? LessonModel.fromMap(Map<String, dynamic>.from(map['nextLesson']))
          : null,
      lessonsRequiringAcknowledgement:
          (map['lessonsRequiringAcknowledgement'] as List<dynamic>? ??
                  const <dynamic>[])
              .map(
                (item) => LessonModel.fromMap(Map<String, dynamic>.from(item)),
              )
              .toList(),
      todayWithoutInstructor:
          (map['todayWithoutInstructor'] as List<dynamic>? ?? const <dynamic>[])
              .map(
                (item) => LessonModel.fromMap(Map<String, dynamic>.from(item)),
              )
              .toList(),
      tomorrowWithoutInstructor:
          (map['tomorrowWithoutInstructor'] as List<dynamic>? ??
                  const <dynamic>[])
              .map(
                (item) => LessonModel.fromMap(Map<String, dynamic>.from(item)),
              )
              .toList(),
      userStats: map['userStats'] is Map
          ? UserStats.fromMap(Map<String, dynamic>.from(map['userStats']))
          : UserStats.empty,
      lastUpdated:
          DateTime.tryParse((map['lastUpdated'] ?? '').toString()) ??
          DateTime.fromMillisecondsSinceEpoch(0),
    );
  }
}

enum StatsPeriod { week, month, quarter, year }

class DashboardService {
  static const String _cacheKey = 'dashboard_cache';
  static const Duration _cacheTimeout = Duration(minutes: 5);

  DashboardFeed? _cachedFeed;
  DateTime? _lastCacheTime;

  DashboardFeed? getCachedDashboardFeed() {
    final snapshot = Globals.appSnapshotStore.getCachedSnapshot(
      _dashboardCacheKey(),
    );
    final data = snapshot?.data;
    if (data is! Map) {
      return null;
    }

    try {
      return DashboardFeed.fromMap(Map<String, dynamic>.from(data));
    } catch (e) {
      if (kDebugMode) {
        print('Помилка читання dashboard snapshot: $e');
      }
      return null;
    }
  }

  /// Отримати найближчі заняття користувача в межах наступного місяця
  Future<List<LessonModel>> getCurrentUserUpcomingLessons() async {
    try {
      if (Globals.firebaseAuth.currentUser == null) return [];

      final now = DateTime.now();
      final startOfDay = DateTime(now.year, now.month, now.day);
      final endOfRange = DateTime(
        now.year,
        now.month,
        now.day + 31,
        23,
        59,
        59,
      );

      final currentGroupId = Globals.profileManager.currentGroupId;
      if (currentGroupId == null) return [];

      final lessons = await Globals.calendarService.getLessonsForPeriod(
        startDate: startOfDay,
        endDate: endOfRange,
        groupId: currentGroupId,
      );

      return lessons
          .where(
            (lesson) =>
                Globals.calendarService.isUserInstructorForLesson(lesson) &&
                lesson.endTime.isAfter(now),
          )
          .toList()
        ..sort((a, b) => a.startTime.compareTo(b.startTime));
    } catch (e) {
      if (kDebugMode) {
        print('Помилка отримання поточних занять: $e');
      }
      return [];
    }
  }

  Future<List<LessonModel>> getLessonsRequiringAcknowledgement(
    List<LessonModel> upcomingLessons,
  ) async {
    final assignmentId = upcomingLessons.isEmpty
        ? null
        : Globals.calendarService.getCurrentUserPrimaryAssignmentId();
    if (assignmentId == null) return [];

    final identityCandidates = Globals.calendarService
        .getCurrentUserAssignmentCandidates();

    return upcomingLessons.where((lesson) {
      final status = LessonStatusUtils.getAcknowledgementStatusForInstructor(
        lesson,
        instructorAssignmentId: assignmentId,
        instructorIdentityCandidates: identityCandidates,
      );

      return status == LessonAcknowledgementStatus.pending ||
          status == LessonAcknowledgementStatus.urgent;
    }).toList()..sort((a, b) => a.startTime.compareTo(b.startTime));
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

      final lessons = querySnapshot.docs
          .map((doc) {
            final data = doc.data();
            return LessonModel.fromFirestore(data, doc.id);
          })
          .where((lesson) => !lesson.hasInstructors)
          .toList();

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

      final allLessons = (await Globals.calendarService.getLessonsForPeriod(
        startDate: startDate,
        endDate: now,
        groupId: currentGroupId,
      )).where(Globals.calendarService.isUserInstructorForLesson).toList();

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
        getCurrentUserUpcomingLessons(),
        getLessonsWithoutInstructor(today),
        getLessonsWithoutInstructor(tomorrow),
        getUserStatistics(StatsPeriod.month),
      ]);

      final upcomingLessons = results[0] as List<LessonModel>;
      final nextLesson = upcomingLessons.isNotEmpty
          ? upcomingLessons.first
          : null;
      final lessonsRequiringAcknowledgement =
          await getLessonsRequiringAcknowledgement(upcomingLessons);

      final feed = DashboardFeed(
        nextLesson: nextLesson,
        lessonsRequiringAcknowledgement: lessonsRequiringAcknowledgement,
        todayWithoutInstructor: results[1] as List<LessonModel>,
        tomorrowWithoutInstructor: results[2] as List<LessonModel>,
        userStats: results[3] as UserStats,
        lastUpdated: DateTime.now(),
      );

      // Кешуємо результат
      _cachedFeed = feed;
      _lastCacheTime = DateTime.now();
      await Globals.appSnapshotStore.saveCachedSnapshot(
        _dashboardCacheKey(),
        feed.toMap(),
      );

      return feed;
    } catch (e) {
      if (kDebugMode) {
        print('Помилка отримання фіду дашборду: $e');
      }

      final cachedFeed = getCachedDashboardFeed();
      if (cachedFeed != null) {
        _cachedFeed = cachedFeed;
        _lastCacheTime = DateTime.now();
        return cachedFeed;
      }

      return DashboardFeed.empty;
    }
  }

  /// Очистити кеш дашборду
  void clearCache() {
    _cachedFeed = null;
    _lastCacheTime = null;
  }

  String _dashboardCacheKey() {
    final groupId = Globals.profileManager.currentGroupId ?? 'no-group';
    final userScope =
        Globals.profileManager.currentUserEmail ??
        Globals.profileManager.currentUserId ??
        'anonymous';
    return 'cache::$_cacheKey::$groupId::$userScope';
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

      final querySnapshot = await query.orderBy('startTime').get();

      var lessons = querySnapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        return LessonModel.fromFirestore(data, doc.id);
      }).toList();

      if (instructorId != null && instructorId.trim().isNotEmpty) {
        final normalizedInstructorId = instructorId.trim().toLowerCase();
        lessons = lessons
            .where(
              (lesson) =>
                  lesson.hasInstructorId(instructorId) ||
                  lesson.hasInstructorId(normalizedInstructorId),
            )
            .toList();
      }

      return lessons;
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
        if (!lesson.hasInstructors) {
          lessonsByInstructor
              .putIfAbsent('Без викладача', () => [])
              .add(lesson);
          continue;
        }

        for (final instructorName in lesson.instructorNames) {
          lessonsByInstructor.putIfAbsent(instructorName, () => []).add(lesson);
        }
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
