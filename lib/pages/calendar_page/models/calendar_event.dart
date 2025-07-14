import 'package:flutter/material.dart';
import 'lesson_model.dart';

class CalendarEvent {
  final LessonModel lesson;
  final DateTime start;
  final DateTime end;
  final Color color;

  CalendarEvent({
    required this.lesson,
    required this.start,
    required this.end,
    required this.color,
  });

  factory CalendarEvent.fromLesson(LessonModel lesson, Color color) {
    return CalendarEvent(
      lesson: lesson,
      start: lesson.startTime,
      end: lesson.endTime,
      color: color,
    );
  }
}
