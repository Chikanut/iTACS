#!/usr/bin/env dart

import 'dart:io';
import 'dart:convert';

/// Скрипт для автоматичної заміни hardcoded текстів на AppLocalizations
void main(List<String> args) async {
  print('🌍 Міграція hardcoded текстів до локалізації...\n');
  
  final dryRun = args.contains('--dry-run');
  final generateArb = args.contains('--generate-arb');
  
  if (dryRun) {
    print('🔍 РЕЖИМ ПОПЕРЕДНЬОГО ПЕРЕГЛЯДУ (без змін)');
  }
  
  final migrator = TextMigrator();
  
  if (generateArb) {
    await migrator.generateArbFromExistingTexts();
  }
  
  final libDir = Directory('lib');
  if (!libDir.existsSync()) {
    print('❌ Папка lib не знайдена.');
    return;
  }

  await migrator.migrateDirectory(libDir, dryRun);
  migrator.printReport();
}

class TextMigrator {
  final Map<String, String> textToKeyMap = {};
  final List<TextReplacement> replacements = [];
  final List<String> modifiedFiles = [];
  int totalReplacements = 0;

  // Предвизначені переклади для поширених текстів
  final predefinedTranslations = {
    // Загальні UI елементи
    'Головна': 'home',
    'Календар': 'calendar',
    'Матеріали': 'materials',
    'Інструменти': 'tools',
    'Профіль': 'profile',
    'Адмін-панель': 'adminPanel',
    
    // Дії
    'Додати': 'add',
    'Видалити': 'delete',
    'Редагувати': 'edit',
    'Зберегти': 'save',
    'Скасувати': 'cancel',
    'Оновити': 'refresh',
    'Завантаження...': 'loading',
    'Пошук': 'search',
    
    // Заняття
    'Заняття': 'lessons',
    'Розклад': 'schedule',
    'Сьогодні': 'today',
    'Завтра': 'tomorrow',
    'Проведене': 'completed',
    'Очікує': 'pending',
    'Незавершене': 'incomplete',
    
    // Статуси
    'Помилка': 'error',
    'Успішно': 'success',
    'Попередження': 'warning',
    
    // Інструменти
    'папка': 'folder',
    'файл': 'file',
    'інструмент': 'tool',
    'Відкрити': 'open',
    
    // Типові повідомлення
    'Нічого не знайдено': 'nothingFound',
    'Спробуйте змінити пошуковий запит': 'tryDifferentQuery',
    'Додайте перший інструмент або папку': 'addFirstToolOrFolder',
  };

  Future<void> generateArbFromExistingTexts() async {
    print('📝 Генерую ARB файли з predefined перекладів...');
    
    final ukTranslations = <String, dynamic>{
      '@@locale': 'uk',
    };
    
    final enTranslations = <String, dynamic>{
      '@@locale': 'en',
    };
    
    // Англійські переклади для predefined текстів
    final englishTranslations = {
      'home': 'Home',
      'calendar': 'Calendar',
      'materials': 'Materials',
      'tools': 'Tools',
      'profile': 'Profile',
      'adminPanel': 'Admin Panel',
      'add': 'Add',
      'delete': 'Delete',
      'edit': 'Edit',
      'save': 'Save',
      'cancel': 'Cancel',
      'refresh': 'Refresh',
      'loading': 'Loading...',
      'search': 'Search',
      'lessons': 'Lessons',
      'schedule': 'Schedule',
      'today': 'Today',
      'tomorrow': 'Tomorrow',
      'completed': 'Completed',
      'pending': 'Pending',
      'incomplete': 'Incomplete',
      'error': 'Error',
      'success': 'Success',
      'warning': 'Warning',
      'folder': 'Folder',
      'file': 'File',
      'tool': 'Tool',
      'open': 'Open',
      'nothingFound': 'Nothing Found',
      'tryDifferentQuery': 'Try a different search query',
      'addFirstToolOrFolder': 'Add your first tool or folder',
    };
    
    predefinedTranslations.forEach((ukrainianText, key) {
      ukTranslations[key] = ukrainianText;
      enTranslations[key] = englishTranslations[key] ?? 'TODO: Translate "$ukrainianText"';
      textToKeyMap[ukrainianText] = key;
    });
    
    await _saveArbFile('lib/l10n/app_uk.arb', ukTranslations);
    await _saveArbFile('lib/l10n/app_en.arb', enTranslations);
    
    print('✅ ARB файли створені з ${predefinedTranslations.length} перекладами');
  }
  
  Future<void> _saveArbFile(String path, Map<String, dynamic> data) async {
    final dir = Directory('lib/l10n');
    await dir.create(recursive: true);
    
    final file = File(path);
    await file.writeAsString(
      const JsonEncoder.withIndent('  ').convert(data),
    );
  }

  Future<void> migrateDirectory(Directory dir, bool dryRun) async {
    await for (final entity in dir.list(recursive: true)) {
      if (entity is File && entity.path.endsWith('.dart')) {
        if (_shouldSkipFile(entity.path)) continue;
        
        try {
          await _processFile(entity, dryRun);
        } catch (e) {
          print('❌ Помилка обробки ${entity.path}: $e');
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
      'app_localizations',
      'l10n.dart',
    ];
    
    return skipPatterns.any((pattern) => path.contains(pattern));
  }
  
  Future<void> _processFile(File file, bool dryRun) async {
    String content = await file.readAsString();
    final originalContent = content;
    int fileReplacements = 0;
    
    // Паттерни для заміни українських текстів
    final patterns = [
      // Text('Український текст')
      RegExp("Text\(\s*['\"]([А-Яа-яІіЇїЄєҐґ][^'\"]*)['\"]"),
      // label: 'Український текст'
      RegExp("label:\s*['\"]([А-Яа-яІіЇїЄєҐґ][^'\"]*)['\"]"),
      // title: 'Український текст'
      RegExp("title:\s*['\"]([А-Яа-яІіЇїЄєҐґ][^'\"]*)['\"]"),
      // 'Український текст' в різних контекстах
      RegExp("['\"]([А-Яа-яІіЇїЄєҐґ][А-Яа-яІіЇїЄєҐґ\s\-\,\.\!\?]{2,})['\"]"),
    ];
    
    for (final pattern in patterns) {
      final matches = pattern.allMatches(content).toList();
      
      for (final match in matches.reversed) { // Обробляємо в зворотному порядку
        final fullMatch = match.group(0) ?? '';
        final ukrainianText = match.group(1) ?? '';
        
        // Пропускаємо технічні рядки
        if (_shouldSkipText(ukrainianText)) continue;
        
        final key = _getKeyForText(ukrainianText);
        if (key == null) continue;
        
        String replacement;
        if (fullMatch.startsWith('Text(')) {
          replacement = "Text(AppLocalizations.of(context).$key)";
        } else if (fullMatch.contains('label:')) {
          replacement = "label: AppLocalizations.of(context).$key";
        } else if (fullMatch.contains('title:')) {
          replacement = "title: AppLocalizations.of(context).$key";
        } else {
          replacement = "AppLocalizations.of(context).$key";
        }
        
        content = content.substring(0, match.start) + 
                 replacement + 
                 content.substring(match.end);
                 
        replacements.add(TextReplacement(
          file: file.path,
          originalText: ukrainianText,
          key: key,
          fullMatch: fullMatch,
          replacement: replacement,
        ));
        
        fileReplacements++;
      }
    }
    
    // Додаємо import якщо потрібно
    if (fileReplacements > 0 && !content.contains('AppLocalizations.of(context)')) {
      content = _addLocalizationImport(content);
    }
    
    // Записуємо файл
    if (!dryRun && content != originalContent) {
      await file.writeAsString(content);
      modifiedFiles.add(file.path);
      print('📝 ${file.path}: $fileReplacements замін');
    } else if (content != originalContent) {
      print('🔍 ${file.path}: $fileReplacements потенційних замін');
    }
    
    totalReplacements += fileReplacements;
  }
  
  bool _shouldSkipText(String text) {
    // Пропускаємо дуже короткі тексти
    if (text.length < 3) return true;
    
    // Пропускаємо технічні рядки
    final skipPatterns = [
      RegExp(r'^[0-9\s\-\+\(\)\.,:;!?]*$'), // Тільки цифри та знаки
      RegExp(r'^[A-Za-z_][A-Za-z0-9_]*$'), // Змінні
      RegExp(r'http[s]?://'), // URLs
      RegExp(r'@[A-Za-z0-9]'), // Email patterns
    ];
    
    return skipPatterns.any((pattern) => pattern.hasMatch(text));
  }
  
  String? _getKeyForText(String text) {
    // Спочатку шукаємо в predefined мапі
    if (textToKeyMap.containsKey(text)) {
      return textToKeyMap[text];
    }
    
    // Генеруємо ключ автоматично
    final key = _generateKeyFromText(text);
    textToKeyMap[text] = key;
    return key;
  }
  
  String _generateKeyFromText(String text) {
    String key = text
        .toLowerCase()
        .replaceAll(RegExp(r'[^а-яіїєґa-z0-9\s]'), '')
        .trim()
        .replaceAll(RegExp(r'\s+'), '_');
        
    // Обмежуємо довжину та берем перші слова
    final words = key.split('_');
    if (words.length > 3) {
      key = words.take(3).join('_');
    }
    
    if (key.length > 25) {
      key = key.substring(0, 25);
    }
    
    // Переконуємось що ключ унікальний
    String finalKey = key;
    int counter = 1;
    while (textToKeyMap.containsValue(finalKey)) {
      finalKey = '${key}_$counter';
      counter++;
    }
    
    return finalKey;
  }
  
  String _addLocalizationImport(String content) {
    if (content.contains('flutter_gen/gen_l10n/app_localizations.dart')) {
      return content;
    }
    
    final lines = content.split('\n');
    final importIndex = lines.indexWhere((line) => line.startsWith('import '));
    
    if (importIndex != -1) {
      lines.insert(importIndex, "import 'package:flutter_gen/gen_l10n/app_localizations.dart';");
    }
    
    return lines.join('\n');
  }
  
  void printReport() {
    print('\n📊 ЗВІТ МІГРАЦІЇ ТЕКСТІВ:');
    print('-' * 40);
    print('• Загальна кількість замін: $totalReplacements');
    print('• Змінених файлів: ${modifiedFiles.length}');
    print('• Унікальних текстів: ${textToKeyMap.length}');
    
    if (replacements.isNotEmpty) {
      print('\n🔤 Приклади замін:');
      for (final replacement in replacements.take(10)) {
        print('   "${replacement.originalText}" → ${replacement.key}');
      }
      
      if (replacements.length > 10) {
        print('   ... і ще ${replacements.length - 10} замін');
      }
    }
    
    if (modifiedFiles.isNotEmpty) {
      print('\n📁 Змінені файли:');
      for (final file in modifiedFiles.take(10)) {
        final fileReplacements = replacements.where((r) => r.file == file).length;
        print('   • $file ($fileReplacements замін)');
      }
      
      if (modifiedFiles.length > 10) {
        print('   ... і ще ${modifiedFiles.length - 10} файлів');
      }
    }
    
    print('\n💡 Наступні кроки:');
    print('   1. flutter gen-l10n');
    print('   2. Перевірте компіляцію: flutter analyze');
    print('   3. Додайте переклади в lib/l10n/app_en.arb');
    print('   4. flutter run для тестування');
  }
}

class TextReplacement {
  final String file;
  final String originalText;
  final String key;
  final String fullMatch;
  final String replacement;
  
  TextReplacement({
    required this.file,
    required this.originalText,
    required this.key,
    required this.fullMatch,
    required this.replacement,
  });
}