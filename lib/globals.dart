import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_application_1/services/error_notification_manager.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'services/app_runtime_state.dart';
import 'services/app_snapshot_store.dart';
import 'services/auth_service.dart';
import 'services/file_manager/file_manager.dart';
import 'services/firestore_manager.dart';
import 'services/profile_manager.dart';
import 'services/personnel_profile_service.dart';
import 'services/reports_service.dart';
import 'services/report_templates_service.dart';
import 'services/templates_service.dart';
import 'services/calendar_service.dart';
import 'services/absences_service.dart';
import 'services/group_notifications_service.dart';
import 'services/push_notifications_service.dart';
import 'services/startup_telemetry.dart';

class Globals {
  static final FirebaseAuth firebaseAuth = FirebaseAuth.instance;
  static final AuthService authService = AuthService();
  static final ErrorNotificationManager errorNotificationManager =
      ErrorNotificationManager();
  static final AppSnapshotStore appSnapshotStore = AppSnapshotStore();
  static final AppRuntimeState appRuntimeState = AppRuntimeState();
  static final StartupTelemetry startupTelemetry = StartupTelemetry();
  static final FirestoreManager firestoreManager = FirestoreManager();
  static final ProfileManager profileManager = ProfileManager();
  static final PersonnelProfileService personnelProfileService =
      PersonnelProfileService();
  static final FileManager fileManager = FileManager();
  static final ReportsService reportsService = ReportsService(); // 👈 ДОДАЄМО
  static final ReportTemplatesService reportTemplatesService =
      ReportTemplatesService();
  static final GroupTemplatesService groupTemplatesService =
      GroupTemplatesService();
  static final CalendarService calendarService =
      CalendarService(); // 👈 ДОДАЄМО
  static final AbsencesService absencesService =
      AbsencesService(); // 👈 ДОДАЄМО
  static final GroupNotificationsService groupNotificationsService =
      GroupNotificationsService();
  static final PushNotificationsService pushNotificationsService =
      PushNotificationsService();

  static bool _backgroundWarmupStarted = false;

  static Future<void> init() async {
    try {
      startupTelemetry.startIfNeeded();
      await appSnapshotStore.initialize();

      debugPrint('✅ Globals ініціалізовано успішно');
    } catch (e) {
      debugPrint('❌ Помилка ініціалізації Globals: $e');
      rethrow;
    }
  }

  static Future<void> warmUpInBackground() async {
    if (_backgroundWarmupStarted) {
      return;
    }

    _backgroundWarmupStarted = true;
    try {
      await reportsService.initialize();
    } catch (e) {
      debugPrint('⚠️ Background warmup failed: $e');
    }
  }

  static Future<void> clearLocalUserState() async {
    await groupTemplatesService.clearAllData();
    await appSnapshotStore.clearAllSnapshots();
    await profileManager.clearProfile();
    appRuntimeState.clearSessionState();
  }

  // Додатковий метод для повторної ініціалізації темплейтів при зміні групи
  static Future<void> reinitializeTemplatesForCurrentGroup() async {
    await groupTemplatesService.ensureInitializedForCurrentGroup();
  }
}
