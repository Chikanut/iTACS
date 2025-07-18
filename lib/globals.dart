// globals.dart

import 'package:flutter_application_1/services/error_notification_manager.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'services/auth_service.dart';
import 'services/file_manager/file_manager.dart';
import 'services/firestore_manager.dart';
import 'services/profile_manager.dart';
import 'services/reports_service.dart';
import 'services/templates_service.dart';
import 'services/calendar_service.dart';
import 'services/absences_service.dart';

class Globals {
  static final FirebaseAuth firebaseAuth = FirebaseAuth.instance;
  static final AuthService authService = AuthService();
  static final ErrorNotificationManager errorNotificationManager = ErrorNotificationManager();
  static final FirestoreManager firestoreManager = FirestoreManager();
  static final ProfileManager profileManager = ProfileManager(); 
  static final ReportsService reportsService = ReportsService(); // 👈 ДОДАЄМО
  static final GroupTemplatesService groupTemplatesService = GroupTemplatesService();
  static final CalendarService calendarService = CalendarService(); // 👈 ДОДАЄМО
  static final AbsencesService absencesService = AbsencesService(); // 👈 ДОДАЄМО
  static late FileManager fileManager;

static Future<void> init() async {
    try {
      // Ініціалізуємо FileManager
      fileManager = await FileManager.create(
        authService: authService,
      );
      
      // Ініціалізуємо ReportsService 👈 ДОДАЄМО
      await reportsService.initialize();
      await groupTemplatesService.initialize();
      
      print('✅ Globals ініціалізовано успішно');
    } catch (e) {
      print('❌ Помилка ініціалізації Globals: $e');
      rethrow;
    }
  }

   // Додатковий метод для повторної ініціалізації темплейтів при зміні групи
  static Future<void> reinitializeTemplatesForCurrentGroup() async {
    await groupTemplatesService.ensureInitializedForCurrentGroup();
  }
}