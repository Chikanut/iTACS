#!/usr/bin/env dart

import 'dart:io';

/// Розширений скрипт міграції з backup та smart detection
void main(List<String> args) async {
  print('🎨 Розумна міграція кольорів...\n');
  
  // Перевіряємо аргументи
  final dryRun = args.contains('--dry-run');
  final backup = args.contains('--backup') || !args.contains('--no-backup');
  
  if (dryRun) {
    print('🔍 РЕЖИМ ПОПЕРЕДНЬОГО ПЕРЕГЛЯДУ (без змін)');
  }
  
  final libDir = Directory('lib');
  if (!libDir.existsSync()) {
    print('❌ Папка lib не знайдена.');
    return;
  }

  // Створюємо backup якщо потрібно
  if (backup && !dryRun) {
    await createBackup();
  }

  final analyzer = ColorAnalyzer();
  await analyzer.analyzeDirectory(libDir, dryRun);
  analyzer.printReport();
  
  if (dryRun) {
    print('\n🔄 Для виконання замін запустіть: dart scripts/advanced_migrate_colors.dart');
  } else {
    print('\n✅ Міграція завершена!');
    print('🔍 Перевір результат: flutter analyze && flutter run');
  }
}

class ColorAnalyzer {
  int filesProcessed = 0;
  int totalReplacements = 0;
  Map<String, int> replacementStats = {};
  List<String> problematicFiles = [];
  
  // Розумні заміни з контекстом
  final smartReplacements = <SmartReplacement>[
    // Основні кольори
    SmartReplacement(
      pattern: r'Colors\.white(?!\w)',
      replacement: 'Theme.of(context).colorScheme.onSurface',
      context: 'text',
      description: 'Білий текст → onSurface',
    ),
    
    SmartReplacement(
      pattern: r'Colors\.white(?=.*foregroundColor)',
      replacement: 'Theme.of(context).colorScheme.onPrimary',
      context: 'button',
      description: 'Білий на кнопці → onPrimary',
    ),
    
    // Папки та файли
    SmartReplacement(
      pattern: r'Colors\.amber\[700\](?=.*folder|.*папк)',
      replacement: 'Theme.of(context).colorScheme.secondary',
      context: 'folder',
      description: 'Папки → secondary',
    ),
    
    SmartReplacement(
      pattern: r'Colors\.blue\[700\](?=.*file|.*файл)',
      replacement: 'Theme.of(context).colorScheme.primary',
      context: 'file',
      description: 'Файли → primary',
    ),
    
    // Фони та поверхні
    SmartReplacement(
      pattern: r'Colors\.grey\.withOpacity\(0\.1\)(?=.*background|.*decoration)',
      replacement: 'Theme.of(context).colorScheme.surfaceContainer',
      context: 'background',
      description: 'Сірий фон → surfaceContainer',
    ),
    
    // Тексти
    SmartReplacement(
      pattern: r'Colors\.grey\[600\](?=.*style|.*color)',
      replacement: 'Theme.of(context).colorScheme.onSurfaceVariant',
      context: 'text',
      description: 'Сірий текст → onSurfaceVariant',
    ),
    
    // Помилки
    SmartReplacement(
      pattern: r'Colors\.red(?=.*error|.*danger|.*помилк)',
      replacement: 'Theme.of(context).colorScheme.error',
      context: 'error',
      description: 'Червоний → error',
    ),
  ];
  
  Future<void> analyzeDirectory(Directory dir, bool dryRun) async {
    await for (final entity in dir.list(recursive: true)) {
      if (entity is File && entity.path.endsWith('.dart')) {
        if (shouldSkipFile(entity.path)) continue;
        
        try {
          await processFile(entity, dryRun);
          filesProcessed++;
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
    ];
    
    return skipPatterns.any((pattern) => path.contains(pattern));
  }
  
  Future<void> processFile(File file, bool dryRun) async {
    String content = await file.readAsString();
    final originalContent = content;
    final fileReplacements = <String, int>{};
    
    // Перевіряємо чи є BuildContext в файлі
    final hasContext = content.contains('BuildContext') || 
                      content.contains('Theme.of(context)');
    
    if (!hasContext && content.contains('Colors.')) {
      // Файл використовує кольори але немає контексту
      if (!dryRun) {
        await addMaterialImport(file, content);
      }
    }
    
    // Виконуємо розумні заміни
    for (final replacement in smartReplacements) {
      final regex = RegExp(replacement.pattern, multiLine: true, dotAll: true);
      final matches = regex.allMatches(content);
      
      if (matches.isNotEmpty) {
        content = content.replaceAll(regex, replacement.replacement);
        fileReplacements[replacement.description] = matches.length;
        totalReplacements += matches.length;
      }
    }
    
    // Додаємо до статистики
    fileReplacements.forEach((desc, count) {
      replacementStats[desc] = (replacementStats[desc] ?? 0) + count;
    });
    
    // Записуємо файл
    if (!dryRun && content != originalContent) {
      await file.writeAsString(content);
      print('📝 ${file.path}: ${fileReplacements.values.fold(0, (a, b) => a + b)} замін');
    } else if (dryRun && content != originalContent) {
      print('🔍 ${file.path}: ${fileReplacements.values.fold(0, (a, b) => a + b)} потенційних замін');
    }
  }
  
  Future<void> addMaterialImport(File file, String content) async {
    if (!content.contains("import 'package:flutter/material.dart'")) {
      final lines = content.split('\n');
      final importIndex = lines.indexWhere((line) => line.startsWith('import '));
      
      if (importIndex != -1) {
        lines.insert(importIndex, "import 'package:flutter/material.dart';");
        await file.writeAsString(lines.join('\n'));
      }
    }
  }
  
  void printReport() {
    print('\n📊 ЗВІТ МІГРАЦІЇ:');
    print('   • Файлів оброблено: $filesProcessed');
    print('   • Загальна кількість замін: $totalReplacements');
    
    if (replacementStats.isNotEmpty) {
      print('\n🔄 Деталі замін:');
      replacementStats.forEach((desc, count) {
        print('   • $desc: $count');
      });
    }
    
    if (problematicFiles.isNotEmpty) {
      print('\n⚠️  Проблемні файли:');
      for (final issue in problematicFiles) {
        print('   • $issue');
      }
    }
  }
}

class SmartReplacement {
  final String pattern;
  final String replacement;
  final String context;
  final String description;
  
  SmartReplacement({
    required this.pattern,
    required this.replacement,
    required this.context,
    required this.description,
  });
}

Future<void> createBackup() async {
  final timestamp = DateTime.now().millisecondsSinceEpoch;
  final backupDir = Directory('backup_$timestamp');
  
  print('💾 Створюю backup...');
  
  await backupDir.create();
  await copyDirectory(Directory('lib'), Directory('${backupDir.path}/lib'));
  
  print('✅ Backup створено: ${backupDir.path}');
}

Future<void> copyDirectory(Directory source, Directory destination) async {
  await destination.create(recursive: true);
  
  await for (final entity in source.list()) {
    final name = entity.path.split(Platform.pathSeparator).last;
    
    if (entity is Directory) {
      await copyDirectory(
        entity,
        Directory('${destination.path}${Platform.pathSeparator}$name')
      );
    } else if (entity is File) {
      await entity.copy('${destination.path}${Platform.pathSeparator}$name');
    }
  }
}