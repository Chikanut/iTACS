import 'package:cloud_firestore/cloud_firestore.dart';

class LessonModel {
  final String id;
  final String title;
  final String description;
  final DateTime startTime;
  final DateTime endTime;
  final String groupId;
  final String groupName;
  final String unit;
  final String instructor;
  final String location;
  final int maxParticipants;
  final int currentParticipants;
  final List<String> participants;
  final String status;
  final List<String> tags;
  final String createdBy;
  final DateTime createdAt;
  final DateTime updatedAt;
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
    required this.instructor,
    required this.location,
    required this.maxParticipants,
    required this.currentParticipants,
    required this.participants,
    required this.status,
    required this.tags,
    required this.createdBy,
    required this.createdAt,
    required this.updatedAt,
    this.recurrence,
    required this.trainingPeriod, // 👈 НОВЕ ПОЛЕ
  });

  factory LessonModel.fromMap(String id, Map<String, dynamic> data) {
    return LessonModel(
      id: id,
      title: data['title'] ?? '',
      description: data['description'] ?? '',
      startTime: (data['startTime'] as Timestamp).toDate(),
      endTime: (data['endTime'] as Timestamp).toDate(),
      groupId: data['groupId'] ?? '',
      groupName: data['groupName'] ?? '',
      unit: data['unit'] ?? '',
      instructor: data['instructor'] ?? '',
      location: data['location'] ?? '',
      maxParticipants: data['maxParticipants'] ?? 0,
      currentParticipants: data['currentParticipants'] ?? 0,
      participants: List<String>.from(data['participants'] ?? []),
      status: data['status'] ?? 'scheduled',
      tags: List<String>.from(data['tags'] ?? []),
      createdBy: data['createdBy'] ?? '',
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      updatedAt: (data['updatedAt'] as Timestamp).toDate(),
      recurrence: data['recurrence'] != null
          ? Recurrence.fromMap(data['recurrence'])
          : null,
      trainingPeriod: data['trainingPeriod'] ?? '', // 👈 НОВЕ ПОЛЕ
    );
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
}
