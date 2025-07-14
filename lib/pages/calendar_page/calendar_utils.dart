import 'package:flutter/material.dart';
import 'models/lesson_model.dart';

class CalendarUtils {
  // Константи для календаря
  static const double timeColumnWidth = 60.0;
  static const double hourHeight = 80.0;
  static const double minuteHeight = hourHeight / 60.0;

  // Отримати мінімальний час з списку занять
  static double getMinHourFromLessons(List<LessonModel> lessons) {
    if (lessons.isEmpty) return 8.0; // fallback якщо немає занять
    
    final minTime = lessons
        .map((lesson) => lesson.startTime.hour + (lesson.startTime.minute / 60.0))
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
  static bool timesOverlap(TimeOfDay start1, TimeOfDay end1, TimeOfDay start2, TimeOfDay end2) {
    final start1Minutes = start1.hour * 60 + start1.minute;
    final end1Minutes = end1.hour * 60 + end1.minute;
    final start2Minutes = start2.hour * 60 + start2.minute;
    final end2Minutes = end2.hour * 60 + end2.minute;
    
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
      const days = ['Понеділок', 'Вівторок', 'Середа', 'Четвер', 'П\'ятниця', 'Субота', 'Неділя'];
      return days[weekday - 1];
    }
  }

  /// Отримати назву місяця
  static String getMonthName(int month, {bool short = false}) {
    if (short) {
      const months = ['Січ', 'Лют', 'Бер', 'Кві', 'Тра', 'Чер', 
                     'Лип', 'Сер', 'Вер', 'Жов', 'Лис', 'Гру'];
      return months[month - 1];
    } else {
      const months = ['Січень', 'Лютий', 'Березень', 'Квітень', 'Травень', 'Червень',
                     'Липень', 'Серпень', 'Вересень', 'Жовтень', 'Листопад', 'Грудень'];
      return months[month - 1];
    }
  }

  /// Перевірити чи дата сьогоднішня
  static bool isToday(DateTime date) {
    final now = DateTime.now();
    return date.year == now.year && date.month == now.month && date.day == now.day;
  }

  /// Отримати дні тижня для заданої дати
  static List<DateTime> getWeekDays(DateTime selectedDate) {
    final startOfWeek = selectedDate.subtract(Duration(days: selectedDate.weekday - 1));
    return List.generate(7, (index) => startOfWeek.add(Duration(days: index)));
  }

  /// Отримати початок тижня
  static DateTime getStartOfWeek(DateTime date) {
    return date.subtract(Duration(days: date.weekday - 1));
  }

  /// Отримати кінець тижня
  static DateTime getEndOfWeek(DateTime date) {
    return getStartOfWeek(date).add(const Duration(days: 6));
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
  static LessonStatus getLessonStatus(int filled, int total, bool isRegistered) {
    if (isRegistered) return LessonStatus.registered;
    if (isFull(filled, total)) return LessonStatus.full;
    if (isAlmostFull(filled, total)) return LessonStatus.almostFull;
    return LessonStatus.available;
  }

  /// Відсортувати заняття за часом
  static List<Map<String, dynamic>> sortLessonsByTime(List<Map<String, dynamic>> lessons) {
    return lessons..sort((a, b) {
      final timeA = a['start'] as TimeOfDay;
      final timeB = b['start'] as TimeOfDay;
      final minutesA = timeA.hour * 60 + timeA.minute;
      final minutesB = timeB.hour * 60 + timeB.minute;
      return minutesA.compareTo(minutesB);
    });
  }

  /// Групувати заняття за днями
  static Map<int, List<Map<String, dynamic>>> groupLessonsByDay(List<Map<String, dynamic>> lessons) {
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
    
    return lessons.where((lesson) => 
      lesson['dayOffset'] == dayIndex && 
      lesson['id'] != targetLesson['id'] &&
      timesOverlap(lesson['start'], lesson['end'], targetStart, targetEnd)
    ).toList();
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
  static String? validateLessonTime(TimeOfDay start, TimeOfDay end, {double? minHour, double? maxHour}) {
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
}

enum LessonStatus {
  available,
  almostFull,
  full,
  registered,
}

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