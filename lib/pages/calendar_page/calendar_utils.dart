import 'package:flutter/material.dart';
import '../../models/lesson_model.dart';
import '../../models/custom_field_model.dart';
import 'package:intl/intl.dart';

enum InstructorLessonStatus { needsInstructor, assigned, teaching }

enum LessonProgressStatus {
  scheduled, // Заплановано
  inProgress, // В процесі
  completed, // Завершено
}

enum LessonReadinessStatus {
  notReady, // Не готове (критичні поля не заповнені)
  needsInstructor, // Потрібен інструктор
  ready, // Готове до проведення
  inProgressReady, // В процесі (все ОК)
  inProgressNotReady, // В процесі (але є проблеми)
  completedReady, // Завершено (все ОК)
  completedNotReady, // Завершено (але є проблеми з даними)
}

enum LessonAcknowledgementStatus { notRequired, pending, acknowledged, urgent }

enum LessonReadinessTone { normal, warning, problem }

class LessonStatusEvaluation {
  final LessonProgressStatus progressStatus;
  final LessonReadinessStatus readinessStatus;
  final LessonReadinessTone tone;
  final String label;
  final String description;
  final List<String> issues;
  final bool missingInstructor;
  final List<String> missingLegacyFields;
  final List<String> missingPostLessonCustomFields;

  const LessonStatusEvaluation({
    required this.progressStatus,
    required this.readinessStatus,
    required this.tone,
    required this.label,
    required this.description,
    required this.issues,
    required this.missingInstructor,
    required this.missingLegacyFields,
    required this.missingPostLessonCustomFields,
  });

  bool get hasIssues => tone != LessonReadinessTone.normal;
  bool get hasProblems => tone == LessonReadinessTone.problem;
  bool get hasWarnings => tone == LessonReadinessTone.warning;

  Color get color {
    switch (tone) {
      case LessonReadinessTone.problem:
        return Colors.red;
      case LessonReadinessTone.warning:
        return Colors.orange;
      case LessonReadinessTone.normal:
        return readinessStatus.color;
    }
  }

  IconData get icon {
    switch (tone) {
      case LessonReadinessTone.problem:
        return Icons.error_outline;
      case LessonReadinessTone.warning:
        return Icons.person_add;
      case LessonReadinessTone.normal:
        return readinessStatus.icon;
    }
  }
}

extension LessonProgressStatusExtension on LessonProgressStatus {
  String get label {
    switch (this) {
      case LessonProgressStatus.scheduled:
        return 'Заплановано';
      case LessonProgressStatus.inProgress:
        return 'Проводиться';
      case LessonProgressStatus.completed:
        return 'Завершено';
    }
  }

  IconData get icon {
    switch (this) {
      case LessonProgressStatus.scheduled:
        return Icons.schedule;
      case LessonProgressStatus.inProgress:
        return Icons.play_circle;
      case LessonProgressStatus.completed:
        return Icons.check_circle;
    }
  }
}

extension LessonReadinessStatusExtension on LessonReadinessStatus {
  Color get color {
    switch (this) {
      case LessonReadinessStatus.notReady:
        return Colors.red; // 🔴 Критичні поля не заповнені
      case LessonReadinessStatus.needsInstructor:
        return Colors.orange; // 🟠 Потрібен інструктор
      case LessonReadinessStatus.ready:
        return Colors.green; // 🟢 Готове до проведення
      case LessonReadinessStatus.inProgressReady:
        return Colors.blue; // 🔵 В процесі (все ОК)
      case LessonReadinessStatus.inProgressNotReady:
        return Colors.red; // 🔴 В процесі але є проблеми
      case LessonReadinessStatus.completedReady:
        return Colors.grey; // ⚫ Завершено (все ОК)
      case LessonReadinessStatus.completedNotReady:
        return Colors.red; // 🔴 Завершено але є проблеми
    }
  }

  String get label {
    switch (this) {
      case LessonReadinessStatus.notReady:
        return 'Не заповнено';
      case LessonReadinessStatus.needsInstructor:
        return 'Потрібен викладач';
      case LessonReadinessStatus.ready:
        return 'Готове';
      case LessonReadinessStatus.inProgressReady:
        return 'Проводиться';
      case LessonReadinessStatus.inProgressNotReady:
        return 'Проводиться (є проблеми)';
      case LessonReadinessStatus.completedReady:
        return 'Завершено';
      case LessonReadinessStatus.completedNotReady:
        return 'Завершено (є проблеми)';
    }
  }

  IconData get icon {
    switch (this) {
      case LessonReadinessStatus.notReady:
        return Icons.error;
      case LessonReadinessStatus.needsInstructor:
        return Icons.person_add;
      case LessonReadinessStatus.ready:
        return Icons.check_circle;
      case LessonReadinessStatus.inProgressReady:
        return Icons.play_circle;
      case LessonReadinessStatus.inProgressNotReady:
        return Icons.warning;
      case LessonReadinessStatus.completedReady:
        return Icons.done_all;
      case LessonReadinessStatus.completedNotReady:
        return Icons.error_outline;
    }
  }

  String get description {
    switch (this) {
      case LessonReadinessStatus.notReady:
        return 'Не заповнені критичні поля для звітності';
      case LessonReadinessStatus.needsInstructor:
        return 'Не призначений інструктор';
      case LessonReadinessStatus.ready:
        return 'Всі дані заповнені, готове до проведення';
      case LessonReadinessStatus.inProgressReady:
        return 'Заняття проводиться, всі дані в порядку';
      case LessonReadinessStatus.inProgressNotReady:
        return 'Заняття проводиться, але є проблеми з даними для звітності';
      case LessonReadinessStatus.completedReady:
        return 'Заняття завершено, всі дані для звітності заповнені';
      case LessonReadinessStatus.completedNotReady:
        return 'Заняття завершено, але потрібно заповнити дані для звітності';
    }
  }
}

extension LessonAcknowledgementStatusExtension on LessonAcknowledgementStatus {
  Color get color {
    switch (this) {
      case LessonAcknowledgementStatus.notRequired:
        return Colors.grey;
      case LessonAcknowledgementStatus.pending:
        return Colors.orange;
      case LessonAcknowledgementStatus.acknowledged:
        return Colors.green;
      case LessonAcknowledgementStatus.urgent:
        return Colors.red;
    }
  }

  IconData get icon {
    switch (this) {
      case LessonAcknowledgementStatus.notRequired:
        return Icons.remove_circle_outline;
      case LessonAcknowledgementStatus.pending:
        return Icons.visibility_outlined;
      case LessonAcknowledgementStatus.acknowledged:
        return Icons.check_circle;
      case LessonAcknowledgementStatus.urgent:
        return Icons.priority_high;
    }
  }

  String get label {
    switch (this) {
      case LessonAcknowledgementStatus.notRequired:
        return 'Ознайомлення не потрібне';
      case LessonAcknowledgementStatus.pending:
        return 'Потрібно ознайомитись';
      case LessonAcknowledgementStatus.acknowledged:
        return 'Ознайомлено';
      case LessonAcknowledgementStatus.urgent:
        return 'Терміново ознайомитись';
    }
  }
}

// ОНОВЛЕНИЙ LessonStatusUtils
class LessonStatusUtils {
  static const List<String> criticalFields = [
    'instructorId',
    'location',
    'unit',
    'maxParticipants',
  ];

  static LessonProgressStatus getProgressStatus(LessonModel lesson) {
    final now = DateTime.now();

    if (now.isBefore(lesson.startTime)) {
      return LessonProgressStatus.scheduled;
    } else if (now.isAfter(lesson.endTime)) {
      return LessonProgressStatus.completed;
    } else {
      return LessonProgressStatus.inProgress;
    }
  }

  static LessonStatusEvaluation evaluateLessonStatus(LessonModel lesson) {
    final progressStatus = getProgressStatus(lesson);
    final missingInstructor = !lesson.hasInstructors;
    final missingLegacyFields = _getMissingLegacyFields(lesson);
    final missingPostLessonCustomFields =
        progressStatus == LessonProgressStatus.completed
        ? _getMissingPostLessonCustomFields(lesson)
        : const <String>[];
    final issues = <String>[
      if (missingInstructor) 'Викладач',
      ...missingLegacyFields,
      ...missingPostLessonCustomFields,
    ];

    if (missingLegacyFields.isNotEmpty ||
        missingPostLessonCustomFields.isNotEmpty) {
      return LessonStatusEvaluation(
        progressStatus: progressStatus,
        readinessStatus: switch (progressStatus) {
          LessonProgressStatus.scheduled => LessonReadinessStatus.notReady,
          LessonProgressStatus.inProgress =>
            LessonReadinessStatus.inProgressNotReady,
          LessonProgressStatus.completed =>
            LessonReadinessStatus.completedNotReady,
        },
        tone: LessonReadinessTone.problem,
        label:
            progressStatus == LessonProgressStatus.completed &&
                missingPostLessonCustomFields.isNotEmpty
            ? 'Не всі поля після заняття заповнені'
            : switch (progressStatus) {
                LessonProgressStatus.scheduled => 'Не заповнено',
                LessonProgressStatus.inProgress => 'Проводиться (є проблеми)',
                LessonProgressStatus.completed => 'Завершено (є проблеми)',
              },
        description: _buildProblemDescription(
          progressStatus: progressStatus,
          missingInstructor: missingInstructor,
          missingLegacyFields: missingLegacyFields,
          missingPostLessonCustomFields: missingPostLessonCustomFields,
        ),
        issues: issues,
        missingInstructor: missingInstructor,
        missingLegacyFields: missingLegacyFields,
        missingPostLessonCustomFields: missingPostLessonCustomFields,
      );
    }

    if (missingInstructor) {
      return LessonStatusEvaluation(
        progressStatus: progressStatus,
        readinessStatus: LessonReadinessStatus.needsInstructor,
        tone: LessonReadinessTone.warning,
        label: 'Потрібен викладач',
        description: 'Викладач не призначений',
        issues: issues,
        missingInstructor: true,
        missingLegacyFields: const <String>[],
        missingPostLessonCustomFields: const <String>[],
      );
    }

    return LessonStatusEvaluation(
      progressStatus: progressStatus,
      readinessStatus: switch (progressStatus) {
        LessonProgressStatus.scheduled => LessonReadinessStatus.ready,
        LessonProgressStatus.inProgress =>
          LessonReadinessStatus.inProgressReady,
        LessonProgressStatus.completed => LessonReadinessStatus.completedReady,
      },
      tone: LessonReadinessTone.normal,
      label: switch (progressStatus) {
        LessonProgressStatus.scheduled => 'Готове',
        LessonProgressStatus.inProgress => 'Проводиться',
        LessonProgressStatus.completed => 'Завершено',
      },
      description: switch (progressStatus) {
        LessonProgressStatus.scheduled =>
          'Всі дані заповнені, готове до проведення',
        LessonProgressStatus.inProgress =>
          'Заняття проводиться, всі дані в порядку',
        LessonProgressStatus.completed =>
          'Заняття завершено, всі дані для звітності заповнені',
      },
      issues: const <String>[],
      missingInstructor: false,
      missingLegacyFields: const <String>[],
      missingPostLessonCustomFields: const <String>[],
    );
  }

  /// Перевірити чи заповнені всі релевантні поля для поточної фази заняття
  static bool areCriticalFieldsFilled(LessonModel lesson) {
    return !evaluateLessonStatus(lesson).hasIssues;
  }

  /// Визначити статус готовності заняття
  static LessonReadinessStatus getReadinessStatus(LessonModel lesson) {
    return evaluateLessonStatus(lesson).readinessStatus;
  }

  /// Отримати комбінований статус (для простішого використання)
  static ({
    LessonProgressStatus progress,
    LessonReadinessStatus readiness,
    List<String> issues,
  })
  getFullStatus(LessonModel lesson) {
    final evaluation = evaluateLessonStatus(lesson);

    return (
      progress: evaluation.progressStatus,
      readiness: evaluation.readinessStatus,
      issues: evaluation.issues,
    );
  }

  /// Отримати список незаповнених критичних полів
  static List<String> getMissingCriticalFields(LessonModel lesson) {
    return evaluateLessonStatus(lesson).issues;
  }

  /// Отримати прогрес заповнення критичних полів (для прогрес-бару)
  static double getCriticalFieldsProgress(LessonModel lesson) {
    var totalCount = 4;
    var filledCount = 0;

    if (lesson.hasInstructors) {
      filledCount++;
    }
    if (lesson.location.isNotEmpty) {
      filledCount++;
    }
    if (lesson.unit.isNotEmpty) {
      filledCount++;
    }
    if (lesson.maxParticipants > 0) {
      filledCount++;
    }

    if (getProgressStatus(lesson) == LessonProgressStatus.completed) {
      totalCount += lesson.customFieldDefinitions.length;
      for (final definition in lesson.customFieldDefinitions) {
        if (_isCustomFieldFilled(
          definition: definition,
          value: lesson.customFieldValues[definition.code],
        )) {
          filledCount++;
        }
      }
    }

    if (totalCount == 0) {
      return 1.0;
    }

    return filledCount / totalCount;
  }

  static List<String> _getMissingLegacyFields(LessonModel lesson) {
    final missing = <String>[];

    if (lesson.location.isEmpty) {
      missing.add('Місце проведення');
    }
    if (lesson.unit.isEmpty) {
      missing.add('Підрозділ');
    }
    if (lesson.maxParticipants <= 0) {
      missing.add('Кількість учнів');
    }

    return missing;
  }

  static List<String> _getMissingPostLessonCustomFields(LessonModel lesson) {
    if (!lesson.hasCustomFields) {
      return const <String>[];
    }

    final missing = <String>[];
    for (final definition in lesson.customFieldDefinitions) {
      final value = lesson.customFieldValues[definition.code];
      if (!_isCustomFieldFilled(definition: definition, value: value)) {
        missing.add(definition.label);
      }
    }

    return missing;
  }

  static bool _isCustomFieldFilled({
    required LessonCustomFieldDefinition definition,
    required LessonCustomFieldValue? value,
  }) {
    if (value == null || value.type != definition.type) {
      return false;
    }

    switch (definition.type) {
      case CustomFieldType.string:
        return (value.stringValue ?? '').trim().isNotEmpty;
      case CustomFieldType.date:
        return value.dateValue != null;
      case CustomFieldType.dateRange:
        return value.rangeStart != null && value.rangeEnd != null;
    }
  }

  static String _buildProblemDescription({
    required LessonProgressStatus progressStatus,
    required bool missingInstructor,
    required List<String> missingLegacyFields,
    required List<String> missingPostLessonCustomFields,
  }) {
    final issues = <String>[
      if (missingInstructor) 'Викладач',
      ...missingLegacyFields,
      ...missingPostLessonCustomFields,
    ];

    if (progressStatus == LessonProgressStatus.completed &&
        missingPostLessonCustomFields.isNotEmpty) {
      return 'Після завершення потрібно заповнити: ${issues.join(', ')}';
    }

    return 'Проблеми з заповненням: ${issues.join(', ')}';
  }

  static String? resolveInstructorAssignmentId(
    LessonModel lesson,
    Iterable<String> candidateIds,
  ) {
    for (final candidate in candidateIds) {
      final normalizedCandidate = LessonModel.normalizeInstructorAssignmentId(
        candidate,
      );
      if (normalizedCandidate.isNotEmpty &&
          lesson.hasInstructorId(normalizedCandidate)) {
        return normalizedCandidate;
      }
    }
    return null;
  }

  static bool requiresAcknowledgementForInstructor(
    LessonModel lesson, {
    required String instructorAssignmentId,
    Iterable<String> instructorIdentityCandidates = const [],
  }) {
    final resolvedAssignmentId = resolveInstructorAssignmentId(lesson, [
      instructorAssignmentId,
      ...instructorIdentityCandidates,
    ]);
    if (resolvedAssignmentId == null) {
      return false;
    }

    final creatorCandidates = <String>{
      LessonModel.normalizeInstructorAssignmentId(instructorAssignmentId),
      ...instructorIdentityCandidates.map(
        LessonModel.normalizeInstructorAssignmentId,
      ),
    }..removeWhere((value) => value.isEmpty);

    return !creatorCandidates.contains(
      LessonModel.normalizeInstructorAssignmentId(lesson.createdBy),
    );
  }

  static LessonAcknowledgementRecord? getAcknowledgementRecordForInstructor(
    LessonModel lesson, {
    required String instructorAssignmentId,
    Iterable<String> instructorIdentityCandidates = const [],
  }) {
    final resolvedAssignmentId = resolveInstructorAssignmentId(lesson, [
      instructorAssignmentId,
      ...instructorIdentityCandidates,
    ]);
    if (resolvedAssignmentId == null) {
      return null;
    }
    return lesson.acknowledgementFor(resolvedAssignmentId);
  }

  static bool isAcknowledgementUrgent(LessonModel lesson) {
    if (getProgressStatus(lesson) == LessonProgressStatus.completed) {
      return false;
    }

    final now = DateTime.now();
    final startOfToday = DateTime(now.year, now.month, now.day);
    final startOfDayAfterTomorrow = DateTime(now.year, now.month, now.day + 2);

    return !lesson.endTime.isBefore(startOfToday) &&
        lesson.startTime.isBefore(startOfDayAfterTomorrow);
  }

  static LessonAcknowledgementStatus getAcknowledgementStatusForInstructor(
    LessonModel lesson, {
    required String instructorAssignmentId,
    Iterable<String> instructorIdentityCandidates = const [],
  }) {
    if (!requiresAcknowledgementForInstructor(
      lesson,
      instructorAssignmentId: instructorAssignmentId,
      instructorIdentityCandidates: instructorIdentityCandidates,
    )) {
      return LessonAcknowledgementStatus.notRequired;
    }

    final record = getAcknowledgementRecordForInstructor(
      lesson,
      instructorAssignmentId: instructorAssignmentId,
      instructorIdentityCandidates: instructorIdentityCandidates,
    );

    if (record != null &&
        record.isValidAfter(lesson.effectiveAcknowledgementResetAt)) {
      return LessonAcknowledgementStatus.acknowledged;
    }

    if (getProgressStatus(lesson) == LessonProgressStatus.completed) {
      return LessonAcknowledgementStatus.pending;
    }

    if (isAcknowledgementUrgent(lesson)) {
      return LessonAcknowledgementStatus.urgent;
    }

    return LessonAcknowledgementStatus.pending;
  }

  static String getAcknowledgementStatusText(
    LessonModel lesson, {
    required String instructorAssignmentId,
    Iterable<String> instructorIdentityCandidates = const [],
    DateFormat? acknowledgedAtFormatter,
  }) {
    final status = getAcknowledgementStatusForInstructor(
      lesson,
      instructorAssignmentId: instructorAssignmentId,
      instructorIdentityCandidates: instructorIdentityCandidates,
    );
    final record = getAcknowledgementRecordForInstructor(
      lesson,
      instructorAssignmentId: instructorAssignmentId,
      instructorIdentityCandidates: instructorIdentityCandidates,
    );
    final progressStatus = getProgressStatus(lesson);

    if (status == LessonAcknowledgementStatus.urgent) {
      return 'Терміново: завтра або сьогодні без підтвердження';
    }

    if (status == LessonAcknowledgementStatus.acknowledged &&
        record?.acknowledgedAt != null &&
        acknowledgedAtFormatter != null) {
      return 'Ознайомлено ${acknowledgedAtFormatter.format(record!.acknowledgedAt!)}';
    }

    if (status == LessonAcknowledgementStatus.acknowledged) {
      return 'Ознайомлено';
    }

    if (status == LessonAcknowledgementStatus.pending &&
        progressStatus == LessonProgressStatus.completed) {
      return 'Не було ознайомлення на момент заняття';
    }

    if (status == LessonAcknowledgementStatus.pending) {
      return 'Очікується ознайомлення';
    }

    return status.label;
  }
}

extension InstructorLessonStatusExtension on InstructorLessonStatus {
  Color get color {
    switch (this) {
      case InstructorLessonStatus.needsInstructor:
        return Colors.orange;
      case InstructorLessonStatus.assigned:
        return Colors.blue;
      case InstructorLessonStatus.teaching:
        return Colors.green;
    }
  }

  String get label {
    switch (this) {
      case InstructorLessonStatus.needsInstructor:
        return 'Потрібен викладач';
      case InstructorLessonStatus.assigned:
        return 'Викладач призначений';
      case InstructorLessonStatus.teaching:
        return 'Ви викладаєте';
    }
  }

  IconData get icon {
    switch (this) {
      case InstructorLessonStatus.needsInstructor:
        return Icons.person_add;
      case InstructorLessonStatus.assigned:
        return Icons.person;
      case InstructorLessonStatus.teaching:
        return Icons.school;
    }
  }
}

class CalendarUtils {
  // Константи для календаря
  static const double timeColumnWidth = 60.0;
  static const double hourHeight = 80.0;
  static const double minuteHeight = hourHeight / 60.0;

  // Отримати мінімальний час з списку занять
  static double getMinHourFromLessons(List<LessonModel> lessons) {
    if (lessons.isEmpty) return 8.0; // fallback якщо немає занять

    final minTime = lessons
        .map(
          (lesson) => lesson.startTime.hour + (lesson.startTime.minute / 60.0),
        )
        .reduce((a, b) => a < b ? a : b);

    // Округлюємо вниз до цілої години з буфером 30 хв
    return (minTime - 0.5).floorToDouble().clamp(0.0, 23.0);
  }

  /// Отримати максимальний час з списку занять
  static double getMaxHourFromLessons(List<LessonModel> lessons) {
    if (lessons.isEmpty) return 20.0; // fallback якщо немає занять

    final maxTime = lessons
        .map((lesson) => lesson.endTime.hour + (lesson.endTime.minute / 60.0))
        .reduce((a, b) => a > b ? a : b);

    // Округлюємо вгору до цілої години з буфером 30 хв
    return (maxTime + 0.5).ceilToDouble().clamp(1.0, 24.0);
  }

  // Кольори для різних рот
  static const Map<String, Color> groupColors = {
    '1-а рота': Color(0xFFE3F2FD),
    '2-а рота': Color(0xFFF3E5F5),
    '3-я рота': Color(0xFFE8F5E8),
    '4-а рота': Color(0xFFFFF3E0),
    '5-а рота': Color(0xFFFCE4EC),
    '6-а рота': Color(0xFFF1F8E9),
  };

  // Іконки для типів занять
  static const Map<String, IconData> lessonTypeIcons = {
    'тактика': Icons.military_tech,
    'фізична': Icons.fitness_center,
    'стройова': Icons.format_align_center,
    'теорія': Icons.school,
    'технічна': Icons.build,
    'водіння': Icons.directions_car,
    'стрільби': Icons.gps_fixed,
  };

  /// Отримати кольор для групи
  static Color getGroupColor(String groupName) {
    return groupColors[groupName] ?? Colors.grey.shade200;
  }

  /// Отримати іконку для типу заняття
  static IconData getLessonTypeIcon(String lessonType) {
    final type = lessonType.toLowerCase();
    return lessonTypeIcons[type] ?? Icons.event;
  }

  /// Перевірити чи перекриваються часи
  static bool timesOverlap(
    TimeOfDay start1,
    TimeOfDay end1,
    TimeOfDay start2,
    TimeOfDay end2,
  ) {
    final start1Minutes = start1.hour * 60 + start1.minute;
    final end1Minutes = end1.hour * 60 + end1.minute;
    final start2Minutes = start2.hour * 60 + start2.minute;
    final end2Minutes = end2.hour * 60 + end2.minute;

    // Заняття перекриваються якщо:
    // (start1 < end2) AND (start2 < end1)
    return start1Minutes < end2Minutes && start2Minutes < end1Minutes;
  }

  /// Отримати позицію елемента в часовій сітці
  static double getTimePosition(TimeOfDay time, double minHour) {
    return (time.hour - minHour) * hourHeight + (time.minute * minuteHeight);
  }

  /// Отримати висоту елемента за тривалістю
  static double getDurationHeight(TimeOfDay start, TimeOfDay end) {
    final startMinutes = start.hour * 60 + start.minute;
    final endMinutes = end.hour * 60 + end.minute;
    final durationMinutes = endMinutes - startMinutes;
    return durationMinutes * minuteHeight;
  }

  /// Форматувати час
  static String formatTime(TimeOfDay time) {
    return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
  }

  /// Отримати назву дня тижня
  static String getDayName(int weekday, {bool short = true}) {
    if (short) {
      const days = ['ПН', 'ВТ', 'СР', 'ЧТ', 'ПТ', 'СБ', 'НД'];
      return days[weekday - 1];
    } else {
      const days = [
        'Понеділок',
        'Вівторок',
        'Середа',
        'Четвер',
        'П\'ятниця',
        'Субота',
        'Неділя',
      ];
      return days[weekday - 1];
    }
  }

  /// Отримати назву місяця
  static String getMonthName(int month, {bool short = false}) {
    const monthNames = [
      'Січень',
      'Лютий',
      'Березень',
      'Квітень',
      'Травень',
      'Червень',
      'Липень',
      'Серпень',
      'Вересень',
      'Жовтень',
      'Листопад',
      'Грудень',
    ];

    const shortMonthNames = [
      'Січ',
      'Лют',
      'Бер',
      'Кві',
      'Тра',
      'Чер',
      'Лип',
      'Сер',
      'Вер',
      'Жов',
      'Лис',
      'Гру',
    ];

    if (month < 1 || month > 12) return '';

    return short ? shortMonthNames[month - 1] : monthNames[month - 1];
  }

  /// Перевірити чи дата сьогоднішня
  static bool isToday(DateTime date) {
    final now = DateTime.now();
    return date.year == now.year &&
        date.month == now.month &&
        date.day == now.day;
  }

  /// Отримати дні тижня для заданої дати
  static List<DateTime> getWeekDays(DateTime selectedDate) {
    final startOfWeek = getStartOfWeek(selectedDate);
    final weekDays = List.generate(
      7,
      (index) => startOfWeek.add(Duration(days: index)),
    );

    // 👈 ДОДАТИ DEBUG
    debugPrint('📅 getWeekDays:');
    debugPrint(
      '  Selected date: ${selectedDate.day}.${selectedDate.month}.${selectedDate.year}',
    );
    debugPrint('  Week days:');
    for (int i = 0; i < weekDays.length; i++) {
      final day = weekDays[i];
      final dayName = getDayName(day.weekday);
      debugPrint('    $i ($dayName): ${day.day}.${day.month}.${day.year}');
    }

    return weekDays;
  }

  /// Отримати початок тижня
  static DateTime getStartOfWeek(DateTime date) {
    final daysFromMonday = date.weekday - 1;
    final startOfWeek = date.subtract(Duration(days: daysFromMonday));

    // 👈 ВИПРАВЛЕННЯ: повертаємо початок дня
    return DateTime(
      startOfWeek.year,
      startOfWeek.month,
      startOfWeek.day,
      0,
      0,
      0,
    );
  }

  /// Отримати кінець тижня (неділя о 23:59:59)
  static DateTime getEndOfWeek(DateTime date) {
    final startOfWeek = getStartOfWeek(date);
    final endOfWeek = startOfWeek.add(const Duration(days: 6));
    return DateTime(endOfWeek.year, endOfWeek.month, endOfWeek.day, 23, 59, 59);
  }

  /// Отримати початок місяця
  static DateTime getStartOfMonth(DateTime date) {
    return DateTime(date.year, date.month, 1);
  }

  /// Отримати кінець місяця
  static DateTime getEndOfMonth(DateTime date) {
    return DateTime(date.year, date.month + 1, 0);
  }

  /// Обчислити рівень заповненості у відсотках
  static double getOccupancyRate(int filled, int total) {
    return total > 0 ? filled / total : 0.0;
  }

  /// Перевірити чи заняття майже заповнене (80%+)
  static bool isAlmostFull(int filled, int total) {
    return getOccupancyRate(filled, total) >= 0.8;
  }

  /// Перевірити чи заняття повністю заповнене
  static bool isFull(int filled, int total) {
    return filled >= total;
  }

  /// Отримати статус заняття
  static LessonStatus getLessonStatus(
    int filled,
    int total,
    bool isRegistered,
  ) {
    if (isRegistered) return LessonStatus.registered;
    if (isFull(filled, total)) return LessonStatus.full;
    if (isAlmostFull(filled, total)) return LessonStatus.almostFull;
    return LessonStatus.available;
  }

  /// Відсортувати заняття за часом
  static List<Map<String, dynamic>> sortLessonsByTime(
    List<Map<String, dynamic>> lessons,
  ) {
    return lessons..sort((a, b) {
      final timeA = a['start'] as TimeOfDay;
      final timeB = b['start'] as TimeOfDay;
      final minutesA = timeA.hour * 60 + timeA.minute;
      final minutesB = timeB.hour * 60 + timeB.minute;
      return minutesA.compareTo(minutesB);
    });
  }

  /// Групувати заняття за днями
  static Map<int, List<Map<String, dynamic>>> groupLessonsByDay(
    List<Map<String, dynamic>> lessons,
  ) {
    final Map<int, List<Map<String, dynamic>>> grouped = {};

    for (final lesson in lessons) {
      final dayOffset = lesson['dayOffset'] as int;
      if (!grouped.containsKey(dayOffset)) {
        grouped[dayOffset] = [];
      }
      grouped[dayOffset]!.add(lesson);
    }

    // Сортуємо заняття в кожному дні за часом
    for (final day in grouped.keys) {
      grouped[day] = sortLessonsByTime(grouped[day]!);
    }

    return grouped;
  }

  /// Знайти перекриваючі заняття
  static List<Map<String, dynamic>> findOverlappingLessons(
    List<Map<String, dynamic>> lessons,
    Map<String, dynamic> targetLesson,
    int dayIndex,
  ) {
    final targetStart = targetLesson['start'] as TimeOfDay;
    final targetEnd = targetLesson['end'] as TimeOfDay;

    return lessons
        .where(
          (lesson) =>
              lesson['dayOffset'] == dayIndex &&
              lesson['id'] != targetLesson['id'] &&
              timesOverlap(
                lesson['start'],
                lesson['end'],
                targetStart,
                targetEnd,
              ),
        )
        .toList();
  }

  /// Обчислити позицію для перекриваючих занять
  static ({double left, double right}) calculateOverlapPosition(
    List<Map<String, dynamic>> overlappingLessons,
    Map<String, dynamic> currentLesson,
    double totalWidth,
    double margin,
  ) {
    final overlapCount = overlappingLessons.length + 1;
    final lessonIndex = overlappingLessons.indexOf(currentLesson);
    final actualIndex = lessonIndex >= 0 ? lessonIndex + 1 : 0;

    final availableWidth = totalWidth - (margin * 2);
    final lessonWidth = availableWidth / overlapCount;

    final left = margin + (actualIndex * lessonWidth);
    final right = margin + ((overlapCount - actualIndex - 1) * lessonWidth);

    return (left: left, right: right);
  }

  /// Валідація часу заняття
  static String? validateLessonTime(
    TimeOfDay start,
    TimeOfDay end, {
    double? minHour,
    double? maxHour,
  }) {
    final startMinutes = start.hour * 60 + start.minute;
    final endMinutes = end.hour * 60 + end.minute;

    if (startMinutes >= endMinutes) {
      return 'Час початку повинен бути раніше часу закінчення';
    }

    if (endMinutes - startMinutes < 30) {
      return 'Мінімальна тривалість заняття - 30 хвилин';
    }

    // Перевіряти межі тільки якщо вони передані
    if (minHour != null && maxHour != null) {
      if (start.hour < minHour || end.hour > maxHour) {
        return 'Заняття повинні проводитися з ${minHour.toInt()}:00 до ${maxHour.toInt()}:00';
      }
    }

    return null;
  }

  /// Генерація кольору для групи (якщо немає в preset)
  static Color generateGroupColor(String groupName) {
    final hash = groupName.hashCode;
    final hue = (hash % 360).toDouble();
    return HSVColor.fromAHSV(1.0, hue, 0.3, 0.95).toColor();
  }

  /// Отримати статус заняття для викладача
  static InstructorLessonStatus getInstructorLessonStatus(
    LessonModel lesson,
    bool isUserInstructor,
  ) {
    if (isUserInstructor) return InstructorLessonStatus.teaching;
    if (!lesson.hasInstructors) {
      return InstructorLessonStatus.needsInstructor;
    }
    return InstructorLessonStatus.assigned;
  }
}

enum LessonStatus { available, almostFull, full, registered }

/// Розширення для LessonStatus
extension LessonStatusExtension on LessonStatus {
  Color get color {
    switch (this) {
      case LessonStatus.available:
        return Colors.green;
      case LessonStatus.almostFull:
        return Colors.orange;
      case LessonStatus.full:
        return Colors.red;
      case LessonStatus.registered:
        return Colors.blue;
    }
  }

  String get label {
    switch (this) {
      case LessonStatus.available:
        return 'Доступно';
      case LessonStatus.almostFull:
        return 'Майже заповнено';
      case LessonStatus.full:
        return 'Заповнено';
      case LessonStatus.registered:
        return 'Зареєстровано';
    }
  }

  IconData get icon {
    switch (this) {
      case LessonStatus.available:
        return Icons.event_available;
      case LessonStatus.almostFull:
        return Icons.warning;
      case LessonStatus.full:
        return Icons.block;
      case LessonStatus.registered:
        return Icons.check_circle;
    }
  }
}
