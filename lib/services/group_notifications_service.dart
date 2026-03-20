import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../globals.dart';
import '../models/group_notification.dart';
import '../models/instructor_absence.dart';

class GroupNotificationsService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<String?> createGroupAnnouncement({
    required String title,
    required String message,
    required Duration duration,
  }) async {
    final currentGroupId = Globals.profileManager.currentGroupId;
    final currentUser = Globals.firebaseAuth.currentUser;

    if (currentGroupId == null || currentUser == null) {
      throw Exception('Група не обрана або користувач не авторизований');
    }

    final now = DateTime.now();
    final notification = GroupNotification(
      id: '',
      groupId: currentGroupId,
      title: title.trim(),
      message: message.trim(),
      type: GroupNotificationType.announcement,
      createdAt: now,
      expiresAt: now.add(duration),
      createdBy: currentUser.uid,
    );

    return _createNotification(notification);
  }

  Future<void> notifyAbsenceApproved(InstructorAbsence absence) async {
    await _createAbsenceNotification(
      absence: absence,
      type: GroupNotificationType.absenceApproved,
      title: 'Відсутність підтверджено',
      message:
          'Ваш запит на ${absence.type.displayName.toLowerCase()} підтверджено.',
    );
  }

  Future<void> notifyAbsenceRejected(InstructorAbsence absence) async {
    await _createAbsenceNotification(
      absence: absence,
      type: GroupNotificationType.absenceRejected,
      title: 'Відсутність відхилено',
      message:
          'Ваш запит на ${absence.type.displayName.toLowerCase()} відхилено.',
    );
  }

  Future<void> notifyAbsenceCancelled(InstructorAbsence absence) async {
    await _createAbsenceNotification(
      absence: absence,
      type: GroupNotificationType.absenceCancelled,
      title: absence.isAdminAssignment
          ? '${absence.type.displayName} скасовано'
          : 'Відсутність скасовано',
      message: absence.isAdminAssignment
          ? '${absence.type.displayName} для вас скасовано.'
          : 'Відсутність ${absence.type.displayName.toLowerCase()} скасовано адміністратором.',
    );
  }

  Future<void> notifyAbsenceAssigned(InstructorAbsence absence) async {
    await _createAbsenceNotification(
      absence: absence,
      type: GroupNotificationType.absenceAssigned,
      title: 'Вам призначили ${absence.type.displayName.toLowerCase()}',
      message:
          'Адміністратор призначив вам ${absence.type.displayName.toLowerCase()}.',
    );
  }

  Future<void> notifyAbsenceUpdated({
    required InstructorAbsence absence,
    required String title,
    required String message,
  }) async {
    await _createAbsenceNotification(
      absence: absence,
      type: GroupNotificationType.absenceUpdated,
      title: title,
      message: message,
    );
  }

  Future<List<GroupNotification>> getNotificationsForCurrentUser() async {
    final currentGroupId = Globals.profileManager.currentGroupId;
    final currentUserId = Globals.profileManager.currentUserId;
    final currentUserEmail = Globals.profileManager.currentUserEmail
        ?.trim()
        .toLowerCase();
    if (currentGroupId == null) return [];

    try {
      final snapshot = await _firestore
          .collection('groups')
          .doc(currentGroupId)
          .collection('notifications')
          .orderBy('createdAt', descending: true)
          .limit(50)
          .get();

      final notifications = snapshot.docs
          .map((doc) => GroupNotification.fromFirestore(doc.data(), doc.id))
          .where(
            (notification) =>
                notification.isActive &&
                (notification.targetUserId == null ||
                    notification.targetUserId == currentUserId ||
                    notification.targetUserId?.trim().toLowerCase() ==
                        currentUserEmail),
          )
          .toList();

      return notifications;
    } catch (e) {
      debugPrint('GroupNotificationsService: Помилка завантаження: $e');
      return [];
    }
  }

  Future<List<GroupNotification>> getAllNotificationsForCurrentGroup() async {
    final currentGroupId = Globals.profileManager.currentGroupId;
    if (currentGroupId == null) return [];

    try {
      final snapshot = await _firestore
          .collection('groups')
          .doc(currentGroupId)
          .collection('notifications')
          .orderBy('createdAt', descending: true)
          .limit(100)
          .get();

      return snapshot.docs
          .map((doc) => GroupNotification.fromFirestore(doc.data(), doc.id))
          .toList();
    } catch (e) {
      debugPrint('GroupNotificationsService: Помилка завантаження списку: $e');
      return [];
    }
  }

  Future<bool> deleteNotification(String notificationId) async {
    final currentGroupId = Globals.profileManager.currentGroupId;
    if (currentGroupId == null) return false;

    try {
      await _firestore
          .collection('groups')
          .doc(currentGroupId)
          .collection('notifications')
          .doc(notificationId)
          .delete();
      return true;
    } catch (e) {
      debugPrint('GroupNotificationsService: Помилка видалення: $e');
      return false;
    }
  }

  Future<String?> _createNotification(GroupNotification notification) async {
    final docRef = await _firestore
        .collection('groups')
        .doc(notification.groupId)
        .collection('notifications')
        .add(notification.toFirestore());
    return docRef.id;
  }

  Future<void> _createAbsenceNotification({
    required InstructorAbsence absence,
    required GroupNotificationType type,
    required String title,
    required String message,
  }) async {
    final currentGroupId = Globals.profileManager.currentGroupId;
    final currentUser = Globals.firebaseAuth.currentUser;

    if (currentGroupId == null || currentUser == null) {
      return;
    }

    final now = DateTime.now();
    final notification = GroupNotification(
      id: '',
      groupId: currentGroupId,
      title: title,
      message:
          '$message Період: ${absence.startDate.day.toString().padLeft(2, '0')}.'
          '${absence.startDate.month.toString().padLeft(2, '0')} - '
          '${absence.endDate.day.toString().padLeft(2, '0')}.'
          '${absence.endDate.month.toString().padLeft(2, '0')}.',
      type: type,
      createdAt: now,
      expiresAt: now.add(const Duration(days: 7)),
      createdBy: currentUser.uid,
      targetUserId: absence.instructorId,
      relatedAbsenceId: absence.id,
      relatedAbsenceCreationType: absence.creationType.value,
    );

    await _createNotification(notification);
  }
}
