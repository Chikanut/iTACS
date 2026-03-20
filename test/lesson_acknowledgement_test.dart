import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_1/models/lesson_model.dart';
import 'package:flutter_application_1/pages/calendar_page/calendar_utils.dart';
import 'package:flutter_application_1/services/calendar_service.dart';

void main() {
  group('Lesson acknowledgement model', () {
    test('falls back to updatedAt when acknowledgement fields are absent', () {
      final updatedAt = DateTime(2026, 3, 10, 12, 0);

      final lesson = LessonModel.fromMap({
        'id': 'lesson-1',
        'title': 'Тактика',
        'description': 'Опис',
        'startTime': DateTime(2026, 3, 20, 9, 0).toIso8601String(),
        'endTime': DateTime(2026, 3, 20, 10, 30).toIso8601String(),
        'groupId': 'g1',
        'groupName': 'GSPP',
        'unit': '1 взвод',
        'instructorId': 'inst-1',
        'instructorName': 'Інструктор 1',
        'instructorIds': ['inst-1'],
        'instructorNames': ['Інструктор 1'],
        'location': 'Клас 1',
        'maxParticipants': 20,
        'participants': <String>[],
        'status': 'scheduled',
        'tags': ['БЗВП'],
        'createdBy': 'author-1',
        'createdAt': DateTime(2026, 3, 1, 8, 0).toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
        'trainingPeriod': '01.03.2026 - 31.03.2026',
      });

      expect(lesson.acknowledgementResetAt, updatedAt);
      expect(lesson.instructorAcknowledgements, isEmpty);
    });

    test('parses persisted acknowledgement records', () {
      final acknowledgedAt = DateTime(2026, 3, 11, 9, 30);

      final lesson = LessonModel.fromMap({
        'id': 'lesson-2',
        'title': 'Медицина',
        'description': '',
        'startTime': DateTime(2026, 3, 21, 9, 0).toIso8601String(),
        'endTime': DateTime(2026, 3, 21, 10, 30).toIso8601String(),
        'groupId': 'g1',
        'groupName': 'GSPP',
        'unit': '2 взвод',
        'instructorId': 'instructor@example.com',
        'instructorName': 'Інструктор 2',
        'instructorIds': ['instructor@example.com'],
        'instructorNames': ['Інструктор 2'],
        'location': 'Полігон',
        'maxParticipants': 25,
        'participants': <String>[],
        'status': 'scheduled',
        'tags': ['Медицина'],
        'createdBy': 'author-2',
        'createdAt': DateTime(2026, 3, 1, 8, 0).toIso8601String(),
        'updatedAt': DateTime(2026, 3, 10, 8, 0).toIso8601String(),
        'acknowledgementResetAt': DateTime(2026, 3, 10, 8, 0).toIso8601String(),
        'instructorAcknowledgements': {
          'instructor@example.com': {
            'acknowledgedAt': acknowledgedAt.toIso8601String(),
            'acknowledgedByUid': 'uid-22',
            'acknowledgedByName': 'Інструктор 2',
          },
        },
        'trainingPeriod': '01.03.2026 - 31.03.2026',
      });

      final record = lesson.acknowledgementFor('instructor@example.com');

      expect(record, isNotNull);
      expect(record!.acknowledgedAt, acknowledgedAt);
      expect(record.acknowledgedByUid, 'uid-22');
      expect(record.acknowledgedByName, 'Інструктор 2');
    });
  });

  group('Lesson acknowledgement status', () {
    test('does not require acknowledgement from the lesson author', () {
      final lesson = _buildLesson(
        createdBy: 'author-uid',
        instructorIds: const ['author-uid', 'other-uid'],
        instructorNames: const ['Автор', 'Інший викладач'],
      );

      expect(
        LessonStatusUtils.getAcknowledgementStatusForInstructor(
          lesson,
          instructorAssignmentId: 'author-uid',
        ),
        LessonAcknowledgementStatus.notRequired,
      );
      expect(
        LessonStatusUtils.getAcknowledgementStatusForInstructor(
          lesson,
          instructorAssignmentId: 'other-uid',
        ),
        LessonAcknowledgementStatus.pending,
      );
    });

    test('treats acknowledgement as valid only after reset timestamp', () {
      final now = DateTime.now();
      final lesson = _buildLesson(
        startTime: now.add(const Duration(days: 10)),
        endTime: now.add(const Duration(days: 10, hours: 2)),
        acknowledgementResetAt: now.subtract(const Duration(hours: 1)),
        instructorAcknowledgements: {
          'other-uid': LessonAcknowledgementRecord(
            acknowledgedAt: now.subtract(const Duration(minutes: 30)),
            acknowledgedByUid: 'other-uid',
            acknowledgedByName: 'Інший викладач',
          ),
        },
      );

      expect(
        LessonStatusUtils.getAcknowledgementStatusForInstructor(
          lesson,
          instructorAssignmentId: 'other-uid',
        ),
        LessonAcknowledgementStatus.acknowledged,
      );

      final invalidatedLesson = lesson.copyWith(acknowledgementResetAt: now);

      expect(
        LessonStatusUtils.getAcknowledgementStatusForInstructor(
          invalidatedLesson,
          instructorAssignmentId: 'other-uid',
        ),
        LessonAcknowledgementStatus.pending,
      );
    });

    test('marks unacknowledged lessons for today or tomorrow as urgent', () {
      final now = DateTime.now();
      final tomorrow = DateTime(now.year, now.month, now.day + 1, 9, 0);
      final lesson = _buildLesson(
        startTime: tomorrow,
        endTime: tomorrow.add(const Duration(hours: 2)),
      );

      expect(
        LessonStatusUtils.getAcknowledgementStatusForInstructor(
          lesson,
          instructorAssignmentId: 'other-uid',
        ),
        LessonAcknowledgementStatus.urgent,
      );
    });

    test(
      'preserves other instructor acknowledgement on non-critical changes',
      () {
        final now = DateTime.now();
        final lesson = _buildLesson(
          startTime: now.add(const Duration(days: 5)),
          endTime: now.add(const Duration(days: 5, hours: 2)),
          acknowledgementResetAt: now.subtract(const Duration(days: 1)),
          instructorIds: const ['first-uid', 'second-uid'],
          instructorNames: const ['Перший', 'Другий'],
          instructorAcknowledgements: {
            'first-uid': LessonAcknowledgementRecord(
              acknowledgedAt: now.subtract(const Duration(hours: 2)),
              acknowledgedByUid: 'first-uid',
              acknowledgedByName: 'Перший',
            ),
            'second-uid': LessonAcknowledgementRecord(
              acknowledgedAt: now.subtract(const Duration(hours: 1)),
              acknowledgedByUid: 'second-uid',
              acknowledgedByName: 'Другий',
            ),
          },
        );

        final updatedLesson = lesson.copyWith(location: 'Новий клас');

        expect(updatedLesson.acknowledgementFor('first-uid'), isNotNull);
        expect(updatedLesson.acknowledgementFor('second-uid'), isNotNull);
        expect(
          LessonStatusUtils.getAcknowledgementStatusForInstructor(
            updatedLesson,
            instructorAssignmentId: 'second-uid',
          ),
          LessonAcknowledgementStatus.acknowledged,
        );
      },
    );
  });

  group('Lesson acknowledgement reset fields', () {
    test('does not reset acknowledgement for location change', () {
      expect(
        CalendarService.shouldResetAcknowledgementsForFields(const [
          'location',
        ]),
        isFalse,
      );
    });

    test('does not reset acknowledgement for description change', () {
      expect(
        CalendarService.shouldResetAcknowledgementsForFields(const [
          'description',
        ]),
        isFalse,
      );
    });

    test('resets acknowledgement for startTime change', () {
      expect(
        CalendarService.shouldResetAcknowledgementsForFields(const [
          'startTime',
        ]),
        isTrue,
      );
    });

    test('resets acknowledgement for endTime change', () {
      expect(
        CalendarService.shouldResetAcknowledgementsForFields(const ['endTime']),
        isTrue,
      );
    });

    test('resets acknowledgement for unit change', () {
      expect(
        CalendarService.shouldResetAcknowledgementsForFields(const ['unit']),
        isTrue,
      );
    });
  });
}

LessonModel _buildLesson({
  String createdBy = 'author-uid',
  List<String> instructorIds = const ['other-uid'],
  List<String> instructorNames = const ['Інший викладач'],
  DateTime? startTime,
  DateTime? endTime,
  DateTime? acknowledgementResetAt,
  Map<String, LessonAcknowledgementRecord>? instructorAcknowledgements,
}) {
  final now = DateTime.now();

  return LessonModel(
    id: 'lesson-id',
    title: 'Навчання',
    description: 'Опис',
    startTime: startTime ?? now.add(const Duration(days: 7)),
    endTime: endTime ?? now.add(const Duration(days: 7, hours: 2)),
    groupId: 'group-1',
    groupName: 'GSPP',
    unit: '1 взвод',
    instructorId: instructorIds.first,
    instructorName: instructorNames.first,
    instructorIds: instructorIds,
    instructorNames: instructorNames,
    location: 'Клас 1',
    maxParticipants: 20,
    participants: const [],
    status: 'scheduled',
    tags: const ['Тактика'],
    createdBy: createdBy,
    createdAt: now.subtract(const Duration(days: 14)),
    updatedAt: now.subtract(const Duration(days: 1)),
    acknowledgementResetAt: acknowledgementResetAt,
    instructorAcknowledgements: instructorAcknowledgements,
    trainingPeriod: '01.03.2026 - 31.03.2026',
  );
}
