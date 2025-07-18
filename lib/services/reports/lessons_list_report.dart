import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:excel/excel.dart' as ex;
import 'package:intl/intl.dart';
import 'base_report.dart';
import '../../models/lesson_model.dart';
import '../../globals.dart';
import '../dashboard_service.dart';

class LessonsListReport extends BaseReport {
  @override
  String get id => 'lessons_list';

  @override
  String get name => 'Список занять';

  @override
  String get description => 
      'Список проведених занять по інструкторах у форматі:\n'
      'Дата | Підрозділ | Період навчання | Назва заняття';

  @override
  IconData get icon => Icons.list_alt;

  @override
  String get category => 'lessons';

  @override
  List<ReportFormat> get supportedFormats => [ReportFormat.excel];

  @override
  bool get requiresParameters => true;

  @override
  List<String> get requiredRoles => ['viewer']; // Доступний всім

  @override
  Widget? getParametersWidget({
    required Function(Map<String, dynamic>) onParametersChanged,
    Map<String, dynamic>? initialParameters,
  }) {
    return LessonsListParametersWidget(
      onParametersChanged: onParametersChanged,
      initialParameters: initialParameters,
    );
  }

  @override
  String? validateParameters(Map<String, dynamic>? parameters) {
    if (parameters == null) return null;
    
    // Перевіряємо ID інструктора якщо вказано
    if (parameters.containsKey('instructorId')) {
      final instructorId = parameters['instructorId'];
      if (instructorId != null && instructorId is! String) {
        return 'ID інструктора має бути рядком';
      }
      if (instructorId != null && (instructorId as String).isEmpty) {
        return 'ID інструктора не може бути порожнім';
      }
    }
    
    return null;
  }

  @override
  Future<String?> validateReportSpecificConditions({
    required DateTime startDate,
    required DateTime endDate,
    Map<String, dynamic>? parameters,
  }) async {
    try {
      // Перевіряємо чи є дані за період
      final dashboardService = DashboardService();
      final lessons = await dashboardService.getLessonsForPeriod(
        startDate: startDate,
        endDate: endDate,
      );

      final filteredLessons = _filterLessons(lessons, parameters);
      
      if (filteredLessons.isEmpty) {
        return 'За вказаний період не знайдено проведених занять з інструкторами';
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

      final filteredLessons = _filterLessons(lessons, parameters);
      final instructorCount = _groupLessonsByInstructor(filteredLessons).length;

      String estimatedSize = 'Мало';
      if (filteredLessons.length > 100) estimatedSize = 'Середньо';
      if (filteredLessons.length > 500) estimatedSize = 'Велико';

      return {
        'reportId': id,
        'reportName': name,
        'dateRange': _formatDateRange(startDate, endDate),
        'estimatedSize': estimatedSize,
        'recordsCount': filteredLessons.length,
        'instructorsCount': instructorCount,
        'hasData': filteredLessons.isNotEmpty,
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
    
    String fileName = 'Список_занять_$dateRange';
    
    // Додаємо ім'я інструктора якщо вибрано конкретного
    if (parameters != null && 
        parameters['instructorName'] != null && 
        parameters['instructorName'] != 'Всі інструктори') {
      final instructorName = (parameters['instructorName'] as String)
          .replaceAll(RegExp(r'[^\w\s-]'), '')
          .replaceAll(' ', '_');
      fileName = 'Список_занять_${instructorName}_$dateRange';
    }
    
    return '$fileName.${format.extension}';
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
    final excel = ex.Excel.createExcel();
    final sheet = excel['Список занять'];
    excel.delete('Sheet1');

    // Отримуємо дані
    final dashboardService = DashboardService();
    final lessons = await dashboardService.getLessonsForPeriod(
      startDate: startDate,
      endDate: endDate,
    );

    // Фільтруємо заняття
    final filteredLessons = _filterLessons(lessons, parameters);
    
    // Групуємо по інструкторах
    final lessonsByInstructor = _groupLessonsByInstructor(filteredLessons);

    // Генеруємо звіт
    _createHeader(sheet, startDate, endDate, parameters);
    _createContent(sheet, lessonsByInstructor);
    _formatSheet(sheet);

    return Uint8List.fromList(excel.encode()!);
  }

  List<LessonModel> _filterLessons(List<LessonModel> lessons, Map<String, dynamic>? parameters) {
    return lessons.where((lesson) {
      // Тільки проведені заняття
      final isCompleted = lesson.endTime.isBefore(DateTime.now());
      if (!isCompleted) return false;

      // Тільки з інструкторами
      final hasInstructor = lesson.instructorId.isNotEmpty;
      if (!hasInstructor) return false;

      // Фільтр по конкретному інструктору
      if (parameters != null && parameters['instructorId'] != null) {
        final instructorId = parameters['instructorId'] as String;
        if (lesson.instructorId != instructorId) return false;
      }

      return true;
    }).toList();
  }

  Map<String, List<LessonModel>> _groupLessonsByInstructor(List<LessonModel> lessons) {
    final grouped = <String, List<LessonModel>>{};
    
    for (final lesson in lessons) {
      final key = lesson.instructorName.isNotEmpty 
          ? lesson.instructorName 
          : 'ID: ${lesson.instructorId}';
      
      grouped.putIfAbsent(key, () => []).add(lesson);
    }

    // Сортуємо заняття в кожній групі по даті
    for (final group in grouped.values) {
      group.sort((a, b) => a.startTime.compareTo(b.startTime));
    }

    return grouped;
  }

  void _createHeader(ex.Sheet sheet, DateTime startDate, DateTime endDate, Map<String, dynamic>? parameters) {
    // Основний заголовок
    final titleText = 'СПИСОК ЗАНЯТЬ';
    final titleCell = sheet.cell(ex.CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 0));
    titleCell.value = ex.TextCellValue(titleText);
    sheet.merge(ex.CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 0), 
               ex.CellIndex.indexByColumnRow(columnIndex: 3, rowIndex: 0));

    titleCell.cellStyle = ex.CellStyle(
      fontSize: 16,
      bold: true,
      horizontalAlign: ex.HorizontalAlign.Center,
    );

    // Період
    final dateRange = 'за період з ${DateFormat('dd.MM.yyyy').format(startDate)} по ${DateFormat('dd.MM.yyyy').format(endDate)}';
    final periodCell = sheet.cell(ex.CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 1));
    periodCell.value = ex.TextCellValue(dateRange);
    sheet.merge(ex.CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 1), 
               ex.CellIndex.indexByColumnRow(columnIndex: 3, rowIndex: 1));

    periodCell.cellStyle = ex.CellStyle(
      fontSize: 12,
      horizontalAlign: ex.HorizontalAlign.Center,
    );

    // Група
    final groupName = Globals.profileManager.currentGroupName ?? 'Не вибрано';
    final groupCell = sheet.cell(ex.CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 2));
    groupCell.value = ex.TextCellValue('Група: $groupName');
    sheet.merge(ex.CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 2), 
               ex.CellIndex.indexByColumnRow(columnIndex: 3, rowIndex: 2));

    groupCell.cellStyle = ex.CellStyle(
      fontSize: 11,
      horizontalAlign: ex.HorizontalAlign.Center,
    );

    // Додаткова інформація про фільтри
    int currentRow = 3;
    if (parameters != null && parameters['instructorName'] != null && parameters['instructorName'] != 'Всі інструктори') {
      final instructorName = parameters['instructorName'] as String;
      final instructorCell = sheet.cell(ex.CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: currentRow));
      instructorCell.value = ex.TextCellValue('Інструктор: $instructorName');
      sheet.merge(ex.CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: currentRow), 
                 ex.CellIndex.indexByColumnRow(columnIndex: 3, rowIndex: currentRow));

      instructorCell.cellStyle = ex.CellStyle(
        fontSize: 11,
        horizontalAlign: ex.HorizontalAlign.Center,
        bold: true,
      );
      currentRow++;
    }

    // Дата генерації
    final generatedText = 'Згенеровано: ${DateFormat('dd.MM.yyyy HH:mm').format(DateTime.now())}';
    final generatedCell = sheet.cell(ex.CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: currentRow));
    generatedCell.value = ex.TextCellValue(generatedText);
    sheet.merge(ex.CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: currentRow), 
               ex.CellIndex.indexByColumnRow(columnIndex: 3, rowIndex: currentRow));

    generatedCell.cellStyle = ex.CellStyle(
      fontSize: 9,
      horizontalAlign: ex.HorizontalAlign.Center,
      fontColorHex: ex.ExcelColor.fromHexString('#666666'),
    );
  }

  void _createContent(ex.Sheet sheet, Map<String, List<LessonModel>> lessonsByInstructor) {
    int currentRow = 5; // Почати після заголовків

    // Заголовки таблиці
    final headers = ['Дата', 'Підрозділ', 'Період навчання', 'Назва заняття'];
    for (int i = 0; i < headers.length; i++) {
      final cell = sheet.cell(ex.CellIndex.indexByColumnRow(columnIndex: i, rowIndex: currentRow));
      cell.value = ex.TextCellValue(headers[i]);
      cell.cellStyle = ex.CellStyle(
        fontSize: 11,
        bold: true,
        backgroundColorHex: ex.ExcelColor.fromHexString('#E6E6FA'),
        horizontalAlign: ex.HorizontalAlign.Center,
        verticalAlign: ex.VerticalAlign.Center,
      );
    }
    currentRow++;

    // Сортуємо інструкторів по алфавіту
    final sortedInstructors = lessonsByInstructor.keys.toList()..sort();

    for (final instructorName in sortedInstructors) {
      final lessons = lessonsByInstructor[instructorName]!;

      // Заголовок інструктора
      final instructorHeaderCell = sheet.cell(ex.CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: currentRow));
      instructorHeaderCell.value = ex.TextCellValue('ІНСТРУКТОР: $instructorName');
      sheet.merge(ex.CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: currentRow), 
                 ex.CellIndex.indexByColumnRow(columnIndex: 3, rowIndex: currentRow));

      instructorHeaderCell.cellStyle = ex.CellStyle(
        fontSize: 11,
        bold: true,
        backgroundColorHex: ex.ExcelColor.fromHexString('#D3D3D3'),
        horizontalAlign: ex.HorizontalAlign.Left,
      );
      currentRow++;

      // Заняття інструктора
      for (final lesson in lessons) {
        // Дата
        final dateCell = sheet.cell(ex.CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: currentRow));
        dateCell.value = ex.TextCellValue(DateFormat('dd.MM.yyyy').format(lesson.startTime));
        dateCell.cellStyle = ex.CellStyle(
          fontSize: 11,
          horizontalAlign: ex.HorizontalAlign.Center,
        );
        
        // Підрозділ (unit)
        final unitCell = sheet.cell(ex.CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: currentRow));
        unitCell.value = ex.TextCellValue(lesson.unit.isNotEmpty ? lesson.unit : '-');
        unitCell.cellStyle = ex.CellStyle(
          fontSize: 11,
          horizontalAlign: ex.HorizontalAlign.Left,
        );
        
        // Період навчання
        final periodCell = sheet.cell(ex.CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: currentRow));
        periodCell.value = ex.TextCellValue(_formatTrainingPeriod(lesson.trainingPeriod));
        periodCell.cellStyle = ex.CellStyle(
          fontSize: 11,
          horizontalAlign: ex.HorizontalAlign.Left,
        );
        
        // Назва заняття
        final titleCell = sheet.cell(ex.CellIndex.indexByColumnRow(columnIndex: 3, rowIndex: currentRow));
        titleCell.value = ex.TextCellValue(lesson.title);
        titleCell.cellStyle = ex.CellStyle(
          fontSize: 11,
          horizontalAlign: ex.HorizontalAlign.Left,
        );
        
        currentRow++;
      }

      // Підсумок для інструктора
      final summaryCell = sheet.cell(ex.CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: currentRow));
      summaryCell.value = ex.TextCellValue('Всього занять: ${lessons.length}');
      sheet.merge(ex.CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: currentRow), 
                 ex.CellIndex.indexByColumnRow(columnIndex: 3, rowIndex: currentRow));
      
      summaryCell.cellStyle = ex.CellStyle(
        fontSize: 11,
        bold: true,
        backgroundColorHex: ex.ExcelColor.fromHexString('#F0F0F0'),
        horizontalAlign: ex.HorizontalAlign.Right,
      );
      currentRow += 2; // Додаємо відступ між інструкторами
    }

    // Загальна статистика в кінці
    if (lessonsByInstructor.isNotEmpty) {
      final totalLessons = lessonsByInstructor.values
          .fold(0, (sum, lessons) => sum + lessons.length);
      final totalInstructors = lessonsByInstructor.length;

      final totalHeaderCell = sheet.cell(ex.CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: currentRow));
      totalHeaderCell.value = ex.TextCellValue('ЗАГАЛЬНА СТАТИСТИКА');
      sheet.merge(ex.CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: currentRow), 
                 ex.CellIndex.indexByColumnRow(columnIndex: 3, rowIndex: currentRow));

      totalHeaderCell.cellStyle = ex.CellStyle(
        fontSize: 12,
        bold: true,
        backgroundColorHex: ex.ExcelColor.fromHexString('#4472C4'),
        fontColorHex: ex.ExcelColor.fromHexString('#FFFFFF'),
        horizontalAlign: ex.HorizontalAlign.Center,
      );
      currentRow++;

      // Кількість інструкторів
      final instructorsCell = sheet.cell(ex.CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: currentRow));
      instructorsCell.value = ex.TextCellValue('Інструкторів: $totalInstructors');
      sheet.merge(ex.CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: currentRow), 
                 ex.CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: currentRow));

      // Загальна кількість занять
      final totalCell = sheet.cell(ex.CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: currentRow));
      totalCell.value = ex.TextCellValue('Всього занять: $totalLessons');
      sheet.merge(ex.CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: currentRow), 
                 ex.CellIndex.indexByColumnRow(columnIndex: 3, rowIndex: currentRow));

      instructorsCell.cellStyle = totalCell.cellStyle = ex.CellStyle(
        fontSize: 11,
        bold: true,
        horizontalAlign: ex.HorizontalAlign.Center,
      );
    }
  }

  String _formatTrainingPeriod(String period) {
    if (period.isEmpty || period == '-') return '-';
    
    if (period.contains(' - ')) {
      try {
        final parts = period.split(' - ');
        if (parts.length == 2) {
          final start = DateTime.parse(parts[0]);
          final end = DateTime.parse(parts[1]);
          return '${DateFormat('dd.MM.yyyy').format(start)} - ${DateFormat('dd.MM.yyyy').format(end)}';
        }
      } catch (e) {
        // Якщо не вдається розпарсити - повертаємо як є
      }
    }
    
    return period;
  }

  void _formatSheet(ex.Sheet sheet) {
    // Налаштовуємо ширину колонок
    sheet.setColumnWidth(0, 15); // Дата
    sheet.setColumnWidth(1, 20); // Підрозділ
    sheet.setColumnWidth(2, 25); // Період навчання
    sheet.setColumnWidth(3, 35); // Назва заняття
  }

  String _formatDateRange(DateTime startDate, DateTime endDate) {
    final formatter = DateFormat('dd.MM.yyyy');
    final start = formatter.format(startDate);
    final end = formatter.format(endDate);
    
    if (start == end) {
      return start;
    }
    
    return '$start-$end';
  }
}

// ===== ВІДЖЕТ ПАРАМЕТРІВ =====

class LessonsListParametersWidget extends StatefulWidget {
  final Function(Map<String, dynamic>) onParametersChanged;
  final Map<String, dynamic>? initialParameters;

  const LessonsListParametersWidget({
    super.key,
    required this.onParametersChanged,
    this.initialParameters,
  });

  @override
  State<LessonsListParametersWidget> createState() => _LessonsListParametersWidgetState();
}

class _LessonsListParametersWidgetState extends State<LessonsListParametersWidget> {
  String? selectedInstructorId;
  String? selectedInstructorName;
  final Map<String, String> availableInstructors = {};
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadInstructors();
    
    // Ініціалізуємо з початковими параметрами
    if (widget.initialParameters != null) {
      selectedInstructorId = widget.initialParameters!['instructorId'];
      selectedInstructorName = widget.initialParameters!['instructorName'];
    }
  }

  Future<void> _loadInstructors() async {
    try {
      setState(() {
        _loading = true;
        _error = null;
      });

      // Отримуємо список інструкторів з останніх занять
      final dashboardService = DashboardService();
      final now = DateTime.now();
      final oneMonthAgo = now.subtract(const Duration(days: 30));
      
      final recentLessons = await dashboardService.getLessonsForPeriod(
        startDate: oneMonthAgo,
        endDate: now,
      );

      // Збираємо унікальних інструкторів
      final instructors = <String, String>{};
      instructors['all'] = 'Всі інструктори';

      for (final lesson in recentLessons) {
        if (lesson.instructorId.isNotEmpty && lesson.instructorName.isNotEmpty) {
          instructors[lesson.instructorId] = lesson.instructorName;
        }
      }

      setState(() {
        availableInstructors.clear();
        availableInstructors.addAll(instructors);
        _loading = false;
      });

      // Встановлюємо значення за замовчуванням
      if (selectedInstructorId == null) {
        selectedInstructorId = 'all';
        selectedInstructorName = 'Всі інструктори';
        _updateParameters();
      }

    } catch (e) {
      setState(() {
        _loading = false;
        _error = 'Помилка завантаження інструкторів: $e';
        availableInstructors.clear();
        availableInstructors['all'] = 'Всі інструктори';
      });
    }
  }

  void _updateParameters() {
    final parameters = <String, dynamic>{};
    
    if (selectedInstructorId != null && selectedInstructorId != 'all') {
      parameters['instructorId'] = selectedInstructorId;
      parameters['instructorName'] = selectedInstructorName;
    }
    
    widget.onParametersChanged(parameters);
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                const Icon(Icons.settings, size: 20),
                const SizedBox(width: 8),
                const Text(
                  'Параметри звіту', 
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            
            if (_loading)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(20),
                  child: CircularProgressIndicator(),
                ),
              )
            else if (_error != null)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  border: Border.all(color: Colors.red.shade200),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(Icons.error, color: Colors.red.shade600, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _error!,
                        style: TextStyle(color: Colors.red.shade700),
                      ),
                    ),
                    TextButton(
                      onPressed: _loadInstructors,
                      child: const Text('Повторити'),
                    ),
                  ],
                ),
              )
            else ...[
              const Text(
                'Інструктор:',
                style: TextStyle(fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 8),
              
              Container(
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade300),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: DropdownButtonFormField<String>(
                  value: selectedInstructorId ?? 'all',
                  decoration: const InputDecoration(
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                  isExpanded: true,
                  items: availableInstructors.entries.map((entry) {
                    return DropdownMenuItem(
                      value: entry.key,
                      child: Text(
                        entry.value,
                        overflow: TextOverflow.ellipsis,
                      ),
                    );
                  }).toList(),
                  onChanged: (value) {
                    setState(() {
                      if (value == 'all') {
                        selectedInstructorId = null;
                        selectedInstructorName = null;
                      } else {
                        selectedInstructorId = value;
                        selectedInstructorName = availableInstructors[value];
                      }
                    });
                    _updateParameters();
                  },
                ),
              ),
              
              const SizedBox(height: 12),
              
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  border: Border.all(color: Colors.blue.shade200),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info, color: Colors.blue.shade600, size: 20),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'Звіт включає тільки проведені заняття з призначеними інструкторами.',
                        style: TextStyle(fontSize: 13),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}