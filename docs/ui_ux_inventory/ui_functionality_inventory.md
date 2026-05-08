# iTACS UI Functionality Inventory

## Контекст продукту

iTACS - внутрішній Flutter-застосунок для навчальних груп GSPP. Основні задачі: перегляд занять, керування календарем, призначення викладачів, робота зі службовими інструментами, адміністрування груп, push-сповіщення, профіль користувача та шаблони звітів.

Точка входу: `lib/main.dart`. Session/bootstrap flow: `AuthGate` -> `AppSessionController` -> `MainScaffold`.

## Ролі та режими доступу

- `admin`: бачить адмін-панель, керує учасниками, сповіщеннями, шаблонами, відсутностями та звітами.
- `editor`: може створювати/редагувати заняття та частину групового контенту, якщо група не у read-only offline mode.
- `viewer`: переглядає доступний контент без керування.
- `read-only offline`: користувач бачить кешовані дані, але дії запису вимкнені.

## Global App Shell

### MainScaffold

Файл: `lib/pages/main_scaffold.dart`

Призначення: глобальна оболонка після авторизації.

Видимі елементи:

- AppBar з аватаром/ініціалами користувача.
- Назва поточної групи.
- Перемикач груп, якщо користувач має більше однієї групи.
- Меню навігації на широких екранах.
- Bottom navigation на мобільних.
- Банери push/web push дозволів.

Навігація:

- `Адмін-панель` - тільки для admin і не в offline read-only.
- `Головна`.
- `Календар`.
- `Інструменти`.
- `Профіль` через аватар.
- `Вийти` через меню.

Стани:

- групи ще завантажуються;
- групи взяті з кешу;
- pending push navigation;
- push відкриває заняття або групове повідомлення;
- помилка відкриття push для недоступної групи;
- заняття з push не знайдено.

Редизайн-нотатки:

- Це операційний shell, не landing page.
- На desktop варто мати стабільну навігаційну структуру з чітким group switcher.
- На mobile важливо зберегти швидкий доступ до 3-4 головних зон.

## Authentication Flow

### Loading / Email Check

Файл: `lib/pages/email_check_page.dart`

Призначення: екран перевірки сесії, silent restore і доступу.

Елементи:

- CircularProgressIndicator.
- Текст: `Перевіряємо сесію та доступ...`.

Стани:

- первинне завантаження;
- silent restore;
- перевірка доступу email.

### Login

Файл: `lib/pages/login_page.dart`

Призначення: вхід через Google.

Елементи:

- одна primary action: `Увійти через Google`.

Дії:

- запуск `sessionController.signIn(context)`.

### Access Denied

Файл: `lib/pages/access_denied_page.dart`

Призначення: показати користувачу, що email не має доступу.

Елементи:

- іконка блокування;
- заголовок `Доступ заборонено`;
- пояснення про email;
- кнопка `Повернутись до входу`.

Дії:

- sign out і повернення до login flow.

## Home / Dashboard

Файл: `lib/pages/home_page.dart`

Призначення: головна стрічка користувача з найближчими заняттями, відсутностями, оголошеннями, статистикою і звітами.

Видимі елементи:

- Sliver header з привітанням за часом доби.
- Ім'я користувача.
- Кнопка зв'язку з підтримкою.
- Pull-to-refresh.
- Картка групових повідомлень.
- Картка `Мої запити` для відсутностей.
- Картка `Заняття на завтра` або `Наступне заняття`.
- Картка `Потрібно ознайомитись`.
- Картка занять без викладача на завтра.
- Картка персональної статистики.
- Картка генерації звітів.
- Картка останнього оновлення.

Дії користувача:

- оновити стрічку pull-to-refresh;
- відкрити діалог підтримки;
- створити запит на відсутність;
- переглянути заняття;
- ознайомитись із заняттям;
- згенерувати швидкий звіт;
- відкрити зовнішні посилання/результати звітів, якщо доступні.

Стани:

- blocking loading, якщо немає кешованого контенту;
- показ кешу плюс фонове оновлення;
- error state з кнопкою повтору;
- порожні списки сповіщень, запитів або занять;
- offline read-only вимикає дії запису;
- помилка оновлення показується як snackbar, якщо є видимий кеш.

Попапи:

- `AbsenceRequestDialog`;
- `FeedbackDialog`;
- `LessonDetailsDialog`;
- `QuickReportDialog`.

Редизайн-нотатки:

- Dashboard має бути щільним, сканованим, операційним.
- Важливо розділити термінові дії, інформаційні блоки й статистику.
- Картки мають підтримувати empty/error/loading без зміни загальної структури.

## Calendar

Файл: `lib/pages/calendar_page/calendar_page.dart`

Призначення: перегляд, фільтрація, створення та редагування занять.

Видимі елементи:

- AppBar `Календар занять`.
- Поточний період: день, тиждень, місяць або рік.
- Кнопка refresh.
- Кнопка фільтрів із badge активних фільтрів.
- CalendarHeader з перемиканням view type і навігацією назад/вперед/сьогодні.
- CalendarGrid.
- FloatingActionButton створення заняття для editor/admin.

Views:

- day;
- week;
- month;
- year.

Дії користувача:

- перемикати view type;
- перейти до попереднього/наступного періоду;
- перейти на сьогодні;
- вибрати дату;
- відкрити заняття;
- створити заняття;
- оновити календар;
- застосувати фільтри.

Стани:

- calendar refresh key перезавантажує дані;
- фільтри ще завантажуються;
- помилка завантаження фільтрів;
- active filters badge;
- read-only offline ховає створення занять.

### Calendar Filters Sheet

Тип: modal bottom sheet.

Елементи:

- заголовок `Фільтри календаря`;
- кнопка `Скинути`;
- switch `Показати мої`;
- секція `Юзери`;
- секція `Шаблони`;
- кнопка `Застосувати`.

### Lesson Details Dialog

Файл: `lib/pages/calendar_page/widgets/lesson_details_dialog.dart`

Призначення: повний перегляд заняття і рольові дії.

Видимі елементи:

- кольорова шапка з типом/назвою заняття;
- група;
- статус заняття;
- час;
- викладачі;
- локація;
- підрозділ;
- очікувана кількість учнів;
- опис;
- custom fields;
- блок викладацького покриття;
- підтвердження ознайомлення викладачів;
- теги;
- панель дій.

Дії:

- взяти заняття;
- відмовитись від заняття;
- призначити викладача;
- зареєструватись/скасувати реєстрацію;
- створити заняття в цей час;
- редагувати;
- дублювати;
- видалити;
- заповнити custom fields;
- підтвердити ознайомлення.

Стани:

- loading під час дій;
- користувач уже викладач;
- заняття потребує викладача;
- є проблеми зі статусом;
- доступні/недоступні викладачі;
- success/error snackbars після кожної операції.

### Lesson Form Dialog

Файл: `lib/pages/calendar_page/widgets/lesson_form_dialog.dart`

Призначення: створення, редагування і дублювання заняття.

Поля:

- назва;
- шаблон;
- дата;
- start/end time;
- reminders/progress reminders;
- локація;
- підрозділ;
- опис;
- max participants;
- instructors: internal та external;
- recurrence: daily, weekly, monthly;
- recurrence end date;
- tags;
- custom field definitions.

Дії:

- застосувати шаблон;
- вибрати дату/час;
- додати/редагувати/видалити custom fields;
- вибрати інструкторів;
- додати external instructor;
- зберегти;
- скасувати.

## Profile

Файл: `lib/pages/profile_page.dart`

Призначення: персональна інформація, повний профіль, налаштування push.

Вкладки:

- `Загальна інформація`;
- `Повна інформація`;
- `Налаштування`.

Видимі елементи:

- AppBar з refresh.
- Header з аватаром, full name, email, current group chip.
- Форма: ім'я, прізвище, звання, посада, телефон.
- Список навчальних груп і ролей.
- Push settings.
- Save / Logout buttons, крім вкладки повної інформації.

Дії:

- оновити профіль;
- змінити персональні поля;
- змінити notification preferences;
- зберегти;
- вийти з акаунту через confirm dialog.

Стани:

- loading profile;
- saving profile;
- success/error snackbars;
- admin-only push preferences.

## Admin Panel

Файл: `lib/pages/admin_page/admin_panel_page.dart`

Призначення: рольова зона для адміністраторів групи.

Вкладки:

- `Статус`;
- `Учасники`;
- `Сповіщення`;
- `Шаблони`;
- `Звіти`.

Стани:

- non-admin access denied inside page;
- compact mobile tab layout;
- loading/error/empty на рівні вкладок.

### Admin: Absences Status

Файл: `lib/pages/admin_page/tabs/absences_grid_tab.dart`

Призначення: календарна сітка статусів викладачів, відсутностей і навантаження.

Елементи:

- навігація по місяцях;
- responsive desktop/mobile grid;
- day headers;
- instructor rows/cells;
- lesson count badges;
- панель з pending/current/upcoming absences;
- cell menu.

Дії:

- відкрити деталі заняття;
- призначити відсутність;
- редагувати відсутність;
- approve/reject/cancel absence request;
- переглянути summary відсутностей.

### Admin: Group Members

Файл: `lib/pages/admin_page/tabs/group_members_tab.dart`

Призначення: керування учасниками групи.

Елементи:

- список member cards;
- роль користувача;
- email/name/rank/position/phone;
- empty state;
- info cards.

Дії:

- додати учасника;
- змінити роль;
- видалити учасника через confirm dialog.

### Admin: Notifications

Файл: `lib/pages/admin_page/tabs/notifications_tab.dart`

Призначення: створення і перегляд групових оголошень.

Елементи:

- notification cards;
- статистичні картки;
- empty state;
- create notification dialog.

Дії:

- створити повідомлення;
- вибрати пріоритет/тип;
- видалити повідомлення.

### Admin: Lesson Templates

Файл: `lib/pages/admin_page/tabs/templates_tab.dart`

Призначення: шаблони занять і autocomplete довідники.

Елементи:

- template cards;
- статистика шаблонів;
- autocomplete editor;
- empty state.

Дії:

- створити/редагувати шаблон;
- видалити шаблон;
- синхронізувати уроки з шаблоном;
- мігрувати уроки;
- додати/видалити autocomplete value;
- налаштувати custom fields.

### Admin: Report Templates

Файл: `lib/pages/admin_page/tabs/report_templates_tab.dart`

Призначення: створення шаблонів звітів.

Елементи:

- report template cards;
- preview dialog;
- editor dialog;
- export/import text dialogs;
- AI info dialog.

Дії:

- створити/редагувати шаблон;
- preview;
- publish/unpublish;
- delete;
- configure columns, filters, group by, sort, totals, calendar grid;
- export/import config text;
- copy prompts/config to clipboard.

## Tools Hub

Файл: `lib/pages/tools_page/tools_page.dart`

Призначення: каталог вбудованих інструментів групи.

Елементи:

- AppBar `Інструменти`;
- search bar;
- stats row;
- grid of tool tiles;
- empty/search empty states;
- FAB додавання інструменту для admin/editor;
- tool tile popup menu.

Дії:

- пошук;
- відкрити embedded tool;
- додати tool;
- редагувати tool;
- видалити tool через confirm dialog;
- вибрати іконку.

Embedded tools:

- Checklist Builder;
- Contacts;
- Schedule Calculator;
- Material Journals;
- Trip Tracking.

## Embedded Tool: Contacts

Файл: `lib/pages/tools_page/embedded/contacts_tool_page.dart`

Призначення: довідник контактів за підрозділами/відділами.

Елементи:

- search bar;
- stats;
- department sections;
- contact cards;
- updated badge;
- empty state.

Дії:

- copy phone;
- open Signal;
- make call;
- add/edit/delete department;
- add/edit/delete contact;
- reorder contacts.

Попапи:

- department create/edit;
- delete department confirm;
- contact create/edit;
- delete contact confirm;
- reorder contacts dialog.

## Embedded Tool: Schedule Calculator

Файл: `lib/pages/tools_page/embedded/schedule_calculator_page.dart`

Призначення: розрахунок тривалості та кінця навчального дня.

Вкладки:

- `Тривалість`;
- `Кінець дня`.

Дії:

- вводити час початку/кінця;
- вводити кількість занять/перерв;
- розрахувати результат;
- переглянути breakdown.

## Embedded Tool: Checklist Builder

Файли: `lib/pages/tools_page/embedded/checklist_builder/*`

Призначення: створення конфігурацій чеклістів для занять, довідкових карток і шаблонів повідомлень.

Основні екрани:

- `ChecklistBuilderHomePage`: список конфігурацій, import/export JSON, duplicate, delete, open lesson mode.
- `ChecklistConfigEditorPage`: загальні налаштування, user fields, checklist sections, info cards, templates.
- `ChecklistSectionEditorPage`: редагування секції і пунктів чекліста.
- `MessageTemplateEditorPage`: редагування шаблону повідомлення і змінних.
- `ChecklistLessonPage`: робочий режим із вкладками `Чеклісти`, `Довідка`, `Шаблони`.

Дії:

- seed defaults;
- create/edit/duplicate/delete config;
- import/export JSON;
- toggle checklist items;
- update global fields;
- reset session;
- copy generated text;
- edit fields, sections, info cards and templates.

## Embedded Tool: Material Journals

Файли: `lib/pages/tools_page/embedded/material_journals/*`

Призначення: облік матеріалів, журналів, шаблонів, залишків, станів і історії.

Основні екрани:

- `MaterialJournalsHomePage`: список журналів.
- `MaterialJournalPage`: список матеріалів у журналі, grouped list, item actions, templates sheet.
- `MaterialItemDetailPage`: деталі позиції та історія.
- `JournalHistoryPage`: історія журналу.

Дії:

- створити/редагувати/видалити журнал;
- створити/редагувати/видалити позицію;
- списати;
- поповнити;
- перемістити;
- змінити стан;
- корекція кількості;
- застосувати шаблон;
- створити/редагувати/видалити шаблон;
- переглянути історію.

Попапи:

- journal dialog;
- item dialog;
- quantity action dialog;
- transfer dialog;
- condition dialog;
- apply template dialog;
- template dialog;
- delete confirmations.

## Embedded Tool: Trip Tracking

Файли: `lib/pages/tools_page/embedded/trip_tracking/*`

Призначення: облік поїздок, машин, людей, історії і боргів.

Вкладки:

- `Поїздка`;
- `Борги`;
- `Історія`;
- `Машини`;
- `Люди`.

Дії:

- додати поїздку;
- переглянути борги;
- переглянути історію;
- керувати машинами;
- керувати людьми;
- shared state синхронізується між вкладками.

## Shared Components та системні патерни

- `ErrorNotificationManager`: глобальні error/success/warning/info snackbars, critical error dialog, confirmation dialog.
- `LoadingIndicator`: reusable loading state.
- `PushPermissionBanner`: запит системного дозволу push.
- `WebPushInstallBanner`: інструкція/стан web push.
- `CustomFieldReadOnlyList` і related dialogs: custom fields для занять і шаблонів.
- `ToolFieldWidget`: поля інструментів.

## Loading / Empty / Error States

Глобальні патерни:

- blocking loader, якщо немає кешу;
- cached content + non-blocking error snackbar;
- empty state з іконкою, поясненням і CTA;
- role-based disabled controls;
- read-only offline text, який пояснює чому редагування недоступне;
- destructive confirm перед видаленням.

## Suggested Template Families for Redesign

1. **App Shell Template**: responsive navigation, profile entry, group switcher, push banners.
2. **Operational Dashboard Template**: stacked cards, priority alerts, stats, quick actions.
3. **Calendar Workspace Template**: period navigation, view switcher, dense event grid, filters.
4. **Detail Dialog Template**: header, status block, metadata rows, action footer.
5. **Entity Editor Dialog Template**: form sections, validation, save/cancel, loading state.
6. **Admin Data Tab Template**: stats, list/grid, toolbar, empty state, destructive actions.
7. **Tool Catalog Template**: searchable grid, management actions, embedded tool launcher.
8. **Embedded Tool Workspace Template**: tabs, local state, import/export/copy actions.
9. **Notification System Template**: snackbars, push prompt, critical modal, inline banners.
