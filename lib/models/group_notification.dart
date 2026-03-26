import 'package:cloud_firestore/cloud_firestore.dart';

enum GroupNotificationType {
  announcement('announcement', 'Оголошення'),
  absenceApproved('absence_approved', 'Підтвердження відсутності'),
  absenceRejected('absence_rejected', 'Відхилення відсутності'),
  absenceCancelled('absence_cancelled', 'Скасування відсутності'),
  absenceAssigned('absence_assigned', 'Призначення відсутності'),
  absenceUpdated('absence_updated', 'Зміна відсутності');

  const GroupNotificationType(this.value, this.displayName);

  final String value;
  final String displayName;

  static GroupNotificationType fromString(String value) {
    return GroupNotificationType.values.firstWhere(
      (type) => type.value == value,
      orElse: () => GroupNotificationType.announcement,
    );
  }
}

class GroupNotification {
  final String id;
  final String groupId;
  final String title;
  final String message;
  final GroupNotificationType type;
  final DateTime createdAt;
  final DateTime expiresAt;
  final String createdBy;
  final String? targetUserId;
  final String? relatedAbsenceId;
  final String? relatedAbsenceCreationType;

  const GroupNotification({
    required this.id,
    required this.groupId,
    required this.title,
    required this.message,
    required this.type,
    required this.createdAt,
    required this.expiresAt,
    required this.createdBy,
    this.targetUserId,
    this.relatedAbsenceId,
    this.relatedAbsenceCreationType,
  });

  bool get isActive => expiresAt.isAfter(DateTime.now());

  Map<String, dynamic> toFirestore() {
    return {
      'groupId': groupId,
      'title': title,
      'message': message,
      'type': type.value,
      'createdAt': Timestamp.fromDate(createdAt),
      'expiresAt': Timestamp.fromDate(expiresAt),
      'createdBy': createdBy,
      'targetUserId': targetUserId,
      'relatedAbsenceId': relatedAbsenceId,
      'relatedAbsenceCreationType': relatedAbsenceCreationType,
    };
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'groupId': groupId,
      'title': title,
      'message': message,
      'type': type.value,
      'createdAt': createdAt.toIso8601String(),
      'expiresAt': expiresAt.toIso8601String(),
      'createdBy': createdBy,
      'targetUserId': targetUserId,
      'relatedAbsenceId': relatedAbsenceId,
      'relatedAbsenceCreationType': relatedAbsenceCreationType,
    };
  }

  factory GroupNotification.fromFirestore(
    Map<String, dynamic> data,
    String id,
  ) {
    return GroupNotification(
      id: id,
      groupId: data['groupId'] ?? '',
      title: data['title'] ?? '',
      message: data['message'] ?? '',
      type: GroupNotificationType.fromString(
        data['type'] ?? GroupNotificationType.announcement.value,
      ),
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      expiresAt: (data['expiresAt'] as Timestamp).toDate(),
      createdBy: data['createdBy'] ?? '',
      targetUserId: data['targetUserId'],
      relatedAbsenceId: data['relatedAbsenceId'],
      relatedAbsenceCreationType: data['relatedAbsenceCreationType'],
    );
  }

  factory GroupNotification.fromMap(Map<String, dynamic> data) {
    return GroupNotification(
      id: (data['id'] ?? '').toString(),
      groupId: (data['groupId'] ?? '').toString(),
      title: (data['title'] ?? '').toString(),
      message: (data['message'] ?? '').toString(),
      type: GroupNotificationType.fromString(
        (data['type'] ?? GroupNotificationType.announcement.value).toString(),
      ),
      createdAt: DateTime.parse(data['createdAt'].toString()),
      expiresAt: DateTime.parse(data['expiresAt'].toString()),
      createdBy: (data['createdBy'] ?? '').toString(),
      targetUserId: data['targetUserId']?.toString(),
      relatedAbsenceId: data['relatedAbsenceId']?.toString(),
      relatedAbsenceCreationType: data['relatedAbsenceCreationType']
          ?.toString(),
    );
  }

  GroupNotification copyWith({
    String? id,
    String? groupId,
    String? title,
    String? message,
    GroupNotificationType? type,
    DateTime? createdAt,
    DateTime? expiresAt,
    String? createdBy,
    String? targetUserId,
    String? relatedAbsenceId,
    String? relatedAbsenceCreationType,
  }) {
    return GroupNotification(
      id: id ?? this.id,
      groupId: groupId ?? this.groupId,
      title: title ?? this.title,
      message: message ?? this.message,
      type: type ?? this.type,
      createdAt: createdAt ?? this.createdAt,
      expiresAt: expiresAt ?? this.expiresAt,
      createdBy: createdBy ?? this.createdBy,
      targetUserId: targetUserId ?? this.targetUserId,
      relatedAbsenceId: relatedAbsenceId ?? this.relatedAbsenceId,
      relatedAbsenceCreationType:
          relatedAbsenceCreationType ?? this.relatedAbsenceCreationType,
    );
  }
}
