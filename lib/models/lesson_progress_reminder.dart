import 'package:cloud_firestore/cloud_firestore.dart';

class LessonProgressReminder {
  final String id;
  final String title;
  final String message;
  final double progressPercent;

  const LessonProgressReminder({
    required this.id,
    required this.title,
    required this.message,
    required this.progressPercent,
  });

  factory LessonProgressReminder.fromMap(Map<String, dynamic> data) {
    return LessonProgressReminder(
      id: _normalizeId(data['id']),
      title: (data['title'] ?? '').toString().trim(),
      message: (data['message'] ?? '').toString().trim(),
      progressPercent: _normalizeProgressPercent(data['progressPercent']),
    );
  }

  factory LessonProgressReminder.fromFirestore(Map<String, dynamic> data) {
    return LessonProgressReminder.fromMap(data);
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'message': message,
      'progressPercent': progressPercent,
    };
  }

  Map<String, dynamic> toFirestore() {
    return toMap();
  }

  LessonProgressReminder copyWith({
    String? id,
    String? title,
    String? message,
    double? progressPercent,
  }) {
    return LessonProgressReminder(
      id: id ?? this.id,
      title: title ?? this.title,
      message: message ?? this.message,
      progressPercent: progressPercent ?? this.progressPercent,
    );
  }

  DateTime calculateDueAt({
    required DateTime startTime,
    required DateTime endTime,
  }) {
    final lessonDuration = endTime.difference(startTime);
    final progressRatio = progressPercent / 100;
    final dueMilliseconds = lessonDuration.inMilliseconds * progressRatio;
    return startTime.add(Duration(milliseconds: dueMilliseconds.round()));
  }

  bool get isValid => title.isNotEmpty && message.isNotEmpty;

  static List<LessonProgressReminder> parseList(dynamic raw) {
    if (raw is! List) {
      return const <LessonProgressReminder>[];
    }

    final reminders = <LessonProgressReminder>[];
    final seenIds = <String>{};

    for (final item in raw) {
      late final LessonProgressReminder reminder;
      if (item is LessonProgressReminder) {
        reminder = item;
      } else if (item is Map) {
        reminder = LessonProgressReminder.fromMap(
          Map<String, dynamic>.from(item),
        );
      } else {
        continue;
      }

      if (!reminder.isValid || seenIds.contains(reminder.id)) {
        continue;
      }

      seenIds.add(reminder.id);
      reminders.add(reminder);
    }

    reminders.sort((left, right) {
      final progressCompare = left.progressPercent.compareTo(
        right.progressPercent,
      );
      if (progressCompare != 0) {
        return progressCompare;
      }
      return left.title.compareTo(right.title);
    });

    return reminders;
  }

  static List<Map<String, dynamic>> toJsonList(
    List<LessonProgressReminder> reminders,
  ) {
    return reminders.map((reminder) => reminder.toMap()).toList();
  }

  static List<Map<String, dynamic>> toFirestoreList(
    List<LessonProgressReminder> reminders,
  ) {
    return reminders.map((reminder) => reminder.toFirestore()).toList();
  }

  static String createId() {
    return Timestamp.now().microsecondsSinceEpoch.toString();
  }

  static String _normalizeId(dynamic value) {
    final normalized = (value ?? '').toString().trim();
    return normalized.isNotEmpty ? normalized : createId();
  }

  static double _normalizeProgressPercent(dynamic value) {
    if (value is num) {
      return value.toDouble().clamp(0, 100);
    }

    final parsed = double.tryParse((value ?? '').toString());
    if (parsed == null) {
      return 0;
    }
    return parsed.clamp(0, 100);
  }
}
