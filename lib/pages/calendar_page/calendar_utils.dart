import 'package:flutter/material.dart';
import '../../models/lesson_model.dart';
import 'package:intl/intl.dart';

enum InstructorLessonStatus { needsInstructor, assigned, teaching }

enum LessonProgressStatus {
  scheduled, // Заплановано
  inProgress, // В процесі
  completed, // Завершено
}

enum LessonReadinessStatus {
  notReady, // Не готове (критичні поля не заповнені)
  needsInstructor, // Потрібен інструктор
  ready, // Готове до проведення
  inProgressReady, // В процесі (все ОК)
  inProgressNotReady, // В процесі (але є проблеми)
  completedReady, // Завершено (все ОК)
  completedNotReady, // Завершено (але є проблеми з даними)
}

extension LessonProgressStatusExtension on LessonProgressStatus {
  String get label {
    switch (this) {
      case LessonProgressStatus.scheduled:
        return 'Заплановано';
      case LessonProgressStatus.inProgress:
        return 'Проводиться';
      case LessonProgressStatus.completed:
        return 'Завершено';
    }
  }

  IconData get icon {
    switch (this) {
      case LessonProgressStatus.scheduled:
        return Icons.schedule;
      case LessonProgressStatus.inProgress:
        return Icons.play_circle;
      case LessonProgressStatus.completed:
        return Icons.check_circle;
    }
  }
}

extension LessonReadinessStatusExtension on LessonReadinessStatus {
  Color get color {
    switch (this) {
      case LessonReadinessStatus.notReady:
        return Colors.red; // 🔴 Критичні поля не заповнені
      case LessonReadinessStatus.needsInstructor:
        return Colors.orange; // 🟠 Потрібен інструктор
      case LessonReadinessStatus.ready:
        return Colors.green; // 🟢 Готове до проведення
      case LessonReadinessStatus.inProgressReady:
        return Colors.blue; // 🔵 В процесі (все ОК)
      case LessonReadinessStatus.inProgressNotReady:
        return Colors.red; // 🔴 В процесі але є проблеми
      case LessonReadinessStatus.completedReady:
        return Colors.grey; // ⚫ Завершено (все ОК)
      case LessonReadinessStatus.completedNotReady:
        return Colors.red; // 🔴 Завершено але є проблеми
    }
  }

  String get label {
    switch (this) {
      case LessonReadinessStatus.notReady:
        return 'Не заповнено';
      case LessonReadinessStatus.needsInstructor:
        return 'Потрібен викладач';
      case LessonReadinessStatus.ready:
        return 'Готове';
      case LessonReadinessStatus.inProgressReady:
        return 'Проводиться';
      case LessonReadinessStatus.inProgressNotReady:
        return 'Проводиться (є проблеми)';
      case LessonReadinessStatus.completedReady:
        return 'Завершено';
      case LessonReadinessStatus.completedNotReady:
        return 'Завершено (є проблеми)';
    }
  }

  IconData get icon {
    switch (this) {
      case LessonReadinessStatus.notReady:
        return Icons.error;
      case LessonReadinessStatus.needsInstructor:
        return Icons.person_add;
      case LessonReadinessStatus.ready:
        return Icons.check_circle;
      case LessonReadinessStatus.inProgressReady:
        return Icons.play_circle;
      case LessonReadinessStatus.inProgressNotReady:
        return Icons.warning;
      case LessonReadinessStatus.completedReady:
        return Icons.done_all;
      case LessonReadinessStatus.completedNotReady:
        return Icons.error_outline;
    }
  }

  String get description {
    switch (this) {
      case LessonReadinessStatus.notReady:
        return 'Не заповнені критичні поля для звітності';
      case LessonReadinessStatus.needsInstructor:
        return 'Не призначений інструктор';
      case LessonReadinessStatus.ready:
        return 'Всі дані заповнені, готове до проведення';
      case LessonReadinessStatus.inProgressReady:
        return 'Заняття проводиться, всі дані в порядку';
      case LessonReadinessStatus.inProgressNotReady:
        return 'Заняття проводиться, але є проблеми з даними для звітності';
      case LessonReadinessStatus.completedReady:
        return 'Заняття завершено, всі дані для звітності заповнені';
      case LessonReadinessStatus.completedNotReady:
        return 'Заняття завершено, але потрібно заповнити дані для звітності';
    }
  }
}

// ОНОВЛЕНИЙ LessonStatusUtils
class LessonStatusUtils {
  // Критичні поля для звітності - ДОДАНО trainingPeriod
  static const List<String> criticalFields = [
    'instructorId',
    'location',
    'unit',
    'maxParticipants',
    'trainingPeriod', // 👈 ДОДАНО
  ];

  /// Перевірити чи заповнені критичні поля
  static bool areCriticalFieldsFilled(LessonModel lesson) {
    // Інструктор
    if (lesson.instructorId.isEmpty || lesson.instructorId == 'Не призначено') {
      return false;
    }

    // Місце проведення
    if (lesson.location.isEmpty) {
      return false;
    }

    // Підрозділ
    if (lesson.unit.isEmpty) {
      return false;
    }

    // Кількість учнів
    if (lesson.maxParticipants <= 0) {
      return false;
    }

    // Період навчання 👈 ДОДАНО
    if (lesson.trainingPeriod.isEmpty) {
      return false;
    }

    return true;
  }

  static LessonProgressStatus getProgressStatus(LessonModel lesson) {
    final now = DateTime.now();

    if (now.isBefore(lesson.startTime)) {
      return LessonProgressStatus.scheduled;
    } else if (now.isAfter(lesson.endTime)) {
      return LessonProgressStatus.completed;
    } else {
      return LessonProgressStatus.inProgress;
    }
  }

  /// Визначити статус готовності заняття
  static LessonReadinessStatus getReadinessStatus(LessonModel lesson) {
    final progressStatus = getProgressStatus(lesson);
    final criticalFieldsFilled = areCriticalFieldsFilled(lesson);
    final hasInstructor =
        lesson.instructorId.isNotEmpty &&
        lesson.instructorId != 'Не призначено';

    switch (progressStatus) {
      case LessonProgressStatus.scheduled:
        if (!criticalFieldsFilled) {
          return LessonReadinessStatus.notReady;
        } else if (!hasInstructor) {
          return LessonReadinessStatus.needsInstructor;
        } else {
          return LessonReadinessStatus.ready;
        }

      case LessonProgressStatus.inProgress:
        if (!criticalFieldsFilled) {
          return LessonReadinessStatus.inProgressNotReady;
        } else {
          return LessonReadinessStatus.inProgressReady;
        }

      case LessonProgressStatus.completed:
        if (!criticalFieldsFilled) {
          return LessonReadinessStatus.completedNotReady;
        } else {
          return LessonReadinessStatus.completedReady;
        }
    }
  }

  /// Отримати комбінований статус (для простішого використання)
  static ({
    LessonProgressStatus progress,
    LessonReadinessStatus readiness,
    List<String> issues,
  })
  getFullStatus(LessonModel lesson) {
    final progress = getProgressStatus(lesson);
    final readiness = getReadinessStatus(lesson);
    final issues = getMissingCriticalFields(lesson);

    return (progress: progress, readiness: readiness, issues: issues);
  }

  /// Отримати список незаповнених критичних полів
  static List<String> getMissingCriticalFields(LessonModel lesson) {
    final List<String> missing = [];

    if (lesson.instructorId.isEmpty || lesson.instructorId == 'Не призначено') {
      missing.add('Інструктор');
    }

    if (lesson.location.isEmpty) {
      missing.add('Місце проведення');
    }

    if (lesson.unit.isEmpty) {
      missing.add('Підрозділ');
    }

    if (lesson.maxParticipants <= 0) {
      missing.add('Кількість учнів');
    }

    if (lesson.trainingPeriod.isEmpty) {
      missing.add('Період навчання'); // 👈 ДОДАНО
    }

    return missing;
  }

  /// Отримати прогрес заповнення критичних полів (для прогрес-бару)
  static double getCriticalFieldsProgress(LessonModel lesson) {
    int filledCount = 0;
    const int totalCount = 5; // 👈 ЗБІЛЬШЕНО до 5 критичних полів

    if (lesson.instructorId.isNotEmpty &&
        lesson.instructorId != 'Не призначено') {
      filledCount++;
    }

    if (lesson.location.isNotEmpty) {
      filledCount++;
    }

    if (lesson.unit.isNotEmpty) {
      filledCount++;
    }

    if (lesson.maxParticipants > 0) {
      filledCount++;
    }

    if (lesson.trainingPeriod.isNotEmpty) {
      // 👈 ДОДАНО
      filledCount++;
    }

    return filledCount / totalCount;
  }

  /// Форматувати період навчання для відображення
  static String formatTrainingPeriod(String trainingPeriod) {
    if (trainingPeriod.isEmpty) return 'Не вказано';

    // Якщо період у форматі "dd.MM.yyyy - dd.MM.yyyy"
    if (trainingPeriod.contains(' - ')) {
      final parts = trainingPeriod.split(' - ');
      if (parts.length == 2) {
        return '${parts[0]} - ${parts[1]}';
      }
    }

    return trainingPeriod;
  }

  /// Валідувати формат періоду навчання
  static bool isValidTrainingPeriod(String period) {
    if (period.isEmpty) return false;

    // Перевіряємо формат "dd.MM.yyyy - dd.MM.yyyy"
    final regex = RegExp(r'^\d{2}\.\d{2}\.\d{4} - \d{2}\.\d{2}\.\d{4}$');
    return regex.hasMatch(period);
  }

  /// Створити період навчання з дат
  static String createTrainingPeriod(DateTime startDate, DateTime endDate) {
    final formatter = DateFormat('dd.MM.yyyy');
    return '${formatter.format(startDate)} - ${formatter.format(endDate)}';
  }

  /// Отримати дати початку та закінчення з періоду
  static (DateTime?, DateTime?) parseTrainingPeriod(String period) {
    if (!isValidTrainingPeriod(period)) return (null, null);

    final parts = period.split(' - ');
    try {
      final formatter = DateFormat('dd.MM.yyyy');
      final startDate = formatter.parse(parts[0]);
      final endDate = formatter.parse(parts[1]);
      return (startDate, endDate);
    } catch (e) {
      return (null, null);
    }
  }

  /// Перевірити чи період активний (поточна дата в межах періоду)
  static bool isTrainingPeriodActive(String period) {
    final (startDate, endDate) = parseTrainingPeriod(period);
    if (startDate == null || endDate == null) return false;

    final now = DateTime.now();
    return now.isAfter(startDate) &&
        now.isBefore(endDate.add(const Duration(days: 1)));
  }
}

extension InstructorLessonStatusExtension on InstructorLessonStatus {
  Color get color {
    switch (this) {
      case InstructorLessonStatus.needsInstructor:
        return Colors.orange;
      case InstructorLessonStatus.assigned:
        return Colors.blue;
      case InstructorLessonStatus.teaching:
        return Colors.green;
    }
  }

  String get label {
    switch (this) {
      case InstructorLessonStatus.needsInstructor:
        return 'Потрібен викладач';
      case InstructorLessonStatus.assigned:
        return 'Викладач призначений';
      case InstructorLessonStatus.teaching:
        return 'Ви викладаєте';
    }
  }

  IconData get icon {
    switch (this) {
      case InstructorLessonStatus.needsInstructor:
        return Icons.person_add;
      case InstructorLessonStatus.assigned:
        return Icons.person;
      case InstructorLessonStatus.teaching:
        return Icons.school;
    }
  }
}

class CalendarUtils {
  // Константи для календаря
  static const double timeColumnWidth = 60.0;
  static const double hourHeight = 80.0;
  static const double minuteHeight = hourHeight / 60.0;

  // Отримати мінімальний час з списку занять
  static double getMinHourFromLessons(List<LessonModel> lessons) {
    if (lessons.isEmpty) return 8.0; // fallback якщо немає занять

    final minTime = lessons
        .map(
          (lesson) => lesson.startTime.hour + (lesson.startTime.minute / 60.0),
        )
        .reduce((a, b) => a < b ? a : b);

    // Округлюємо вниз до цілої години з буфером 30 хв
    return (minTime - 0.5).floorToDouble().clamp(0.0, 23.0);
  }

  /// Отримати максимальний час з списку занять
  static double getMaxHourFromLessons(List<LessonModel> lessons) {
    if (lessons.isEmpty) return 20.0; // fallback якщо немає занять

    final maxTime = lessons
        .map((lesson) => lesson.endTime.hour + (lesson.endTime.minute / 60.0))
        .reduce((a, b) => a > b ? a : b);

    // Округлюємо вгору до цілої години з буфером 30 хв
    return (maxTime + 0.5).ceilToDouble().clamp(1.0, 24.0);
  }

  // Кольори для різних рот
  static const Map<String, Color> groupColors = {
    '1-а рота': Color(0xFFE3F2FD),
    '2-а рота': Color(0xFFF3E5F5),
    '3-я рота': Color(0xFFE8F5E8),
    '4-а рота': Color(0xFFFFF3E0),
    '5-а рота': Color(0xFFFCE4EC),
    '6-а рота': Color(0xFFF1F8E9),
  };

  // Іконки для типів занять
  static const Map<String, IconData> lessonTypeIcons = {
    'тактика': Icons.military_tech,
    'фізична': Icons.fitness_center,
    'стройова': Icons.format_align_center,
    'теорія': Icons.school,
    'технічна': Icons.build,
    'водіння': Icons.directions_car,
    'стрільби': Icons.gps_fixed,
  };

  /// Отримати кольор для групи
  static Color getGroupColor(String groupName) {
    return groupColors[groupName] ?? Colors.grey.shade200;
  }

  /// Отримати іконку для типу заняття
  static IconData getLessonTypeIcon(String lessonType) {
    final type = lessonType.toLowerCase();
    return lessonTypeIcons[type] ?? Icons.event;
  }

  /// Перевірити чи перекриваються часи
  static bool timesOverlap(
    TimeOfDay start1,
    TimeOfDay end1,
    TimeOfDay start2,
    TimeOfDay end2,
  ) {
    final start1Minutes = start1.hour * 60 + start1.minute;
    final end1Minutes = end1.hour * 60 + end1.minute;
    final start2Minutes = start2.hour * 60 + start2.minute;
    final end2Minutes = end2.hour * 60 + end2.minute;

    // Заняття перекриваються якщо:
    // (start1 < end2) AND (start2 < end1)
    return start1Minutes < end2Minutes && start2Minutes < end1Minutes;
  }

  /// Отримати позицію елемента в часовій сітці
  static double getTimePosition(TimeOfDay time, double minHour) {
    return (time.hour - minHour) * hourHeight + (time.minute * minuteHeight);
  }

  /// Отримати висоту елемента за тривалістю
  static double getDurationHeight(TimeOfDay start, TimeOfDay end) {
    final startMinutes = start.hour * 60 + start.minute;
    final endMinutes = end.hour * 60 + end.minute;
    final durationMinutes = endMinutes - startMinutes;
    return durationMinutes * minuteHeight;
  }

  /// Форматувати час
  static String formatTime(TimeOfDay time) {
    return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
  }

  /// Отримати назву дня тижня
  static String getDayName(int weekday, {bool short = true}) {
    if (short) {
      const days = ['ПН', 'ВТ', 'СР', 'ЧТ', 'ПТ', 'СБ', 'НД'];
      return days[weekday - 1];
    } else {
      const days = [
        'Понеділок',
        'Вівторок',
        'Середа',
        'Четвер',
        'П\'ятниця',
        'Субота',
        'Неділя',
      ];
      return days[weekday - 1];
    }
  }

  /// Отримати назву місяця
  static String getMonthName(int month, {bool short = false}) {
    const monthNames = [
      'Січень',
      'Лютий',
      'Березень',
      'Квітень',
      'Травень',
      'Червень',
      'Липень',
      'Серпень',
      'Вересень',
      'Жовтень',
      'Листопад',
      'Грудень',
    ];

    const shortMonthNames = [
      'Січ',
      'Лют',
      'Бер',
      'Кві',
      'Тра',
      'Чер',
      'Лип',
      'Сер',
      'Вер',
      'Жов',
      'Лис',
      'Гру',
    ];

    if (month < 1 || month > 12) return '';

    return short ? shortMonthNames[month - 1] : monthNames[month - 1];
  }

  /// Перевірити чи дата сьогоднішня
  static bool isToday(DateTime date) {
    final now = DateTime.now();
    return date.year == now.year &&
        date.month == now.month &&
        date.day == now.day;
  }

  /// Отримати дні тижня для заданої дати
  static List<DateTime> getWeekDays(DateTime selectedDate) {
    final startOfWeek = getStartOfWeek(selectedDate);
    final weekDays = List.generate(
      7,
      (index) => startOfWeek.add(Duration(days: index)),
    );

    // 👈 ДОДАТИ DEBUG
    debugPrint('📅 getWeekDays:');
    debugPrint(
      '  Selected date: ${selectedDate.day}.${selectedDate.month}.${selectedDate.year}',
    );
    debugPrint('  Week days:');
    for (int i = 0; i < weekDays.length; i++) {
      final day = weekDays[i];
      final dayName = getDayName(day.weekday);
      debugPrint('    $i ($dayName): ${day.day}.${day.month}.${day.year}');
    }

    return weekDays;
  }

  /// Отримати початок тижня
  static DateTime getStartOfWeek(DateTime date) {
    final daysFromMonday = date.weekday - 1;
    final startOfWeek = date.subtract(Duration(days: daysFromMonday));

    // 👈 ВИПРАВЛЕННЯ: повертаємо початок дня
    return DateTime(
      startOfWeek.year,
      startOfWeek.month,
      startOfWeek.day,
      0,
      0,
      0,
    );
  }

  /// Отримати кінець тижня (неділя о 23:59:59)
  static DateTime getEndOfWeek(DateTime date) {
    final startOfWeek = getStartOfWeek(date);
    final endOfWeek = startOfWeek.add(const Duration(days: 6));
    return DateTime(endOfWeek.year, endOfWeek.month, endOfWeek.day, 23, 59, 59);
  }

  /// Отримати початок місяця
  static DateTime getStartOfMonth(DateTime date) {
    return DateTime(date.year, date.month, 1);
  }

  /// Отримати кінець місяця
  static DateTime getEndOfMonth(DateTime date) {
    return DateTime(date.year, date.month + 1, 0);
  }

  /// Обчислити рівень заповненості у відсотках
  static double getOccupancyRate(int filled, int total) {
    return total > 0 ? filled / total : 0.0;
  }

  /// Перевірити чи заняття майже заповнене (80%+)
  static bool isAlmostFull(int filled, int total) {
    return getOccupancyRate(filled, total) >= 0.8;
  }

  /// Перевірити чи заняття повністю заповнене
  static bool isFull(int filled, int total) {
    return filled >= total;
  }

  /// Отримати статус заняття
  static LessonStatus getLessonStatus(
    int filled,
    int total,
    bool isRegistered,
  ) {
    if (isRegistered) return LessonStatus.registered;
    if (isFull(filled, total)) return LessonStatus.full;
    if (isAlmostFull(filled, total)) return LessonStatus.almostFull;
    return LessonStatus.available;
  }

  /// Відсортувати заняття за часом
  static List<Map<String, dynamic>> sortLessonsByTime(
    List<Map<String, dynamic>> lessons,
  ) {
    return lessons..sort((a, b) {
      final timeA = a['start'] as TimeOfDay;
      final timeB = b['start'] as TimeOfDay;
      final minutesA = timeA.hour * 60 + timeA.minute;
      final minutesB = timeB.hour * 60 + timeB.minute;
      return minutesA.compareTo(minutesB);
    });
  }

  /// Групувати заняття за днями
  static Map<int, List<Map<String, dynamic>>> groupLessonsByDay(
    List<Map<String, dynamic>> lessons,
  ) {
    final Map<int, List<Map<String, dynamic>>> grouped = {};

    for (final lesson in lessons) {
      final dayOffset = lesson['dayOffset'] as int;
      if (!grouped.containsKey(dayOffset)) {
        grouped[dayOffset] = [];
      }
      grouped[dayOffset]!.add(lesson);
    }

    // Сортуємо заняття в кожному дні за часом
    for (final day in grouped.keys) {
      grouped[day] = sortLessonsByTime(grouped[day]!);
    }

    return grouped;
  }

  /// Знайти перекриваючі заняття
  static List<Map<String, dynamic>> findOverlappingLessons(
    List<Map<String, dynamic>> lessons,
    Map<String, dynamic> targetLesson,
    int dayIndex,
  ) {
    final targetStart = targetLesson['start'] as TimeOfDay;
    final targetEnd = targetLesson['end'] as TimeOfDay;

    return lessons
        .where(
          (lesson) =>
              lesson['dayOffset'] == dayIndex &&
              lesson['id'] != targetLesson['id'] &&
              timesOverlap(
                lesson['start'],
                lesson['end'],
                targetStart,
                targetEnd,
              ),
        )
        .toList();
  }

  /// Обчислити позицію для перекриваючих занять
  static ({double left, double right}) calculateOverlapPosition(
    List<Map<String, dynamic>> overlappingLessons,
    Map<String, dynamic> currentLesson,
    double totalWidth,
    double margin,
  ) {
    final overlapCount = overlappingLessons.length + 1;
    final lessonIndex = overlappingLessons.indexOf(currentLesson);
    final actualIndex = lessonIndex >= 0 ? lessonIndex + 1 : 0;

    final availableWidth = totalWidth - (margin * 2);
    final lessonWidth = availableWidth / overlapCount;

    final left = margin + (actualIndex * lessonWidth);
    final right = margin + ((overlapCount - actualIndex - 1) * lessonWidth);

    return (left: left, right: right);
  }

  /// Валідація часу заняття
  static String? validateLessonTime(
    TimeOfDay start,
    TimeOfDay end, {
    double? minHour,
    double? maxHour,
  }) {
    final startMinutes = start.hour * 60 + start.minute;
    final endMinutes = end.hour * 60 + end.minute;

    if (startMinutes >= endMinutes) {
      return 'Час початку повинен бути раніше часу закінчення';
    }

    if (endMinutes - startMinutes < 30) {
      return 'Мінімальна тривалість заняття - 30 хвилин';
    }

    // Перевіряти межі тільки якщо вони передані
    if (minHour != null && maxHour != null) {
      if (start.hour < minHour || end.hour > maxHour) {
        return 'Заняття повинні проводитися з ${minHour.toInt()}:00 до ${maxHour.toInt()}:00';
      }
    }

    return null;
  }

  /// Генерація кольору для групи (якщо немає в preset)
  static Color generateGroupColor(String groupName) {
    final hash = groupName.hashCode;
    final hue = (hash % 360).toDouble();
    return HSVColor.fromAHSV(1.0, hue, 0.3, 0.95).toColor();
  }

  /// Отримати статус заняття для викладача
  static InstructorLessonStatus getInstructorLessonStatus(
    LessonModel lesson,
    bool isUserInstructor,
  ) {
    if (isUserInstructor) return InstructorLessonStatus.teaching;
    if (lesson.instructorId.isEmpty || lesson.instructorId == 'Не призначено') {
      return InstructorLessonStatus.needsInstructor;
    }
    return InstructorLessonStatus.assigned;
  }
}

enum LessonStatus { available, almostFull, full, registered }

/// Розширення для LessonStatus
extension LessonStatusExtension on LessonStatus {
  Color get color {
    switch (this) {
      case LessonStatus.available:
        return Colors.green;
      case LessonStatus.almostFull:
        return Colors.orange;
      case LessonStatus.full:
        return Colors.red;
      case LessonStatus.registered:
        return Colors.blue;
    }
  }

  String get label {
    switch (this) {
      case LessonStatus.available:
        return 'Доступно';
      case LessonStatus.almostFull:
        return 'Майже заповнено';
      case LessonStatus.full:
        return 'Заповнено';
      case LessonStatus.registered:
        return 'Зареєстровано';
    }
  }

  IconData get icon {
    switch (this) {
      case LessonStatus.available:
        return Icons.event_available;
      case LessonStatus.almostFull:
        return Icons.warning;
      case LessonStatus.full:
        return Icons.block;
      case LessonStatus.registered:
        return Icons.check_circle;
    }
  }
}
