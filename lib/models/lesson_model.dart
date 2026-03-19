import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class LessonAcknowledgementRecord {
  final DateTime? acknowledgedAt;
  final String acknowledgedByUid;
  final String acknowledgedByName;

  const LessonAcknowledgementRecord({
    required this.acknowledgedAt,
    required this.acknowledgedByUid,
    required this.acknowledgedByName,
  });

  factory LessonAcknowledgementRecord.fromMap(Map<String, dynamic> data) {
    return LessonAcknowledgementRecord(
      acknowledgedAt: LessonModel._parseNullableDateTime(
        data['acknowledgedAt'],
      ),
      acknowledgedByUid: (data['acknowledgedByUid'] ?? '').toString().trim(),
      acknowledgedByName: (data['acknowledgedByName'] ?? '').toString().trim(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'acknowledgedAt': acknowledgedAt?.toIso8601String(),
      'acknowledgedByUid': acknowledgedByUid,
      'acknowledgedByName': acknowledgedByName,
    };
  }

  Map<String, dynamic> toFirestore() {
    return {
      'acknowledgedAt': acknowledgedAt != null
          ? Timestamp.fromDate(acknowledgedAt!)
          : null,
      'acknowledgedByUid': acknowledgedByUid,
      'acknowledgedByName': acknowledgedByName,
    };
  }

  LessonAcknowledgementRecord copyWith({
    DateTime? acknowledgedAt,
    String? acknowledgedByUid,
    String? acknowledgedByName,
  }) {
    return LessonAcknowledgementRecord(
      acknowledgedAt: acknowledgedAt ?? this.acknowledgedAt,
      acknowledgedByUid: acknowledgedByUid ?? this.acknowledgedByUid,
      acknowledgedByName: acknowledgedByName ?? this.acknowledgedByName,
    );
  }

  bool isValidAfter(DateTime resetAt) {
    final acknowledgedAt = this.acknowledgedAt;
    if (acknowledgedAt == null) return false;
    return !acknowledgedAt.isBefore(resetAt);
  }
}

class LessonModel {
  final String id;
  final String title;
  final String description;
  final DateTime startTime;
  final DateTime endTime;
  final String groupId;
  final String groupName;
  final String unit;
  final String instructorId;
  final String instructorName;
  final List<String> instructorIds;
  final List<String> instructorNames;
  final String location;
  final int maxParticipants;
  final List<String> participants;
  final String status;
  final List<String> tags;
  final String createdBy;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? acknowledgementResetAt;
  final Map<String, LessonAcknowledgementRecord> instructorAcknowledgements;
  final Recurrence? recurrence;
  final String trainingPeriod; // 👈 НОВЕ ПОЛЕ

  LessonModel({
    required this.id,
    required this.title,
    required this.description,
    required this.startTime,
    required this.endTime,
    required this.groupId,
    required this.groupName,
    required this.unit,
    required String instructorId,
    required String instructorName,
    List<String>? instructorIds,
    List<String>? instructorNames,
    required this.location,
    required this.maxParticipants,
    required this.participants,
    required this.status,
    required this.tags,
    required this.createdBy,
    required this.createdAt,
    required this.updatedAt,
    this.acknowledgementResetAt,
    Map<String, LessonAcknowledgementRecord>? instructorAcknowledgements,
    this.recurrence,
    required this.trainingPeriod, // 👈 НОВЕ ПОЛЕ
  }) : instructorIds = _normalizeInstructorIds(
         instructorIds,
         fallbackId: instructorId,
       ),
       instructorNames = _normalizeInstructorNames(
         instructorNames,
         fallbackName: instructorName,
       ),
       instructorId = _resolvePrimaryInstructorId(
         instructorId: instructorId,
         instructorIds: instructorIds,
       ),
       instructorName = _resolvePrimaryInstructorName(
         instructorName: instructorName,
         instructorNames: instructorNames,
       ),
       instructorAcknowledgements = _normalizeAcknowledgements(
         instructorAcknowledgements,
       );

  /// Додатковий factory конструктор для Firestore
  factory LessonModel.fromFirestore(Map<String, dynamic> data, String id) {
    final createdAt = _parseRequiredDateTime(data['createdAt']);
    final updatedAt = _parseRequiredDateTime(
      data['updatedAt'],
      fallback: createdAt,
    );
    final acknowledgementResetAt =
        _parseNullableDateTime(data['acknowledgementResetAt']) ?? updatedAt;

    return LessonModel(
      id: id,
      title: data['title'] ?? '',
      description: data['description'] ?? '',
      startTime: _parseRequiredDateTime(data['startTime']),
      endTime: _parseRequiredDateTime(data['endTime']),
      groupId: data['groupId'] ?? '',
      groupName: data['groupName'] ?? '',
      unit: data['unit'] ?? '',
      instructorId: data['instructorId'] ?? '',
      instructorName: data['instructorName'] ?? '',
      instructorIds: List<String>.from(data['instructorIds'] ?? const []),
      instructorNames: List<String>.from(data['instructorNames'] ?? const []),
      location: data['location'] ?? '',
      maxParticipants: data['maxParticipants'] ?? 0,
      participants: List<String>.from(data['participants'] ?? []),
      status: data['status'] ?? 'scheduled',
      tags: List<String>.from(data['tags'] ?? []),
      createdBy: data['createdBy'] ?? '',
      createdAt: createdAt,
      updatedAt: updatedAt,
      acknowledgementResetAt: acknowledgementResetAt,
      instructorAcknowledgements: _parseAcknowledgements(
        data['instructorAcknowledgements'],
      ),
      recurrence: data['recurrence'] != null
          ? Recurrence.fromMap(data['recurrence'])
          : null,
      trainingPeriod: data['trainingPeriod'] ?? '',
    );
  }

  /// Альтернативний factory конструктор для Map без Timestamp
  factory LessonModel.fromMap(Map<String, dynamic> data) {
    final createdAt = _parseRequiredDateTime(data['createdAt']);
    final updatedAt = _parseRequiredDateTime(
      data['updatedAt'],
      fallback: createdAt,
    );
    final acknowledgementResetAt =
        _parseNullableDateTime(data['acknowledgementResetAt']) ?? updatedAt;

    return LessonModel(
      id: data['id'] ?? '',
      title: data['title'] ?? '',
      description: data['description'] ?? '',
      startTime: _parseRequiredDateTime(data['startTime']),
      endTime: _parseRequiredDateTime(data['endTime']),
      groupId: data['groupId'] ?? '',
      groupName: data['groupName'] ?? '',
      unit: data['unit'] ?? '',
      instructorId: data['instructorId'] ?? '',
      instructorName: data['instructorName'] ?? '',
      instructorIds: List<String>.from(data['instructorIds'] ?? const []),
      instructorNames: List<String>.from(data['instructorNames'] ?? const []),
      location: data['location'] ?? '',
      maxParticipants: data['maxParticipants'] ?? 0,
      participants: List<String>.from(data['participants'] ?? []),
      status: data['status'] ?? 'scheduled',
      tags: List<String>.from(data['tags'] ?? []),
      createdBy: data['createdBy'] ?? '',
      createdAt: createdAt,
      updatedAt: updatedAt,
      acknowledgementResetAt: acknowledgementResetAt,
      instructorAcknowledgements: _parseAcknowledgements(
        data['instructorAcknowledgements'],
      ),
      recurrence: data['recurrence'] != null
          ? Recurrence.fromMap(data['recurrence'])
          : null,
      trainingPeriod: data['trainingPeriod'] ?? '',
    );
  }

  /// Конвертувати у Map для збереження
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'startTime': startTime,
      'endTime': endTime,
      'groupId': groupId,
      'groupName': groupName,
      'unit': unit,
      'instructorId': instructorId,
      'instructorName': instructorName,
      'instructorIds': instructorIds,
      'instructorNames': instructorNames,
      'location': location,
      'maxParticipants': maxParticipants,
      'participants': participants,
      'status': status,
      'tags': tags,
      'createdBy': createdBy,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
      'acknowledgementResetAt': acknowledgementResetAt?.toIso8601String(),
      'instructorAcknowledgements': instructorAcknowledgements.map(
        (key, value) => MapEntry(key, value.toMap()),
      ),
      'recurrence': recurrence?.toMap(),
      'trainingPeriod': trainingPeriod,
    };
  }

  /// Конвертувати у Map для Firestore (з Timestamp)
  Map<String, dynamic> toFirestore() {
    return {
      'title': title,
      'description': description,
      'startTime': Timestamp.fromDate(startTime),
      'endTime': Timestamp.fromDate(endTime),
      'groupId': groupId,
      'groupName': groupName,
      'unit': unit,
      'instructorId': instructorId,
      'instructorName': instructorName,
      'instructorIds': instructorIds,
      'instructorNames': instructorNames,
      'location': location,
      'maxParticipants': maxParticipants,
      'participants': participants,
      'status': status,
      'tags': tags,
      'createdBy': createdBy,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
      'acknowledgementResetAt': acknowledgementResetAt != null
          ? Timestamp.fromDate(acknowledgementResetAt!)
          : null,
      'instructorAcknowledgements': instructorAcknowledgements.map(
        (key, value) => MapEntry(key, value.toFirestore()),
      ),
      'recurrence': recurrence?.toMap(),
      'trainingPeriod': trainingPeriod,
    };
  }

  /// Створити копію з оновленими полями
  LessonModel copyWith({
    String? id,
    String? title,
    String? description,
    DateTime? startTime,
    DateTime? endTime,
    String? groupId,
    String? groupName,
    String? unit,
    String? instructorId,
    String? instructorName,
    List<String>? instructorIds,
    List<String>? instructorNames,
    String? location,
    int? maxParticipants,
    List<String>? participants,
    String? status,
    List<String>? tags,
    String? createdBy,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? acknowledgementResetAt,
    Map<String, LessonAcknowledgementRecord>? instructorAcknowledgements,
    Recurrence? recurrence,
    String? trainingPeriod,
  }) {
    return LessonModel(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      groupId: groupId ?? this.groupId,
      groupName: groupName ?? this.groupName,
      unit: unit ?? this.unit,
      instructorId: instructorId ?? this.instructorId,
      instructorName: instructorName ?? this.instructorName,
      instructorIds: instructorIds ?? this.instructorIds,
      instructorNames: instructorNames ?? this.instructorNames,
      location: location ?? this.location,
      maxParticipants: maxParticipants ?? this.maxParticipants,
      participants: participants ?? this.participants,
      status: status ?? this.status,
      tags: tags ?? this.tags,
      createdBy: createdBy ?? this.createdBy,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      acknowledgementResetAt:
          acknowledgementResetAt ?? this.acknowledgementResetAt,
      instructorAcknowledgements:
          instructorAcknowledgements ?? this.instructorAcknowledgements,
      recurrence: recurrence ?? this.recurrence,
      trainingPeriod: trainingPeriod ?? this.trainingPeriod,
    );
  }

  /// Отримати тип заняття (перший тег або 'Загальне')
  String get type {
    if (tags.isNotEmpty) {
      return tags.first;
    }
    return 'Загальне';
  }

  /// Тривалість заняття в хвилинах
  int get durationInMinutes {
    return endTime.difference(startTime).inMinutes;
  }

  /// Чи заняття в минулому
  bool get isPast {
    return endTime.isBefore(DateTime.now());
  }

  /// Чи заняття активне зараз
  bool get isActive {
    final now = DateTime.now();
    return startTime.isBefore(now) && endTime.isAfter(now);
  }

  /// Чи заняття в майбутньому
  bool get isFuture {
    return startTime.isAfter(DateTime.now());
  }

  /// Рядок з інформацією про час
  String get timeString {
    final formatter = DateFormat('HH:mm');
    return '${formatter.format(startTime)}-${formatter.format(endTime)}';
  }

  bool get hasInstructors => instructorIds.isNotEmpty;

  String get displayInstructorNames {
    if (instructorNames.isNotEmpty) {
      return instructorNames.join(', ');
    }
    if (instructorName.trim().isNotEmpty) {
      return instructorName.trim();
    }
    return 'Не призначено';
  }

  bool hasInstructorId(String value) {
    final normalized = _normalizeInstructorId(value);
    return normalized.isNotEmpty && instructorIds.contains(normalized);
  }

  bool hasInstructorName(String value) {
    final normalized = value.trim();
    return normalized.isNotEmpty && instructorNames.contains(normalized);
  }

  /// Рядок з інформацією про дату
  String get dateString {
    return DateFormat('dd.MM.yyyy').format(startTime);
  }

  /// Рядок з інформацією про дату та час
  String get dateTimeString {
    return '$dateString $timeString';
  }

  DateTime get effectiveAcknowledgementResetAt =>
      acknowledgementResetAt ?? updatedAt;

  LessonAcknowledgementRecord? acknowledgementFor(String assignmentId) {
    final normalizedAssignmentId = normalizeInstructorAssignmentId(
      assignmentId,
    );
    if (normalizedAssignmentId.isEmpty) return null;
    return instructorAcknowledgements[normalizedAssignmentId];
  }

  Map<String, String> get instructorAssignmentsById {
    final assignments = <String, String>{};

    for (var i = 0; i < instructorIds.length; i++) {
      final assignmentId = instructorIds[i];
      final resolvedName = i < instructorNames.length
          ? instructorNames[i].trim()
          : '';
      assignments[assignmentId] = resolvedName.isNotEmpty
          ? resolvedName
          : assignmentId;
    }

    if (assignments.isEmpty && instructorId.trim().isNotEmpty) {
      final normalizedId = normalizeInstructorAssignmentId(instructorId);
      if (normalizedId.isNotEmpty) {
        assignments[normalizedId] = instructorName.trim().isNotEmpty
            ? instructorName.trim()
            : normalizedId;
      }
    }

    return assignments;
  }

  @override
  String toString() {
    return 'LessonModel(id: $id, title: $title, startTime: $startTime, instructorIds: $instructorIds, instructorNames: $instructorNames)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is LessonModel && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;

  static String _resolvePrimaryInstructorId({
    required String instructorId,
    List<String>? instructorIds,
  }) {
    final normalizedIds = _normalizeInstructorIds(
      instructorIds,
      fallbackId: instructorId,
    );
    return normalizedIds.isNotEmpty ? normalizedIds.first : '';
  }

  static String _resolvePrimaryInstructorName({
    required String instructorName,
    List<String>? instructorNames,
  }) {
    final normalizedNames = _normalizeInstructorNames(
      instructorNames,
      fallbackName: instructorName,
    );
    return normalizedNames.isNotEmpty ? normalizedNames.first : '';
  }

  static List<String> _normalizeInstructorIds(
    List<String>? instructorIds, {
    String fallbackId = '',
  }) {
    final result = <String>[];

    void addValue(String? value) {
      final normalized = _normalizeInstructorId(value ?? '');
      if (normalized.isEmpty || result.contains(normalized)) {
        return;
      }
      result.add(normalized);
    }

    for (final instructorId in instructorIds ?? const <String>[]) {
      addValue(instructorId);
    }
    addValue(fallbackId);

    return result;
  }

  static List<String> _normalizeInstructorNames(
    List<String>? instructorNames, {
    String fallbackName = '',
  }) {
    final result = <String>[];

    void addValue(String? value) {
      final normalized = (value ?? '').trim();
      if (normalized.isEmpty || result.contains(normalized)) {
        return;
      }
      result.add(normalized);
    }

    for (final instructorName in instructorNames ?? const <String>[]) {
      addValue(instructorName);
    }
    addValue(fallbackName);

    return result;
  }

  static Map<String, LessonAcknowledgementRecord> _normalizeAcknowledgements(
    Map<String, LessonAcknowledgementRecord>? acknowledgements,
  ) {
    final result = <String, LessonAcknowledgementRecord>{};
    final entries =
        acknowledgements?.entries ??
        const <MapEntry<String, LessonAcknowledgementRecord>>[];

    for (final entry in entries) {
      final normalizedKey = normalizeInstructorAssignmentId(entry.key);
      if (normalizedKey.isEmpty) continue;
      result[normalizedKey] = entry.value;
    }

    return result;
  }

  static Map<String, LessonAcknowledgementRecord> _parseAcknowledgements(
    dynamic raw,
  ) {
    if (raw is! Map) {
      return const <String, LessonAcknowledgementRecord>{};
    }

    final result = <String, LessonAcknowledgementRecord>{};

    for (final entry in raw.entries) {
      final normalizedKey = normalizeInstructorAssignmentId(
        entry.key.toString(),
      );
      if (normalizedKey.isEmpty || entry.value is! Map) {
        continue;
      }

      result[normalizedKey] = LessonAcknowledgementRecord.fromMap(
        Map<String, dynamic>.from(entry.value as Map),
      );
    }

    return result;
  }

  static DateTime _parseRequiredDateTime(dynamic value, {DateTime? fallback}) {
    return _parseNullableDateTime(value) ?? fallback ?? DateTime.now();
  }

  static DateTime? _parseNullableDateTime(dynamic value) {
    if (value == null) return null;
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    if (value is String && value.trim().isNotEmpty) {
      return DateTime.tryParse(value);
    }
    return null;
  }

  static String normalizeInstructorAssignmentId(String value) {
    return _normalizeInstructorId(value);
  }

  static String _normalizeInstructorId(String value) {
    final normalized = value.trim();
    if (normalized.contains('@')) {
      return normalized.toLowerCase();
    }
    return normalized;
  }
}

class Recurrence {
  final String type; // none, daily, weekly, monthly
  final int interval;
  final DateTime endDate;

  Recurrence({
    required this.type,
    required this.interval,
    required this.endDate,
  });

  factory Recurrence.fromMap(Map<String, dynamic> data) {
    return Recurrence(
      type: data['type'] ?? 'none',
      interval: data['interval'] ?? 1,
      endDate: (data['endDate'] as Timestamp).toDate(),
    );
  }

  factory Recurrence.fromMapGeneric(Map<String, dynamic> data) {
    return Recurrence(
      type: data['type'] ?? 'none',
      interval: data['interval'] ?? 1,
      endDate: data['endDate'] is Timestamp
          ? (data['endDate'] as Timestamp).toDate()
          : DateTime.parse(data['endDate'] ?? DateTime.now().toIso8601String()),
    );
  }

  /// Конвертувати у Map
  Map<String, dynamic> toMap() {
    return {'type': type, 'interval': interval, 'endDate': endDate};
  }

  /// Конвертувати у Map для Firestore (з Timestamp)
  Map<String, dynamic> toFirestore() {
    return {
      'type': type,
      'interval': interval,
      'endDate': Timestamp.fromDate(endDate),
    };
  }

  /// Створити копію з оновленими полями
  Recurrence copyWith({String? type, int? interval, DateTime? endDate}) {
    return Recurrence(
      type: type ?? this.type,
      interval: interval ?? this.interval,
      endDate: endDate ?? this.endDate,
    );
  }

  /// Чи повторення активне
  bool get isActive {
    return type != 'none' && endDate.isAfter(DateTime.now());
  }

  /// Чи повторення закінчилося
  bool get isExpired {
    return endDate.isBefore(DateTime.now());
  }

  /// Отримати наступну дату повторення після заданої дати
  DateTime? getNextOccurrence(DateTime currentDate) {
    if (!isActive || currentDate.isAfter(endDate)) {
      return null;
    }

    DateTime nextDate;

    switch (type) {
      case 'daily':
        nextDate = currentDate.add(Duration(days: interval));
        break;
      case 'weekly':
        nextDate = currentDate.add(Duration(days: 7 * interval));
        break;
      case 'monthly':
        nextDate = DateTime(
          currentDate.year,
          currentDate.month + interval,
          currentDate.day,
          currentDate.hour,
          currentDate.minute,
        );
        break;
      default:
        return null;
    }

    // Перевіряємо, чи наступна дата не перевищує кінцеву дату
    return nextDate.isBefore(endDate) || nextDate.isAtSameMomentAs(endDate)
        ? nextDate
        : null;
  }

  /// Отримати всі дати повторень у заданому періоді
  List<DateTime> getOccurrencesInPeriod(
    DateTime startDate,
    DateTime periodStart,
    DateTime periodEnd,
  ) {
    if (!isActive) return [];

    List<DateTime> occurrences = [];
    DateTime currentDate = startDate;

    // Якщо початкова дата в періоді - додаємо її
    if (currentDate.isAfter(periodStart) && currentDate.isBefore(periodEnd)) {
      occurrences.add(currentDate);
    }

    // Генеруємо наступні повторення
    while (true) {
      final nextDate = getNextOccurrence(currentDate);
      if (nextDate == null || nextDate.isAfter(periodEnd)) {
        break;
      }

      if (nextDate.isAfter(periodStart) && nextDate.isBefore(periodEnd)) {
        occurrences.add(nextDate);
      }

      currentDate = nextDate;
    }

    return occurrences;
  }

  /// Отримати опис повторення для користувача
  String get description {
    if (type == 'none') return 'Без повторення';

    String intervalText = interval == 1 ? '' : 'кожні $interval ';
    String typeText;

    switch (type) {
      case 'daily':
        typeText = interval == 1 ? 'щодня' : '$intervalTextдні';
        break;
      case 'weekly':
        typeText = interval == 1 ? 'щотижня' : '$intervalTextтижні';
        break;
      case 'monthly':
        typeText = interval == 1 ? 'щомісяця' : '$intervalTextмісяці';
        break;
      default:
        typeText = 'невідомо';
    }

    final endDateStr = DateFormat('dd.MM.yyyy').format(endDate);
    return 'Повторювати $typeText до $endDateStr';
  }

  /// Короткий опис повторення
  String get shortDescription {
    switch (type) {
      case 'daily':
        return interval == 1 ? 'Щодня' : 'Кожні $interval дні';
      case 'weekly':
        return interval == 1 ? 'Щотижня' : 'Кожні $interval тижні';
      case 'monthly':
        return interval == 1 ? 'Щомісяця' : 'Кожні $interval місяці';
      default:
        return 'Без повторення';
    }
  }

  /// Отримати іконку для типу повторення
  IconData get icon {
    switch (type) {
      case 'daily':
        return Icons.today;
      case 'weekly':
        return Icons.date_range;
      case 'monthly':
        return Icons.calendar_month;
      default:
        return Icons.event;
    }
  }

  /// Перевірити чи дата є повторенням
  bool isOccurrenceDate(DateTime date, DateTime originalDate) {
    if (!isActive) return false;

    if (date.isAtSameMomentAs(originalDate)) return true;
    if (date.isBefore(originalDate) || date.isAfter(endDate)) return false;

    final difference = date.difference(originalDate);

    switch (type) {
      case 'daily':
        return difference.inDays % interval == 0;
      case 'weekly':
        return difference.inDays % (7 * interval) == 0;
      case 'monthly':
        final monthsDiff =
            (date.year - originalDate.year) * 12 +
            (date.month - originalDate.month);
        return monthsDiff % interval == 0 &&
            date.day == originalDate.day &&
            date.hour == originalDate.hour &&
            date.minute == originalDate.minute;
      default:
        return false;
    }
  }

  @override
  String toString() {
    return 'Recurrence(type: $type, interval: $interval, endDate: $endDate)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Recurrence &&
        other.type == type &&
        other.interval == interval &&
        other.endDate == endDate;
  }

  @override
  int get hashCode => Object.hash(type, interval, endDate);
}
