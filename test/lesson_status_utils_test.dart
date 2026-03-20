import 'package:flutter_application_1/models/custom_field_model.dart';
import 'package:flutter_application_1/models/lesson_model.dart';
import 'package:flutter_application_1/pages/calendar_page/calendar_utils.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('LessonStatusUtils', () {
    test('returns warning when lesson has no instructor in any phase', () {
      final scheduled = _buildLesson(
        startTime: DateTime.now().add(const Duration(days: 2)),
        endTime: DateTime.now().add(const Duration(days: 2, hours: 2)),
        instructorIds: const [],
        instructorNames: const [],
      );
      final inProgress = _buildLesson(
        startTime: DateTime.now().subtract(const Duration(minutes: 30)),
        endTime: DateTime.now().add(const Duration(minutes: 30)),
        instructorIds: const [],
        instructorNames: const [],
      );
      final completed = _buildLesson(
        startTime: DateTime.now().subtract(const Duration(hours: 3)),
        endTime: DateTime.now().subtract(const Duration(hours: 1)),
        instructorIds: const [],
        instructorNames: const [],
      );

      for (final lesson in [scheduled, inProgress, completed]) {
        final evaluation = LessonStatusUtils.evaluateLessonStatus(lesson);

        expect(evaluation.tone, LessonReadinessTone.warning);
        expect(evaluation.label, 'Потрібен викладач');
        expect(evaluation.issues, ['Викладач']);
      }
    });

    test('returns problem when legacy fields are missing in any phase', () {
      final scheduled = _buildLesson(
        startTime: DateTime.now().add(const Duration(days: 2)),
        endTime: DateTime.now().add(const Duration(days: 2, hours: 2)),
        location: '',
        unit: '',
        maxParticipants: 0,
      );
      final inProgress = _buildLesson(
        startTime: DateTime.now().subtract(const Duration(minutes: 30)),
        endTime: DateTime.now().add(const Duration(minutes: 30)),
        location: '',
        unit: '',
        maxParticipants: 0,
      );
      final completed = _buildLesson(
        startTime: DateTime.now().subtract(const Duration(hours: 3)),
        endTime: DateTime.now().subtract(const Duration(hours: 1)),
        location: '',
        unit: '',
        maxParticipants: 0,
      );

      for (final lesson in [scheduled, inProgress, completed]) {
        final evaluation = LessonStatusUtils.evaluateLessonStatus(lesson);

        expect(evaluation.tone, LessonReadinessTone.problem);
        expect(evaluation.missingLegacyFields, [
          'Місце проведення',
          'Підрозділ',
          'Кількість учнів',
        ]);
      }
    });

    test('checks custom fields only after lesson completion', () {
      final definitions = const [
        LessonCustomFieldDefinition(
          code: 'actual_period',
          label: 'Фактичний період',
          type: CustomFieldType.dateRange,
        ),
        LessonCustomFieldDefinition(
          code: 'note',
          label: 'Примітка',
          type: CustomFieldType.string,
        ),
      ];

      final inProgress = _buildLesson(
        startTime: DateTime.now().subtract(const Duration(minutes: 30)),
        endTime: DateTime.now().add(const Duration(minutes: 30)),
        customFieldDefinitions: definitions,
      );
      final completed = _buildLesson(
        startTime: DateTime.now().subtract(const Duration(hours: 3)),
        endTime: DateTime.now().subtract(const Duration(hours: 1)),
        customFieldDefinitions: definitions,
      );

      final inProgressEvaluation = LessonStatusUtils.evaluateLessonStatus(
        inProgress,
      );
      final completedEvaluation = LessonStatusUtils.evaluateLessonStatus(
        completed,
      );

      expect(inProgressEvaluation.tone, LessonReadinessTone.normal);
      expect(inProgressEvaluation.missingPostLessonCustomFields, isEmpty);

      expect(completedEvaluation.tone, LessonReadinessTone.problem);
      expect(completedEvaluation.label, 'Не всі поля після заняття заповнені');
      expect(completedEvaluation.missingPostLessonCustomFields, [
        'Фактичний період',
        'Примітка',
      ]);
    });

    test('treats dateRange with one date as unfilled after completion', () {
      final lesson = _buildLesson(
        startTime: DateTime.now().subtract(const Duration(hours: 4)),
        endTime: DateTime.now().subtract(const Duration(hours: 1)),
        customFieldDefinitions: const [
          LessonCustomFieldDefinition(
            code: 'actual_period',
            label: 'Фактичний період',
            type: CustomFieldType.dateRange,
          ),
        ],
        customFieldValues: {
          'actual_period': LessonCustomFieldValue.dateRange(
            start: DateTime(2026, 3, 1),
          ),
        },
      );

      final evaluation = LessonStatusUtils.evaluateLessonStatus(lesson);

      expect(evaluation.tone, LessonReadinessTone.problem);
      expect(evaluation.missingPostLessonCustomFields, ['Фактичний період']);
    });

    test(
      'considers completed lesson without custom fields and issues as ok',
      () {
        final lesson = _buildLesson(
          startTime: DateTime.now().subtract(const Duration(hours: 4)),
          endTime: DateTime.now().subtract(const Duration(hours: 1)),
        );

        final evaluation = LessonStatusUtils.evaluateLessonStatus(lesson);

        expect(evaluation.tone, LessonReadinessTone.normal);
        expect(
          evaluation.readinessStatus,
          LessonReadinessStatus.completedReady,
        );
        expect(evaluation.issues, isEmpty);
      },
    );

    test(
      'counts instructor warning as incomplete in areCriticalFieldsFilled',
      () {
        final lesson = _buildLesson(
          startTime: DateTime.now().add(const Duration(days: 1)),
          endTime: DateTime.now().add(const Duration(days: 1, hours: 2)),
          instructorIds: const [],
          instructorNames: const [],
        );

        expect(LessonStatusUtils.areCriticalFieldsFilled(lesson), isFalse);
      },
    );
  });
}

LessonModel _buildLesson({
  DateTime? startTime,
  DateTime? endTime,
  List<String> instructorIds = const ['inst-1'],
  List<String> instructorNames = const ['Інструктор'],
  String location = 'Клас 1',
  String unit = '1 взвод',
  int maxParticipants = 20,
  List<LessonCustomFieldDefinition> customFieldDefinitions = const [],
  Map<String, LessonCustomFieldValue> customFieldValues = const {},
}) {
  final resolvedInstructorId = instructorIds.isNotEmpty
      ? instructorIds.first
      : '';
  final resolvedInstructorName = instructorNames.isNotEmpty
      ? instructorNames.first
      : '';

  return LessonModel(
    id: 'lesson-id',
    title: 'Тактика',
    description: 'Опис',
    startTime: startTime ?? DateTime.now().add(const Duration(days: 2)),
    endTime: endTime ?? DateTime.now().add(const Duration(days: 2, hours: 2)),
    groupId: 'group-1',
    groupName: 'GSPP',
    unit: unit,
    instructorId: resolvedInstructorId,
    instructorName: resolvedInstructorName,
    instructorIds: instructorIds,
    instructorNames: instructorNames,
    location: location,
    maxParticipants: maxParticipants,
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
