import 'package:flutter_application_1/models/custom_field_model.dart';
import 'package:flutter_application_1/models/lesson_model.dart';
import 'package:flutter_application_1/services/calendar_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('LessonModel external instructors', () {
    test('serializes and restores external instructor names', () {
      final lesson = _buildLesson(
        instructorIds: const [],
        instructorNames: const [],
        externalInstructorNames: const ['Запрошений викладач'],
      );

      final restored = LessonModel.fromMap(lesson.toMap());

      expect(restored.externalInstructorNames, ['Запрошений викладач']);
      expect(restored.hasInstructors, isTrue);
      expect(restored.hasInternalInstructors, isFalse);
      expect(restored.hasOnlyExternalInstructors, isTrue);
      expect(restored.displayInstructorNames, 'Запрошений викладач');
    });

    test('displays internal and external instructors together', () {
      final lesson = _buildLesson(
        instructorIds: const ['internal-1'],
        instructorNames: const ['Штатний викладач'],
        externalInstructorNames: const ['Гість'],
      );

      expect(lesson.hasInstructors, isTrue);
      expect(lesson.hasInternalInstructors, isTrue);
      expect(lesson.hasOnlyExternalInstructors, isFalse);
      expect(lesson.displayInstructorNames, 'Штатний викладач, Гість');
      expect(lesson.instructorAssignmentsById.keys, ['internal-1']);
    });
  });

  group('Linked lessons', () {
    test('serializes the main lesson relationship', () {
      final lesson = _buildLesson(
        linkedSetId: 'set-1',
        mainLessonId: 'lesson-id',
        linkedLessonRole: 'main',
      );

      final restored = LessonModel.fromMap(lesson.toMap());

      expect(restored.linkedSetId, 'set-1');
      expect(restored.mainLessonId, 'lesson-id');
      expect(restored.isLinkedLesson, isTrue);
      expect(restored.isMainLinkedLesson, isTrue);
      expect(restored.isLearningPoint, isFalse);
    });

    test('recognizes a learning point', () {
      final lesson = _buildLesson(
        linkedSetId: 'set-1',
        mainLessonId: 'main-1',
        linkedLessonRole: 'learningPoint',
      );

      expect(lesson.isLearningPoint, isTrue);
      expect(lesson.isMainLinkedLesson, isFalse);
    });

    test('moves a point to another date and preserves its own time', () {
      final moved = CalendarService.moveLessonTimeToDate(
        DateTime(2026, 3, 10, 14, 35),
        DateTime(2026, 4, 2, 8, 0),
      );

      expect(moved, DateTime(2026, 4, 2, 14, 35));
    });

    test('copies matching custom fields from main lesson to a point', () {
      const sharedDefinition = LessonCustomFieldDefinition(
        code: 'arrived_students',
        label: 'Кількість курсантів',
        type: CustomFieldType.string,
      );
      const pointOnlyDefinition = LessonCustomFieldDefinition(
        code: 'point_note',
        label: 'Примітка точки',
        type: CustomFieldType.string,
      );

      final synchronized = CalendarService.synchronizeLearningPointCustomValues(
        mainDefinitions: const [sharedDefinition],
        mainValues: {'arrived_students': LessonCustomFieldValue.string('24')},
        pointDefinitions: const [sharedDefinition, pointOnlyDefinition],
        pointValues: {
          'arrived_students': LessonCustomFieldValue.string('18'),
          'point_note': LessonCustomFieldValue.string('Окрема інформація'),
        },
      );

      expect(synchronized['arrived_students']?.stringValue, '24');
      expect(synchronized['point_note']?.stringValue, 'Окрема інформація');
    });

    test('clears a shared point value when the main value is empty', () {
      const definition = LessonCustomFieldDefinition(
        code: 'arrived_students',
        label: 'Кількість курсантів',
        type: CustomFieldType.string,
      );

      final synchronized = CalendarService.synchronizeLearningPointCustomValues(
        mainDefinitions: const [definition],
        mainValues: const {},
        pointDefinitions: const [definition],
        pointValues: {'arrived_students': LessonCustomFieldValue.string('18')},
      );

      expect(synchronized, isNot(contains('arrived_students')));
    });
  });
}

LessonModel _buildLesson({
  List<String> instructorIds = const ['inst-1'],
  List<String> instructorNames = const ['Інструктор'],
  List<String> externalInstructorNames = const [],
  String linkedSetId = '',
  String mainLessonId = '',
  String linkedLessonRole = '',
}) {
  return LessonModel(
    id: 'lesson-id',
    title: 'Тактика',
    description: 'Опис',
    startTime: DateTime(2026, 3, 10, 9, 0),
    endTime: DateTime(2026, 3, 10, 11, 0),
    groupId: 'group-1',
    groupName: 'GSPP',
    linkedSetId: linkedSetId,
    mainLessonId: mainLessonId,
    linkedLessonRole: linkedLessonRole,
    unit: '1 взвод',
    instructorId: instructorIds.isNotEmpty ? instructorIds.first : '',
    instructorName: instructorNames.isNotEmpty ? instructorNames.first : '',
    instructorIds: instructorIds,
    instructorNames: instructorNames,
    externalInstructorNames: externalInstructorNames,
    location: 'Клас 1',
    maxParticipants: 20,
    participants: const [],
    status: 'scheduled',
    tags: const ['Тактика'],
    createdBy: 'admin-1',
    createdAt: DateTime(2026, 3, 1, 8, 0),
    updatedAt: DateTime(2026, 3, 1, 9, 0),
  );
}
