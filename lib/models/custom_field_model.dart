import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

enum CustomFieldType {
  string('string', 'Текст'),
  date('date', 'Дата'),
  dateRange('dateRange', 'Період');

  const CustomFieldType(this.id, this.displayName);

  final String id;
  final String displayName;

  static CustomFieldType fromId(String? id) {
    return CustomFieldType.values.firstWhere(
      (type) => type.id == id,
      orElse: () => CustomFieldType.string,
    );
  }
}

class LessonCustomFieldDefinition {
  final String code;
  final String label;
  final CustomFieldType type;

  const LessonCustomFieldDefinition({
    required this.code,
    required this.label,
    required this.type,
  });

  factory LessonCustomFieldDefinition.fromMap(Map<String, dynamic> data) {
    final label = (data['label'] ?? data['name'] ?? '').toString().trim();
    final rawCode = (data['code'] ?? '').toString().trim();

    return LessonCustomFieldDefinition(
      code: normalizeCode(rawCode.isNotEmpty ? rawCode : generateCode(label)),
      label: label,
      type: CustomFieldType.fromId(data['type']?.toString()),
    );
  }

  Map<String, dynamic> toJson() {
    return {'code': code, 'label': label, 'type': type.id};
  }

  Map<String, dynamic> toFirestore() => toJson();

  LessonCustomFieldDefinition copyWith({
    String? code,
    String? label,
    CustomFieldType? type,
  }) {
    return LessonCustomFieldDefinition(
      code: normalizeCode(code ?? this.code),
      label: (label ?? this.label).trim(),
      type: type ?? this.type,
    );
  }

  static List<LessonCustomFieldDefinition> parseDefinitions(dynamic raw) {
    final definitions = <LessonCustomFieldDefinition>[];

    if (raw is List) {
      for (final item in raw) {
        if (item is Map) {
          definitions.add(
            LessonCustomFieldDefinition.fromMap(
              Map<String, dynamic>.from(item),
            ),
          );
        }
      }
      return normalizeDefinitions(definitions);
    }

    if (raw is Map) {
      for (final entry in raw.entries) {
        final key = entry.key.toString().trim();
        if (key.isEmpty) continue;

        if (entry.value is Map) {
          final valueMap = Map<String, dynamic>.from(entry.value as Map);
          definitions.add(
            LessonCustomFieldDefinition.fromMap({
              'code': valueMap['code'] ?? key,
              'label': valueMap['label'] ?? valueMap['name'] ?? key,
              'type': valueMap['type'] ?? 'string',
            }),
          );
          continue;
        }

        definitions.add(
          LessonCustomFieldDefinition(
            code: normalizeCode(key),
            label: key,
            type: CustomFieldType.string,
          ),
        );
      }
    }

    return normalizeDefinitions(definitions);
  }

  static List<LessonCustomFieldDefinition> normalizeDefinitions(
    Iterable<LessonCustomFieldDefinition> definitions,
  ) {
    final normalized = <LessonCustomFieldDefinition>[];
    final usedCodes = <String>{};
    final usedLabels = <String>{};

    for (final definition in definitions) {
      final code = normalizeCode(definition.code);
      final label = definition.label.trim();
      final labelKey = label.toLowerCase();

      if (code.isEmpty ||
          label.isEmpty ||
          usedCodes.contains(code) ||
          usedLabels.contains(labelKey)) {
        continue;
      }

      normalized.add(
        LessonCustomFieldDefinition(
          code: code,
          label: label,
          type: definition.type,
        ),
      );
      usedCodes.add(code);
      usedLabels.add(labelKey);
    }

    return normalized;
  }

  static String? validateDefinitions(
    Iterable<LessonCustomFieldDefinition> definitions,
  ) {
    final usedCodes = <String>{};
    final usedLabels = <String>{};

    for (final definition in definitions) {
      final code = normalizeCode(definition.code);
      final label = definition.label.trim();
      final labelKey = label.toLowerCase();

      if (label.isEmpty) {
        return 'Кожен параметр має мати назву';
      }
      if (code.isEmpty) {
        return 'Кожен параметр має мати code';
      }
      if (usedCodes.contains(code)) {
        return 'Code "$code" дублюється';
      }
      if (usedLabels.contains(labelKey)) {
        return 'Назва "$label" дублюється';
      }

      usedCodes.add(code);
      usedLabels.add(labelKey);
    }

    return null;
  }

  static String generateCode(String label) {
    final lower = label.trim().toLowerCase();
    final normalized = lower
        .replaceAll(RegExp(r'\s+'), '_')
        .replaceAll(RegExp(r'[^a-z0-9а-щьюяєіїґ_]+'), '')
        .replaceAll(RegExp(r'_+'), '_')
        .replaceAll(RegExp(r'^_+|_+$'), '');

    return normalized.isNotEmpty ? normalized : 'field';
  }

  static String normalizeCode(String code) {
    return generateCode(code);
  }
}

class LessonCustomFieldValue {
  final CustomFieldType type;
  final String? stringValue;
  final DateTime? dateValue;
  final DateTime? rangeStart;
  final DateTime? rangeEnd;

  const LessonCustomFieldValue._({
    required this.type,
    this.stringValue,
    this.dateValue,
    this.rangeStart,
    this.rangeEnd,
  });

  factory LessonCustomFieldValue.string(String value) {
    return LessonCustomFieldValue._(
      type: CustomFieldType.string,
      stringValue: value.trim(),
    );
  }

  factory LessonCustomFieldValue.date(DateTime? value) {
    return LessonCustomFieldValue._(
      type: CustomFieldType.date,
      dateValue: value == null ? null : _normalizeDate(value),
    );
  }

  factory LessonCustomFieldValue.dateRange({DateTime? start, DateTime? end}) {
    return LessonCustomFieldValue._(
      type: CustomFieldType.dateRange,
      rangeStart: start == null ? null : _normalizeDate(start),
      rangeEnd: end == null ? null : _normalizeDate(end),
    );
  }

  factory LessonCustomFieldValue.fromMap(Map<String, dynamic> data) {
    final type = CustomFieldType.fromId(data['type']?.toString());

    switch (type) {
      case CustomFieldType.date:
        return LessonCustomFieldValue.date(
          _parseNullableDateTime(data['value']),
        );
      case CustomFieldType.dateRange:
        return LessonCustomFieldValue.dateRange(
          start: _parseNullableDateTime(data['start']),
          end: _parseNullableDateTime(data['end']),
        );
      case CustomFieldType.string:
        return LessonCustomFieldValue.string((data['value'] ?? '').toString());
    }
  }

  Map<String, dynamic> toJson() {
    switch (type) {
      case CustomFieldType.date:
        return {'type': type.id, 'value': dateValue?.toIso8601String()};
      case CustomFieldType.dateRange:
        return {
          'type': type.id,
          'start': rangeStart?.toIso8601String(),
          'end': rangeEnd?.toIso8601String(),
        };
      case CustomFieldType.string:
        return {'type': type.id, 'value': stringValue ?? ''};
    }
  }

  Map<String, dynamic> toFirestore() {
    switch (type) {
      case CustomFieldType.date:
        return {
          'type': type.id,
          'value': dateValue != null ? Timestamp.fromDate(dateValue!) : null,
        };
      case CustomFieldType.dateRange:
        return {
          'type': type.id,
          'start': rangeStart != null ? Timestamp.fromDate(rangeStart!) : null,
          'end': rangeEnd != null ? Timestamp.fromDate(rangeEnd!) : null,
        };
      case CustomFieldType.string:
        return {'type': type.id, 'value': stringValue ?? ''};
    }
  }

  LessonCustomFieldValue copyWith({
    String? stringValue,
    DateTime? dateValue,
    DateTime? rangeStart,
    DateTime? rangeEnd,
  }) {
    switch (type) {
      case CustomFieldType.date:
        return LessonCustomFieldValue.date(dateValue ?? this.dateValue);
      case CustomFieldType.dateRange:
        return LessonCustomFieldValue.dateRange(
          start: rangeStart ?? this.rangeStart,
          end: rangeEnd ?? this.rangeEnd,
        );
      case CustomFieldType.string:
        return LessonCustomFieldValue.string(
          stringValue ?? this.stringValue ?? '',
        );
    }
  }

  bool get isEmpty {
    switch (type) {
      case CustomFieldType.date:
        return dateValue == null;
      case CustomFieldType.dateRange:
        return rangeStart == null && rangeEnd == null;
      case CustomFieldType.string:
        return (stringValue ?? '').trim().isEmpty;
    }
  }

  String formatDisplayValue({String emptyFallback = 'Не вказано'}) {
    if (isEmpty) return emptyFallback;

    switch (type) {
      case CustomFieldType.date:
        return _dateFormatter.format(dateValue!);
      case CustomFieldType.dateRange:
        final start = rangeStart != null
            ? _dateFormatter.format(rangeStart!)
            : '?';
        final end = rangeEnd != null ? _dateFormatter.format(rangeEnd!) : '?';
        return '$start - $end';
      case CustomFieldType.string:
        return stringValue!.trim();
    }
  }

  static Map<String, LessonCustomFieldValue> parseValues(dynamic raw) {
    if (raw is! Map) {
      return const <String, LessonCustomFieldValue>{};
    }

    final result = <String, LessonCustomFieldValue>{};
    for (final entry in raw.entries) {
      final code = LessonCustomFieldDefinition.normalizeCode(
        entry.key.toString(),
      );
      if (code.isEmpty) continue;

      final value = entry.value;
      if (value is Map) {
        result[code] = LessonCustomFieldValue.fromMap(
          Map<String, dynamic>.from(value),
        );
        continue;
      }

      if (value is String) {
        result[code] = LessonCustomFieldValue.string(value);
      }
    }

    return result;
  }

  static Map<String, LessonCustomFieldValue> retainCompatibleValues({
    required List<LessonCustomFieldDefinition> definitions,
    required Map<String, LessonCustomFieldValue> currentValues,
  }) {
    final definitionByCode = {
      for (final definition in definitions) definition.code: definition,
    };
    final nextValues = <String, LessonCustomFieldValue>{};

    for (final entry in currentValues.entries) {
      final definition = definitionByCode[entry.key];
      if (definition == null || definition.type != entry.value.type) {
        continue;
      }
      if (!entry.value.isEmpty) {
        nextValues[entry.key] = entry.value;
      }
    }

    return nextValues;
  }

  static Map<String, LessonCustomFieldValue> sanitizeValues({
    required List<LessonCustomFieldDefinition> definitions,
    required Map<String, LessonCustomFieldValue> values,
  }) {
    return retainCompatibleValues(
      definitions: definitions,
      currentValues: values,
    );
  }

  static DateTime _normalizeDate(DateTime value) {
    return DateTime.utc(value.year, value.month, value.day);
  }

  static DateTime? _parseNullableDateTime(dynamic value) {
    if (value == null) return null;
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    if (value is String && value.trim().isNotEmpty) {
      return DateTime.tryParse(value.trim());
    }
    return null;
  }

  static final DateFormat _dateFormatter = DateFormat('dd.MM.yyyy');
}
