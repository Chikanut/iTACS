# iTACS

Flutter-застосунок для внутрішньої роботи навчальних груп GSPP: розклад, матеріали, інструменти, профілі користувачів, звіти та рольовий доступ через Firebase.

## Що вміє проєкт

- авторизація через Google + Firebase Auth;
- перевірка доступу до груп через Firestore;
- календар занять та dashboard для інструкторів;
- матеріали та інструменти з доступом до файлів Google Drive;
- локальне кешування профілю, групи та файлів;
- базова адмін-панель і генерація Excel-звітів;
- динамічні шаблони звітів із Firestore, preview та серверною генерацією через Firebase Functions.

## Автологін і офлайн

- застосунок відновлює trusted-device сесію без повторного вводу пароля через persisted Google/Firebase session;
- після успішного онлайн-сеансу локально зберігаються snapshot-дані профілю, активної групи, dashboard, календаря, матеріалів та інструментів;
- якщо мережі немає, застосунок може відкритися у `read-only offline` режимі зі станом на момент останньої синхронізації;
- write-операції та генерація звітів без інтернету не виконуються: UI лишається стабільним і показує останній збережений стан;
- web-версія використовує Flutter app-shell service worker і Firestore persistence для швидшого повторного старту та офлайн-відкриття.

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

## Push-сповіщення

- Android push побудовано на `firebase_messaging` + `flutter_local_notifications`.
- Web push працює через `firebase_messaging` + `web/firebase-messaging-sw.js`.
- Клієнт зберігає FCM token у `users/{uid}/devices/{token}` і очищає його під час logout.
- Групові та персональні Firestore-сповіщення з `groups/{groupId}/notifications` автоматично дублюються push-сповіщеннями через Firebase Functions.
- Призначення на заняття, зняття із заняття та критичні зміни заняття також шлються через Firebase Functions.
- Нагадування під час заняття зберігаються у шаблоні або конкретному занятті як `progressReminders` і доставляються окремо через `lesson_reminder_jobs`.
- Reminder jobs синхронізуються на кожну зміну заняття, а хвилинний scheduler у Firebase Functions відправляє push у момент досягнення потрібного відсотка timeline.
- Шаблон заняття може масово оновити всі пов’язані заняття за `templateId`; при такій синхронізації оновлюються тип, опис, тривалість, нагадування й теги, а кастомні параметри додаються без перезапису однакових `id`.
- Для старих занять без `templateId` на шаблоні є одноразова дія міграції: вона шукає незавершені заняття з точно такою самою назвою, прив’язує їх до шаблону і відразу запускає синхронізацію.
- Критичними для повторного ознайомлення вважаються лише зміни `startTime`, `endTime` або `unit`.
- Користувач керує типами push-сповіщень у `Профіль -> Налаштування`; ці тогли зберігаються в `users/{uid}.notificationPreferences`.
- Для нагадувань під час заняття використовується окремий toggle `Нагадування під час заняття`; якщо його вимкнути, такі push-сповіщення не надсилаються.
- Public VAPID key вже зашита в коді та VS Code tasks для автоматичної web-збірки. За потреби її все одно можна перевизначити через `--dart-define=FCM_WEB_VAPID_KEY=...`.
- Private VAPID key не зберігається в репозиторії й не потрібна Flutter/web-клієнту; вона має лишатися тільки у Firebase Console.
- На iPhone/iPad web push очікується лише для PWA/Home Screen сценарію.
- Для деплою Functions потрібен Blaze plan, але сам FCM лишається no-cost.

## Структура

- `lib/main.dart` - точка входу Flutter.
- `lib/pages/auth_gate.dart` - кореневий session router.
- `lib/services/app_session_controller.dart` - bootstrap, persisted auth, logout.
- `lib/services/auth_service.dart` - Google/Firebase sign-in, silent restore, token access.
- `lib/services/firestore_manager.dart` - групи, профілі, Firestore CRUD.
- `lib/services/file_manager/` - кешування, завантаження та відкриття файлів.
- `lib/services/report_templates_service.dart` - CRUD шаблонів звітів, preview/publish/generate через callable functions.
- `functions/report_templates.js` - safe DSL для шаблонів звітів, enrich даних і генерація `.xlsx`.
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
