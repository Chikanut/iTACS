import 'dart:convert';
import 'dart:typed_data';
import 'package:archive/archive.dart';
import 'package:flutter/material.dart';
import 'package:excel/excel.dart' as excel;
import 'package:intl/intl.dart';
import 'base_report.dart';
import '../../models/lesson_model.dart';
import '../../pages/calendar_page/calendar_utils.dart';
import '../../globals.dart';
import '../dashboard_service.dart';

class _CellComment {
  final int colIndex;
  final int rowIndex;
  final String text;

  _CellComment({
    required this.colIndex,
    required this.rowIndex,
    required this.text,
  });

  String get cellRef => '${_colLetter(colIndex)}${rowIndex + 1}';

  static String _colLetter(int col) {
    String result = '';
    int c = col + 1;
    while (c > 0) {
      final rem = (c - 1) % 26;
      result = String.fromCharCode(65 + rem) + result;
      c = (c - 1) ~/ 26;
    }
    return result;
  }
}

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

      final units = lessons
          .map((l) => l.unit)
          .where((u) => u.isNotEmpty)
          .toSet();
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
      throw UnsupportedError(
        'Формат ${format.displayName} поки не підтримується для звіту "$name"',
      );
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

    final dashboardService = DashboardService();
    final lessons = await dashboardService.getLessonsForPeriod(
      startDate: startDate,
      endDate: endDate,
    );

    final daysInPeriod = _generateDaysList(startDate, endDate);
    final unitsList = _getUniqueUnits(lessons);
    final lessonsByUnitAndDate = _organizeLessonsByUnitAndDate(
      lessons,
      daysInPeriod,
    );

    _createHeader(sheet, startDate, endDate);

    final comments = <_CellComment>[];
    _createCalendarGrid(
      sheet,
      daysInPeriod,
      unitsList,
      lessonsByUnitAndDate,
      comments,
    );
    _addLegend(sheet, daysInPeriod.length, unitsList.length);
    _formatSheet(sheet, daysInPeriod.length);

    final xlsxBytes = Uint8List.fromList(excelFile.encode()!);

    if (comments.isNotEmpty) {
      return _injectComments(xlsxBytes, comments);
    }

    return xlsxBytes;
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
    final titleCell = sheet.cell(
      excel.CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 0),
    );
    titleCell.value = excel.TextCellValue('КАЛЕНДАРНА СІТКА');
    titleCell.cellStyle = excel.CellStyle(
      fontSize: 16,
      bold: true,
      horizontalAlign: excel.HorizontalAlign.Center,
    );

    final dateRange =
        'Період: ${DateFormat('dd.MM.yyyy').format(startDate)} - ${DateFormat('dd.MM.yyyy').format(endDate)}';
    final periodCell = sheet.cell(
      excel.CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 1),
    );
    periodCell.value = excel.TextCellValue(dateRange);
    periodCell.cellStyle = excel.CellStyle(
      fontSize: 12,
      horizontalAlign: excel.HorizontalAlign.Center,
    );

    final groupName = Globals.profileManager.currentGroupName ?? 'Не вибрано';
    final groupCell = sheet.cell(
      excel.CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 2),
    );
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
    List<_CellComment> comments,
  ) {
    const startRow = 4;

    for (int dayIndex = 0; dayIndex < days.length; dayIndex++) {
      final day = days[dayIndex];
      final dayName = CalendarUtils.getDayName(day.weekday, short: true);
      final dayNumber = day.day.toString();

      final headerCell = sheet.cell(
        excel.CellIndex.indexByColumnRow(
          columnIndex: dayIndex + 1,
          rowIndex: startRow,
        ),
      );
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

    final unitHeaderCell = sheet.cell(
      excel.CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: startRow),
    );
    unitHeaderCell.value = excel.TextCellValue('Підрозділ');
    unitHeaderCell.cellStyle = excel.CellStyle(
      fontSize: 11,
      bold: true,
      backgroundColorHex: excel.ExcelColor.fromHexString('#4472C4'),
      fontColorHex: excel.ExcelColor.fromHexString('#FFFFFF'),
      horizontalAlign: excel.HorizontalAlign.Center,
      verticalAlign: excel.VerticalAlign.Center,
    );

    int currentRow = startRow + 1;

    for (final unit in units) {
      final unitLessons = lessonsByUnitAndDate[unit] ?? {};

      int maxLessonsPerDay = 0;
      for (final dayLessons in unitLessons.values) {
        if (dayLessons.length > maxLessonsPerDay) {
          maxLessonsPerDay = dayLessons.length;
        }
      }
      if (maxLessonsPerDay == 0) maxLessonsPerDay = 1;

      for (int lessonRow = 0; lessonRow < maxLessonsPerDay; lessonRow++) {
        if (lessonRow == 0) {
          final unitCell = sheet.cell(
            excel.CellIndex.indexByColumnRow(
              columnIndex: 0,
              rowIndex: currentRow,
            ),
          );
          unitCell.value = excel.TextCellValue(unit);
          unitCell.cellStyle = excel.CellStyle(
            fontSize: 10,
            bold: true,
            backgroundColorHex: excel.ExcelColor.fromHexString('#E6E6FA'),
            horizontalAlign: excel.HorizontalAlign.Left,
            verticalAlign: excel.VerticalAlign.Center,
          );

          if (maxLessonsPerDay > 1) {
            sheet.merge(
              excel.CellIndex.indexByColumnRow(
                columnIndex: 0,
                rowIndex: currentRow,
              ),
              excel.CellIndex.indexByColumnRow(
                columnIndex: 0,
                rowIndex: currentRow + maxLessonsPerDay - 1,
              ),
            );
          }
        }

        for (int dayIndex = 0; dayIndex < days.length; dayIndex++) {
          final day = days[dayIndex];
          final dayLessons = unitLessons[day] ?? [];

          final lessonCell = sheet.cell(
            excel.CellIndex.indexByColumnRow(
              columnIndex: dayIndex + 1,
              rowIndex: currentRow,
            ),
          );

          if (lessonRow < dayLessons.length) {
            final lesson = dayLessons[lessonRow];
            lessonCell.value = excel.TextCellValue(lesson.title);

            final backgroundColor = _getLessonColor(lesson.title);
            lessonCell.cellStyle = excel.CellStyle(
              fontSize: 9,
              bold: true,
              backgroundColorHex: excel.ExcelColor.fromHexString(
                backgroundColor,
              ),
              horizontalAlign: excel.HorizontalAlign.Center,
              verticalAlign: excel.VerticalAlign.Center,
              textWrapping: excel.TextWrapping.WrapText,
            );

            comments.add(_CellComment(
              colIndex: dayIndex + 1,
              rowIndex: currentRow,
              text: _buildCommentText(unit, lesson),
            ));
          } else {
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

  String _buildCommentText(String unit, LessonModel lesson) {
    final parts = <String>[];

    parts.add('Підрозділ: $unit');
    parts.add('');

    if (lesson.description.isNotEmpty) {
      parts.add('${lesson.title}: "${lesson.description}"');
    } else {
      parts.add(lesson.title);
    }

    final minutes = lesson.durationInMinutes;
    final hours = minutes ~/ 60;
    final remainMins = minutes % 60;
    final durStr = remainMins == 0
        ? '$hours ${_ukrainianHours(hours)}'
        : '$hours ${_ukrainianHours(hours)} $remainMins хв';
    parts.add('Час: $durStr');
    parts.add('');

    for (final def in lesson.customFieldDefinitions) {
      final value = lesson.customFieldDisplayValueByCode(
        def.code,
        emptyFallback: '',
      );
      if (value.isNotEmpty && value != 'Не вказано') {
        if (def.label.isNotEmpty) {
          parts.add('${def.label}  №$value');
        } else {
          parts.add(value);
        }
      }
    }

    while (parts.isNotEmpty && parts.last.isEmpty) {
      parts.removeLast();
    }

    return parts.join('\n');
  }

  String _ukrainianHours(int hours) {
    final mod10 = hours % 10;
    final mod100 = hours % 100;
    if (mod10 == 1 && mod100 != 11) return 'година';
    if (mod10 >= 2 && mod10 <= 4 && (mod100 < 10 || mod100 >= 20)) {
      return 'години';
    }
    return 'годин';
  }

  String _getLessonColor(String lessonTitle) {
    final title = lessonTitle.toLowerCase();

    if (title.contains('теор') || title.contains('лекц')) {
      return '#E6F3FF';
    } else if (title.contains('практ') || title.contains('навч')) {
      return '#E6FFE6';
    } else if (title.contains('стрільб') || title.contains('вогнев')) {
      return '#FFE6E6';
    } else if (title.contains('фізич') || title.contains('спорт')) {
      return '#FFFFE6';
    } else if (title.contains('тактич') || title.contains('бойов')) {
      return '#F0E6FF';
    } else if (title.contains('техніч') || title.contains('обслуг')) {
      return '#FFE6F0';
    } else {
      return '#F5F5F5';
    }
  }

  void _addLegend(excel.Sheet sheet, int daysCount, int unitsCount) {
    final legendStartRow = 6 + unitsCount * 2;

    final legendHeaderCell = sheet.cell(
      excel.CellIndex.indexByColumnRow(
        columnIndex: 0,
        rowIndex: legendStartRow,
      ),
    );
    legendHeaderCell.value = excel.TextCellValue('ЛЕГЕНДА КОЛЬОРІВ:');
    legendHeaderCell.cellStyle = excel.CellStyle(fontSize: 11, bold: true);

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

      final colorCell = sheet.cell(
        excel.CellIndex.indexByColumnRow(
          columnIndex: 0,
          rowIndex: legendStartRow + 1 + i,
        ),
      );
      colorCell.value = excel.TextCellValue('■');
      colorCell.cellStyle = excel.CellStyle(
        fontSize: 14,
        backgroundColorHex: excel.ExcelColor.fromHexString(color),
      );

      final labelCell = sheet.cell(
        excel.CellIndex.indexByColumnRow(
          columnIndex: 1,
          rowIndex: legendStartRow + 1 + i,
        ),
      );
      labelCell.value = excel.TextCellValue(label);
      labelCell.cellStyle = excel.CellStyle(fontSize: 9);
    }

    final generatedCell = sheet.cell(
      excel.CellIndex.indexByColumnRow(
        columnIndex: 0,
        rowIndex: legendStartRow + colorLegend.length + 2,
      ),
    );
    generatedCell.value = excel.TextCellValue(
      'Згенеровано: ${DateFormat('dd.MM.yyyy HH:mm').format(DateTime.now())}',
    );
    generatedCell.cellStyle = excel.CellStyle(
      fontSize: 8,
      fontColorHex: excel.ExcelColor.fromHexString('#666666'),
    );
  }

  void _formatSheet(excel.Sheet sheet, int daysCount) {
    sheet.setColumnWidth(0, 20);
    for (int i = 1; i <= daysCount; i++) {
      sheet.setColumnWidth(i, 15);
    }
    sheet.setRowHeight(4, 25);
  }

  String _formatDateRange(DateTime startDate, DateTime endDate) {
    final formatter = DateFormat('dd.MM.yyyy');
    final start = formatter.format(startDate);
    final end = formatter.format(endDate);
    if (start == end) return start;
    return '$start-$end';
  }

  // ===== COMMENT INJECTION =====

  Uint8List _injectComments(Uint8List xlsxBytes, List<_CellComment> comments) {
    final archive = ZipDecoder().decodeBytes(xlsxBytes);

    ArchiveFile? worksheetFile;
    for (final file in archive.files) {
      if (file.isFile &&
          file.name.startsWith('xl/worksheets/sheet') &&
          file.name.endsWith('.xml') &&
          !file.name.contains('_rels')) {
        worksheetFile = file;
        break;
      }
    }

    if (worksheetFile == null) return xlsxBytes;

    final worksheetFileName = worksheetFile.name.split('/').last;
    final sheetNum =
        worksheetFileName.replaceAll(RegExp(r'\D'), '').isEmpty
        ? '1'
        : worksheetFileName.replaceAll(RegExp(r'\D'), '');
    final commentsPath = 'xl/comments$sheetNum.xml';
    final vmlPath = 'xl/drawings/vmlDrawing$sheetNum.vml';
    final relsPath = 'xl/worksheets/_rels/$worksheetFileName.rels';

    final newArchive = Archive();
    bool relsFound = false;

    for (final file in archive.files) {
      if (!file.isFile) {
        newArchive.addFile(file);
        continue;
      }

      final rawContent = file.content as List<int>;

      if (file.name == worksheetFile.name) {
        final text = utf8.decode(rawContent, allowMalformed: true);
        final modified = text.replaceFirst(
          '</worksheet>',
          '<legacyDrawing r:id="rId_cv"/></worksheet>',
        );
        final bytes = utf8.encode(modified);
        newArchive.addFile(ArchiveFile(file.name, bytes.length, bytes));
        continue;
      }

      if (file.name == '[Content_Types].xml') {
        var text = utf8.decode(rawContent, allowMalformed: true);
        if (!text.contains('vmlDrawing')) {
          text = text.replaceFirst(
            '</Types>',
            '<Default Extension="vml" ContentType="application/vnd.openxmlformats-officedocument.vmlDrawing"/></Types>',
          );
        }
        if (!text.contains('spreadsheetml.comments')) {
          text = text.replaceFirst(
            '</Types>',
            '<Override PartName="/$commentsPath" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.comments+xml"/></Types>',
          );
        }
        final bytes = utf8.encode(text);
        newArchive.addFile(ArchiveFile(file.name, bytes.length, bytes));
        continue;
      }

      if (file.name == relsPath) {
        relsFound = true;
        final text = utf8.decode(rawContent, allowMalformed: true);
        final modified = text.replaceFirst(
          '</Relationships>',
          '<Relationship Id="rId_cc" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/comments" Target="../comments$sheetNum.xml"/>'
          '<Relationship Id="rId_cv" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/vmlDrawing" Target="../drawings/vmlDrawing$sheetNum.vml"/>'
          '</Relationships>',
        );
        final bytes = utf8.encode(modified);
        newArchive.addFile(ArchiveFile(file.name, bytes.length, bytes));
        continue;
      }

      newArchive.addFile(file);
    }

    if (!relsFound) {
      final relsContent =
          '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
          '<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">'
          '<Relationship Id="rId_cc" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/comments" Target="../comments$sheetNum.xml"/>'
          '<Relationship Id="rId_cv" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/vmlDrawing" Target="../drawings/vmlDrawing$sheetNum.vml"/>'
          '</Relationships>';
      final bytes = utf8.encode(relsContent);
      newArchive.addFile(ArchiveFile(relsPath, bytes.length, bytes));
    }

    final commentsXml = _buildCommentsXml(comments);
    final commentsBytes = utf8.encode(commentsXml);
    newArchive.addFile(
      ArchiveFile(commentsPath, commentsBytes.length, commentsBytes),
    );

    final vmlXml = _buildVmlXml(comments);
    final vmlBytes = utf8.encode(vmlXml);
    newArchive.addFile(ArchiveFile(vmlPath, vmlBytes.length, vmlBytes));

    return Uint8List.fromList(ZipEncoder().encode(newArchive)!);
  }

  String _buildCommentsXml(List<_CellComment> comments) {
    final buf = StringBuffer();
    buf.write('<?xml version="1.0" encoding="UTF-8" standalone="yes"?>');
    buf.write(
      '<comments xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">',
    );
    buf.write('<authors><author></author></authors>');
    buf.write('<commentList>');
    for (final c in comments) {
      buf.write('<comment ref="${c.cellRef}" authorId="0">');
      buf.write('<text><r>');
      buf.write('<rPr><b/><sz val="9"/><name val="Tahoma"/></rPr>');
      buf.write('<t xml:space="preserve">${_xmlEscape(c.text)}</t>');
      buf.write('</r></text>');
      buf.write('</comment>');
    }
    buf.write('</commentList></comments>');
    return buf.toString();
  }

  String _buildVmlXml(List<_CellComment> comments) {
    final buf = StringBuffer();
    buf.write(
      '<xml xmlns:v="urn:schemas-microsoft-com:vml"'
      ' xmlns:o="urn:schemas-microsoft-com:office:office"'
      ' xmlns:x="urn:schemas-microsoft-com:office:excel">',
    );
    buf.write(
      '<o:shapelayout v:ext="edit">'
      '<o:idmap v:ext="edit" data="1"/>'
      '</o:shapelayout>',
    );
    buf.write(
      '<v:shapetype id="_x0000_t202" coordsize="21600,21600" o:spt="202"'
      ' path="m,l,21600r21600,l21600,xe">'
      '<v:stroke joinstyle="miter"/>'
      '<v:path gradientshapeok="t" o:connecttype="rect"/>'
      '</v:shapetype>',
    );

    for (int i = 0; i < comments.length; i++) {
      final c = comments[i];
      final shapeId = 1025 + i;
      final col = c.colIndex;
      final row = c.rowIndex;
      // Anchor: leftCol, leftOffset, topRow, topOffset, rightCol, rightOffset, bottomRow, bottomOffset
      final anchor = '${col + 1}, 15, $row, 2, ${col + 3}, 15, ${row + 5}, 16';

      buf.write(
        '<v:shape id="_x0000_s$shapeId" type="#_x0000_t202"'
        ' style="position:absolute;margin-left:59.25pt;margin-top:1.5pt;'
        'width:200pt;height:150pt;z-index:${i + 1};visibility:hidden"'
        ' fillcolor="#ffffe1" o:insetmode="auto">',
      );
      buf.write('<v:fill color2="#ffffe1"/>');
      buf.write('<v:shadow on="t" color="black" obscured="t"/>');
      buf.write('<v:path o:connecttype="none"/>');
      buf.write(
        '<v:textbox style="mso-direction-alt:auto">'
        '<div style="text-align:left"/>'
        '</v:textbox>',
      );
      buf.write('<x:ClientData ObjectType="Note">');
      buf.write('<x:MoveWithCells/>');
      buf.write('<x:SizeWithCells/>');
      buf.write('<x:Anchor>$anchor</x:Anchor>');
      buf.write('<x:AutoFill>False</x:AutoFill>');
      buf.write('<x:Row>$row</x:Row>');
      buf.write('<x:Column>$col</x:Column>');
      buf.write('</x:ClientData>');
      buf.write('</v:shape>');
    }

    buf.write('</xml>');
    return buf.toString();
  }

  String _xmlEscape(String text) {
    return text
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;')
        .replaceAll('"', '&quot;');
  }
}
