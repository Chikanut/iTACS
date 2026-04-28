// report_template_model.dart

import 'dart:convert';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';

enum ReportTemplateStatus {
  draft('draft', 'Чернетка'),
  active('active', 'Активний');

  const ReportTemplateStatus(this.id, this.displayName);

  final String id;
  final String displayName;

  static ReportTemplateStatus fromId(String? id) {
    return ReportTemplateStatus.values.firstWhere(
      (value) => value.id == id,
      orElse: () => ReportTemplateStatus.draft,
    );
  }
}

enum ReportTemplateSource {
  lessons('lessons', 'Заняття');

  const ReportTemplateSource(this.id, this.displayName);

  final String id;
  final String displayName;

  static ReportTemplateSource fromId(String? id) {
    return ReportTemplateSource.values.firstWhere(
      (value) => value.id == id,
      orElse: () => ReportTemplateSource.lessons,
    );
  }
}

enum ReportTemplatePeriodField {
  startTime('startTime', 'Початок заняття'),
  endTime('endTime', 'Завершення заняття');

  const ReportTemplatePeriodField(this.id, this.displayName);

  final String id;
  final String displayName;

  static ReportTemplatePeriodField fromId(String? id) {
    return ReportTemplatePeriodField.values.firstWhere(
      (value) => value.id == id,
      orElse: () => ReportTemplatePeriodField.startTime,
    );
  }
}

enum ReportTemplateRowMode {
  lesson('lesson', 'Один рядок = одне заняття'),
  lessonInstructor('lesson_instructor', 'Один рядок = заняття + інструктор'),
  calendarGrid('calendar_grid', 'Календарна сітка (рядок = особа, колонка = день)');

  const ReportTemplateRowMode(this.id, this.displayName);

  final String id;
  final String displayName;

  static ReportTemplateRowMode fromId(String? id) {
    return ReportTemplateRowMode.values.firstWhere(
      (value) => value.id == id,
      orElse: () => ReportTemplateRowMode.lesson,
    );
  }
}

enum ReportTemplateFilterOperator {
  eq('eq', '='),
  neq('neq', '!='),
  inList('in', 'in'),
  contains('contains', 'contains'),
  exists('exists', 'exists'),
  dateBetween('date_between', 'date_between'),
  lteNow('lte_now', '<= now');

  const ReportTemplateFilterOperator(this.id, this.displayName);

  final String id;
  final String displayName;

  static ReportTemplateFilterOperator fromId(String? id) {
    return ReportTemplateFilterOperator.values.firstWhere(
      (value) => value.id == id,
      orElse: () => ReportTemplateFilterOperator.eq,
    );
  }
}

enum ReportTemplateSortDirection {
  asc('asc', 'За зростанням'),
  desc('desc', 'За спаданням');

  const ReportTemplateSortDirection(this.id, this.displayName);

  final String id;
  final String displayName;

  static ReportTemplateSortDirection fromId(String? id) {
    return ReportTemplateSortDirection.values.firstWhere(
      (value) => value.id == id,
      orElse: () => ReportTemplateSortDirection.asc,
    );
  }
}

enum ReportTemplateTotalType {
  count('count', 'Кількість'),
  countDistinct('countDistinct', 'Унікальні значення'),
  sum('sum', 'Сума');

  const ReportTemplateTotalType(this.id, this.displayName);

  final String id;
  final String displayName;

  static ReportTemplateTotalType fromId(String? id) {
    return ReportTemplateTotalType.values.firstWhere(
      (value) => value.id == id,
      orElse: () => ReportTemplateTotalType.count,
    );
  }
}

class ReportTemplateColumn {
  final String key;
  final String label;

  const ReportTemplateColumn({required this.key, required this.label});

  factory ReportTemplateColumn.fromMap(Map<String, dynamic> map) {
    return ReportTemplateColumn(
      key: (map['key'] ?? '').toString().trim(),
      label: (map['label'] ?? '').toString().trim(),
    );
  }

  Map<String, dynamic> toJson() => {'key': key, 'label': label};

  ReportTemplateColumn copyWith({String? key, String? label}) {
    return ReportTemplateColumn(
      key: key ?? this.key,
      label: label ?? this.label,
    );
  }
}

class ReportTemplateFilter {
  final String key;
  final ReportTemplateFilterOperator operator;
  final Object? value;
  final List<Object> values;
  final String? start;
  final String? end;

  const ReportTemplateFilter({
    required this.key,
    required this.operator,
    this.value,
    this.values = const [],
    this.start,
    this.end,
  });

  factory ReportTemplateFilter.fromMap(Map<String, dynamic> map) {
    return ReportTemplateFilter(
      key: (map['key'] ?? '').toString().trim(),
      operator: ReportTemplateFilterOperator.fromId(
        map['operator']?.toString(),
      ),
      value: map['value'],
      values: (map['values'] as List?)?.cast<Object>() ?? const [],
      start: map['start']?.toString(),
      end: map['end']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'key': key,
      'operator': operator.id,
      if (value != null) 'value': value,
      if (values.isNotEmpty) 'values': values,
      if (start != null && start!.trim().isNotEmpty) 'start': start,
      if (end != null && end!.trim().isNotEmpty) 'end': end,
    };
  }

  ReportTemplateFilter copyWith({
    String? key,
    ReportTemplateFilterOperator? operator,
    Object? value = _sentinel,
    List<Object>? values,
    String? start = _sentinelString,
    String? end = _sentinelString,
  }) {
    return ReportTemplateFilter(
      key: key ?? this.key,
      operator: operator ?? this.operator,
      value: identical(value, _sentinel) ? this.value : value,
      values: values ?? this.values,
      start: identical(start, _sentinelString) ? this.start : start,
      end: identical(end, _sentinelString) ? this.end : end,
    );
  }
}

class ReportTemplateSort {
  final String key;
  final ReportTemplateSortDirection dir;

  const ReportTemplateSort({required this.key, required this.dir});

  factory ReportTemplateSort.fromMap(Map<String, dynamic> map) {
    return ReportTemplateSort(
      key: (map['key'] ?? '').toString().trim(),
      dir: ReportTemplateSortDirection.fromId(map['dir']?.toString()),
    );
  }

  Map<String, dynamic> toJson() => {'key': key, 'dir': dir.id};

  ReportTemplateSort copyWith({String? key, ReportTemplateSortDirection? dir}) {
    return ReportTemplateSort(key: key ?? this.key, dir: dir ?? this.dir);
  }
}

class ReportTemplateTotal {
  final ReportTemplateTotalType type;
  final String key;
  final String label;

  const ReportTemplateTotal({
    required this.type,
    this.key = '',
    this.label = '',
  });

  factory ReportTemplateTotal.fromMap(Map<String, dynamic> map) {
    return ReportTemplateTotal(
      type: ReportTemplateTotalType.fromId(map['type']?.toString()),
      key: (map['key'] ?? '').toString().trim(),
      label: (map['label'] ?? '').toString().trim(),
    );
  }

  Map<String, dynamic> toJson() => {
    'type': type.id,
    if (key.trim().isNotEmpty) 'key': key,
    if (label.trim().isNotEmpty) 'label': label,
  };

  ReportTemplateTotal copyWith({
    ReportTemplateTotalType? type,
    String? key,
    String? label,
  }) {
    return ReportTemplateTotal(
      type: type ?? this.type,
      key: key ?? this.key,
      label: label ?? this.label,
    );
  }
}

class ReportTemplateSheet {
  final String name;
  final bool freezeHeader;
  final bool autoWidth;

  const ReportTemplateSheet({
    required this.name,
    this.freezeHeader = true,
    this.autoWidth = true,
  });

  factory ReportTemplateSheet.fromMap(Map<String, dynamic> map) {
    return ReportTemplateSheet(
      name: (map['name'] ?? '').toString().trim(),
      freezeHeader: map['freezeHeader'] != false,
      autoWidth: map['autoWidth'] != false,
    );
  }

  Map<String, dynamic> toJson() => {
    'name': name,
    'freezeHeader': freezeHeader,
    'autoWidth': autoWidth,
  };

  ReportTemplateSheet copyWith({
    String? name,
    bool? freezeHeader,
    bool? autoWidth,
  }) {
    return ReportTemplateSheet(
      name: name ?? this.name,
      freezeHeader: freezeHeader ?? this.freezeHeader,
      autoWidth: autoWidth ?? this.autoWidth,
    );
  }
}

class ReportTemplateConfig {
  final ReportTemplateSource source;
  final ReportTemplatePeriodField periodField;
  final ReportTemplateRowMode rowMode;
  final List<ReportTemplateFilter> filters;
  final List<ReportTemplateColumn> columns;
  final List<String> groupBy;
  final List<ReportTemplateSort> sort;
  final List<ReportTemplateTotal> totals;
  final ReportTemplateSheet sheet;
  // calendar_grid specific
  final List<String> calendarNoteFields;
  final String calendarCellMark;

  const ReportTemplateConfig({
    required this.source,
    required this.periodField,
    required this.rowMode,
    required this.filters,
    required this.columns,
    required this.groupBy,
    required this.sort,
    required this.totals,
    required this.sheet,
    this.calendarNoteFields = const [],
    this.calendarCellMark = 'З',
  });

  factory ReportTemplateConfig.fromMap(Map<String, dynamic> map) {
    return ReportTemplateConfig(
      source: ReportTemplateSource.fromId(map['source']?.toString()),
      periodField: ReportTemplatePeriodField.fromId(
        map['periodField']?.toString(),
      ),
      rowMode: ReportTemplateRowMode.fromId(map['rowMode']?.toString()),
      filters: (map['filters'] as List? ?? const [])
          .whereType<Map>()
          .map(
            (item) =>
                ReportTemplateFilter.fromMap(Map<String, dynamic>.from(item)),
          )
          .toList(),
      columns: (map['columns'] as List? ?? const [])
          .whereType<Map>()
          .map(
            (item) =>
                ReportTemplateColumn.fromMap(Map<String, dynamic>.from(item)),
          )
          .toList(),
      groupBy: (map['groupBy'] as List? ?? const [])
          .map((item) => item.toString().trim())
          .where((item) => item.isNotEmpty)
          .toList(),
      sort: (map['sort'] as List? ?? const [])
          .whereType<Map>()
          .map(
            (item) =>
                ReportTemplateSort.fromMap(Map<String, dynamic>.from(item)),
          )
          .toList(),
      totals: (map['totals'] as List? ?? const [])
          .whereType<Map>()
          .map(
            (item) =>
                ReportTemplateTotal.fromMap(Map<String, dynamic>.from(item)),
          )
          .toList(),
      sheet: ReportTemplateSheet.fromMap(
        Map<String, dynamic>.from(map['sheet'] ?? const {}),
      ),
      calendarNoteFields: (map['calendarNoteFields'] as List? ?? const [])
          .map((item) => item.toString().trim())
          .where((item) => item.isNotEmpty)
          .toList(),
      calendarCellMark: (map['calendarCellMark'] as String?) ?? 'З',
    );
  }

  Map<String, dynamic> toJson() => {
    'source': source.id,
    'periodField': periodField.id,
    'rowMode': rowMode.id,
    'filters': filters.map((item) => item.toJson()).toList(),
    'columns': columns.map((item) => item.toJson()).toList(),
    'groupBy': groupBy,
    'sort': sort.map((item) => item.toJson()).toList(),
    'totals': totals.map((item) => item.toJson()).toList(),
    'sheet': sheet.toJson(),
    if (calendarNoteFields.isNotEmpty) 'calendarNoteFields': calendarNoteFields,
    if (calendarCellMark != 'З') 'calendarCellMark': calendarCellMark,
  };

  ReportTemplateConfig copyWith({
    ReportTemplateSource? source,
    ReportTemplatePeriodField? periodField,
    ReportTemplateRowMode? rowMode,
    List<ReportTemplateFilter>? filters,
    List<ReportTemplateColumn>? columns,
    List<String>? groupBy,
    List<ReportTemplateSort>? sort,
    List<ReportTemplateTotal>? totals,
    ReportTemplateSheet? sheet,
    List<String>? calendarNoteFields,
    String? calendarCellMark,
  }) {
    return ReportTemplateConfig(
      source: source ?? this.source,
      periodField: periodField ?? this.periodField,
      rowMode: rowMode ?? this.rowMode,
      filters: filters ?? this.filters,
      columns: columns ?? this.columns,
      groupBy: groupBy ?? this.groupBy,
      sort: sort ?? this.sort,
      totals: totals ?? this.totals,
      sheet: sheet ?? this.sheet,
      calendarNoteFields: calendarNoteFields ?? this.calendarNoteFields,
      calendarCellMark: calendarCellMark ?? this.calendarCellMark,
    );
  }
}

class ReportTemplate {
  final String id;
  final String name;
  final String description;
  final String groupId;
  final List<String> allowedRoles;
  final ReportTemplateStatus status;
  final ReportTemplateConfig draftConfig;
  final ReportTemplateConfig? activeConfig;
  final int draftVersion;
  final int activeVersion;
  final String createdBy;
  final String updatedBy;
  final String publishedBy;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? publishedAt;

  const ReportTemplate({
    required this.id,
    required this.name,
    required this.description,
    required this.groupId,
    required this.allowedRoles,
    required this.status,
    required this.draftConfig,
    required this.activeConfig,
    required this.draftVersion,
    required this.activeVersion,
    required this.createdBy,
    required this.updatedBy,
    required this.publishedBy,
    required this.createdAt,
    required this.updatedAt,
    required this.publishedAt,
  });

  factory ReportTemplate.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return ReportTemplate.fromMap({'id': doc.id, ...data});
  }

  factory ReportTemplate.fromMap(Map<String, dynamic> map) {
    return ReportTemplate(
      id: (map['id'] ?? '').toString().trim(),
      name: (map['name'] ?? '').toString().trim(),
      description: (map['description'] ?? '').toString().trim(),
      groupId: (map['groupId'] ?? '').toString().trim(),
      allowedRoles: (map['allowedRoles'] as List? ?? const [])
          .map((item) => item.toString().trim())
          .where((item) => item.isNotEmpty)
          .toList(),
      status: ReportTemplateStatus.fromId(map['status']?.toString()),
      draftConfig: ReportTemplateConfig.fromMap(
        Map<String, dynamic>.from(map['draftConfig'] ?? const {}),
      ),
      activeConfig: map['activeConfig'] is Map
          ? ReportTemplateConfig.fromMap(
              Map<String, dynamic>.from(map['activeConfig']),
            )
          : null,
      draftVersion: _readInt(map['draftVersion'], fallback: 1),
      activeVersion: _readInt(map['activeVersion'], fallback: 0),
      createdBy: (map['createdBy'] ?? '').toString().trim(),
      updatedBy: (map['updatedBy'] ?? '').toString().trim(),
      publishedBy: (map['publishedBy'] ?? '').toString().trim(),
      createdAt: _readDate(map['createdAt']) ?? DateTime.now(),
      updatedAt: _readDate(map['updatedAt']) ?? DateTime.now(),
      publishedAt: _readDate(map['publishedAt']),
    );
  }

  Map<String, dynamic> toFirestore() => {
    'name': name,
    'description': description,
    'groupId': groupId,
    'allowedRoles': allowedRoles,
    'status': status.id,
    'draftConfig': draftConfig.toJson(),
    'activeConfig': activeConfig?.toJson(),
    'draftVersion': draftVersion,
    'activeVersion': activeVersion,
    'createdBy': createdBy,
    'updatedBy': updatedBy,
    'publishedBy': publishedBy,
    'createdAt': Timestamp.fromDate(createdAt),
    'updatedAt': Timestamp.fromDate(updatedAt),
    'publishedAt': publishedAt != null
        ? Timestamp.fromDate(publishedAt!)
        : null,
  };

  ReportTemplate copyWith({
    String? id,
    String? name,
    String? description,
    String? groupId,
    List<String>? allowedRoles,
    ReportTemplateStatus? status,
    ReportTemplateConfig? draftConfig,
    ReportTemplateConfig? activeConfig = _sentinelConfig,
    int? draftVersion,
    int? activeVersion,
    String? createdBy,
    String? updatedBy,
    String? publishedBy,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? publishedAt = _sentinelDate,
  }) {
    return ReportTemplate(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      groupId: groupId ?? this.groupId,
      allowedRoles: allowedRoles ?? this.allowedRoles,
      status: status ?? this.status,
      draftConfig: draftConfig ?? this.draftConfig,
      activeConfig: identical(activeConfig, _sentinelConfig)
          ? this.activeConfig
          : activeConfig,
      draftVersion: draftVersion ?? this.draftVersion,
      activeVersion: activeVersion ?? this.activeVersion,
      createdBy: createdBy ?? this.createdBy,
      updatedBy: updatedBy ?? this.updatedBy,
      publishedBy: publishedBy ?? this.publishedBy,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      publishedAt: identical(publishedAt, _sentinelDate)
          ? this.publishedAt
          : publishedAt,
    );
  }

  bool get isActive => status == ReportTemplateStatus.active;
}

class ReportTemplatePreview {
  final String templateId;
  final String templateName;
  final List<ReportTemplateColumn> columns;
  final List<Map<String, String>> sampleRows;
  final int totalRows;
  final List<String> warnings;

  const ReportTemplatePreview({
    required this.templateId,
    required this.templateName,
    required this.columns,
    required this.sampleRows,
    required this.totalRows,
    required this.warnings,
  });

  factory ReportTemplatePreview.fromMap(Map<String, dynamic> map) {
    return ReportTemplatePreview(
      templateId: (map['templateId'] ?? '').toString().trim(),
      templateName: (map['templateName'] ?? '').toString().trim(),
      columns: (map['columns'] as List? ?? const [])
          .whereType<Map>()
          .map(
            (item) =>
                ReportTemplateColumn.fromMap(Map<String, dynamic>.from(item)),
          )
          .toList(),
      sampleRows: (map['sampleRows'] as List? ?? const [])
          .whereType<Map>()
          .map(
            (item) => Map<String, String>.from(
              item.map(
                (key, value) =>
                    MapEntry(key.toString(), value?.toString() ?? ''),
              ),
            ),
          )
          .toList(),
      totalRows: _readInt(map['totalRows']),
      warnings: (map['warnings'] as List? ?? const [])
          .map((item) => item.toString())
          .toList(),
    );
  }
}

class GeneratedTemplateReport {
  final String fileName;
  final String mimeType;
  final Uint8List bytes;
  final List<String> warnings;
  final int totalRows;

  const GeneratedTemplateReport({
    required this.fileName,
    required this.mimeType,
    required this.bytes,
    required this.warnings,
    required this.totalRows,
  });

  factory GeneratedTemplateReport.fromMap(Map<String, dynamic> map) {
    return GeneratedTemplateReport(
      fileName: (map['fileName'] ?? '').toString().trim(),
      mimeType: (map['mimeType'] ?? '').toString().trim(),
      bytes: Uint8List.fromList(
        base64Decode((map['bytesBase64'] ?? '').toString()),
      ),
      warnings: (map['warnings'] as List? ?? const [])
          .map((item) => item.toString())
          .toList(),
      totalRows: _readInt(map['totalRows']),
    );
  }
}

const _sentinel = Object();
const _sentinelString = '__report_template_sentinel__';
const _sentinelConfig = null;
const _sentinelDate = null;

int _readInt(dynamic value, {int fallback = 0}) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '') ?? fallback;
}

DateTime? _readDate(dynamic value) {
  if (value == null) return null;
  if (value is Timestamp) return value.toDate();
  if (value is DateTime) return value;
  if (value is String && value.trim().isNotEmpty) {
    return DateTime.tryParse(value.trim());
  }
  return null;
}

const List<String> kReportTemplateBaseFieldSuggestions = [
  'lesson.title',
  'lesson.description',
  'lesson.startDate',
  'lesson.startTime',
  'lesson.endDate',
  'lesson.endTime',
  'lesson.unit',
  'lesson.location',
  'lesson.status',
  'lesson.tags',
  'lesson.groupName',
  'lesson.maxParticipants',
  'lesson.currentParticipants',
  'lesson.typeId',
  'lesson.templateId',
  'instructor.assignmentId',
  'instructor.name',
  'member.uid',
  'member.email',
  'member.fullName',
  'member.role',
  'member.rank',
  'member.position',
  'member.phone',
];

ReportTemplateConfig buildDefaultLessonsListReportConfig() {
  return const ReportTemplateConfig(
    source: ReportTemplateSource.lessons,
    periodField: ReportTemplatePeriodField.startTime,
    rowMode: ReportTemplateRowMode.lessonInstructor,
    filters: [
      ReportTemplateFilter(
        key: 'lesson.endTime',
        operator: ReportTemplateFilterOperator.lteNow,
      ),
    ],
    columns: [
      ReportTemplateColumn(key: 'lesson.startDate', label: 'Дата'),
      ReportTemplateColumn(key: 'lesson.unit', label: 'Підрозділ'),
      ReportTemplateColumn(
        key: 'custom.період_навчання',
        label: 'Період навчання',
      ),
      ReportTemplateColumn(key: 'lesson.title', label: 'Назва заняття'),
    ],
    groupBy: ['instructor.name'],
    sort: [
      ReportTemplateSort(
        key: 'lesson.startTime',
        dir: ReportTemplateSortDirection.asc,
      ),
    ],
    totals: [
      ReportTemplateTotal(
        type: ReportTemplateTotalType.count,
        label: 'Всього записів',
      ),
    ],
    sheet: ReportTemplateSheet(
      name: 'Список занять',
      freezeHeader: true,
      autoWidth: true,
    ),
  );
}

ReportTemplate buildSeedLessonsListReportTemplate({
  required String groupId,
  required String userId,
  required DateTime now,
}) {
  final config = buildDefaultLessonsListReportConfig();
  return ReportTemplate(
    id: '',
    name: 'Список занять',
    description:
        'Динамічний звіт по проведених заняттях, згрупованих за інструкторами.',
    groupId: groupId,
    allowedRoles: const ['viewer'],
    status: ReportTemplateStatus.active,
    draftConfig: config,
    activeConfig: config,
    draftVersion: 1,
    activeVersion: 1,
    createdBy: userId,
    updatedBy: userId,
    publishedBy: userId,
    createdAt: now,
    updatedAt: now,
    publishedAt: now,
  );
}
