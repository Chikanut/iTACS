import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:excel/excel.dart' as excel;
import 'package:intl/intl.dart';
import 'base_report.dart';
import '../../pages/calendar_page/models/lesson_model.dart';
import '../../pages/calendar_page/calendar_utils.dart';
import '../../globals.dart';
import '../dashboard_service.dart';

class CalendarGridReport extends BaseReport {
  @override
  String get id => 'calendar_grid';

  @override
  String get name => 'Календарна сітка';

  @override
  String get description => 
      'Візуальна календарна сітка з заняттями по підрозділах у форматі:\n'
      'Підрозділи × Дні місяця з кольоровою диференціацією';

  @override
  IconData get icon => Icons.calendar_view_month;

  @override
  String get category => 'calendar';

  @override
  List<ReportFormat> get supportedFormats => [ReportFormat.excel];

  @override
  bool get requiresParameters => false;

  @override
  List<String> get requiredRoles => ['viewer'];

  @override
  Future<String?> validateReportSpecificConditions({
    required DateTime startDate,
    required DateTime endDate,
    Map<String, dynamic>? parameters,
  }) async {
    // Перевіряємо що період не більше 31 дня (для календарної сітки)
    final days = endDate.difference(startDate).inDays + 1;
    if (days > 31) {
      return 'Максимальний період для календарної сітки - 31 день';
    }

    try {
      final dashboardService = DashboardService();
      final lessons = await dashboardService.getLessonsForPeriod(
        startDate: startDate,
        endDate: endDate,
      );

      if (lessons.isEmpty) {
        return 'За вказаний період не знайдено занять';
      }

      return null;
    } catch (e) {
      return 'Помилка перевірки даних: $e';
    }
  }

  @override
  Future<Map<String, dynamic>> getPreview({
    required DateTime startDate,
    required DateTime endDate,
    Map<String, dynamic>? parameters,
  }) async {
    try {
      final dashboardService = DashboardService();
      final lessons = await dashboardService.getLessonsForPeriod(
        startDate: startDate,
        endDate: endDate,
      );

      final units = lessons.map((l) => l.unit).where((u) => u.isNotEmpty).toSet();
      final days = endDate.difference(startDate).inDays + 1;

      return {
        'reportId': id,
        'reportName': name,
        'dateRange': _formatDateRange(startDate, endDate),
        'estimatedSize': days > 7 ? 'Середньо' : 'Мало',
        'recordsCount': lessons.length,
        'unitsCount': units.length,
        'daysCount': days,
        'hasData': lessons.isNotEmpty,
      };
    } catch (e) {
      return {
        'reportId': id,
        'reportName': name,
        'dateRange': _formatDateRange(startDate, endDate),
        'estimatedSize': 'Невідомо',
        'recordsCount': 0,
        'error': e.toString(),
      };
    }
  }

  @override
  String getDefaultFileName({
    required ReportFormat format,
    required DateTime startDate,
    required DateTime endDate,
    Map<String, dynamic>? parameters,
  }) {
    final dateRange = _formatDateRange(startDate, endDate);
    return 'Календарна_сітка_$dateRange.${format.extension}';
  }

  @override
  Future<Uint8List> generate({
    required ReportFormat format,
    required DateTime startDate,
    required DateTime endDate,
    Map<String, dynamic>? parameters,
  }) async {
    if (format != ReportFormat.excel) {
      throw UnsupportedError('Формат ${format.displayName} поки не підтримується для звіту "$name"');
    }

    return await _generateExcelReport(
      startDate: startDate,
      endDate: endDate,
      parameters: parameters,
    );
  }

  // ===== ПРИВАТНІ МЕТОДИ =====

  Future<Uint8List> _generateExcelReport({
    required DateTime startDate,
    required DateTime endDate,
    Map<String, dynamic>? parameters,
  }) async {
    final excelFile = excel.Excel.createExcel();
    final sheet = excelFile['Календарна сітка'];
    excelFile.delete('Sheet1');

    // Отримуємо дані
    final dashboardService = DashboardService();
    final lessons = await dashboardService.getLessonsForPeriod(
      startDate: startDate,
      endDate: endDate,
    );

    // Організуємо дані
    final daysInPeriod = _generateDaysList(startDate, endDate);
    final unitsList = _getUniqueUnits(lessons);
    final lessonsByUnitAndDate = _organizeLessonsByUnitAndDate(lessons, daysInPeriod);

    // Генеруємо звіт
    _createHeader(sheet, startDate, endDate);
    _createCalendarGrid(sheet, daysInPeriod, unitsList, lessonsByUnitAndDate);
    _addLegend(sheet, daysInPeriod.length, unitsList.length);
    _formatSheet(sheet, daysInPeriod.length);

    return Uint8List.fromList(excelFile.encode()!);
  }

  List<DateTime> _generateDaysList(DateTime startDate, DateTime endDate) {
    final days = <DateTime>[];
    DateTime current = startDate;
    
    while (current.isBefore(endDate) || current.isAtSameMomentAs(endDate)) {
      days.add(DateTime(current.year, current.month, current.day));
      current = current.add(const Duration(days: 1));
    }
    
    return days;
  }

  List<String> _getUniqueUnits(List<LessonModel> lessons) {
    final units = lessons
        .map((l) => l.unit)
        .where((u) => u.isNotEmpty)
        .toSet()
        .toList();
    
    units.sort();
    return units;
  }

  Map<String, Map<DateTime, List<LessonModel>>> _organizeLessonsByUnitAndDate(
    List<LessonModel> lessons,
    List<DateTime> days,
  ) {
    final organized = <String, Map<DateTime, List<LessonModel>>>{};
    
    for (final lesson in lessons) {
      final unit = lesson.unit.isEmpty ? 'Без підрозділу' : lesson.unit;
      final lessonDate = DateTime(
        lesson.startTime.year,
        lesson.startTime.month,
        lesson.startTime.day,
      );
      
      organized.putIfAbsent(unit, () => {});
      organized[unit]!.putIfAbsent(lessonDate, () => []);
      organized[unit]![lessonDate]!.add(lesson);
    }
    
    return organized;
  }

  void _createHeader(excel.Sheet sheet, DateTime startDate, DateTime endDate) {
    // Основний заголовок
    final titleText = 'КАЛЕНДАРНА СІТКА';
    final titleCell = sheet.cell(excel.CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 0));
    titleCell.value = excel.TextCellValue(titleText);
    
    titleCell.cellStyle = excel.CellStyle(
      fontSize: 16,
      bold: true,
      horizontalAlign: excel.HorizontalAlign.Center,
    );

    // Період
    final dateRange = 'Період: ${DateFormat('dd.MM.yyyy').format(startDate)} - ${DateFormat('dd.MM.yyyy').format(endDate)}';
    final periodCell = sheet.cell(excel.CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 1));
    periodCell.value = excel.TextCellValue(dateRange);
    
    periodCell.cellStyle = excel.CellStyle(
      fontSize: 12,
      horizontalAlign: excel.HorizontalAlign.Center,
    );

    // Група
    final groupName = Globals.profileManager.currentGroupName ?? 'Не вибрано';
    final groupCell = sheet.cell(excel.CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 2));
    groupCell.value = excel.TextCellValue('Група: $groupName');
    
    groupCell.cellStyle = excel.CellStyle(
      fontSize: 11,
      horizontalAlign: excel.HorizontalAlign.Center,
    );
  }

  void _createCalendarGrid(
    excel.Sheet sheet,
    List<DateTime> days,
    List<String> units,
    Map<String, Map<DateTime, List<LessonModel>>> lessonsByUnitAndDate,
  ) {
    const startRow = 4; // Почати після заголовків
    
    // Заголовки днів
    for (int dayIndex = 0; dayIndex < days.length; dayIndex++) {
      final day = days[dayIndex];
      final dayName = CalendarUtils.getDayName(day.weekday, short: true);
      final dayNumber = day.day.toString();
      
      final headerCell = sheet.cell(excel.CellIndex.indexByColumnRow(
        columnIndex: dayIndex + 1, 
        rowIndex: startRow,
      ));
      headerCell.value = excel.TextCellValue('$dayName $dayNumber');
      headerCell.cellStyle = excel.CellStyle(
        fontSize: 10,
        bold: true,
        backgroundColorHex: excel.ExcelColor.fromHexString('#4472C4'),
        fontColorHex: excel.ExcelColor.fromHexString('#FFFFFF'),
        horizontalAlign: excel.HorizontalAlign.Center,
        verticalAlign: excel.VerticalAlign.Center,
      );
    }

    // Заголовок колонки підрозділів
    final unitHeaderCell = sheet.cell(excel.CellIndex.indexByColumnRow(
      columnIndex: 0, 
      rowIndex: startRow,
    ));
    unitHeaderCell.value = excel.TextCellValue('Підрозділ');
    unitHeaderCell.cellStyle = excel.CellStyle(
      fontSize: 11,
      bold: true,
      backgroundColorHex: excel.ExcelColor.fromHexString('#4472C4'),
      fontColorHex: excel.ExcelColor.fromHexString('#FFFFFF'),
      horizontalAlign: excel.HorizontalAlign.Center,
      verticalAlign: excel.VerticalAlign.Center,
    );

    // Генеруємо рядки для кожного підрозділу
    int currentRow = startRow + 1;
    
    for (final unit in units) {
      final unitLessons = lessonsByUnitAndDate[unit] ?? {};
      
      // Знаходимо максимальну кількість занять в один день для цього підрозділу
      int maxLessonsPerDay = 0;
      for (final dayLessons in unitLessons.values) {
        if (dayLessons.length > maxLessonsPerDay) {
          maxLessonsPerDay = dayLessons.length;
        }
      }
      
      // Якщо немає занять - один рядок
      if (maxLessonsPerDay == 0) maxLessonsPerDay = 1;
      
      // Створюємо рядки для підрозділу
      for (int lessonRow = 0; lessonRow < maxLessonsPerDay; lessonRow++) {
        // Назва підрозділу (тільки в першому рядку)
        if (lessonRow == 0) {
          final unitCell = sheet.cell(excel.CellIndex.indexByColumnRow(
            columnIndex: 0, 
            rowIndex: currentRow,
          ));
          unitCell.value = excel.TextCellValue(unit);
          unitCell.cellStyle = excel.CellStyle(
            fontSize: 10,
            bold: true,
            backgroundColorHex: excel.ExcelColor.fromHexString('#E6E6FA'),
            horizontalAlign: excel.HorizontalAlign.Left,
            verticalAlign: excel.VerticalAlign.Center,
          );
          
          // Об'єднуємо клітинки по вертикалі якщо кілька рядків
          if (maxLessonsPerDay > 1) {
            sheet.merge(
              excel.CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: currentRow),
              excel.CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: currentRow + maxLessonsPerDay - 1),
            );
          }
        }
        
        // Заняття для кожного дня
        for (int dayIndex = 0; dayIndex < days.length; dayIndex++) {
          final day = days[dayIndex];
          final dayLessons = unitLessons[day] ?? [];
          
          final lessonCell = sheet.cell(excel.CellIndex.indexByColumnRow(
            columnIndex: dayIndex + 1, 
            rowIndex: currentRow,
          ));
          
          if (lessonRow < dayLessons.length) {
            final lesson = dayLessons[lessonRow];
            final cellContent = '${lesson.title}\n${lesson.maxParticipants} осіб';
            lessonCell.value = excel.TextCellValue(cellContent);
            
            // Кольорова диференціація по типу заняття
            final backgroundColor = _getLessonColor(lesson.title);
            lessonCell.cellStyle = excel.CellStyle(
              fontSize: 9,
              backgroundColorHex: excel.ExcelColor.fromHexString(backgroundColor),
              horizontalAlign: excel.HorizontalAlign.Center,
              verticalAlign: excel.VerticalAlign.Center,
              textWrapping: excel.TextWrapping.WrapText,
            );
          } else {
            // Порожня клітинка
            lessonCell.value = excel.TextCellValue('');
            lessonCell.cellStyle = excel.CellStyle(
              backgroundColorHex: excel.ExcelColor.fromHexString('#FFFFFF'),
            );
          }
        }
        
        currentRow++;
      }
    }
  }

  String _getLessonColor(String lessonTitle) {
    // Кольорова диференціація по ключових словах в назві заняття
    final title = lessonTitle.toLowerCase();
    
    if (title.contains('теор') || title.contains('лекц')) {
      return '#E6F3FF'; // Світло-блакитний для теорії
    } else if (title.contains('практ') || title.contains('навч')) {
      return '#E6FFE6'; // Світло-зелений для практики
    } else if (title.contains('стрільб') || title.contains('вогнев')) {
      return '#FFE6E6'; // Світло-червоний для стрільби
    } else if (title.contains('фізич') || title.contains('спорт')) {
      return '#FFFFE6'; // Світло-жовтий для фізподготовки
    } else if (title.contains('тактич') || title.contains('бойов')) {
      return '#F0E6FF'; // Світло-фіолетовий для тактики
    } else if (title.contains('техніч') || title.contains('обслуг')) {
      return '#FFE6F0'; // Світло-рожевий для технічних занять
    } else {
      return '#F5F5F5'; // Світло-сірий для інших
    }
  }

  void _addLegend(excel.Sheet sheet, int daysCount, int unitsCount) {
    final legendStartRow = 6 + unitsCount * 2; // Після таблиці
    
    // Заголовок легенди
    final legendHeaderCell = sheet.cell(excel.CellIndex.indexByColumnRow(
      columnIndex: 0, 
      rowIndex: legendStartRow,
    ));
    legendHeaderCell.value = excel.TextCellValue('ЛЕГЕНДА КОЛЬОРІВ:');
    legendHeaderCell.cellStyle = excel.CellStyle(
      fontSize: 11,
      bold: true,
    );

    // Кольори та їх значення
    final colorLegend = [
      ('Теорія/Лекції', '#E6F3FF'),
      ('Практика/Навчання', '#E6FFE6'),
      ('Стрільба/Вогнева', '#FFE6E6'),
      ('Фізична підготовка', '#FFFFE6'),
      ('Тактика/Бойова', '#F0E6FF'),
      ('Технічна підготовка', '#FFE6F0'),
      ('Інші заняття', '#F5F5F5'),
    ];

    for (int i = 0; i < colorLegend.length; i++) {
      final (label, color) = colorLegend[i];
      
      // Кольорова клітинка
      final colorCell = sheet.cell(excel.CellIndex.indexByColumnRow(
        columnIndex: 0, 
        rowIndex: legendStartRow + 1 + i,
      ));
      colorCell.value = excel.TextCellValue('■');
      colorCell.cellStyle = excel.CellStyle(
        fontSize: 14,
        backgroundColorHex: excel.ExcelColor.fromHexString(color),
      );
      
      // Підпис
      final labelCell = sheet.cell(excel.CellIndex.indexByColumnRow(
        columnIndex: 1, 
        rowIndex: legendStartRow + 1 + i,
      ));
      labelCell.value = excel.TextCellValue(label);
      labelCell.cellStyle = excel.CellStyle(
        fontSize: 9,
      );
    }

    // Дата генерації
    final generatedCell = sheet.cell(excel.CellIndex.indexByColumnRow(
      columnIndex: 0, 
      rowIndex: legendStartRow + colorLegend.length + 2,
    ));
    generatedCell.value = excel.TextCellValue(
      'Згенеровано: ${DateFormat('dd.MM.yyyy HH:mm').format(DateTime.now())}'
    );
    generatedCell.cellStyle = excel.CellStyle(
      fontSize: 8,
      fontColorHex: excel.ExcelColor.fromHexString('#666666'),
    );
  }

  void _formatSheet(excel.Sheet sheet, int daysCount) {
    // Налаштовуємо ширину колонок
    sheet.setColumnWidth(0, 20); // Підрозділ
    for (int i = 1; i <= daysCount; i++) {
      sheet.setColumnWidth(i, 15); // Дні
    }
    
    // Висота рядків
    sheet.setRowHeight(4, 25); // Заголовки днів
  }

  String _formatDateRange(DateTime startDate, DateTime endDate) {
    final formatter = DateFormat('dd.MM.yyyy');
    final start = formatter.format(startDate);
    final end = formatter.format(endDate);
    
    if (start == end) {
      return start;
    }
    
    return '${start}-${end}';
  }
}