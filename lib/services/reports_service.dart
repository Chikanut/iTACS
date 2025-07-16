import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'reports/base_report.dart';
import 'reports/lessons_list_report.dart';
import 'reports/calendar_grid_report.dart';
// import 'reports/instructor_stats_report.dart';
// import 'reports/monthly_calendar_report.dart';
// import 'reports/attendance_report.dart';
import '../globals.dart';

class ReportsService {
  static final ReportsService _instance = ReportsService._internal();
  factory ReportsService() => _instance;
  ReportsService._internal();

  final List<BaseReport> _reports = [];
  bool _initialized = false;

  /// Ініціалізація сервісу з реєстрацією всіх звітів
  Future<void> initialize() async {
    if (_initialized) return;
    
    try {
      // Реєструємо всі доступні звіти
      _reports.clear();
      _reports.addAll([
        LessonsListReport(),
        CalendarGridReport(),
        // InstructorStatsReport(),
        // MonthlyCalendarReport(),
        // WeeklyScheduleReport(),
        // AttendanceReport(),
      ]);
      
      _initialized = true;
      
      if (kDebugMode) {
        print('ReportsService ініціалізовано з ${_reports.length} звітами');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Помилка ініціалізації ReportsService: $e');
      }
      rethrow;
    }
  }

  /// Отримати список всіх доступних звітів для поточного користувача
  List<BaseReport> getAvailableReports() {
    _ensureInitialized();

    final currentUserRole = Globals.profileManager.getRoleInGroup(Globals.profileManager.currentGroupId != null ? Globals.profileManager.currentGroupId! : 'viewer');

    return _reports.where((report) {
      // Перевіряємо чи доступний звіт загалом
      if (!report.isAvailable) return false;
      
      // Перевіряємо чи має користувач потрібну роль
      if (!report.requiredRoles.contains(currentUserRole)) {
        // Якщо роль не підходить точно, перевіряємо ієрархію ролей
        return _hasRequiredRole(currentUserRole!, report.requiredRoles);
      }
      
      return true;
    }).toList();
  }

  /// Отримати звіти за категорією
  List<BaseReport> getReportsByCategory(String category) {
    _ensureInitialized();
    return getAvailableReports()
        .where((report) => report.category == category)
        .toList();
  }

  /// Отримати всі доступні категорії
  List<String> getAvailableCategories() {
    _ensureInitialized();
    final categories = getAvailableReports()
        .map((report) => report.category)
        .toSet()
        .toList();
    categories.sort();
    return categories;
  }

  /// Отримати звіт за ID
  BaseReport? getReportById(String id) {
    _ensureInitialized();
    try {
      return _reports.firstWhere((report) => report.id == id);
    } catch (e) {
      return null;
    }
  }

  /// Згенерувати звіт
  Future<Uint8List> generateReport({
    required String reportId,
    required ReportFormat format,
    required DateTime startDate,
    required DateTime endDate,
    Map<String, dynamic>? parameters,
  }) async {
    _ensureInitialized();
    
    final report = getReportById(reportId);
    if (report == null) {
      throw Exception('Звіт з ID "$reportId" не знайдено');
    }

    // Перевіряємо доступ користувача до звіту
    if (!getAvailableReports().contains(report)) {
      throw Exception('Недостатньо прав для генерації звіту "${report.name}"');
    }

    if (!report.supportedFormats.contains(format)) {
      throw Exception('Формат ${format.displayName} не підтримується для звіту "${report.name}"');
    }

    // Валідуємо дати
    final dateValidationError = report.validateDateRange(startDate, endDate);
    if (dateValidationError != null) {
      throw Exception('Помилка валідації дат: $dateValidationError');
    }

    // Валідуємо параметри
    final paramValidationError = report.validateParameters(parameters);
    if (paramValidationError != null) {
      throw Exception('Помилка валідації параметрів: $paramValidationError');
    }

    // Додаткова валідація специфічна для звіту
    final specificValidationError = await report.validateReportSpecificConditions(
      startDate: startDate,
      endDate: endDate,
      parameters: parameters,
    );
    if (specificValidationError != null) {
      throw Exception('Помилка валідації: $specificValidationError');
    }

    if (kDebugMode) {
      print('Генерація звіту: ${report.name} у форматі ${format.displayName}');
    }

    try {
      final startTime = DateTime.now();
      
      final result = await report.generate(
        format: format,
        startDate: startDate,
        endDate: endDate,
        parameters: parameters,
      );
      
      final duration = DateTime.now().difference(startTime);
      if (kDebugMode) {
        print('Звіт "${report.name}" згенеровано за ${duration.inMilliseconds}мс');
      }

      return result;
    } catch (e) {
      if (kDebugMode) {
        print('Помилка генерації звіту "${report.name}": $e');
      }
      rethrow;
    }
  }

  /// Отримати попередній перегляд звіту
  Future<Map<String, dynamic>> getReportPreview({
    required String reportId,
    required DateTime startDate,
    required DateTime endDate,
    Map<String, dynamic>? parameters,
  }) async {
    _ensureInitialized();
    
    final report = getReportById(reportId);
    if (report == null) {
      throw Exception('Звіт з ID "$reportId" не знайдено');
    }

    if (!getAvailableReports().contains(report)) {
      throw Exception('Недостатньо прав для перегляду звіту "${report.name}"');
    }

    try {
      return await report.getPreview(
        startDate: startDate,
        endDate: endDate,
        parameters: parameters,
      );
    } catch (e) {
      if (kDebugMode) {
        print('Помилка отримання попереднього перегляду звіту "${report.name}": $e');
      }
      rethrow;
    }
  }

  /// Отримати ім'я файлу для звіту
  String getReportFileName({
    required String reportId,
    required ReportFormat format,
    required DateTime startDate,
    required DateTime endDate,
    Map<String, dynamic>? parameters,
  }) {
    _ensureInitialized();
    
    final report = getReportById(reportId);
    if (report == null) {
      throw Exception('Звіт з ID "$reportId" не знайдено');
    }

    return report.getDefaultFileName(
      format: format,
      startDate: startDate,
      endDate: endDate,
      parameters: parameters,
    );
  }

  /// Перевірити чи ініціалізований сервіс
  void _ensureInitialized() {
    if (!_initialized) {
      throw Exception('ReportsService не ініціалізовано. Викличте initialize() спочатку.');
    }
  }

  /// Перевірити чи має користувач потрібну роль (з урахуванням ієрархії)
  bool _hasRequiredRole(String userRole, List<String> requiredRoles) {
    // Ієрархія ролей: admin > editor > viewer
    const roleHierarchy = {
      'admin': 3,
      'editor': 2,
      'viewer': 1,
    };

    final userLevel = roleHierarchy[userRole] ?? 0;
    final minRequiredLevel = requiredRoles
        .map((role) => roleHierarchy[role] ?? 0)
        .reduce((a, b) => a < b ? a : b);

    return userLevel >= minRequiredLevel;
  }

  /// Очистити кеш та перезавантажити звіти
  Future<void> reload() async {
    _initialized = false;
    _reports.clear();
    await initialize();
  }

  /// Отримати статистику використання звітів
  Map<String, dynamic> getUsageStatistics() {
    _ensureInitialized();
    
    final availableReports = getAvailableReports();
    final formatStats = <String, int>{};
    final categoryStats = <String, int>{};
    
    for (final format in ReportFormat.values) {
      final count = availableReports
          .where((r) => r.supportedFormats.contains(format))
          .length;
      formatStats[format.displayName] = count;
    }

    for (final report in availableReports) {
      final category = report.category;
      categoryStats[category] = (categoryStats[category] ?? 0) + 1;
    }

    return {
      'total_reports': availableReports.length,
      'total_registered': _reports.length,
      'current_user_role': Globals.profileManager.getRoleInGroup(Globals.profileManager.currentGroupId != null ? Globals.profileManager.currentGroupId! : 'unknown'),
      'available_formats': ReportFormat.values.map((f) => f.displayName).toList(),
      'reports_by_format': formatStats,
      'reports_by_category': categoryStats,
      'categories': getAvailableCategories(),
    };
  }

  /// Отримати мета-дані про звіт
  Map<String, dynamic> getReportMetadata(String reportId) {
    _ensureInitialized();
    
    final report = getReportById(reportId);
    if (report == null) {
      throw Exception('Звіт з ID "$reportId" не знайдено');
    }

    return {
      'id': report.id,
      'name': report.name,
      'description': report.description,
      'category': report.category,
      'supported_formats': report.supportedFormats.map((f) => f.displayName).toList(),
      'requires_parameters': report.requiresParameters,
      'required_roles': report.requiredRoles,
      'is_available': report.isAvailable,
      'is_accessible': getAvailableReports().contains(report),
    };
  }

  /// Експортувати конфігурацію звітів (для резервного копіювання)
  Map<String, dynamic> exportConfiguration() {
    _ensureInitialized();
    
    return {
      'version': '1.0',
      'exported_at': DateTime.now().toIso8601String(),
      'reports': _reports.map((report) => getReportMetadata(report.id)).toList(),
      'user_context': {
        'group': Globals.profileManager.currentGroupName,
        'role': Globals.profileManager.getRoleInGroup(Globals.profileManager.currentGroupId != null ? Globals.profileManager.currentGroupId! : ''),
      },
    };
  }
}