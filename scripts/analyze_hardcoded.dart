#!/usr/bin/env dart

import 'dart:io';
import 'dart:convert';

/// Скрипт для аналізу hardcoded кольорів та текстових рядків
void main(List<String> args) async {
  print('🔍 Аналіз hardcoded значень у проєкті...\n');

  final outputToFile = args.contains('--file');
  final onlyColors = args.contains('--colors-only');
  final onlyTexts = args.contains('--texts-only');

  final libDir = Directory('lib');
  if (!libDir.existsSync()) {
    print('❌ Папка lib не знайдена.');
    return;
  }

  final analyzer = HardcodedAnalyzer();
  await analyzer.analyzeDirectory(libDir);

  final report = analyzer.generateReport(onlyColors, onlyTexts);

  if (outputToFile) {
    await saveReportToFile(report);
  } else {
    print(report);
  }
}

class HardcodedAnalyzer {
  final List<ColorIssue> colorIssues = [];
  final List<TextIssue> textIssues = [];
  final List<String> problematicFiles = [];

  // Паттерни для кольорів
  final colorPatterns = [
    ColorPattern(
      r'Colors\.\w+(?:\[\d+\])?(?:\.withOpacity\([^)]+\))?',
      'Colors.*',
    ),
    ColorPattern(r'Color\(0x[0-9A-Fa-f]{8}\)', 'Color(0x...)'),
    ColorPattern(r'Color\(0x[0-9A-Fa-f]{6}\)', 'Color(0x...) without alpha'),
    ColorPattern(r'Color\.fromARGB\([^)]+\)', 'Color.fromARGB(...)'),
    ColorPattern(r'Color\.fromRGBO\([^)]+\)', 'Color.fromRGBO(...)'),
    ColorPattern(r'#[0-9A-Fa-f]{6,8}', 'Hex colors (#...)'),
  ];

  // Паттерни для текстів (українські та англійські рядки)
  final textPatterns = [
    TextPattern(r"'[А-Яа-яІіЇїЄєҐґ][^']*'", 'Українські рядки'),
    TextPattern(
      r'"[А-Яа-яІіЇїЄєҐґ][^"]*"',
      'Українські рядки в подвійних лапках',
    ),
    TextPattern(
      r"'[A-Za-z][A-Za-z\s]{3,}[^']*'",
      'Англійські рядки (>3 символи)',
    ),
    TextPattern(
      r'"[A-Za-z][A-Za-z\s]{3,}[^"]*"',
      'Англійські рядки в подвійних лапках',
    ),
    TextPattern("Text\\(\\s*['\"][^'\"]+['\"]", 'Text() з hardcoded рядком'),
    TextPattern("label:\\s*['\"][^'\"]+['\"]", 'label: з рядком'),
    TextPattern("title:\\s*['\"][^'\"]+['\"]", 'title: з рядком'),
    TextPattern("hintText:\\s*['\"][^'\"]+['\"]", 'hintText: з рядком'),
  ];

  // Виключення для текстів (техніні рядки, які не треба переводити)
  final textExclusions = [
    r"'http[s]?://", // URLs
    r'"http[s]?://',
    r"'[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+\.[A-Za-z]+", // Домени
    r"'[A-Za-z0-9_-]+@[A-Za-z0-9_-]+", // Email patterns
    r"'[A-Fa-f0-9-]{36}'", // UUID
    r"'[A-Za-z0-9+/]{20,}='*", // Base64
    r"'[A-Za-z_][A-Za-z0-9_]*'", // Змінні/ключі < 15 символів
    r'"[A-Za-z_][A-Za-z0-9_]*"',
    r"'(GET|POST|PUT|DELETE|PATCH)'", // HTTP methods
    r"'(png|jpg|jpeg|gif|svg|webp|ico)'", // Файлові розширення
    r"'application/[^']+'", // MIME types
  ];

  Future<void> analyzeDirectory(Directory dir) async {
    await for (final entity in dir.list(recursive: true)) {
      if (entity is File && entity.path.endsWith('.dart')) {
        if (shouldSkipFile(entity.path)) continue;

        try {
          await analyzeFile(entity);
        } catch (e) {
          problematicFiles.add('${entity.path}: $e');
        }
      }
    }
  }

  bool shouldSkipFile(String path) {
    final skipPatterns = [
      '.g.dart',
      '.freezed.dart',
      'firebase_options.dart',
      '/generated/',
      'l10n.dart',
      'app_localizations',
    ];

    return skipPatterns.any((pattern) => path.contains(pattern));
  }

  Future<void> analyzeFile(File file) async {
    final content = await file.readAsString();
    final lines = content.split('\n');

    // Аналізуємо кольори
    for (final pattern in colorPatterns) {
      final regex = RegExp(pattern.pattern);
      final matches = regex.allMatches(content);

      for (final match in matches) {
        final lineNumber = _getLineNumber(content, match.start);
        final line = lines[lineNumber - 1].trim();

        colorIssues.add(
          ColorIssue(
            file: file.path,
            lineNumber: lineNumber,
            line: line,
            match: match.group(0) ?? '',
            type: pattern.description,
            context: _extractContext(lines, lineNumber - 1),
          ),
        );
      }
    }

    // Аналізуємо тексти
    for (final pattern in textPatterns) {
      final regex = RegExp(pattern.pattern);
      final matches = regex.allMatches(content);

      for (final match in matches) {
        final matchText = match.group(0) ?? '';

        // Перевіряємо виключення
        if (_shouldExcludeText(matchText)) continue;

        final lineNumber = _getLineNumber(content, match.start);
        final line = lines[lineNumber - 1].trim();

        textIssues.add(
          TextIssue(
            file: file.path,
            lineNumber: lineNumber,
            line: line,
            match: matchText,
            type: pattern.description,
            context: _extractContext(lines, lineNumber - 1),
            extractedText: _extractTextContent(matchText),
          ),
        );
      }
    }
  }

  bool _shouldExcludeText(String text) {
    for (final exclusion in textExclusions) {
      if (RegExp(exclusion).hasMatch(text)) return true;
    }

    // Виключаємо дуже короткі рядки
    final content = _extractTextContent(text);
    if (content.length < 3) return true;

    // Виключаємо рядки тільки з цифрами/символами
    if (RegExp(r'^[0-9\s\-\+\(\)\.,:;!?]*$').hasMatch(content)) return true;

    return false;
  }

  String _extractTextContent(String match) {
    // Витягуємо текст з лапок
    final regex = RegExp("['\"]([^'\"]+)['\"]");
    final matchResult = regex.firstMatch(match);
    return matchResult?.group(1) ?? match;
  }

  int _getLineNumber(String content, int position) {
    return content.substring(0, position).split('\n').length;
  }

  List<String> _extractContext(List<String> lines, int lineIndex) {
    final start = (lineIndex - 2).clamp(0, lines.length);
    final end = (lineIndex + 3).clamp(0, lines.length);
    return lines.sublist(start, end);
  }

  String generateReport(bool onlyColors, bool onlyTexts) {
    final buffer = StringBuffer();

    buffer.writeln('🎨📝 ЗВІТ АНАЛІЗУ HARDCODED ЗНАЧЕНЬ');
    buffer.writeln('=' * 50);

    if (!onlyTexts) {
      _generateColorReport(buffer);
    }

    if (!onlyColors) {
      _generateTextReport(buffer);
    }

    _generateSummary(buffer);
    _generateRecommendations(buffer);

    return buffer.toString();
  }

  void _generateColorReport(StringBuffer buffer) {
    buffer.writeln('\n🎨 HARDCODED КОЛЬОРИ:');
    buffer.writeln('-' * 30);

    final colorStats = <String, int>{};
    final colorsByFile = <String, List<ColorIssue>>{};

    for (final issue in colorIssues) {
      colorStats[issue.type] = (colorStats[issue.type] ?? 0) + 1;
      colorsByFile.putIfAbsent(issue.file, () => []).add(issue);
    }

    buffer.writeln('📊 Статистика по типах кольорів:');
    colorStats.forEach((type, count) {
      buffer.writeln('   • $type: $count');
    });

    buffer.writeln('\n📁 По файлах:');
    colorsByFile.forEach((file, issues) {
      buffer.writeln('\n🔸 $file (${issues.length} кольорів):');
      for (final issue in issues.take(5)) {
        // Показуємо перші 5
        buffer.writeln('   Рядок ${issue.lineNumber}: ${issue.match}');
        buffer.writeln('   Контекст: ${issue.line}');
      }
      if (issues.length > 5) {
        buffer.writeln('   ... і ще ${issues.length - 5} кольорів');
      }
    });
  }

  void _generateTextReport(StringBuffer buffer) {
    buffer.writeln('\n📝 HARDCODED ТЕКСТИ:');
    buffer.writeln('-' * 30);

    final textStats = <String, int>{};
    final textsByFile = <String, List<TextIssue>>{};
    final uniqueTexts = <String>{};

    for (final issue in textIssues) {
      textStats[issue.type] = (textStats[issue.type] ?? 0) + 1;
      textsByFile.putIfAbsent(issue.file, () => []).add(issue);
      uniqueTexts.add(issue.extractedText);
    }

    buffer.writeln('📊 Статистика по типах текстів:');
    textStats.forEach((type, count) {
      buffer.writeln('   • $type: $count');
    });

    buffer.writeln(
      '\n🌍 Унікальні тексти для перекладу (${uniqueTexts.length}):',
    );
    final sortedTexts = uniqueTexts.toList()..sort();
    for (final text in sortedTexts.take(20)) {
      // Показуємо перші 20
      buffer.writeln('   • "$text"');
    }
    if (uniqueTexts.length > 20) {
      buffer.writeln('   ... і ще ${uniqueTexts.length - 20} текстів');
    }

    buffer.writeln('\n📁 По файлах з найбільшою кількістю hardcoded текстів:');
    final sortedFiles = textsByFile.entries.toList()
      ..sort((a, b) => b.value.length.compareTo(a.value.length));

    for (final entry in sortedFiles.take(10)) {
      buffer.writeln('\n🔸 ${entry.key} (${entry.value.length} текстів):');
      for (final issue in entry.value.take(3)) {
        buffer.writeln(
          '   Рядок ${issue.lineNumber}: "${issue.extractedText}"',
        );
      }
      if (entry.value.length > 3) {
        buffer.writeln('   ... і ще ${entry.value.length - 3} текстів');
      }
    }
  }

  void _generateSummary(StringBuffer buffer) {
    buffer.writeln('\n📊 ПІДСУМОК:');
    buffer.writeln('-' * 30);
    buffer.writeln('• Знайдено кольорів: ${colorIssues.length}');
    buffer.writeln('• Знайдено текстів: ${textIssues.length}');
    buffer.writeln(
      '• Унікальних текстів: ${textIssues.map((e) => e.extractedText).toSet().length}',
    );
    buffer.writeln(
      '• Файлів з кольорами: ${colorIssues.map((e) => e.file).toSet().length}',
    );
    buffer.writeln(
      '• Файлів з текстами: ${textIssues.map((e) => e.file).toSet().length}',
    );

    if (problematicFiles.isNotEmpty) {
      buffer.writeln('\n⚠️ Проблемні файли:');
      for (final file in problematicFiles) {
        buffer.writeln('   • $file');
      }
    }
  }

  void _generateRecommendations(StringBuffer buffer) {
    buffer.writeln('\n💡 РЕКОМЕНДАЦІЇ:');
    buffer.writeln('-' * 30);

    if (colorIssues.isNotEmpty) {
      buffer.writeln('\n🎨 Для кольорів:');
      buffer.writeln('   1. Запустіть скрипт міграції кольорів');
      buffer.writeln(
        '   2. Замініть Colors.* на Theme.of(context).colorScheme.*',
      );
      buffer.writeln('   3. Створіть власну тему в theme/app_theme.dart');
    }

    if (textIssues.isNotEmpty) {
      buffer.writeln('\n📝 Для інтернаціоналізації:');
      buffer.writeln('   1. Додайте flutter_localizations до pubspec.yaml');
      buffer.writeln('   2. Створіть файли l10n/app_en.arb та l10n/app_uk.arb');
      buffer.writeln(
        '   3. Замініть hardcoded тексти на AppLocalizations.of(context).key',
      );
      buffer.writeln('   4. Налаштуйте l10n.yaml для генерації');
    }

    buffer.writeln('\n🚀 Наступні кроки:');
    buffer.writeln('   • dart scripts/migrate_colors.dart --dry-run');
    buffer.writeln('   • flutter pub add flutter_localizations');
    buffer.writeln('   • flutter gen-l10n');
  }
}

class ColorIssue {
  final String file;
  final int lineNumber;
  final String line;
  final String match;
  final String type;
  final List<String> context;

  ColorIssue({
    required this.file,
    required this.lineNumber,
    required this.line,
    required this.match,
    required this.type,
    required this.context,
  });
}

class TextIssue {
  final String file;
  final int lineNumber;
  final String line;
  final String match;
  final String type;
  final List<String> context;
  final String extractedText;

  TextIssue({
    required this.file,
    required this.lineNumber,
    required this.line,
    required this.match,
    required this.type,
    required this.context,
    required this.extractedText,
  });
}

class ColorPattern {
  final String pattern;
  final String description;

  ColorPattern(this.pattern, this.description);
}

class TextPattern {
  final String pattern;
  final String description;

  TextPattern(this.pattern, this.description);
}

Future<void> saveReportToFile(String report) async {
  final timestamp = DateTime.now()
      .toIso8601String()
      .substring(0, 19)
      .replaceAll(':', '-');
  final fileName = 'analysis_report_$timestamp.txt';
  final file = File(fileName);

  await file.writeAsString(report);
  print('📋 Звіт збережено у файл: $fileName');
}
