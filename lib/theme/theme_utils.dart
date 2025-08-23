import 'package:flutter/material.dart';
import 'app_theme.dart';

/// Утилітарний клас для швидкого доступу до теми без контексту
class ThemeUtils {
  
  // 🎨 Статичні кольори для випадків, коли немає контексту
  static const Color primary = AppTheme.primaryBlue;
  static const Color accent = AppTheme.accentBlue;
  static const Color success = AppTheme.secondaryGreen;
  static const Color warning = AppTheme.warningOrange;
  static const Color danger = AppTheme.dangerRed;
  static const Color folder = AppTheme.folderColor;
  static const Color file = AppTheme.fileColor;
  
  // 📝 Текстові стилі
  static const TextStyle headlineStyle = TextStyle(
    color: AppTheme.textPrimary,
    fontSize: 24,
    fontWeight: FontWeight.bold,
  );
  
  static const TextStyle titleStyle = TextStyle(
    color: AppTheme.textPrimary,
    fontSize: 18,
    fontWeight: FontWeight.w600,
  );
  
  static const TextStyle bodyStyle = TextStyle(
    color: AppTheme.textPrimary,
    fontSize: 16,
    fontWeight: FontWeight.normal,
  );
  
  static const TextStyle captionStyle = TextStyle(
    color: AppTheme.textSecondary,
    fontSize: 14,
    fontWeight: FontWeight.normal,
  );
  
  static const TextStyle mutedStyle = TextStyle(
    color: AppTheme.textMuted,
    fontSize: 12,
    fontWeight: FontWeight.normal,
  );

  // 🎯 Готові BoxDecoration
  static BoxDecoration get cardDecoration => BoxDecoration(
    color: AppTheme.cardDark,
    borderRadius: BorderRadius.circular(12),
    boxShadow: [
      BoxShadow(
        color: Colors.black.withOpacity(0.1),
        blurRadius: 4,
        offset: const Offset(0, 2),
      ),
    ],
  );
  
  static BoxDecoration get surfaceDecoration => BoxDecoration(
    color: AppTheme.surfaceDark,
    borderRadius: BorderRadius.circular(8),
  );
  
  // 🚨 Декорації для статусів
  static BoxDecoration successDecoration = BoxDecoration(
    color: AppTheme.secondaryGreen.withOpacity(0.1),
    borderRadius: BorderRadius.circular(6),
    border: Border.all(color: AppTheme.secondaryGreen.withOpacity(0.3)),
  );
  
  static BoxDecoration warningDecoration = BoxDecoration(
    color: AppTheme.warningOrange.withOpacity(0.1),
    borderRadius: BorderRadius.circular(6),
    border: Border.all(color: AppTheme.warningOrange.withOpacity(0.3)),
  );
  
  static BoxDecoration dangerDecoration = BoxDecoration(
    color: AppTheme.dangerRed.withOpacity(0.1),
    borderRadius: BorderRadius.circular(6),
    border: Border.all(color: AppTheme.dangerRed.withOpacity(0.3)),
  );

  // 🎛 Методи для отримання кольорів з контекстом
  static Color getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'success':
      case 'completed':
      case 'done':
        return success;
      case 'warning':
      case 'pending':
        return warning;
      case 'error':
      case 'failed':
      case 'danger':
        return danger;
      default:
        return primary;
    }
  }
  
  static Color getTypeColor(String type) {
    switch (type.toLowerCase()) {
      case 'folder':
      case 'directory':
        return folder;
      case 'file':
      case 'document':
        return file;
      default:
        return primary;
    }
  }
}