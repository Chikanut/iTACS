#!/usr/bin/env dart

import 'dart:io';

/// Розумний скрипт міграції кольорів з контекстним аналізом
void main(List<String> args) async {
  print('🧠 РОЗУМНА МІГРАЦІЯ КОЛЬОРІВ...\n');
  
  final dryRun = args.contains('--dry-run');
  final fixExisting = args.contains('--fix-existing');
  
  if (dryRun) {
    print('🔍 РЕЖИМ ПОПЕРЕДНЬОГО ПЕРЕГЛЯДУ');
  }
  
  if (fixExisting) {
    print('🔧 РЕЖИМ ВИПРАВЛЕННЯ ІСНУЮЧИХ ПОМИЛОК');
  }

  final libDir = Directory('lib');
  if (!libDir.existsSync()) {
    print('❌ Папка lib не знайдена.');
    return;
  }

  final migrator = SmartColorMigrator();
  await migrator.processDirectory(libDir, dryRun, fixExisting);
  migrator.printReport();
}

class SmartColorMigrator {
  int totalReplacements = 0;
  int filesProcessed = 0;
  final List<String> modifiedFiles = [];
  final Map<String, int> replacementTypes = {};
  final List<String> manualFixesNeeded = [];

  Future<void> processDirectory(Directory dir, bool dryRun, bool fixExisting) async {
    await for (final entity in dir.list(recursive: true)) {
      if (entity is File && entity.path.endsWith('.dart')) {
        if (_shouldSkipFile(entity.path)) continue;
        
        try {
          await _processFile(entity, dryRun, fixExisting);
          filesProcessed++;
        } catch (e) {
          print('❌ Помилка в ${entity.path}: $e');
        }
      }
    }
  }
  
  bool _shouldSkipFile(String path) {
    final skipPatterns = [
      '.g.dart',
      '.freezed.dart',
      'firebase_options.dart',
      '/generated/',
      'app_theme.dart', // Не чіпаємо файл теми
    ];
    
    return skipPatterns.any((pattern) => path.contains(pattern));
  }

  Future<void> _processFile(File file, bool dryRun, bool fixExisting) async {
    String content = await file.readAsString();
    final originalContent = content;
    int fileReplacements = 0;
    
    // Аналізуємо контекст файлу
    final fileContext = _analyzeFileContext(content, file.path);
    
    if (fixExisting) {
      // Режим виправлення існуючих помилок після автоматичної міграції
      content = _fixExistingIssues(content, fileContext);
    } else {
      // Режим первинної міграції
      content = _performSmartMigration(content, fileContext);
    }
    
    // Підраховуємо зміни
    if (content != originalContent) {
      final changeCount = _countChanges(originalContent, content);
      fileReplacements = changeCount;
      totalReplacements += changeCount;
      
      if (!dryRun) {
        await file.writeAsString(content);
        modifiedFiles.add(file.path);
        print('📝 ${file.path}: $fileReplacements змін');
      } else {
        print('🔍 ${file.path}: $fileReplacements потенційних змін');
      }
    }
  }
  
  FileContext _analyzeFileContext(String content, String filePath) {
    return FileContext(
      hasContext: content.contains('BuildContext') || content.contains('Widget'),
      hasThemeImport: content.contains("import 'package:flutter/material.dart'"),
      isServiceFile: filePath.contains('/services/'),
      isUtilFile: filePath.contains('/utils/') || filePath.contains('_utils.dart'),
      isModelFile: filePath.contains('/models/') || filePath.contains('_model.dart'),
      isWidgetFile: filePath.contains('/widgets/') || filePath.contains('/pages/'),
      hasStaticMethods: RegExp(r'static\s+\w+').hasMatch(content),
      hasConstConstructors: content.contains('const '),
      filePath: filePath,
    );
  }
  
  String _performSmartMigration(String content, FileContext context) {
    // 1. Спочатку виправляемо shade властивості
    content = _fixShadeProperties(content);
    
    // 2. Обробляємо різні типи кольорів залежно від контексту
    if (context.isServiceFile || context.hasStaticMethods) {
      content = _migrateWithStaticColors(content, context);
    } else if (context.isWidgetFile && context.hasContext) {
      content = _migrateWithThemeColors(content, context);
    } else {
      content = _migrateWithMixedApproach(content, context);
    }
    
    // 3. Додаємо необхідні імпорти
    if (!context.hasThemeImport && content.contains('Theme.of(context)')) {
      content = _addMaterialImport(content);
    }
    
    return content;
  }
  
  String _fixExistingIssues(String content, FileContext context) {
    int fixes = 0;
    
    // 1. Виправляємо const + Theme.of(context)
    final constThemeRegex = RegExp(r'const\s+(\w+)\((.*?)Theme\.of\(context\)(.*?)\)');
    content = content.replaceAllMapped(constThemeRegex, (match) {
      fixes++;
      replacementTypes['Прибрано const'] = (replacementTypes['Прибрано const'] ?? 0) + 1;
      return '${match.group(1)}(${match.group(2)}Theme.of(context)${match.group(3)})';
    });
    
    // 2. Виправляємо ГОЛОВНУ ПРОБЛЕМУ: Theme.of(context).colorScheme.*.shade*
    content = content.replaceAllMapped(
      RegExp(r'Theme\.of\(context\)\.colorScheme\.(primary|secondary|tertiary|error)\.shade(\d+)'),
      (match) {
        final colorType = match.group(1)!;
        final shade = match.group(2)!;
        
        final mapping = {
          'primary': 'context.primaryBlue',
          'secondary': 'context.warningOrange', 
          'tertiary': 'context.secondaryGreen',
          'error': 'context.dangerRed',
        };
        
        fixes++;
        replacementTypes['ColorScheme.shade → MaterialColor.shade'] = 
            (replacementTypes['ColorScheme.shade → MaterialColor.shade'] ?? 0) + 1;
        return '${mapping[colorType]}.shade$shade';
      }
    );
    
    // 3. Виправляємо старі shade властивості для не-MaterialColor
    content = _fixShadeProperties(content);
    
    // 4. Виправляємо Theme.of(context) в service файлах
    if (context.isServiceFile) {
      content = content.replaceAllMapped(RegExp(r'Theme\.of\(context\)\.colorScheme\.(\w+)'), (match) {
        final colorProperty = match.group(1);
        final staticColor = _getStaticColorForProperty(colorProperty!);
        fixes++;
        replacementTypes['Service → статичний колір'] = (replacementTypes['Service → статичний колір'] ?? 0) + 1;
        return staticColor;
      });
    }
    
    // 5. Виправляємо невизначений context
    if (content.contains('Theme.of(context)') && !context.hasContext) {
      manualFixesNeeded.add('${context.filePath}: Потрібен context або статичні кольори');
    }
    
    return content;
  }
  
  String _fixShadeProperties(String content) {
    // Тепер ми підтримуємо справжні shade в AppTheme!
    
    // 1. Заміна Theme.of(context).colorScheme.error.shade700 → context.dangerRed.shade700
    content = content.replaceAllMapped(
      RegExp(r'Theme\.of\(context\)\.colorScheme\.error\.shade(\d+)'),
      (match) {
        final shade = match.group(1);
        replacementTypes['Error shade → dangerRed'] = (replacementTypes['Error shade → dangerRed'] ?? 0) + 1;
        return 'context.dangerRed.shade$shade';
      }
    );
    
    // 2. Заміна Theme.of(context).colorScheme.primary.shade700 → context.primaryBlue.shade700
    content = content.replaceAllMapped(
      RegExp(r'Theme\.of\(context\)\.colorScheme\.primary\.shade(\d+)'),
      (match) {
        final shade = match.group(1);
        replacementTypes['Primary shade → primaryBlue'] = (replacementTypes['Primary shade → primaryBlue'] ?? 0) + 1;
        return 'context.primaryBlue.shade$shade';
      }
    );
    
    // 3. Заміна Theme.of(context).colorScheme.secondary.shade700 → context.warningOrange.shade700
    content = content.replaceAllMapped(
      RegExp(r'Theme\.of\(context\)\.colorScheme\.secondary\.shade(\d+)'),
      (match) {
        final shade = match.group(1);
        replacementTypes['Secondary shade → warningOrange'] = (replacementTypes['Secondary shade → warningOrange'] ?? 0) + 1;
        return 'context.warningOrange.shade$shade';
      }
    );
    
    // 4. Заміна для статичних кольорів в service файлах
    content = content.replaceAllMapped(
      RegExp(r'AppTheme\.(primaryBlue|secondaryGreen|warningOrange|dangerRed|greyScale)\.shade(\d+)'),
      (match) {
        final colorName = match.group(1);
        final shade = match.group(2);
        // Залишаємо як є - тепер у нас справжні MaterialColor!
        return 'AppTheme.$colorName.shade$shade';
      }
    );
    
    // 5. Старі shade що треба конвертувати в opacity (для зворотної сумісності)
    final legacyShadeToOpacity = {
      'shade50': '0.05',
      'shade100': '0.1', 
      'shade200': '0.2',
      'shade300': '0.3',
      'shade400': '0.4',
      'shade500': '0.5',
      'shade600': '0.6',
      'shade700': '0.7',
      'shade800': '0.8',
      'shade900': '0.9',
    };
    
    // Тільки для кольорів, які не є MaterialColor
    legacyShadeToOpacity.forEach((shade, opacity) {
      // Для Theme.of(context).colorScheme.onSurface.shade700 → withOpacity
      final pattern = RegExp(r'(Theme\.of\(context\)\.colorScheme\.(?:onSurface|onSurfaceVariant|outline))\.$shade');
      content = content.replaceAllMapped(pattern, (match) {
        replacementTypes['Legacy shade → opacity'] = (replacementTypes['Legacy shade → opacity'] ?? 0) + 1;
        return '${match.group(1)}.withOpacity($opacity)';
      });
    });
    
    return content;
  }
  
  String _migrateWithStaticColors(String content, FileContext context) {
    final colorMappings = [
      ['Colors\\.white(?!\\w)', 'AppTheme.textPrimary'],
      ['Colors\\.black(?!\\w)', 'AppTheme.backgroundDark'],
      ['Colors\\.red(?!\\w)', 'AppTheme.dangerRed.shade600'],
      ['Colors\\.red\\.shade(\\d+)', 'AppTheme.dangerRed.shade\$1'],
      ['Colors\\.green(?!\\w)', 'AppTheme.secondaryGreen.shade600'],
      ['Colors\\.green\\.shade(\\d+)', 'AppTheme.secondaryGreen.shade\$1'],
      ['Colors\\.blue(?!\\w)', 'AppTheme.primaryBlue.shade600'],
      ['Colors\\.blue\\.shade(\\d+)', 'AppTheme.primaryBlue.shade\$1'],
      ['Colors\\.orange(?!\\w)', 'AppTheme.warningOrange.shade600'],
      ['Colors\\.orange\\.shade(\\d+)', 'AppTheme.warningOrange.shade\$1'],
      ['Colors\\.amber\\[700\\]', 'AppTheme.warningOrange.shade700'],
      ['Colors\\.blue\\[700\\]', 'AppTheme.primaryBlue.shade700'],
      ['Colors\\.grey\\[600\\]', 'AppTheme.greyScale.shade600'],
      ['Colors\\.grey\\[500\\]', 'AppTheme.greyScale.shade500'],
      ['Colors\\.grey\\.shade(\\d+)', 'AppTheme.greyScale.shade\$1'],
      ['Colors\\.grey\\.withOpacity\\(0\\.1\\)', 'AppTheme.cardDark'],
    ];
    
    for (final mapping in colorMappings) {
      final regex = RegExp(mapping[0]);
      if (regex.hasMatch(content)) {
        content = content.replaceAll(regex, mapping[1]);
        replacementTypes['Static colors with shade'] = (replacementTypes['Static colors with shade'] ?? 0) + 1;
      }
    }
    
    // Додаємо імпорт AppTheme якщо потрібно
    if (content.contains('AppTheme.') && !content.contains('app_theme.dart')) {
      content = _addAppThemeImport(content);
    }
    
    return content;
  }
  
  String _migrateWithThemeColors(String content, FileContext context) {
    final colorMappings = [
      ['Colors\\.white(?!\\w)', 'Theme.of(context).colorScheme.onSurface'],
      ['Colors\\.black(?!\\w)', 'Theme.of(context).colorScheme.surface'],
      ['Colors\\.red(?!\\w)', 'context.dangerRed.shade600'],
      ['Colors\\.red\\.shade(\\d+)', 'context.dangerRed.shade\$1'],
      ['Colors\\.green(?!\\w)', 'context.secondaryGreen.shade600'],
      ['Colors\\.green\\.shade(\\d+)', 'context.secondaryGreen.shade\$1'],
      ['Colors\\.blue(?!\\w)', 'context.primaryBlue.shade600'],
      ['Colors\\.blue\\.shade(\\d+)', 'context.primaryBlue.shade\$1'],
      ['Colors\\.orange(?!\\w)', 'context.warningOrange.shade600'],
      ['Colors\\.orange\\.shade(\\d+)', 'context.warningOrange.shade\$1'],
      ['Colors\\.amber\\[700\\]', 'context.warningOrange.shade700'],
      ['Colors\\.blue\\[700\\]', 'context.primaryBlue.shade700'],
      ['Colors\\.grey\\[600\\]', 'context.greyScale.shade600'],
      ['Colors\\.grey\\[500\\]', 'context.greyScale.shade500'],
      ['Colors\\.grey\\.shade(\\d+)', 'context.greyScale.shade\$1'],
      ['Colors\\.grey\\.withOpacity\\(0\\.1\\)', 'Theme.of(context).colorScheme.surfaceContainer'],
    ];
    
    // Перевіряємо const контексти та не замінюємо там
    for (final mapping in colorMappings) {
      final regex = RegExp(mapping[0]);
      content = content.replaceAllMapped(regex, (match) {
        final matchStart = match.start;
        final beforeMatch = content.substring(0, matchStart);
        
        // Перевіряємо чи це в const контексті
        final constMatch = RegExp(r'const\s+\w+\([^)]*$').hasMatch(beforeMatch.split('\n').last);
        
        if (constMatch) {
          // Залишаємо як є і додаємо до списку ручних виправлень
          manualFixesNeeded.add('${context.filePath}:${_getLineNumber(content, matchStart)} - const конфлікт');
          return match.group(0)!;
        }
        
        replacementTypes['Theme colors with shade'] = (replacementTypes['Theme colors with shade'] ?? 0) + 1;
        return mapping[1];
      });
    }
    
    return content;
  }
  
  String _migrateWithMixedApproach(String content, FileContext context) {
    // Для файлів де не ясно - використовуємо консервативний підхід
    if (context.hasContext) {
      return _migrateWithThemeColors(content, context);
    } else {
      return _migrateWithStaticColors(content, context);
    }
  }
  
  String _getStaticColorForProperty(String property) {
    final mapping = {
      'primary': 'AppTheme.primaryBlue.shade700',
      'secondary': 'AppTheme.warningOrange.shade600',
      'tertiary': 'AppTheme.secondaryGreen.shade600',
      'error': 'AppTheme.dangerRed.shade600',
      'onSurface': 'AppTheme.textPrimary',
      'onSurfaceVariant': 'AppTheme.textSecondary',
      'surface': 'AppTheme.backgroundDark',
      'surfaceContainer': 'AppTheme.cardDark',
      'outline': 'AppTheme.greyScale.shade600',
    };
    
    return mapping[property] ?? 'AppTheme.primaryBlue.shade600';
  }
  
  String _addMaterialImport(String content) {
    if (content.contains("import 'package:flutter/material.dart'")) {
      return content;
    }
    
    final lines = content.split('\n');
    final importIndex = lines.indexWhere((line) => line.startsWith('import '));
    
    if (importIndex != -1) {
      lines.insert(importIndex, "import 'package:flutter/material.dart';");
    }
    
    return lines.join('\n');
  }
  
  String _addAppThemeImport(String content) {
    if (content.contains('app_theme.dart')) {
      return content;
    }
    
    final lines = content.split('\n');
    final importIndex = lines.indexWhere((line) => line.startsWith('import '));
    
    if (importIndex != -1) {
      lines.insert(importIndex, "import '../theme/app_theme.dart';");
    }
    
    return lines.join('\n');
  }
  
  int _getLineNumber(String content, int position) {
    return content.substring(0, position).split('\n').length;
  }
  
  int _countChanges(String original, String modified) {
    final originalLines = original.split('\n');
    final modifiedLines = modified.split('\n');
    int changes = 0;
    
    for (int i = 0; i < originalLines.length && i < modifiedLines.length; i++) {
      if (originalLines[i] != modifiedLines[i]) {
        changes++;
      }
    }
    
    return changes;
  }
  
  void printReport() {
    print('\n🧠 ЗВІТ РОЗУМНОЇ МІГРАЦІЇ:');
    print('=' * 50);
    print('• Оброблено файлів: $filesProcessed');
    print('• Загальна кількість змін: $totalReplacements');
    print('• Змінених файлів: ${modifiedFiles.length}');
    
    if (replacementTypes.isNotEmpty) {
      print('\n📊 Типи замін:');
      replacementTypes.forEach((type, count) {
        print('   • $type: $count');
      });
    }
    
    if (manualFixesNeeded.isNotEmpty) {
      print('\n⚠️  ПОТРІБНІ РУЧНІ ВИПРАВЛЕННЯ:');
      for (final fix in manualFixesNeeded.take(10)) {
        print('   • $fix');
      }
      if (manualFixesNeeded.length > 10) {
        print('   ... і ще ${manualFixesNeeded.length - 10} випадків');
      }
    }
    
    if (modifiedFiles.isNotEmpty) {
      print('\n📁 Змінені файли:');
      for (final file in modifiedFiles.take(10)) {
        print('   • $file');
      }
      if (modifiedFiles.length > 10) {
        print('   ... і ще ${modifiedFiles.length - 10} файлів');
      }
    }
    
    print('\n💡 РЕКОМЕНДАЦІЇ:');
    print('   1. flutter analyze - перевір помилки');
    print('   2. Якщо є помилки: dart scripts/smart_migrate_colors.dart --fix-existing');
    print('   3. flutter run - протестуй додаток');
    print('   4. Виправ ручні випадки зі списку вище');
  }
}

class FileContext {
  final bool hasContext;
  final bool hasThemeImport;
  final bool isServiceFile;
  final bool isUtilFile;
  final bool isModelFile;
  final bool isWidgetFile;
  final bool hasStaticMethods;
  final bool hasConstConstructors;
  final String filePath;
  
  FileContext({
    required this.hasContext,
    required this.hasThemeImport,
    required this.isServiceFile,
    required this.isUtilFile,
    required this.isModelFile,
    required this.isWidgetFile,
    required this.hasStaticMethods,
    required this.hasConstConstructors,
    required this.filePath,
  });
}