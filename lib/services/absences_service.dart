import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/instructor_absence.dart';
import '../models/lesson_model.dart';
import '../globals.dart';

class AbsencesService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Створити запит на відсутність (користувач)
  Future<bool> createAbsenceRequest({
    required AbsenceType type,
    required DateTime startDate,
    required DateTime endDate,
    required String reason,
    String? documentNumber,
  }) async {
    try {
      final currentUser = Globals.firebaseAuth.currentUser;
      final currentGroupId = Globals.profileManager.currentGroupId;
      
      if (currentUser == null || currentGroupId == null) {
        throw Exception('Не авторизований або не обрана група');
      }

      // Перевіряємо чи дозволений тип запиту для користувача
      if (type == AbsenceType.businessTrip || type == AbsenceType.duty) {
        throw Exception('Цей тип відсутності може призначати тільки адміністратор');
      }

      // Перевіряємо перетини з існуючими відсутностями
      final hasConflict = await _checkAbsenceConflict(
        currentUser.uid, 
        startDate, 
        endDate,
      );
      
      if (hasConflict) {
        throw Exception('У вказаний період вже є зареєстрована відсутність');
      }

      final absence = InstructorAbsence(
        id: '', // буде присвоєно при збереженні
        instructorId: currentUser.uid,
        instructorName: Globals.profileManager.currentUserName,
        instructorEmail: currentUser.email!,
        type: type,
        startDate: startDate,
        endDate: endDate,
        reason: reason,
        documentNumber: documentNumber,
        status: AbsenceStatus.pending,
        creationType: CreationType.userRequest,
        createdAt: DateTime.now(),
        createdBy: currentUser.uid,
        affectedLessons: await _findAffectedLessons(currentUser.uid, startDate, endDate),
      );

      await _saveAbsence(absence);
      return true;
    } catch (e) {
      debugPrint('AbsencesService: Помилка створення запиту: $e');
      rethrow;
    }
  }

  /// Призначити відсутність адміном
  Future<bool> assignAbsence({
    required String instructorId,
    required String instructorName,
    required String instructorEmail,
    required AbsenceType type,
    required DateTime startDate,
    required DateTime endDate,
    required String reason,
    AssignmentDetails? assignmentDetails,
  }) async {
    try {
      final currentUser = Globals.firebaseAuth.currentUser;
      final currentGroupId = Globals.profileManager.currentGroupId;
      final currentRole = Globals.profileManager.currentRole;
      
      if (currentUser == null || currentGroupId == null || currentRole != 'admin') {
        throw Exception('Недостатньо прав для виконання операції');
      }

      // Перевіряємо перетини
      final hasConflict = await _checkAbsenceConflict(
        instructorId, 
        startDate, 
        endDate,
      );
      
      if (hasConflict) {
        throw Exception('У вказаний період інструктор вже має зареєстровану відсутність');
      }

      final absence = InstructorAbsence(
        id: '',
        instructorId: instructorId,
        instructorName: instructorName,
        instructorEmail: instructorEmail,
        type: type,
        startDate: startDate,
        endDate: endDate,
        reason: reason,
        status: AbsenceStatus.active, // Призначення адміном одразу активні
        creationType: CreationType.adminAssignment,
        assignmentDetails: assignmentDetails,
        createdAt: DateTime.now(),
        createdBy: currentUser.uid,
        affectedLessons: await _findAffectedLessons(instructorId, startDate, endDate),
      );

      await _saveAbsence(absence);
      return true;
    } catch (e) {
      debugPrint('AbsencesService: Помилка призначення відсутності: $e');
      rethrow;
    }
  }

  /// Отримати відсутності за період
  Future<List<InstructorAbsence>> getAbsencesForPeriod({
    required DateTime startDate,
    required DateTime endDate,
    String? instructorId,
  }) async {
    try {
      final currentGroupId = Globals.profileManager.currentGroupId;
      if (currentGroupId == null) return [];

      final docs = await Globals.firestoreManager.getAbsencesForGroup(
        groupId: currentGroupId,
        startDate: startDate,
        endDate: endDate,
        instructorId: instructorId,
      );
      
      return docs.map((doc) {
        return InstructorAbsence.fromFirestore(doc.data() as Map<String, dynamic>, doc.id);
      }).toList();
    } catch (e) {
      debugPrint('AbsencesService: Помилка отримання відсутностей: $e');
      return [];
    }
  }

  Future<List<InstructorAbsence>> getAllAbsencesForGroup() async {
    try {
      final currentGroupId = Globals.profileManager.currentGroupId;
      if (currentGroupId == null) return [];

      final docs = await Globals.firestoreManager.getAbsencesForGroup(
        groupId: currentGroupId,
        // Не передаємо startDate та endDate щоб отримати всі записи
      );
      
      final allAbsences = docs.map((doc) {
        return InstructorAbsence.fromFirestore(doc.data() as Map<String, dynamic>, doc.id);
      }).toList();

      // Сортуємо за датою створення (найновіші спочатку)
      allAbsences.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      
      debugPrint('AbsencesService: Завантажено ${allAbsences.length} відсутностей для групи $currentGroupId');
      
      return allAbsences;
    } catch (e) {
      debugPrint('AbsencesService: Помилка отримання всіх відсутностей групи: $e');
      return [];
    }
  }

  /// Отримати поточні відсутності користувача
  Future<List<InstructorAbsence>> getCurrentUserAbsences() async {
    final currentUser = Globals.firebaseAuth.currentUser;
    if (currentUser == null) return [];

    final now = DateTime.now();
    final startOfMonth = DateTime(now.year, now.month, 1);
    final endOfMonth = DateTime(now.year, now.month + 1, 0);

    return getAbsencesForPeriod(
      startDate: startOfMonth,
      endDate: endOfMonth,
      instructorId: currentUser.uid,
    );
  }

  /// Отримати відсутності на конкретну дату
  Future<List<InstructorAbsence>> getAbsencesForDate(DateTime date) async {
    final startOfDay = DateTime(date.year, date.month, date.day);
    final endOfDay = DateTime(date.year, date.month, date.day, 23, 59, 59);

    final absences = await getAbsencesForPeriod(
      startDate: startOfDay,
      endDate: endOfDay,
    );

    return absences.where((absence) => absence.isActiveOnDate(date)).toList();
  }

  /// Підтвердити запит на відсутність (тільки адмін)
  Future<bool> approveAbsenceRequest(String absenceId) async {
    try {
      final currentRole = Globals.profileManager.currentRole;
      if (currentRole != 'admin') {
        throw Exception('Недостатньо прав для підтвердження запиту');
      }

      await _updateAbsenceStatus(absenceId, AbsenceStatus.active);
      return true;
    } catch (e) {
      debugPrint('AbsencesService: Помилка підтвердження запиту: $e');
      rethrow;
    }
  }

  /// Відхилити запит на відсутність (тільки адмін)
  Future<bool> rejectAbsenceRequest(String absenceId) async {
    try {
      final currentRole = Globals.profileManager.currentRole;
      if (currentRole != 'admin') {
        throw Exception('Недостатньо прав для відхилення запиту');
      }

      await _updateAbsenceStatus(absenceId, AbsenceStatus.cancelled);
      return true;
    } catch (e) {
      debugPrint('AbsencesService: Помилка відхилення запиту: $e');
      rethrow;
    }
  }

  /// Скасувати відсутність
  Future<bool> cancelAbsence(String absenceId) async {
    try {
      await _updateAbsenceStatus(absenceId, AbsenceStatus.cancelled);
      return true;
    } catch (e) {
      debugPrint('AbsencesService: Помилка скасування відсутності: $e');
      rethrow;
    }
  }

  /// Перевірити чи доступний інструктор на дату
  Future<bool> isInstructorAvailable(String instructorId, DateTime date) async {
    final absences = await getAbsencesForDate(date);
    return !absences.any((absence) => 
      absence.instructorId == instructorId && absence.status == AbsenceStatus.active);
  }

  /// Отримати список усіх інструкторів групи з їх статусами на дату
  Future<Map<String, InstructorAbsence?>> getInstructorsStatusForDate(DateTime date) async {
    try {
      final currentGroupId = Globals.profileManager.currentGroupId;
      if (currentGroupId == null) return {};

      // Отримуємо список учасників групи з повною інформацією
      final members = await Globals.firestoreManager.getGroupMembersWithDetails(currentGroupId);
      final instructors = <String, InstructorAbsence?>{};

      // Отримуємо відсутності на дату
      final absences = await getAbsencesForDate(date);

      // Заповнюємо статуси
      for (final member in members) {
        final uid = member['uid'] as String;
        final name = member['fullName'] as String;
        
        final absence = absences.where((a) => a.instructorId == uid).firstOrNull;
        instructors[name] = absence;
      }

      return instructors;
    } catch (e) {
      debugPrint('AbsencesService: Помилка отримання статусів інструкторів: $e');
      return {};
    }
  }

  // === ПРИВАТНІ МЕТОДИ ===

  Future<void> _saveAbsence(InstructorAbsence absence) async {
    final currentGroupId = Globals.profileManager.currentGroupId;
    if (currentGroupId == null) throw Exception('Група не обрана');

    final absenceId = await Globals.firestoreManager.createAbsence(
      groupId: currentGroupId,
      absenceData: absence.toFirestore(),
    );

    if (absenceId == null) {
      throw Exception('Не вдалося створити відсутність');
    }
  }

  Future<bool> _checkAbsenceConflict(
    String instructorId, 
    DateTime startDate, 
    DateTime endDate,
  ) async {
    final existingAbsences = await getAbsencesForPeriod(
      startDate: startDate.subtract(const Duration(days: 1)),
      endDate: endDate.add(const Duration(days: 1)),
      instructorId: instructorId,
    );

    return existingAbsences.any((absence) =>
      absence.status != AbsenceStatus.cancelled &&
      !(endDate.isBefore(absence.startDate) || startDate.isAfter(absence.endDate))
    );
  }

  Future<List<String>> _findAffectedLessons(
    String instructorId, 
    DateTime startDate, 
    DateTime endDate,
  ) async {
    try {
      final lessons = await Globals.calendarService.getLessonsForPeriodByInstructor(
        startDate: startDate,
        endDate: endDate,
        instructorId: instructorId,
      );

      return lessons.map((lesson) => lesson.id).toList();
    } catch (e) {
      debugPrint('Помилка пошуку заторкнутих занять: $e');
      return [];
    }
  }

  Future<void> _updateAbsenceStatus(String absenceId, AbsenceStatus status) async {
    final currentGroupId = Globals.profileManager.currentGroupId;
    if (currentGroupId == null) throw Exception('Група не обрана');

    final success = await Globals.firestoreManager.updateAbsence(
      groupId: currentGroupId,
      absenceId: absenceId,
      updates: {
        'status': status.value,
        'modifiedAt': FieldValue.serverTimestamp(),
      },
    );

    if (!success) {
      throw Exception('Не вдалося оновити статус відсутності');
    }
  }
}