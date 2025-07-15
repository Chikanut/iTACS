import 'dart:typed_data';
import 'package:excel/excel.dart';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import '../pages/calendar_page/models/lesson_model.dart';
import '../pages/calendar_page/calendar_utils.dart';
import '../globals.dart';
import 'dashboard_service.dart';

enum CalendarPeriod { week, month }
enum ReportFormat { excel, csv }

class ReportsService {
  static const String _defaultFontFamily = 'Calibri';
  static const double _defaultFontSize = 11.0;

  /// Генерувати Excel календар на тиждень або місяць
  Future<Uint8List> generateCalendarExcel({
    required DateTime startDate,
    required CalendarPeriod period,
    String? title,
  }) async {
    try {
      final excel = Excel.createExcel();
      final sheet = excel['Календар'];
      
      // Видаляємо дефолтний лист
      excel.delete('Sheet1');

      // Налаштування дат
      final DateTime endDate;
      final List<DateTime> days;
      
      if (period == CalendarPeriod.week) {
        final weekStart = CalendarUtils.getStartOfWeek(startDate);
        endDate = CalendarUtils.getEndOfWeek(startDate);
        days = CalendarUtils.getWeekDays(startDate);
      } else {
        final monthStart = CalendarUtils.getStartOfMonth(startDate);
        endDate = CalendarUtils.getEndOfMonth(startDate);
        days = _getMonthDays(startDate);
      }

      // Отримуємо заняття за період
      final dashboardService = DashboardService();
      final lessons = await dashboardService.getLessonsForPeriod(
        startDate: days.first,
        endDate: days.last.add(const Duration(hours: 23, minutes: 59)),
      );

      // Створюємо заголовок
      _createCalendarHeader(sheet, startDate, period, title);
      
      // Створюємо календарну сітку
      if (period == CalendarPeriod.week) {
        _createWeekCalendar(sheet, days, lessons);
      } else {
        _createMonthCalendar(sheet, days, lessons, startDate);
      }

      // Додаємо легенду
      _addCalendarLegend(sheet, period == CalendarPeriod.week ? 15 : 25);

      // Налаштовуємо стилі
      _formatCalendarSheet(sheet);

      return Uint8List.fromList(excel.encode()!);
    } catch (e) {
      if (kDebugMode) {
        print('Помилка генерації календаря Excel: $e');
      }
      rethrow;
    }
  }

  /// Генерувати звіт по інструкторах (для admin)
  Future<Uint8List> generateInstructorReport({
    required DateTime startDate,
    required DateTime endDate,
    String? title,
  }) async {
    try {
      final excel = Excel.createExcel();
      final sheet = excel['Звіт по інструкторах'];
      excel.delete('Sheet1');

      // Отримуємо статистику інструкторів
      final dashboardService = DashboardService();
      final instructorStats = await dashboardService.getInstructorsStatistics(
        startDate: startDate,
        endDate: endDate,
      );

      // Створюємо заголовок звіту
      _createReportHeader(sheet, startDate, endDate, title);

      // Створюємо таблицю статистики
      _createInstructorStatsTable(sheet, instructorStats);

      // Додаємо сумарну статистику
      _addTotalStatistics(sheet, instructorStats);

      // Налаштовуємо стилі
      _formatReportSheet(sheet);

      return Uint8List.fromList(excel.encode()!);
    } catch (e) {
      if (kDebugMode) {
        print('Помилка генерації звіту по інструкторах: $e');
      }
      rethrow;
    }
  }

  /// Генерувати звіт по заняттях за період
  Future<Uint8List> generateLessonsReport({
    required DateTime startDate,
    required DateTime endDate,
    String? instructorId,
    String? title,
  }) async {
    try {
      final excel = Excel.createExcel();
      final sheet = excel['Звіт по заняттях'];
      excel.delete('Sheet1');

      // Отримуємо заняття за період
      final dashboardService = DashboardService();
      final lessons = await dashboardService.getLessonsForPeriod(
        startDate: startDate,
        endDate: endDate,
        instructorId: instructorId,
      );

      // Створюємо заголовок звіту
      _createReportHeader(sheet, startDate, endDate, title);

      // Створюємо таблицю занять
      _createLessonsTable(sheet, lessons);

      // Додаємо статистику
      _addLessonsStatistics(sheet, lessons);

      // Налаштовуємо стилі
      _formatReportSheet(sheet);

      return Uint8List.fromList(excel.encode()!);
    } catch (e) {
      if (kDebugMode) {
        print('Помилка генерації звіту по заняттях: $e');
      }
      rethrow;
    }
  }

  // ===== ПРИВАТНІ МЕТОДИ =====

  /// Створити заголовок календаря
  void _createCalendarHeader(Sheet sheet, DateTime date, CalendarPeriod period, String? title) {
    final titleText = title ?? _getCalendarTitle(date, period);
    
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 0)).value = TextCellValue(titleText);
    sheet.merge(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 0), CellIndex.indexByColumnRow(columnIndex: 7, rowIndex: 0));
    
    // Стилі заголовка
    final titleCell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 0));
    titleCell.cellStyle = CellStyle(
      fontFamily: _defaultFontFamily,
      fontSize: 16,
      bold: true,
      horizontalAlign: HorizontalAlign.Center,
    );

    // Підзаголовок з датами
    final dateRange = _getDateRangeText(date, period);
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 1)).value = TextCellValue(dateRange);
    sheet.merge(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 1), CellIndex.indexByColumnRow(columnIndex: 7, rowIndex: 1));
    
    final subtitleCell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 1));
    subtitleCell.cellStyle = CellStyle(
      fontFamily: _defaultFontFamily,
      fontSize: 12,
      horizontalAlign: HorizontalAlign.Center,
    );
  }

  /// Створити тижневий календар
  void _createWeekCalendar(Sheet sheet, List<DateTime> days, List<LessonModel> lessons) {
    // Заголовки днів
    const startRow = 3; // 0-indexed, тому це 4-й рядок
    const timeColumn = 0;
    
    // Час у першій колонці
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: timeColumn, rowIndex: startRow)).value = TextCellValue('Час');
    
    // Дні тижня
    for (int i = 0; i < days.length; i++) {
      final day = days[i];
      final dayName = CalendarUtils.getDayName(day.weekday, short: true);
      final dayDate = DateFormat('dd.MM').format(day);
      
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: i + 1, rowIndex: startRow)).value = TextCellValue('$dayName\n$dayDate');
    }

    // Створюємо сітку по годинах
    final lessonsGrouped = CalendarUtils.groupLessonsByDay(
      lessons.map((l) => l.toMap()).toList()
    );

    // Визначаємо діапазон годин
    final minHour = lessons.isEmpty ? 8.0 : CalendarUtils.getMinHourFromLessons(lessons);
    final maxHour = lessons.isEmpty ? 18.0 : CalendarUtils.getMaxHourFromLessons(lessons);
    
    int currentRow = startRow + 1;
    
    for (int hour = minHour.floor(); hour <= maxHour.ceil(); hour++) {
      // Час у першій колонці
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: timeColumn, rowIndex: currentRow)).value = TextCellValue('${hour.toString().padLeft(2, '0')}:00');
      
      // Заняття для кожного дня
      for (int dayIndex = 0; dayIndex < days.length; dayIndex++) {
        final day = days[dayIndex];
        final dayLessons = lessonsGrouped[day.weekday] ?? [];
        
        // Знаходимо заняття на цю годину
        final hourLessons = dayLessons.where((lessonMap) {
          final lesson = LessonModel.fromMap(lessonMap);
          final lessonHour = lesson.startTime.hour;
          return lessonHour == hour;
        }).toList();

        String cellContent = '';
        if (hourLessons.isNotEmpty) {
          for (final lessonMap in hourLessons) {
            final lesson = LessonModel.fromMap(lessonMap);
            final timeRange = '${DateFormat('HH:mm').format(lesson.startTime)}-${DateFormat('HH:mm').format(lesson.endTime)}';
            cellContent += '${lesson.title}\n$timeRange\n${lesson.instructorId.isNotEmpty ? lesson.instructorName : 'Без викладача'}\n\n';
          }
        }
        
        sheet.cell(CellIndex.indexByColumnRow(columnIndex: dayIndex + 1, rowIndex: currentRow)).value = TextCellValue(cellContent.trim());
      }
      
      currentRow++;
    }
  }

  /// Створити місячний календар
  void _createMonthCalendar(Sheet sheet, List<DateTime> days, List<LessonModel> lessons, DateTime monthDate) {
    const startRow = 3; // 0-indexed, тому це 4-й рядок
    
    // Заголовки днів тижня
    const weekDays = ['Пн', 'Вт', 'Ср', 'Чт', 'Пт', 'Сб', 'Нд'];
    for (int i = 0; i < weekDays.length; i++) {
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: i, rowIndex: startRow)).value = TextCellValue(weekDays[i]);
    }

    // Групуємо заняття по датах
    final lessonsByDate = <DateTime, List<LessonModel>>{};
    for (final lesson in lessons) {
      final date = DateTime(lesson.startTime.year, lesson.startTime.month, lesson.startTime.day);
      lessonsByDate.putIfAbsent(date, () => []).add(lesson);
    }

    // Створюємо календарну сітку
    int currentRow = startRow + 1;
    int currentWeekDay = 0;
    
    // Початок місяця
    final firstDay = DateTime(monthDate.year, monthDate.month, 1);
    final startWeekDay = (firstDay.weekday - 1) % 7; // Понеділок = 0
    
    // Пусті клітинки до початку місяця
    for (int i = 0; i < startWeekDay; i++) {
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: i, rowIndex: currentRow)).value = TextCellValue('');
      currentWeekDay++;
    }

    // Дні місяця
    final daysInMonth = DateTime(monthDate.year, monthDate.month + 1, 0).day;
    
    for (int day = 1; day <= daysInMonth; day++) {
      final date = DateTime(monthDate.year, monthDate.month, day);
      final dayLessons = lessonsByDate[date] ?? [];
      
      String cellContent = '$day\n';
      if (dayLessons.isNotEmpty) {
        for (final lesson in dayLessons.take(3)) { // Максимум 3 заняття
          final time = DateFormat('HH:mm').format(lesson.startTime);
          cellContent += '$time ${lesson.title}\n';
        }
        if (dayLessons.length > 3) {
          cellContent += '... ще ${dayLessons.length - 3}';
        }
      }

      sheet.cell(CellIndex.indexByColumnRow(columnIndex: currentWeekDay, rowIndex: currentRow)).value = TextCellValue(cellContent.trim());
      
      currentWeekDay++;
      if (currentWeekDay >= 7) {
        currentWeekDay = 0;
        currentRow++;
      }
    }
  }

  /// Створити таблицю статистики інструкторів
  void _createInstructorStatsTable(Sheet sheet, Map<String, UserStats> instructorStats) {
    const startRow = 4; // 0-indexed, тому це 5-й рядок
    
    // Заголовки таблиці
    final headers = ['Інструктор', 'Всього занять', 'Проведено', 'Відсоток завершення', 'Незаповнені'];
    for (int i = 0; i < headers.length; i++) {
      final cell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: i, rowIndex: startRow));
      cell.value = TextCellValue(headers[i]);
      cell.cellStyle = CellStyle(
        fontFamily: _defaultFontFamily,
        bold: true,
        backgroundColorHex: ExcelColor.fromHexString('#E6E6FA'),
      );
    }

    // Дані інструкторів
    int currentRow = startRow + 1;
    for (final entry in instructorStats.entries) {
      final instructor = entry.key;
      final stats = entry.value;
      
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: currentRow)).value = TextCellValue(instructor);
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: currentRow)).value = IntCellValue(stats.totalLessons);
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: currentRow)).value = IntCellValue(stats.conductedLessons);
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 3, rowIndex: currentRow)).value = TextCellValue('${stats.completionRate.toStringAsFixed(1)}%');
      
      currentRow++;
    }
  }

  /// Створити таблицю занять
  void _createLessonsTable(Sheet sheet, List<LessonModel> lessons) {
    const startRow = 4; // 0-indexed, тому це 5-й рядок
    
    // Заголовки таблиці
    final headers = ['Дата', 'Час', 'Назва', 'Інструктор', 'Місце', 'Учасники'];
    for (int i = 0; i < headers.length; i++) {
      final cell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: i, rowIndex: startRow));
      cell.value = TextCellValue(headers[i]);
      cell.cellStyle = CellStyle(
        fontFamily: _defaultFontFamily,
        bold: true,
        backgroundColorHex: ExcelColor.fromHexString('#E6E6FA'),
      );
    }

    // Дані занять
    int currentRow = startRow + 1;
    for (final lesson in lessons) {
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: currentRow)).value = TextCellValue(DateFormat('dd.MM.yyyy').format(lesson.startTime));
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: currentRow)).value = TextCellValue('${DateFormat('HH:mm').format(lesson.startTime)}-${DateFormat('HH:mm').format(lesson.endTime)}');
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: currentRow)).value = TextCellValue(lesson.title);
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 3, rowIndex: currentRow)).value = TextCellValue(lesson.instructorId.isEmpty ? 'Без викладача' : lesson.instructorName);
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 4, rowIndex: currentRow)).value = TextCellValue(lesson.location);
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 5, rowIndex: currentRow)).value = TextCellValue('${lesson.maxParticipants}');
      
      currentRow++;
    }
  }

  /// Додати легенду до календаря
  void _addCalendarLegend(Sheet sheet, int startRow) {
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: startRow)).value = TextCellValue('Легенда:');
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: startRow + 1)).value = TextCellValue('• Час - початок заняття');
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: startRow + 2)).value = TextCellValue('• Якщо немає викладача - показано "Без викладача"');
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: startRow + 3)).value = TextCellValue('• Сгенеровано: ${DateFormat('dd.MM.yyyy HH:mm').format(DateTime.now())}');
  }

  /// Додати сумарну статистику
  void _addTotalStatistics(Sheet sheet, Map<String, UserStats> instructorStats) {
    final totalLessons = instructorStats.values.fold(0, (sum, stats) => sum + stats.totalLessons);
    final totalConducted = instructorStats.values.fold(0, (sum, stats) => sum + stats.conductedLessons);
    final avgCompletion = instructorStats.values.isEmpty ? 0.0 : 
        instructorStats.values.fold(0.0, (sum, stats) => sum + stats.completionRate) / instructorStats.length;

    final startRow = 6 + instructorStats.length; // 0-indexed
    
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: startRow)).value = TextCellValue('ВСЬОГО:');
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: startRow)).value = IntCellValue(totalLessons);
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: startRow)).value = IntCellValue(totalConducted);
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 3, rowIndex: startRow)).value = TextCellValue('${avgCompletion.toStringAsFixed(1)}%');
  }

  /// Додати статистику занять
  void _addLessonsStatistics(Sheet sheet, List<LessonModel> lessons) {
    final startRow = 6 + lessons.length; // 0-indexed
    final now = DateTime.now();
    
    final conducted = lessons.where((l) => l.endTime.isBefore(now)).length;
    final withInstructor = lessons.where((l) => l.instructorId.isNotEmpty).length;
  

    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: startRow)).value = TextCellValue('Статистика:');
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: startRow + 1)).value = TextCellValue('Всього занять: ${lessons.length}');
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: startRow + 2)).value = TextCellValue('Проведено: $conducted');
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: startRow + 3)).value = TextCellValue('З викладачем: $withInstructor');
    
  }

  /// Налаштувати стилі календаря
  void _formatCalendarSheet(Sheet sheet) {
    // Автоширина колонок та інші стилі будуть налаштовані в Excel клієнті
    // Тут можна додати базові стилі для клітинок
  }

  /// Налаштувати стилі звіту
  void _formatReportSheet(Sheet sheet) {
    // Базові стилі для звіту
  }

  /// Створити заголовок звіту
  void _createReportHeader(Sheet sheet, DateTime startDate, DateTime endDate, String? title) {
    final titleText = title ?? 'Звіт по заняттях';
    final dateRange = 'Період: ${DateFormat('dd.MM.yyyy').format(startDate)} - ${DateFormat('dd.MM.yyyy').format(endDate)}';
    
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 0)).value = TextCellValue(titleText);
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 1)).value = TextCellValue(dateRange);
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 2)).value = TextCellValue('Група: ${Globals.profileManager.currentGroupName ?? 'Не вибрано'}');
  }

  /// Отримати назву календаря
  String _getCalendarTitle(DateTime date, CalendarPeriod period) {
    if (period == CalendarPeriod.week) {
      return 'Календар занять на тиждень';
    } else {
      return 'Календар занять на місяць';
    }
  }

  /// Отримати текст діапазону дат
  String _getDateRangeText(DateTime date, CalendarPeriod period) {
    if (period == CalendarPeriod.week) {
      final start = CalendarUtils.getStartOfWeek(date);
      final end = CalendarUtils.getEndOfWeek(date);
      return '${DateFormat('dd.MM.yyyy').format(start)} - ${DateFormat('dd.MM.yyyy').format(end)}';
    } else {
      return DateFormat('MMMM yyyy', 'uk').format(date);
    }
  }

  /// Отримати дні місяця
  List<DateTime> _getMonthDays(DateTime date) {
    final daysInMonth = DateTime(date.year, date.month + 1, 0).day;
    return List.generate(daysInMonth, (index) => DateTime(date.year, date.month, index + 1));
  }
}