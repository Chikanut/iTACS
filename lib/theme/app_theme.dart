import 'package:flutter/material.dart';

class AppTheme {
  // 🎨 Основна палітра кольорів
  static const Color primaryBlue = Color(0xFF1E3A8A);      // Темно-синій
  static const Color accentBlue = Color(0xFF3B82F6);       // Яскравий синій
  static const Color secondaryGreen = Color(0xFF10B981);   // Зелений (успіх)
  static const Color warningOrange = Color(0xFFF59E0B);    // Помаранчевий
  static const Color dangerRed = Color(0xFFEF4444);        // Червоний (помилка)
  
  // 🌫 Нейтральні тони
  static const Color backgroundDark = Color(0xFF0F172A);   // Темний фон
  static const Color surfaceDark = Color(0xFF1E293B);      // Темна поверхня
  static const Color cardDark = Color(0xFF334155);         // Темні картки
  
  // 📝 Текстові кольори
  static const Color textPrimary = Color(0xFFF8FAFC);      // Основний текст
  static const Color textSecondary = Color(0xFFCBD5E1);    // Вторинний текст
  static const Color textMuted = Color(0xFF64748B);        // Приглушений текст

  // ✨ Акцентні кольори для специфічних елементів
  static const Color folderColor = Color(0xFFF59E0B);      // Папки
  static const Color fileColor = Color(0xFF3B82F6);        // Файли
  static const Color selectedDay = Color(0xFF10B981);      // Вибраний день в календарі

  // 🎯 Створення ColorScheme
  static ColorScheme get _colorScheme => const ColorScheme.dark(
    primary: primaryBlue,
    primaryContainer: accentBlue,
    secondary: secondaryGreen,
    secondaryContainer: Color(0xFF065F46),
    surface: surfaceDark,
    surfaceContainer: cardDark,
    onPrimary: textPrimary,
    onSecondary: textPrimary,
    onSurface: textPrimary,
    onSurfaceVariant: textSecondary,
    error: dangerRed,
    onError: textPrimary,
    outline: Color(0xFF475569),
    shadow: Color(0x1A000000),
  );

  // 🎨 Головна темна тема
  static ThemeData get darkTheme => ThemeData(
    useMaterial3: true,
    colorScheme: _colorScheme,
    
    // 📱 AppBar стиль
    appBarTheme: const AppBarTheme(
      backgroundColor: backgroundDark,
      foregroundColor: textPrimary,
      elevation: 0,
      centerTitle: true,
      titleTextStyle: TextStyle(
        color: textPrimary,
        fontSize: 18,
        fontWeight: FontWeight.w600,
      ),
    ),

    // 🃏 Card стиль
    cardTheme: CardThemeData(
      color: cardDark,
      elevation: 2,
      shadowColor: Colors.black.withOpacity(0.1),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
    ),

    // 🔘 Elevated Button стиль
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: primaryBlue,
        foregroundColor: textPrimary,
        elevation: 2,
        shadowColor: Colors.black.withOpacity(0.2),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      ),
    ),

    // 🔲 Text Button стиль
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: accentBlue,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    ),

    // 📝 Input Decoration стиль
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: surfaceDark,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: Color(0xFF475569)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: Color(0xFF475569)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: primaryBlue, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: dangerRed),
      ),
      labelStyle: const TextStyle(color: textSecondary),
      hintStyle: const TextStyle(color: textMuted),
    ),

    // 🧭 Bottom Navigation стиль
    bottomNavigationBarTheme: const BottomNavigationBarThemeData(
      backgroundColor: surfaceDark,
      selectedItemColor: secondaryGreen,
      unselectedItemColor: textMuted,
      type: BottomNavigationBarType.fixed,
      elevation: 8,
    ),

    // 📊 Scaffold стиль
    scaffoldBackgroundColor: backgroundDark,

    // 📱 Lista Tile стиль
    listTileTheme: const ListTileThemeData(
      textColor: textPrimary,
      iconColor: textSecondary,
    ),

    // ⚪ Divider стиль
    dividerTheme: const DividerThemeData(
      color: Color(0xFF475569),
      thickness: 0.5,
    ),
  );

  // 🌟 Світла тема (якщо буде потреба в майбутньому)
  static ThemeData get lightTheme => ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(
      seedColor: primaryBlue,
      brightness: Brightness.light,
    ),
    scaffoldBackgroundColor: Colors.grey[50],
  );
}

// 🎯 Extension для легкого доступу до кольорів через context
extension AppColors on BuildContext {
  Color get primary => Theme.of(this).colorScheme.primary;
  Color get secondary => Theme.of(this).colorScheme.secondary;
  Color get surface => Theme.of(this).colorScheme.surface;
  Color get background => Theme.of(this).scaffoldBackgroundColor;
  Color get error => Theme.of(this).colorScheme.error;
  
  // Кастомні кольори
  Color get folderColor => AppTheme.folderColor;
  Color get fileColor => AppTheme.fileColor;
  Color get selectedDay => AppTheme.selectedDay;
  Color get textPrimary => AppTheme.textPrimary;
  Color get textSecondary => AppTheme.textSecondary;
  Color get textMuted => AppTheme.textMuted;
}