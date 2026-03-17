# iTACS

Flutter-застосунок для внутрішньої роботи навчальних груп GSPP: розклад, матеріали, інструменти, профілі користувачів, звіти та рольовий доступ через Firebase.

## Що вміє проєкт

- авторизація через Google + Firebase Auth;
- перевірка доступу до груп через Firestore;
- календар занять та dashboard для інструкторів;
- матеріали та інструменти з доступом до файлів Google Drive;
- локальне кешування профілю, групи та файлів;
- базова адмін-панель і генерація Excel-звітів.

## Стек

- Flutter / Dart
- Firebase Auth, Firestore, Cloud Functions
- Google Sign-In + Google Drive API scopes
- Hive, SharedPreferences
- Excel, Share Plus, Open Filex

## Швидкий старт

1. Встановіть Flutter SDK і перевірте `flutter doctor`.
2. Переконайтесь, що локально доступні Firebase-конфіги:
   - `lib/services/firebase_options.dart`
   - `android/app/google-services.json`
   - відповідні Apple/Web налаштування, якщо потрібні
3. Отримайте залежності:

```bash
flutter pub get
```

4. За потреби встановіть root Node-залежності для допоміжних скриптів:

```bash
npm install
```

5. Запустіть застосунок:

```bash
flutter run
```

## Основні команди

```bash
dart format lib test scripts
flutter analyze
flutter test
flutter run -d chrome
flutter run -d windows
firebase deploy --only hosting
firebase deploy --only firestore:rules
```

## Firebase deploy

- Firestore rules зберігаються у `cloudstore_rules` і підключені через `firebase.json`.
- VS Code task `DeployFirebase` збирає web-версію та деплоїть `hosting` і `firestore:rules`.
- VS Code task `DeployFunctionsBlaze` лишено окремо, бо деплой `functions` потребує Blaze plan.

## Структура

- `lib/main.dart` - точка входу Flutter.
- `lib/pages/auth_gate.dart` - кореневий session router.
- `lib/services/app_session_controller.dart` - bootstrap, persisted auth, logout.
- `lib/services/auth_service.dart` - Google/Firebase sign-in, silent restore, token access.
- `lib/services/firestore_manager.dart` - групи, профілі, Firestore CRUD.
- `lib/services/file_manager/` - кешування, завантаження та відкриття файлів.
- `docs/` - setup, огляд архітектури та roadmap.
- `scripts/` - допоміжні утиліти для міграцій і локалізації.

## Quality Gates

- `dart format` для змінених Dart-файлів.
- `flutter analyze` без analyzer errors.
- `flutter test` для session-routing baseline.
- Оновлення документації при зміні auth-flow, структури сервісів або workflow.

## Документація

- [AGENTS.md](./AGENTS.md)
- [CONTRIBUTING.md](./CONTRIBUTING.md)
- [docs/SETUP.md](./docs/SETUP.md)
- [docs/PROJECT_OVERVIEW.md](./docs/PROJECT_OVERVIEW.md)
- [docs/ROADMAP.md](./docs/ROADMAP.md)
- [CHANGELOG.md](./CHANGELOG.md)

## Відомі обмеження

- Кодова база має legacy lint debt, який зафіксований у roadmap.
- `HomePage` і `FileManager` залишаються великими модулями і потребують подальшої декомпозиції.
- Частина dev-скриптів підтримується як внутрішні утиліти і ще потребує нормалізації.
