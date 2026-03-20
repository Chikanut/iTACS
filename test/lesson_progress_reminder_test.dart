import 'package:flutter_application_1/models/custom_field_model.dart';
import 'package:flutter_application_1/models/lesson_model.dart';
import 'package:flutter_application_1/models/lesson_progress_reminder.dart';
import 'package:flutter_application_1/services/templates_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('LessonProgressReminder', () {
    test('serializes and deserializes reminder lists in lesson model', () {
      final lesson = LessonModel(
        id: 'lesson-1',
        title: 'Тактика',
        description: '',
        startTime: DateTime(2026, 3, 20, 8, 15),
        endTime: DateTime(2026, 3, 20, 13, 35),
        groupId: 'group-1',
        groupName: 'GSPP',
        typeId: 'lesson',
        templateId: 'template-1',
        unit: '1 НР',
        instructorId: 'inst-1',
        instructorName: 'Інструктор',
        instructorIds: const ['inst-1'],
        instructorNames: const ['Інструктор'],
        location: 'Клас',
        maxParticipants: 30,
        participants: const [],
        status: 'scheduled',
        tags: const ['тактика'],
        createdBy: 'admin-1',
        createdAt: DateTime(2026, 3, 1, 9, 0),
        updatedAt: DateTime(2026, 3, 1, 9, 30),
        progressReminders: const [
          LessonProgressReminder(
            id: 'r-1',
            title: 'Уточнити період',
            message: 'Не забудьте уточнити реальний навчальний період.',
            progressPercent: 90,
          ),
        ],
      );

      final restored = LessonModel.fromMap(lesson.toMap());

      expect(restored.progressReminders, hasLength(1));
      expect(restored.progressReminders.first.id, 'r-1');
      expect(restored.progressReminders.first.progressPercent, 90);
      expect(restored.progressReminders.first.title, 'Уточнити період');
      expect(restored.typeId, 'lesson');
      expect(restored.templateId, 'template-1');
    });

    test('serializes and deserializes reminder lists in template model', () {
      final template = GroupTemplate.fromJson({
        'id': 'template-1',
        'title': 'Тактика',
        'description': '',
        'location': 'Клас 1',
        'unit': '1 НР',
        'tags': ['тактика'],
        'durationMinutes': 90,
        'type': 'lesson',
        'groupId': 'group-1',
        'createdBy': 'admin-1',
        'createdAt': DateTime(2026, 3, 1).toIso8601String(),
        'updatedAt': DateTime(2026, 3, 2).toIso8601String(),
        'progressReminders': [
          {
            'id': 'r-1',
            'title': 'Кінець заняття',
            'message': 'Уточнити дані підрозділу.',
            'progressPercent': 90,
          },
        ],
      });

      expect(template.progressReminders, hasLength(1));

      final json = template.toJson();
      final reminders = json['progressReminders'] as List<dynamic>;
      expect(reminders, hasLength(1));
      expect(reminders.first['title'], 'Кінець заняття');
    });

    test('copies reminders from template to generated lesson payload', () {
      final template = GroupTemplate.fromJson({
        'id': 'template-1',
        'title': 'Тактика',
        'description': '',
        'location': 'Клас 1',
        'unit': '1 НР',
        'tags': ['тактика'],
        'durationMinutes': 90,
        'type': 'lesson',
        'groupId': 'group-1',
        'createdBy': 'admin-1',
        'createdAt': DateTime(2026, 3, 1).toIso8601String(),
        'updatedAt': DateTime(2026, 3, 2).toIso8601String(),
        'progressReminders': [
          {
            'id': 'r-1',
            'title': 'Кінець заняття',
            'message': 'Уточнити дані підрозділу.',
            'progressPercent': 90,
          },
        ],
      });

      final payload = GroupTemplatesService().createLessonFromTemplate(
        template,
      );
      final reminders = payload['progressReminders'] as List<dynamic>;

      expect(reminders, hasLength(1));
      expect(reminders.first['id'], 'r-1');
      expect(reminders.first['progressPercent'], 90);
      expect(payload['templateId'], 'template-1');
      expect(payload['type'], 'lesson');
    });

    test(
      'merges custom parameters from template without replacing same ids',
      () {
        final mergedDefinitions = mergeLessonCustomFieldDefinitionsFromTemplate(
          lessonDefinitions: const [
            LessonCustomFieldDefinition(
              code: 'real_period',
              label: 'Фактичний період',
              type: CustomFieldType.string,
            ),
            LessonCustomFieldDefinition(
              code: 'instructor_note',
              label: 'Примітка інструктора',
              type: CustomFieldType.string,
            ),
          ],
          templateDefinitions: const [
            LessonCustomFieldDefinition(
              code: 'real_period',
              label: 'Період з шаблону',
              type: CustomFieldType.dateRange,
            ),
            LessonCustomFieldDefinition(
              code: 'subunit',
              label: 'Підрозділ',
              type: CustomFieldType.string,
            ),
          ],
        );

        expect(mergedDefinitions, hasLength(3));
        expect(mergedDefinitions.first.code, 'real_period');
        expect(mergedDefinitions.first.label, 'Фактичний період');
        expect(mergedDefinitions.first.type, CustomFieldType.string);
        expect(mergedDefinitions.last.code, 'subunit');
      },
    );

    test('calculates synced end time from template duration', () {
      final syncedEndTime = calculateSyncedLessonEndTime(
        startTime: DateTime(2026, 3, 20, 8, 15),
        durationMinutes: 320,
      );

      expect(syncedEndTime, DateTime(2026, 3, 20, 13, 35));
    });

    test('migrates only future unlinked lessons with the same title', () {
      final template = GroupTemplate.fromJson({
        'id': 'template-1',
        'title': 'Тактика',
        'description': 'Оновлений опис',
        'location': 'Клас 1',
        'unit': '1 НР',
        'tags': ['тактика'],
        'durationMinutes': 90,
        'type': 'lesson',
        'groupId': 'group-1',
        'createdBy': 'admin-1',
        'createdAt': DateTime(2026, 3, 1).toIso8601String(),
        'updatedAt': DateTime(2026, 3, 2).toIso8601String(),
      });

      final migratableLesson = LessonModel(
        id: 'lesson-1',
        title: 'Тактика',
        description: '',
        startTime: DateTime(2026, 3, 20, 8, 15),
        endTime: DateTime(2026, 3, 20, 10, 15),
        groupId: 'group-1',
        groupName: 'GSPP',
        unit: '1 НР',
        instructorId: '',
        instructorName: '',
        location: 'Клас',
        maxParticipants: 30,
        participants: const [],
        status: 'scheduled',
        tags: const ['тактика'],
        createdBy: 'admin-1',
        createdAt: DateTime(2026, 3, 1, 9, 0),
        updatedAt: DateTime(2026, 3, 1, 9, 30),
      );

      final linkedLesson = migratableLesson.copyWith(templateId: 'template-2');
      final pastLesson = migratableLesson.copyWith(
        startTime: DateTime(2026, 3, 10, 8, 15),
        endTime: DateTime(2026, 3, 10, 10, 15),
      );
      final anotherTitleLesson = migratableLesson.copyWith(title: 'Інша тема');

      final now = DateTime(2026, 3, 20, 8, 0);

      expect(
        shouldMigrateLessonToTemplate(
          lesson: migratableLesson,
          template: template,
          now: now,
        ),
        isTrue,
      );
      expect(
        shouldMigrateLessonToTemplate(
          lesson: linkedLesson,
          template: template,
          now: now,
        ),
        isFalse,
      );
      expect(
        shouldMigrateLessonToTemplate(
          lesson: pastLesson,
          template: template,
          now: now,
        ),
        isFalse,
      );
      expect(
        shouldMigrateLessonToTemplate(
          lesson: anotherTitleLesson,
          template: template,
          now: now,
        ),
        isFalse,
      );
    });

    test('calculates reminder due time for 0, 90 and 100 percent', () {
      final startTime = DateTime(2026, 3, 20, 8, 15);
      final endTime = DateTime(2026, 3, 20, 13, 35);

      expect(
        const LessonProgressReminder(
          id: 'r-0',
          title: 'Старт',
          message: 'Початок',
          progressPercent: 0,
        ).calculateDueAt(startTime: startTime, endTime: endTime),
        startTime,
      );

      expect(
        const LessonProgressReminder(
          id: 'r-90',
          title: '90%',
          message: 'Майже кінець',
          progressPercent: 90,
        ).calculateDueAt(startTime: startTime, endTime: endTime),
        DateTime(2026, 3, 20, 13, 3),
      );

      expect(
        const LessonProgressReminder(
          id: 'r-100',
          title: 'Фініш',
          message: 'Кінець',
          progressPercent: 100,
        ).calculateDueAt(startTime: startTime, endTime: endTime),
        endTime,
      );
    });

    test('recalculates due time when lesson timing changes', () {
      const reminder = LessonProgressReminder(
        id: 'r-1',
        title: 'Контроль',
        message: 'Перевірити стан',
        progressPercent: 50,
      );

      final initialDueAt = reminder.calculateDueAt(
        startTime: DateTime(2026, 3, 20, 8, 15),
        endTime: DateTime(2026, 3, 20, 10, 15),
      );
      final updatedDueAt = reminder.calculateDueAt(
        startTime: DateTime(2026, 3, 20, 9, 0),
        endTime: DateTime(2026, 3, 20, 13, 0),
      );

      expect(initialDueAt, DateTime(2026, 3, 20, 9, 15));
      expect(updatedDueAt, DateTime(2026, 3, 20, 11, 0));
    });
  });
}
