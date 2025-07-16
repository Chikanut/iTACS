import 'dart:typed_data';
import 'package:intl/intl.dart';
import 'package:flutter/material.dart';

enum ReportFormat { excel, docx, pdf, png }

extension ReportFormatExtension on ReportFormat {
  String get extension {
    switch (this) {
      case ReportFormat.excel:
        return 'xlsx';
      case ReportFormat.docx:
        return 'docx';
      case ReportFormat.pdf:
        return 'pdf';
      case ReportFormat.png:
        return 'png';
    }
  }
  
  String get mimeType {
    switch (this) {
      case ReportFormat.excel:
        return 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';
      case ReportFormat.docx:
        return 'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
      case ReportFormat.pdf:
        return 'application/pdf';
      case ReportFormat.png:
        return 'image/png';
    }
  }

  String get displayName {
    switch (this) {
      case ReportFormat.excel:
        return 'Excel';
      case ReportFormat.docx:
        return 'Word';
      case ReportFormat.pdf:
        return 'PDF';
      case ReportFormat.png:
        return 'Зображення';
    }
  }
}

/// Базовий клас для всіх звітів
abstract class BaseReport {
  /// Унікальний ідентифікатор звіту
  String get id;
  
  /// Назва звіту для відображення в UI
  String get name;
  
  /// Опис звіту
  String get description;
  
  /// Іконка для звіту
  IconData get icon;
  
  /// Підтримувані формати
  List<ReportFormat> get supportedFormats;
  
  /// Чи потрібні додаткові параметри для генерації
  bool get requiresParameters => false;
  
  /// Категорія звіту (для групування в UI)
  String get category => 'general';
  
  /// Чи доступний звіт для поточного користувача
  bool get isAvailable => true;
  
  /// Мінімальні ролі користувача для доступу до звіту
  List<String> get requiredRoles => ['viewer'];
  
  /// Отримати віджет для налаштування параметрів (якщо потрібно)
  Widget? getParametersWidget({
    required Function(Map<String, dynamic>) onParametersChanged,
    Map<String, dynamic>? initialParameters,
  }) => null;
  
  /// Згенерувати звіт
  Future<Uint8List> generate({
    required ReportFormat format,
    required DateTime startDate,
    required DateTime endDate,
    Map<String, dynamic>? parameters,
  });
  
  /// Валідація параметрів перед генерацією
  String? validateParameters(Map<String, dynamic>? parameters) => null;
  
  /// Валідація дат
  String? validateDateRange(DateTime startDate, DateTime endDate) {
    if (startDate.isAfter(endDate)) {
      return 'Початкова дата не може бути пізніше за кінцеву';
    }
    
    final now = DateTime.now();
    if (startDate.isAfter(now)) {
      return 'Початкова дата не може бути в майбутньому';
    }
    
    final maxRange = const Duration(days: 365);
    if (endDate.difference(startDate) > maxRange) {
      return 'Максимальний період звіту - 365 днів';
    }
    
    return null;
  }
  
  /// Отримати ім'я файлу за замовчуванням
  String getDefaultFileName({
    required ReportFormat format,
    required DateTime startDate,
    required DateTime endDate,
    Map<String, dynamic>? parameters,
  }) {
    final dateRange = _formatDateRange(startDate, endDate);
    final sanitizedName = name.replaceAll(RegExp(r'[^\w\s-]'), '').replaceAll(' ', '_');
    return '${sanitizedName}_$dateRange.${format.extension}';
  }
  
  /// Форматувати діапазон дат для імені файлу
  String _formatDateRange(DateTime startDate, DateTime endDate) {
    final formatter = DateFormat('dd.MM.yyyy');
    if (_isSameDay(startDate, endDate)) {
      return formatter.format(startDate);
    }
    return '${formatter.format(startDate)}-${formatter.format(endDate)}';
  }
  
  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }
  
  /// Отримати попередній перегляд звіту (мета-інформація)
  Future<Map<String, dynamic>> getPreview({
    required DateTime startDate,
    required DateTime endDate,
    Map<String, dynamic>? parameters,
  }) async {
    return {
      'reportId': id,
      'reportName': name,
      'dateRange': _formatDateRange(startDate, endDate),
      'estimatedSize': 'Невідомо',
      'recordsCount': 0,
    };
  }
  
  /// Додаткова валідація специфічна для кожного звіту
  Future<String?> validateReportSpecificConditions({
    required DateTime startDate,
    required DateTime endDate,
    Map<String, dynamic>? parameters,
  }) async => null;
}