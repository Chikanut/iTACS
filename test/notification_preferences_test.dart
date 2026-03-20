import 'package:flutter_application_1/models/notification_preferences.dart';
import 'package:flutter_application_1/services/profile_manager.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('NotificationPreferences', () {
    test('uses enabled defaults when map is absent', () {
      final preferences = NotificationPreferences.fromMap(null);

      expect(preferences.groupAnnouncements, isTrue);
      expect(preferences.lessonAssigned, isTrue);
      expect(preferences.lessonRemoved, isTrue);
      expect(preferences.lessonCriticalChanged, isTrue);
      expect(preferences.absenceRequestResult, isTrue);
      expect(preferences.lessonProgressReminder, isTrue);
      expect(preferences.adminAbsenceAssignment, isTrue);
      expect(preferences.adminLessonAcknowledged, isTrue);
    });

    test('serializes and deserializes toggles correctly', () {
      const original = NotificationPreferences(
        groupAnnouncements: false,
        lessonAssigned: true,
        lessonRemoved: false,
        lessonCriticalChanged: true,
        absenceRequestResult: false,
        lessonProgressReminder: true,
        adminAbsenceAssignment: true,
        adminLessonAcknowledged: false,
      );

      final restored = NotificationPreferences.fromMap(original.toMap());

      expect(restored.groupAnnouncements, isFalse);
      expect(restored.lessonAssigned, isTrue);
      expect(restored.lessonRemoved, isFalse);
      expect(restored.lessonCriticalChanged, isTrue);
      expect(restored.absenceRequestResult, isFalse);
      expect(restored.lessonProgressReminder, isTrue);
      expect(restored.adminAbsenceAssignment, isTrue);
      expect(restored.adminLessonAcknowledged, isFalse);
    });
  });

  group('UserProfile notification preferences', () {
    test('falls back to enabled defaults when preferences are absent', () {
      final profile = UserProfile.fromMap({
        'firstName': 'Іван',
        'lastName': 'Петренко',
        'email': 'ivan@example.com',
      });

      expect(profile.notificationPreferences.groupAnnouncements, isTrue);
      expect(profile.notificationPreferences.lessonAssigned, isTrue);
      expect(profile.notificationPreferences.lessonRemoved, isTrue);
      expect(profile.notificationPreferences.lessonProgressReminder, isTrue);
      expect(profile.notificationPreferences.adminLessonAcknowledged, isTrue);
    });

    test('persists notification preferences inside profile map', () {
      final profile = UserProfile(
        firstName: 'Іван',
        lastName: 'Петренко',
        email: 'ivan@example.com',
        notificationPreferences: const NotificationPreferences(
          groupAnnouncements: false,
          lessonAssigned: false,
          lessonRemoved: true,
          lessonCriticalChanged: true,
          absenceRequestResult: true,
          lessonProgressReminder: false,
          adminAbsenceAssignment: false,
          adminLessonAcknowledged: false,
        ),
      );

      final restored = UserProfile.fromMap(profile.toMap());

      expect(restored.notificationPreferences.groupAnnouncements, isFalse);
      expect(restored.notificationPreferences.lessonAssigned, isFalse);
      expect(restored.notificationPreferences.lessonRemoved, isTrue);
      expect(restored.notificationPreferences.lessonProgressReminder, isFalse);
      expect(restored.notificationPreferences.adminAbsenceAssignment, isFalse);
      expect(restored.notificationPreferences.adminLessonAcknowledged, isFalse);
    });
  });
}
