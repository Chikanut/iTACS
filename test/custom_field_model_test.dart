import 'package:flutter_application_1/models/custom_field_model.dart';
import 'package:flutter_application_1/models/lesson_model.dart';
import 'package:flutter_application_1/services/templates_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Custom field definitions', () {
    test('serializes and deserializes template definitions', () {
      final template = GroupTemplate.fromJson({
        'id': 'template-1',
        'title': 'Тактика',
        'description': '',
        'location': 'Клас 1',
        'unit': '1 взвод',
        'tags': ['тактика'],
        'durationMinutes': 90,
        'type': 'lesson',
        'groupId': 'group-1',
        'createdBy': 'admin-1',
        'createdAt': DateTime(2026, 3, 1).toIso8601String(),
        'updatedAt': DateTime(2026, 3, 2).toIso8601String(),
        'customFieldDefinitions': [
          {'code': 'order_number', 'label': '№ наказу', 'type': 'string'},
          {'code': 'lesson_period', 'label': 'Період', 'type': 'dateRange'},
        ],
      });

      expect(template.customFieldDefinitions, hasLength(2));
      expect(template.customFieldDefinitions.first.label, '№ наказу');

      final json = template.toJson();
      final definitions = json['customFieldDefinitions'] as List<dynamic>;
      expect(definitions, hasLength(2));
      expect(definitions.first['code'], 'order_number');
      expect(definitions.last['type'], 'dateRange');
    });

    test('parses legacy customFields map as string definitions', () {
      final template = GroupTemplate.fromJson({
        'id': 'template-legacy',
        'title': 'Стрільба',
        'description': '',
        'location': '',
        'unit': '',
        'tags': const <String>[],
        'durationMinutes': 60,
        'type': 'lesson',
        'groupId': 'group-1',
        'createdBy': 'admin-1',
        'createdAt': DateTime(2026, 3, 1).toIso8601String(),
        'updatedAt': DateTime(2026, 3, 2).toIso8601String(),
        'customFields': {'№ наказу': 'legacy value'},
      });

      expect(template.customFieldDefinitions, hasLength(1));
      expect(template.customFieldDefinitions.first.label, '№ наказу');
      expect(
        template.customFieldDefinitions.first.type,
        CustomFieldType.string,
      );
    });

    test('rejects duplicated codes and labels', () {
      final duplicatedCode = LessonCustomFieldDefinition.validateDefinitions([
        const LessonCustomFieldDefinition(
          code: 'order_number',
          label: '№ наказу',
          type: CustomFieldType.string,
        ),
        const LessonCustomFieldDefinition(
          code: 'order_number',
          label: 'Дата наказу',
          type: CustomFieldType.date,
        ),
      ]);
      final duplicatedLabel = LessonCustomFieldDefinition.validateDefinitions([
        const LessonCustomFieldDefinition(
          code: 'order_number',
          label: '№ наказу',
          type: CustomFieldType.string,
        ),
        const LessonCustomFieldDefinition(
          code: 'order_date',
          label: '№ наказу',
          type: CustomFieldType.date,
        ),
      ]);

      expect(duplicatedCode, contains('дублюється'));
      expect(duplicatedLabel, contains('дублюється'));
    });
  });

  group('Lesson custom field values', () {
    test('supports lookup by code and label', () {
      final lesson = _buildLesson(
        customFieldDefinitions: const [
          LessonCustomFieldDefinition(
            code: 'order_number',
            label: '№ наказу',
            type: CustomFieldType.string,
          ),
          LessonCustomFieldDefinition(
            code: 'order_date',
            label: 'Дата наказу',
            type: CustomFieldType.date,
          ),
        ],
        customFieldValues: {
          'order_number': LessonCustomFieldValue.string('123/26'),
          'order_date': LessonCustomFieldValue.date(DateTime(2026, 3, 20)),
        },
      );

      expect(
        lesson.customFieldValueByCode('order_number')?.stringValue,
        '123/26',
      );
      expect(
        lesson.customFieldValueByLabel('Дата наказу')?.formatDisplayValue(),
        '20.03.2026',
      );
      expect(lesson.customFieldDisplayValueByLabel('№ наказу'), '123/26');
    });

    test('serializes and deserializes lesson custom fields', () {
      final lesson = _buildLesson(
        customFieldDefinitions: const [
          LessonCustomFieldDefinition(
            code: 'lesson_period',
            label: 'Період',
            type: CustomFieldType.dateRange,
          ),
        ],
        customFieldValues: {
          'lesson_period': LessonCustomFieldValue.dateRange(
            start: DateTime(2026, 3, 1),
            end: DateTime(2026, 3, 31),
          ),
        },
      );

      final serialized = lesson.toMap();
      final restored = LessonModel.fromMap(serialized);

      expect(restored.customFieldDefinitions, hasLength(1));
      expect(
        restored.customFieldDisplayValueByCode('lesson_period'),
        '01.03.2026 - 31.03.2026',
      );
    });

    test('retains only compatible values when definitions change', () {
      final nextDefinitions = const [
        LessonCustomFieldDefinition(
          code: 'order_number',
          label: '№ наказу',
          type: CustomFieldType.string,
        ),
        LessonCustomFieldDefinition(
          code: 'order_date',
          label: 'Дата наказу',
          type: CustomFieldType.date,
        ),
      ];

      final retained = LessonCustomFieldValue.retainCompatibleValues(
        definitions: nextDefinitions,
        currentValues: {
          'order_number': LessonCustomFieldValue.string('15'),
          'order_date': LessonCustomFieldValue.string('not-a-date'),
          'removed_field': LessonCustomFieldValue.string('x'),
        },
      );

      expect(retained.keys, ['order_number']);
      expect(retained['order_number']?.stringValue, '15');
    });

    test('formats supported value types', () {
      expect(
        LessonCustomFieldValue.string('Текст').formatDisplayValue(),
        'Текст',
      );
      expect(
        LessonCustomFieldValue.date(DateTime(2026, 3, 20)).formatDisplayValue(),
        '20.03.2026',
      );
      expect(
        LessonCustomFieldValue.dateRange(
          start: DateTime(2026, 3, 1),
          end: DateTime(2026, 3, 31),
        ).formatDisplayValue(),
        '01.03.2026 - 31.03.2026',
      );
    });
  });
}

LessonModel _buildLesson({
  List<LessonCustomFieldDefinition> customFieldDefinitions = const [],
  Map<String, LessonCustomFieldValue> customFieldValues = const {},
}) {
  return LessonModel(
    id: 'lesson-id',
    title: 'Тактика',
    description: 'Опис',
    startTime: DateTime(2026, 3, 20, 9, 0),
    endTime: DateTime(2026, 3, 20, 11, 0),
    groupId: 'group-1',
    groupName: 'GSPP',
    unit: '1 взвод',
    instructorId: 'inst-1',
    instructorName: 'Інструктор',
    instructorIds: const ['inst-1'],
    instructorNames: const ['Інструктор'],
    location: 'Клас 1',
    maxParticipants: 20,
    participants: const [],
    status: 'scheduled',
    tags: const ['тактика'],
    createdBy: 'admin-1',
    createdAt: DateTime(2026, 3, 1, 8, 0),
    updatedAt: DateTime(2026, 3, 1, 9, 0),
    customFieldDefinitions: customFieldDefinitions,
    customFieldValues: customFieldValues,
  );
}
