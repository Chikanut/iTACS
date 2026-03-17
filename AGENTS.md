# AGENTS.md

## Контекст проєкту

- Це Flutter-проєкт `iTACS` для внутрішнього використання навчальними групами GSPP.
- Точка входу: `lib/main.dart`.
- Session/bootstrap flow: `lib/pages/auth_gate.dart` -> `lib/services/app_session_controller.dart`.
- Google sign-in, silent restore та access tokens живуть у `lib/services/auth_service.dart`.
- Глобальні singleton-сервіси реєструються в `lib/globals.dart`.

## Обов'язкові команди перед завершенням змін

```bash
dart format lib test scripts
flutter analyze
flutter test
```

## Локальні правила для агентів

- Документацію в репозиторії вести українською мовою.
- Не комітити `build/`, `node_modules/`, backup-папки, тимчасові звіти та локальні карти проєкту.
- Не дублювати auth-логіку в UI: для входу, silent restore та logout використовувати `AuthService` і `AppSessionController`.
- Перед редагуванням theme-файлів перевіряти `git status`: у цій зоні часто бувають локальні незавершені правки.
- Не змінювати Firebase-конфіги, секрети чи Google scopes без окремого запиту.

## Високоризикові модулі

- `lib/pages/home_page.dart` - великий dashboard-екран з мішаниною UI та бізнес-логіки.
- `lib/services/file_manager/file_manager.dart` - великий сервіс з кешуванням, інжекцією HTML та інтеграцією з Drive.
- `lib/pages/calendar_page/widgets/lesson_details_dialog.dart` - складний діалог з багатьма гілками поведінки.

## Очікуваний workflow

1. Перевірити `git status`.
2. Зібрати контекст по конкретному модулю.
3. Внести мінімально достатні зміни.
4. Прогнати форматування й перевірки.
5. Оновити README/docs, якщо змінився workflow, auth-flow або архітектура.
