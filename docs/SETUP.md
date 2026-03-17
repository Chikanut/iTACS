# Setup

## Передумови

- Flutter SDK сумісної версії з `sdk: ^3.8.1`
- Android Studio або VS Code з Flutter/Dart plugin
- Firebase-проєкт із налаштованим Auth + Firestore
- Доступ до Google-акаунтів, які мають право входу в застосунок

## Обов'язкові локальні файли

- `lib/services/firebase_options.dart`
- `android/app/google-services.json`
- Apple/Web конфіги, якщо збірка потрібна не лише для Android/Windows/Web

## Встановлення залежностей

```bash
flutter pub get
```

Опційно для допоміжних Node-скриптів у корені:

```bash
npm install
```

## Локальний запуск

```bash
flutter run
```

Поширені варіанти:

```bash
flutter run -d chrome
flutter run -d windows
flutter run -d emulator-5554
```

## Корисні задачі

- `.vscode/tasks.json` містить задачі для build/deploy і генерації карти проєкту.
- `scripts/` містить утиліти для локалізації та міграцій.

## Перевірки перед комітом

```bash
dart format lib test scripts
flutter analyze
flutter test
```

## Нотатки по Firebase

- Доступ до застосунку контролюється колекцією `allowed_users`.
- Профіль користувача синхронізується в колекцію `users`.
- Silent restore на старті спирається на Firebase session і локальний прапорець Google sign-in.
