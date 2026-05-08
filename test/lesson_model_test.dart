import 'package:flutter_application_1/models/lesson_model.dart';
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
}

LessonModel _buildLesson({
  List<String> instructorIds = const ['inst-1'],
  List<String> instructorNames = const ['Інструктор'],
  List<String> externalInstructorNames = const [],
}) {
  return LessonModel(
    id: 'lesson-id',
    title: 'Тактика',
    description: 'Опис',
    startTime: DateTime(2026, 3, 10, 9, 0),
    endTime: DateTime(2026, 3, 10, 11, 0),
    groupId: 'group-1',
    groupName: 'GSPP',
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
