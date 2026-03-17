# Roadmap

## P0

- Завершити стабілізацію auth bootstrap і persisted login.
- Утримувати централізований logout через `AppSessionController` + `AuthService`.
- Тримати `flutter analyze` без analyzer errors і `flutter test` у зеленому стані.
- Прибрати з репозиторію локальні артефакти, backup-папки та випадкові тимчасові файли.

## P1

- Розбити `lib/pages/home_page.dart` на менші feature-віджети та окремі view-model/service шари.
- Декомпозувати `lib/services/file_manager/file_manager.dart`.
- Прибрати дублювання bootstrapping логіки профілю/груп.
- Поступово замінити legacy-патерни типу `withOpacity`, прямі `print`, проблемні async-context виклики.

## P2

- Нормалізувати всі dev-скрипти в `scripts/`.
- Винести локалізацію з hardcoded текстів у повноцінний l10n pipeline.
- Розширити test coverage для календаря, матеріалів, звітів та адмін-панелі.
- Переглянути VS Code tasks/launch конфігурації та автоматизацію збірок.

## Відомий технічний борг

- Legacy warnings тимчасово приглушені analysis baseline, але не усунуті.
- `Globals` зручний для швидких змін, але заважає ізольованому тестуванню.
- В UI ще залишаються екрани з великим обсягом бізнес-логіки.
