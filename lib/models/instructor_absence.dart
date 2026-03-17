import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

enum AbsenceType {
  sickLeave('sick_leave', '🏥', 'Лікарняний'),
  vacation('vacation', '🏖️', 'Відпустка'),
  businessTrip('business_trip', '✈️', 'Відрядження'),
  duty('duty', '🛡️', 'Наряд');

  const AbsenceType(this.value, this.emoji, this.displayName);

  final String value;
  final String emoji;
  final String displayName;

  static AbsenceType fromString(String value) {
    return AbsenceType.values.firstWhere(
      (type) => type.value == value,
      orElse: () => AbsenceType.sickLeave,
    );
  }
}

enum AbsenceStatus {
  pending('pending', 'Очікує підтвердження'),
  active('active', 'Активно'),
  completed('completed', 'Завершено'),
  cancelled('cancelled', 'Скасовано');

  const AbsenceStatus(this.value, this.displayName);

  final String value;
  final String displayName;

  static AbsenceStatus fromString(String value) {
    return AbsenceStatus.values.firstWhere(
      (status) => status.value == value,
      orElse: () => AbsenceStatus.pending,
    );
  }
}

enum CreationType {
  userRequest('user_request', 'Запит користувача'),
  adminAssignment('admin_assignment', 'Призначено адміном');

  const CreationType(this.value, this.displayName);

  final String value;
  final String displayName;

  static CreationType fromString(String value) {
    return CreationType.values.firstWhere(
      (type) => type.value == value,
      orElse: () => CreationType.userRequest,
    );
  }
}

class AssignmentDetails {
  final String? orderNumber;
  final String? destination;
  final String? duty;
  final String? instructions;

  const AssignmentDetails({
    this.orderNumber,
    this.destination,
    this.duty,
    this.instructions,
  });

  Map<String, dynamic> toMap() {
    return {
      'orderNumber': orderNumber,
      'destination': destination,
      'duty': duty,
      'instructions': instructions,
    };
  }

  factory AssignmentDetails.fromMap(Map<String, dynamic> map) {
    return AssignmentDetails(
      orderNumber: map['orderNumber'],
      destination: map['destination'],
      duty: map['duty'],
      instructions: map['instructions'],
    );
  }

  DateTime? get orderDate {
    // Якщо orderNumber містить дату у певному форматі, тут можна її розпарсити.
    // Наприклад, якщо orderNumber = "2024-07-18/123", то:
    if (orderNumber == null) return null;
    final match = RegExp(r'^(\d{4}-\d{2}-\d{2})').firstMatch(orderNumber!);
    if (match != null) {
      try {
        return DateTime.parse(match.group(1)!);
      } catch (_) {
        return null;
      }
    }
    return null;
  }

  String? get orderBase {
    if (orderNumber == null) return null;
    // Якщо orderNumber у форматі "2024-07-18/123", повертає "123"
    final match = RegExp(r'^\d{4}-\d{2}-\d{2}/(.+)$').firstMatch(orderNumber!);
    if (match != null) {
      return match.group(1);
    }
    // Якщо формат інший, повертає все після першого "/"
    final parts = orderNumber!.split('/');
    if (parts.length > 1) {
      return parts.sublist(1).join('/');
    }
    return null;
  }
}

class InstructorAbsence {
  final String id;
  final String instructorId;
  final String instructorName;
  final String instructorEmail;
  final AbsenceType type;
  final DateTime startDate;
  final DateTime endDate;
  final String reason;
  final String? documentNumber;
  final AbsenceStatus status;
  final CreationType creationType;
  final AssignmentDetails? assignmentDetails;
  final DateTime createdAt;
  final String createdBy;
  final DateTime? modifiedAt;
  final List<String> affectedLessons;

  const InstructorAbsence({
    required this.id,
    required this.instructorId,
    required this.instructorName,
    required this.instructorEmail,
    required this.type,
    required this.startDate,
    required this.endDate,
    required this.reason,
    this.documentNumber,
    required this.status,
    required this.creationType,
    this.assignmentDetails,
    required this.createdAt,
    required this.createdBy,
    this.modifiedAt,
    this.affectedLessons = const [],
  });

  /// Перевіряє чи відсутність активна на вказану дату
  bool isActiveOnDate(DateTime date) {
    final dateOnly = DateTime(date.year, date.month, date.day);
    final startOnly = DateTime(startDate.year, startDate.month, startDate.day);
    final endOnly = DateTime(endDate.year, endDate.month, endDate.day);

    return (dateOnly.isAtSameMomentAs(startOnly) ||
            dateOnly.isAfter(startOnly)) &&
        (dateOnly.isAtSameMomentAs(endOnly) || dateOnly.isBefore(endOnly)) &&
        status == AbsenceStatus.active;
  }

  /// Отримати короткий символ для таблиці
  String get shortSymbol {
    switch (type) {
      case AbsenceType.sickLeave:
        return 'Х';
      case AbsenceType.vacation:
        return 'В';
      case AbsenceType.businessTrip:
        return 'ВД';
      case AbsenceType.duty:
        return 'Н';
    }
  }

  /// Перевіряє чи це призначення адміном
  bool get isAdminAssignment => creationType == CreationType.adminAssignment;

  /// Отримати кольорове кодування
  Color get displayColor {
    if (isAdminAssignment) {
      return const Color(0xFF1976D2); // Синій для призначень адміном
    }

    switch (type) {
      case AbsenceType.sickLeave:
        return const Color(0xFFE53935); // Червоний
      case AbsenceType.vacation:
        return const Color(0xFF43A047); // Зелений
      case AbsenceType.businessTrip:
        return const Color(0xFFFF9800); // Помаранчевий
      case AbsenceType.duty:
        return const Color(0xFF9C27B0); // Фіолетовий
    }
  }

  Map<String, dynamic> toFirestore() {
    return {
      'instructorId': instructorId,
      'instructorName': instructorName,
      'instructorEmail': instructorEmail,
      'type': type.value,
      'startDate': Timestamp.fromDate(startDate),
      'endDate': Timestamp.fromDate(endDate),
      'reason': reason,
      'documentNumber': documentNumber,
      'status': status.value,
      'creationType': creationType.value,
      'assignmentDetails': assignmentDetails?.toMap(),
      'createdAt': Timestamp.fromDate(createdAt),
      'createdBy': createdBy,
      'modifiedAt': modifiedAt != null ? Timestamp.fromDate(modifiedAt!) : null,
      'affectedLessons': affectedLessons,
    };
  }

  factory InstructorAbsence.fromFirestore(
    Map<String, dynamic> data,
    String id,
  ) {
    return InstructorAbsence(
      id: id,
      instructorId: data['instructorId'] ?? '',
      instructorName: data['instructorName'] ?? '',
      instructorEmail: data['instructorEmail'] ?? '',
      type: AbsenceType.fromString(data['type'] ?? 'sick_leave'),
      startDate: (data['startDate'] as Timestamp).toDate(),
      endDate: (data['endDate'] as Timestamp).toDate(),
      reason: data['reason'] ?? '',
      documentNumber: data['documentNumber'],
      status: AbsenceStatus.fromString(data['status'] ?? 'pending'),
      creationType: CreationType.fromString(
        data['creationType'] ?? 'user_request',
      ),
      assignmentDetails: data['assignmentDetails'] != null
          ? AssignmentDetails.fromMap(
              Map<String, dynamic>.from(data['assignmentDetails']),
            )
          : null,
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      createdBy: data['createdBy'] ?? '',
      modifiedAt: data['modifiedAt'] != null
          ? (data['modifiedAt'] as Timestamp).toDate()
          : null,
      affectedLessons: List<String>.from(data['affectedLessons'] ?? []),
    );
  }

  InstructorAbsence copyWith({
    String? id,
    String? instructorId,
    String? instructorName,
    String? instructorEmail,
    AbsenceType? type,
    DateTime? startDate,
    DateTime? endDate,
    String? reason,
    String? documentNumber,
    AbsenceStatus? status,
    CreationType? creationType,
    AssignmentDetails? assignmentDetails,
    DateTime? createdAt,
    String? createdBy,
    DateTime? modifiedAt,
    List<String>? affectedLessons,
  }) {
    return InstructorAbsence(
      id: id ?? this.id,
      instructorId: instructorId ?? this.instructorId,
      instructorName: instructorName ?? this.instructorName,
      instructorEmail: instructorEmail ?? this.instructorEmail,
      type: type ?? this.type,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      reason: reason ?? this.reason,
      documentNumber: documentNumber ?? this.documentNumber,
      status: status ?? this.status,
      creationType: creationType ?? this.creationType,
      assignmentDetails: assignmentDetails ?? this.assignmentDetails,
      createdAt: createdAt ?? this.createdAt,
      createdBy: createdBy ?? this.createdBy,
      modifiedAt: modifiedAt ?? this.modifiedAt,
      affectedLessons: affectedLessons ?? this.affectedLessons,
    );
  }
}
