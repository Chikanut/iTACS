import 'package:flutter/material.dart';

enum AppStatusTone { neutral, info, success, warning, danger, accent, weekend }

@immutable
class AppStatusColors {
  final Color background;
  final Color border;
  final Color foreground;
  final Color badge;

  const AppStatusColors({
    required this.background,
    required this.border,
    required this.foreground,
    required this.badge,
  });
}

class AppTheme {
  static const String appVersion = '2.0.0';

  // Додатковий акцентний синій колір
  static const Color accentBlue = Color(
    0xFF2563EB,
  ); // Можна змінити на бажаний shade

  // 🎨 Основна палітра кольорів з shade підтримкою
  static const MaterialColor primaryBlue = MaterialColor(0xFF1E3A8A, {
    50: Color(0xFFEFF6FF),
    100: Color(0xFFDBEAFE),
    200: Color(0xFFBFDBFE),
    300: Color(0xFF93C5FD),
    400: Color(0xFF60A5FA),
    500: Color(0xFF3B82F6),
    600: Color(0xFF2563EB),
    700: Color(0xFF1D4ED8),
    800: Color(0xFF1E40AF),
    900: Color(0xFF1E3A8A),
  });

  static const MaterialColor secondaryGreen = MaterialColor(0xFF10B981, {
    50: Color(0xFFECFDF5),
    100: Color(0xFFD1FAE5),
    200: Color(0xFFA7F3D0),
    300: Color(0xFF6EE7B7),
    400: Color(0xFF34D399),
    500: Color(0xFF10B981),
    600: Color(0xFF059669),
    700: Color(0xFF047857),
    800: Color(0xFF065F46),
    900: Color(0xFF064E3B),
  });

  static const MaterialColor warningOrange = MaterialColor(0xFFF59E0B, {
    50: Color(0xFFFFFBEB),
    100: Color(0xFFFEF3C7),
    200: Color(0xFFFDE68A),
    300: Color(0xFFFCD34D),
    400: Color(0xFFFBBF24),
    500: Color(0xFFF59E0B),
    600: Color(0xFFD97706),
    700: Color(0xFFB45309),
    800: Color(0xFF92400E),
    900: Color(0xFF78350F),
  });

  static const MaterialColor dangerRed = MaterialColor(0xFFEF4444, {
    50: Color(0xFFFEF2F2),
    100: Color(0xFFFEE2E2),
    200: Color(0xFFFECACA),
    300: Color(0xFFFCA5A5),
    400: Color(0xFFF87171),
    500: Color(0xFFEF4444),
    600: Color(0xFFDC2626),
    700: Color(0xFFB91C1C),
    800: Color(0xFF991B1B),
    900: Color(0xFF7F1D1D),
  });

  static const MaterialColor greyScale = MaterialColor(0xFF64748B, {
    50: Color(0xFFF8FAFC),
    100: Color(0xFFF1F5F9),
    200: Color(0xFFE2E8F0),
    300: Color(0xFFCBD5E1),
    400: Color(0xFF94A3B8),
    500: Color(0xFF64748B),
    600: Color(0xFF475569),
    700: Color(0xFF334155),
    800: Color(0xFF1E293B),
    900: Color(0xFF0F172A),
  });

  // 🌫 Нейтральні тони (використовуючи greyScale)
  static Color get backgroundDark => greyScale.shade900; // Темний фон
  static Color get surfaceDark => greyScale.shade800; // Темна поверхня
  static Color get cardDark => greyScale.shade700; // Темні картки
  static const Color surfaceRaised = Color(0xFF243247);
  static const Color surfaceOverlay = Color(0xFF192538);
  static const Color borderSubtle = Color(0xFF46556C);

  // 📝 Текстові кольори (використовуючи greyScale)
  static Color get textPrimary => greyScale.shade50; // Основний текст
  static Color get textSecondary => greyScale.shade300; // Вторинний текст
  static Color get textMuted => greyScale.shade500; // Приглушений текст

  // ✨ Акцентні кольори для специфічних елементів
  static Color get folderColor => warningOrange.shade600; // Папки
  static Color get fileColor => primaryBlue.shade600; // Файли
  static Color get selectedDay =>
      secondaryGreen.shade600; // Вибраний день в календарі

  static const AppStatusColors neutralStatus = AppStatusColors(
    background: Color(0xFF253246),
    border: Color(0xFF516178),
    foreground: Color(0xFFF8FAFC),
    badge: Color(0xFFCBD5E1),
  );

  static const AppStatusColors infoStatus = AppStatusColors(
    background: Color(0xFF17314F),
    border: Color(0xFF4B8BFF),
    foreground: Color(0xFFE2EEFF),
    badge: Color(0xFF93C5FD),
  );

  static const AppStatusColors successStatus = AppStatusColors(
    background: Color(0xFF18362E),
    border: Color(0xFF34D399),
    foreground: Color(0xFFDCFCE7),
    badge: Color(0xFF6EE7B7),
  );

  static const AppStatusColors warningStatus = AppStatusColors(
    background: Color(0xFF493416),
    border: Color(0xFFF59E0B),
    foreground: Color(0xFFFFE7C2),
    badge: Color(0xFFFCD34D),
  );

  static const AppStatusColors dangerStatus = AppStatusColors(
    background: Color(0xFF4A202A),
    border: Color(0xFFF87171),
    foreground: Color(0xFFFFE0E6),
    badge: Color(0xFFFCA5A5),
  );

  static const AppStatusColors accentStatus = AppStatusColors(
    background: Color(0xFF372753),
    border: Color(0xFFC084FC),
    foreground: Color(0xFFF4E8FF),
    badge: Color(0xFFD8B4FE),
  );

  static const AppStatusColors weekendStatus = AppStatusColors(
    background: Color(0xFF5B1F31),
    border: Color(0xFF8E314B),
    foreground: Color(0xFFFFE0E8),
    badge: Color(0xFFF9A8D4),
  );

  static AppStatusColors statusColors(AppStatusTone tone) {
    switch (tone) {
      case AppStatusTone.info:
        return infoStatus;
      case AppStatusTone.success:
        return successStatus;
      case AppStatusTone.warning:
        return warningStatus;
      case AppStatusTone.danger:
        return dangerStatus;
      case AppStatusTone.accent:
        return accentStatus;
      case AppStatusTone.weekend:
        return weekendStatus;
      case AppStatusTone.neutral:
        return neutralStatus;
    }
  }

  static BoxDecoration statusDecoration(
    AppStatusTone tone, {
    double radius = 12,
  }) {
    final colors = statusColors(tone);
    return BoxDecoration(
      color: colors.background,
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(color: colors.border.withOpacity(0.75)),
    );
  }

  // 🎯 Створення ColorScheme
  static ColorScheme get _colorScheme => ColorScheme.dark(
    primary: primaryBlue, // Основний синій (файли, кнопки)
    primaryContainer: accentBlue,
    secondary: warningOrange, // Помаранчевий (папки, попередження)
    secondaryContainer: const Color(0xFF9A3412),
    tertiary: secondaryGreen, // Зелений (успіх, завершено)
    tertiaryContainer: const Color(0xFF065F46),
    surface: backgroundDark, // Фон сторінок
    surfaceContainer: cardDark, // Фон карток і контейнерів
    surfaceContainerHighest: surfaceDark, // Піднесені поверхні
    onPrimary: textPrimary, // Білий текст на синьому
    onSecondary: textPrimary, // Білий текст на помаранчевому
    onSurface: textPrimary, // Основний білий текст
    onSurfaceVariant: textSecondary, // Сірий текст (описи, підписи)
    error: dangerRed, // Червоний для помилок
    onError: textPrimary,
    outline: borderSubtle, // Кольір рамок і роздільників
    shadow: const Color(0x1A000000),
  );

  // 🎨 Головна темна тема
  static ThemeData get darkTheme => ThemeData(
    useMaterial3: true,
    colorScheme: _colorScheme,
    scaffoldBackgroundColor: backgroundDark,
    canvasColor: backgroundDark,
    cardColor: cardDark,
    splashColor: primaryBlue.shade400.withOpacity(0.12),
    highlightColor: primaryBlue.shade400.withOpacity(0.06),
    textTheme: ThemeData.dark().textTheme
        .apply(bodyColor: textPrimary, displayColor: textPrimary)
        .copyWith(
          titleLarge: const TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
          titleMedium: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w600,
            color: textPrimary,
          ),
          titleSmall: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: textSecondary,
          ),
          bodyLarge: TextStyle(fontSize: 16, color: textPrimary),
          bodyMedium: TextStyle(fontSize: 14, color: textPrimary),
          bodySmall: TextStyle(fontSize: 12, color: textSecondary),
          labelLarge: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: textPrimary,
          ),
        ),
    iconTheme: IconThemeData(color: textSecondary),

    // 📱 AppBar стиль
    appBarTheme: AppBarTheme(
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

    // 📄 Card стиль
    cardTheme: CardThemeData(
      color: cardDark,
      elevation: 2,
      shadowColor: Colors.black.withOpacity(0.1),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: borderSubtle),
      ),
      margin: EdgeInsets.zero,
    ),

    // 🔘 Elevated Button стиль
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: primaryBlue.shade700,
        foregroundColor: textPrimary,
        elevation: 2,
        shadowColor: Colors.black.withOpacity(0.2),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      ),
    ),

    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: primaryBlue.shade600,
        foregroundColor: textPrimary,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    ),

    // 🔲 Text Button стиль
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: primaryBlue.shade300,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    ),

    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: textPrimary,
        side: BorderSide(color: greyScale.shade600),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    ),

    // 📝 Input Decoration стиль
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: surfaceOverlay,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: greyScale.shade600),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: greyScale.shade600),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: primaryBlue.shade600, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: dangerRed.shade600),
      ),
      labelStyle: TextStyle(color: textSecondary),
      hintStyle: TextStyle(color: textMuted),
    ),

    chipTheme: ChipThemeData(
      backgroundColor: surfaceOverlay,
      selectedColor: primaryBlue.shade700.withOpacity(0.2),
      secondarySelectedColor: primaryBlue.shade700.withOpacity(0.2),
      disabledColor: greyScale.shade700,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: const BorderSide(color: borderSubtle),
      ),
      labelStyle: TextStyle(color: textPrimary, fontWeight: FontWeight.w600),
      secondaryLabelStyle: TextStyle(
        color: textPrimary,
        fontWeight: FontWeight.w600,
      ),
      brightness: Brightness.dark,
    ),

    dialogTheme: DialogThemeData(
      backgroundColor: surfaceRaised,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      titleTextStyle: TextStyle(
        color: textPrimary,
        fontSize: 18,
        fontWeight: FontWeight.w700,
      ),
      contentTextStyle: TextStyle(color: textSecondary, fontSize: 14),
    ),

    snackBarTheme: SnackBarThemeData(
      backgroundColor: surfaceRaised,
      contentTextStyle: TextStyle(color: textPrimary),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),

    dividerColor: borderSubtle,

    // 🧭 Bottom Navigation стиль
    bottomNavigationBarTheme: BottomNavigationBarThemeData(
      backgroundColor: surfaceOverlay,
      selectedItemColor: secondaryGreen.shade500,
      unselectedItemColor: textMuted,
      type: BottomNavigationBarType.fixed,
      elevation: 8,
    ),

    // 📱 Lista Tile стиль
    listTileTheme: ListTileThemeData(
      textColor: textPrimary,
      iconColor: textSecondary,
    ),

    tabBarTheme: TabBarThemeData(
      labelColor: textPrimary,
      unselectedLabelColor: textSecondary,
      indicator: UnderlineTabIndicator(
        borderSide: BorderSide(color: secondaryGreen.shade400, width: 3),
      ),
      dividerColor: Colors.transparent,
    ),

    // ⚪ Divider стиль
    dividerTheme: const DividerThemeData(color: borderSubtle, thickness: 0.5),
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
  // Основні кольори теми
  Color get primary => Theme.of(this).colorScheme.primary;
  Color get secondary => Theme.of(this).colorScheme.secondary;
  Color get tertiary => Theme.of(this).colorScheme.tertiary;
  Color get surface => Theme.of(this).colorScheme.surface;
  Color get background => Theme.of(this).scaffoldBackgroundColor;
  Color get error => Theme.of(this).colorScheme.error;

  // Прямий доступ до MaterialColor з усіма shade
  MaterialColor get primaryBlue => AppTheme.primaryBlue;
  MaterialColor get secondaryGreen => AppTheme.secondaryGreen;
  MaterialColor get warningOrange => AppTheme.warningOrange;
  MaterialColor get dangerRed => AppTheme.dangerRed;
  MaterialColor get greyScale => AppTheme.greyScale;

  // Кастомні кольори (для зворотної сумісності)
  Color get folderColor => AppTheme.folderColor;
  Color get fileColor => AppTheme.fileColor;
  Color get selectedDay => AppTheme.selectedDay;
  Color get textPrimary => AppTheme.textPrimary;
  Color get textSecondary => AppTheme.textSecondary;
  Color get textMuted => AppTheme.textMuted;
  AppStatusColors status(AppStatusTone tone) => AppTheme.statusColors(tone);
}

// 🎨 Extension для швидкого доступу до shade без context
extension AppColorShades on Color {
  /// Отримати shade варіант кольору (якщо це MaterialColor)
  Color shade(int value) {
    if (this is MaterialColor) {
      final materialColor = this as MaterialColor;
      return materialColor[value] ?? this;
    }

    // Для звичайних кольорів використовуємо opacity
    final opacityMap = {
      50: 0.05,
      100: 0.1,
      200: 0.2,
      300: 0.3,
      400: 0.4,
      500: 0.5,
      600: 0.6,
      700: 0.7,
      800: 0.8,
      900: 0.9,
    };

    final opacity = opacityMap[value] ?? 1.0;
    return withOpacity(opacity);
  }
}
