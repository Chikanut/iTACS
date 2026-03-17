#!/usr/bin/env dart

import 'dart:io';
import 'dart:convert';

/// Скрипт для автоматичної генерації файлів локалізації
void main(List<String> args) async {
  print('🌍 Генерація файлів локалізації...\n');

  final extractFromAnalysis = args.contains('--from-analysis');

  // Створюємо структуру папок
  await createL10nStructure();

  if (extractFromAnalysis) {
    print('📝 Витягуємо тексти з аналізу...');
    await extractTextsFromCode();
  } else {
    print('📝 Створюємо базові файли локалізації...');
    await createBaseL10nFiles();
  }

  await createL10nConfig();

  print('✅ Файли локалізації створені!');
  print('🔄 Наступні кроки:');
  print('   1. flutter pub get');
  print('   2. flutter gen-l10n');
  print('   3. Додайте import до main.dart');
}

Future<void> createL10nStructure() async {
  final l10nDir = Directory('lib/l10n');
  await l10nDir.create(recursive: true);
  print('📁 Створено папку: ${l10nDir.path}');
}

Future<void> createL10nConfig() async {
  final configContent = '''# l10n.yaml
arb-dir: lib/l10n
template-arb-file: app_en.arb
output-localization-file: app_localizations.dart
output-class: AppLocalizations
output-dir: lib/generated/l10n
nullable-getter: false
''';

  final configFile = File('l10n.yaml');
  await configFile.writeAsString(configContent);
  print('⚙️ Створено l10n.yaml');
}

Future<void> createBaseL10nFiles() async {
  // Базові переклади для військового додатку
  final baseTranslations = {
    // Загальні
    'appTitle': 'GSPP Training App',
    'loading': 'Завантаження...',
    'error': 'Помилка',
    'success': 'Успішно',
    'cancel': 'Скасувати',
    'save': 'Зберегти',
    'delete': 'Видалити',
    'edit': 'Редагувати',
    'add': 'Додати',
    'search': 'Пошук',
    'refresh': 'Оновити',

    // Навігація
    'home': 'Головна',
    'calendar': 'Календар',
    'materials': 'Матеріали',
    'tools': 'Інструменти',
    'profile': 'Профіль',
    'adminPanel': 'Адмін-панель',

    // Календар
    'schedule': 'Розклад',
    'lesson': 'Заняття',
    'lessons': 'Заняття',
    'today': 'Сьогодні',
    'tomorrow': 'Завтра',
    'thisWeek': 'Цей тиждень',
    'nextWeek': 'Наступний тиждень',
    'noLessonsToday': 'На сьогодні занять немає',
    'lessonCompleted': 'Заняття проведене',
    'lessonPending': 'Очікує проведення',
    'lessonIncomplete': 'Незавершене',

    // Матеріали
    'methodology': 'Методичка',
    'methodologies': 'Методички',
    'template': 'Шаблон',
    'templates': 'Шаблони',
    'document': 'Документ',
    'documents': 'Документи',
    'downloadedMaterials': 'Завантажені матеріали',

    // Інструменти
    'tool': 'Інструмент',
    'folder': 'Папка',
    'file': 'Файл',
    'openTool': 'Відкрити інструмент',
    'addTool': 'Додати інструмент',
    'addFolder': 'Додати папку',
    'toolsNotFound': 'Інструменти відсутні',
    'addFirstTool': 'Додайте перший інструмент або папку',

    // Профіль
    'personalInfo': 'Особисті дані',
    'militaryRank': 'Військове звання',
    'position': 'Посада',
    'unit': 'Підрозділ',
    'phone': 'Телефон',
    'email': 'Електронна пошта',
    'signOut': 'Вийти',

    // Повідомлення
    'accessDenied': 'Доступ заборонений',
    'notAuthorized': 'Ви не авторизовані для доступу до цієї системи',
    'checkEmailWhitelist':
        'Перевірте, чи ваша електронна адреса додана до білого списку',
    'contactAdministrator': 'Зверніться до адміністратора',

    // Помилки
    'networkError': 'Помилка мережі',
    'noInternetConnection': 'Відсутнє з\'єднання з Інтернетом',
    'serverError': 'Помилка сервера',
    'unknownError': 'Невідома помилка',
    'tryAgain': 'Спробуйте ще раз',

    // Статуси
    'draft': 'Чернетка',
    'inProgress': 'В процесі',
    'completed': 'Завершено',
    'archived': 'Архів',
    'active': 'Активний',
    'inactive': 'Неактивний',
  };

  // Англійські переклади
  final enTranslations = {
    'appTitle': 'GSPP Training App',
    'loading': 'Loading...',
    'error': 'Error',
    'success': 'Success',
    'cancel': 'Cancel',
    'save': 'Save',
    'delete': 'Delete',
    'edit': 'Edit',
    'add': 'Add',
    'search': 'Search',
    'refresh': 'Refresh',

    'home': 'Home',
    'calendar': 'Calendar',
    'materials': 'Materials',
    'tools': 'Tools',
    'profile': 'Profile',
    'adminPanel': 'Admin Panel',

    'schedule': 'Schedule',
    'lesson': 'Lesson',
    'lessons': 'Lessons',
    'today': 'Today',
    'tomorrow': 'Tomorrow',
    'thisWeek': 'This Week',
    'nextWeek': 'Next Week',
    'noLessonsToday': 'No lessons today',
    'lessonCompleted': 'Lesson completed',
    'lessonPending': 'Pending',
    'lessonIncomplete': 'Incomplete',

    'methodology': 'Methodology',
    'methodologies': 'Methodologies',
    'template': 'Template',
    'templates': 'Templates',
    'document': 'Document',
    'documents': 'Documents',
    'downloadedMaterials': 'Downloaded Materials',

    'tool': 'Tool',
    'folder': 'Folder',
    'file': 'File',
    'openTool': 'Open Tool',
    'addTool': 'Add Tool',
    'addFolder': 'Add Folder',
    'toolsNotFound': 'No tools found',
    'addFirstTool': 'Add your first tool or folder',

    'personalInfo': 'Personal Information',
    'militaryRank': 'Military Rank',
    'position': 'Position',
    'unit': 'Unit',
    'phone': 'Phone',
    'email': 'Email',
    'signOut': 'Sign Out',

    'accessDenied': 'Access Denied',
    'notAuthorized': 'You are not authorized to access this system',
    'checkEmailWhitelist':
        'Please check if your email is added to the whitelist',
    'contactAdministrator': 'Contact the administrator',

    'networkError': 'Network Error',
    'noInternetConnection': 'No Internet Connection',
    'serverError': 'Server Error',
    'unknownError': 'Unknown Error',
    'tryAgain': 'Try Again',

    'draft': 'Draft',
    'inProgress': 'In Progress',
    'completed': 'Completed',
    'archived': 'Archived',
    'active': 'Active',
    'inactive': 'Inactive',
  };

  // Створюємо ARB файли
  await createArbFile('lib/l10n/app_uk.arb', baseTranslations, 'uk');
  await createArbFile('lib/l10n/app_en.arb', enTranslations, 'en');

  print('📝 Створено базові файли перекладів');
}

Future<void> createArbFile(
  String path,
  Map<String, String> translations,
  String locale,
) async {
  final arbData = <String, dynamic>{'@@locale': locale};

  translations.forEach((key, value) {
    arbData[key] = value;
  });

  final file = File(path);
  await file.writeAsString(const JsonEncoder.withIndent('  ').convert(arbData));

  print('📄 Створено: $path (${translations.length} перекладів)');
}

Future<void> extractTextsFromCode() async {
  print('🔍 Сканування коду для витягування текстів...');

  final libDir = Directory('lib');
  final extractedTexts = <String>{};

  await for (final entity in libDir.list(recursive: true)) {
    if (entity is File && entity.path.endsWith('.dart')) {
      final content = await entity.readAsString();

      // Витягуємо українські тексти
      final ukrainianRegex = RegExp(r'''['"][А-Яа-яІіЇїЄєҐґ][^'"]*['"]''');
      final matches = ukrainianRegex.allMatches(content);

      for (final match in matches) {
        final text = match.group(0)?.replaceAll(RegExp(r'''['"]'''), '') ?? '';
        if (text.length > 2 && !text.contains('http')) {
          extractedTexts.add(text);
        }
      }
    }
  }

  print('📊 Знайдено ${extractedTexts.length} унікальних текстів');

  // Генеруємо ключі та файли
  final translations = <String, String>{};
  for (final text in extractedTexts) {
    final key = generateKeyFromText(text);
    translations[key] = text;
  }

  await createArbFile('lib/l10n/app_uk.arb', translations, 'uk');

  // Створюємо порожній англійський файл для заповнення
  final englishTranslations = <String, String>{};
  translations.forEach((key, value) {
    englishTranslations[key] = 'TODO: Translate "$value"';
  });

  await createArbFile('lib/l10n/app_en.arb', englishTranslations, 'en');
}

String generateKeyFromText(String text) {
  // Генеруємо ключ з тексту
  String key = text
      .toLowerCase()
      .replaceAll(RegExp(r'[^а-яіїєґa-z0-9\s]'), '')
      .trim()
      .replaceAll(RegExp(r'\s+'), '_');

  // Обмежуємо довжину ключа
  if (key.length > 30) {
    final words = key.split('_');
    key = words.take(3).join('_');
  }

  // Якщо ключ порожній, генеруємо випадковий
  if (key.isEmpty) {
    key = 'text_${DateTime.now().millisecondsSinceEpoch % 10000}';
  }

  return key;
}
