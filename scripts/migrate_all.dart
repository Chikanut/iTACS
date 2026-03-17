#!/usr/bin/env dart

import 'dart:io';

/// Майстер-скрипт для повної міграції проєкту
void main(List<String> args) async {
  print('🚀 ПОВНА МІГРАЦІЯ FLUTTER ПРОЄКТУ');
  print('=' * 50);

  final interactive = !args.contains('--auto');
  final skipAnalysis = args.contains('--skip-analysis');
  final skipColors = args.contains('--skip-colors');
  final skipTexts = args.contains('--skip-texts');

  // Перевіряємо git статус
  if (!await _checkGitStatus()) {
    print('❌ Зафіксуйте зміни в git перед міграцією');
    return;
  }

  try {
    if (!skipAnalysis) {
      await _runAnalysis();
      if (interactive && !_confirmContinue('Продовжити після аналізу?')) return;
    }

    if (!skipColors) {
      await _migrateColors();
      if (interactive && !_confirmContinue('Продовжити з міграцією текстів?'))
        return;
    }

    if (!skipTexts) {
      await _setupLocalization();
      await _migrateTexts();
    }

    await _runFinalChecks();
    _printSuccessMessage();
  } catch (e) {
    print('❌ Помилка під час міграції: $e');
    exit(1);
  }
}

Future<bool> _checkGitStatus() async {
  print('\n🔍 Перевірка Git статусу...');

  final result = await Process.run('git', ['status', '--porcelain']);
  if (result.exitCode != 0) {
    print('⚠️  Git не ініціалізовано. Ініціалізую...');
    await Process.run('git', ['init']);
    await Process.run('git', ['add', '.']);
    await Process.run('git', [
      'commit',
      '-m',
      'Initial commit before migration',
    ]);
    return true;
  }

  if (result.stdout.toString().trim().isNotEmpty) {
    print('⚠️  У вас є незафіксовані зміни.');

    final commit = _confirmContinue('Автоматично зробити commit?');
    if (commit) {
      await Process.run('git', ['add', '.']);
      await Process.run('git', ['commit', '-m', 'Pre-migration backup']);
      print('✅ Зміни зафіксовані');
      return true;
    }
    return false;
  }

  print('✅ Git статус чистий');
  return true;
}

Future<void> _runAnalysis() async {
  print('\n📊 КРОК 1: Аналіз hardcoded значень...');

  final result = await Process.run('dart', [
    'scripts/analyze_hardcoded.dart',
    '--file',
  ]);

  if (result.exitCode == 0) {
    print('✅ Аналіз завершено. Звіт збережено в analysis_report_*.txt');
  } else {
    print('⚠️  Помилка аналізу: ${result.stderr}');
  }
}

Future<void> _migrateColors() async {
  print('\n🎨 КРОК 2: Міграція кольорів...');

  // Спочатку пробний прогон
  print('🔍 Пробний прогон міграції кольорів...');
  var result = await Process.run('dart', [
    'scripts/migrate_colors.dart',
    '--dry-run',
  ]);

  if (result.exitCode != 0) {
    throw 'Помилка dry-run міграції кольорів: ${result.stderr}';
  }

  print(result.stdout);

  if (!_confirmContinue('Виконати міграцію кольорів?')) return;

  // Виконуємо міграцію
  result = await Process.run('dart', ['scripts/migrate_colors.dart']);

  if (result.exitCode == 0) {
    print('✅ Міграція кольорів завершена');
    print(result.stdout);
  } else {
    throw 'Помилка міграції кольорів: ${result.stderr}';
  }
}

Future<void> _setupLocalization() async {
  print('\n🌍 КРОК 3: Налаштування локалізації...');

  // Генеруємо l10n файли
  final result = await Process.run('dart', [
    'scripts/generate_l10n_files.dart',
    '--from-analysis',
  ]);

  if (result.exitCode == 0) {
    print('✅ L10n файли створені');
    print(result.stdout);
  } else {
    print('⚠️  Помилка створення l10n: ${result.stderr}');
  }

  // Додаємо залежності
  print('📦 Додаю flutter_localizations...');
  await Process.run('flutter', ['pub', 'add', 'flutter_localizations']);
  await Process.run('flutter', ['pub', 'get']);
}

Future<void> _migrateTexts() async {
  print('\n📝 КРОК 4: Міграція текстів...');

  // Спочатку генеруємо ARB файли
  var result = await Process.run('dart', [
    'scripts/migrate_texts_to_l10n.dart',
    '--generate-arb',
  ]);

  if (result.exitCode != 0) {
    print('⚠️  Помилка генерації ARB: ${result.stderr}');
  }

  // Пробний прогон міграції текстів
  print('🔍 Пробний прогон міграції текстів...');
  result = await Process.run('dart', [
    'scripts/migrate_texts_to_l10n.dart',
    '--dry-run',
  ]);

  if (result.exitCode != 0) {
    throw 'Помилка dry-run міграції текстів: ${result.stderr}';
  }

  print(result.stdout);

  if (!_confirmContinue('Виконати міграцію текстів?')) return;

  // Виконуємо міграцію
  result = await Process.run('dart', ['scripts/migrate_texts_to_l10n.dart']);

  if (result.exitCode == 0) {
    print('✅ Міграція текстів завершена');
    print(result.stdout);
  } else {
    throw 'Помилка міграції текстів: ${result.stderr}';
  }
}

Future<void> _runFinalChecks() async {
  print('\n🔍 КРОК 5: Фінальні перевірки...');

  // Генеруємо локалізації
  print('⚙️  Генерую локалізації...');
  var result = await Process.run('flutter', ['gen-l10n']);
  if (result.exitCode != 0) {
    print('⚠️  Помилка gen-l10n: ${result.stderr}');
  }

  // Flutter analyze
  print('🔍 Аналізую код...');
  result = await Process.run('flutter', ['analyze']);
  if (result.exitCode == 0) {
    print('✅ Аналіз пройшов успішно');
  } else {
    print('⚠️  Знайдені проблеми в коді:');
    print(result.stdout);
  }

  // Flutter pub get
  print('📦 Оновлю залежності...');
  await Process.run('flutter', ['pub', 'get']);
}

bool _confirmContinue(String message) {
  stdout.write('❓ $message (y/N): ');
  final input = stdin.readLineSync()?.toLowerCase();
  return input == 'y' || input == 'yes';
}

void _printSuccessMessage() {
  print('\n🎉 МІГРАЦІЯ ЗАВЕРШЕНА УСПІШНО!');
  print('=' * 50);
  print('✅ Що зроблено:');
  print('   • Проаналізовано hardcoded значення');
  print('   • Мігровано кольори на Theme.of(context)');
  print('   • Налаштовано локалізацію (l10n)');
  print('   • Мігровано тексти на AppLocalizations');
  print('   • Створено файли перекладів');

  print('\n🚀 Наступні кроки:');
  print('   1. flutter run - перевір роботу додатку');
  print('   2. Заповни переклади в lib/l10n/app_en.arb');
  print('   3. Протестуй зміну мови');
  print('   4. git add . && git commit -m "Complete migration"');

  print('\n📁 Створені файли:');
  print('   • lib/theme/app_theme.dart - власна тема');
  print('   • lib/l10n/app_uk.arb - українські переклади');
  print('   • lib/l10n/app_en.arb - англійські переклади');
  print('   • l10n.yaml - конфігурація локалізації');
  print('   • analysis_report_*.txt - звіт аналізу');
}
