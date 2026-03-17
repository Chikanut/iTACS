# Project Overview

## Призначення

`iTACS` допомагає інструкторам і адміністраторам працювати з розкладом занять, навчальними матеріалами, інструментами та звітністю в межах груп GSPP.

## Ключові підсистеми

### Auth і bootstrap

- `AuthGate` керує кореневим роутингом станів сесії.
- `AppSessionController` робить startup bootstrap, silent restore, revalidate і централізований logout.
- `AuthService` працює з Google Sign-In, Firebase Auth і Google Drive token cache.

### Дані користувача

- `FirestoreManager` читає доступні групи, ролі та профільні дані з Firestore.
- `ProfileManager` кешує профіль і поточну групу через Hive.

### Основні екрани

- `HomePage` - dashboard, статистика, звіти, відсутності.
- `CalendarPage` - календар занять.
- `MaterialsPage` / `ToolsPage` - файлові та довідкові ресурси.
- `AdminPanelPage` - адміністративні сценарії для груп.

### Файли та звіти

- `FileManager` відповідає за Drive metadata, кешування, download/open/share.
- `ReportsService` і `lib/services/reports/` генерують Excel-звіти.

## Зберігання стану

- Firebase Auth зберігає основну сесію користувача.
- `SharedPreferences` тримає допоміжний прапорець для silent restore Google sign-in.
- Hive зберігає профіль, поточну групу і файловий кеш.

## Поточні архітектурні ризики

- Великі монолітні файли (`HomePage`, `FileManager`, частина calendar widgets).
- Значна кількість legacy warnings/lints.
- Частина сервісів досі жорстко прив'язана до `Globals`, що ускладнює тестування.
