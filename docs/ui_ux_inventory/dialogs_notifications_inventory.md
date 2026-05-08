# iTACS Dialogs, Popups and Notifications Inventory

## Глобальні snackbar/popup патерни

Файл: `lib/services/error_notification_manager.dart`

### Error Snackbar

- Призначення: звичайні помилки.
- Візуал: floating snackbar, red background, error icon.
- Опційна дія: `Повторити`.

### Success Snackbar

- Призначення: успішне завершення дії.
- Візуал: floating snackbar, green background, check icon.

### Warning Snackbar

- Призначення: попередження.
- Візуал: floating snackbar, orange background, warning icon.

### Info Snackbar

- Призначення: нейтральні інформаційні повідомлення.
- Візуал: floating snackbar, blue background, info icon.

### Critical Error Dialog

- Призначення: критичні помилки, які не можна просто сховати в snackbar.
- Елементи: title, message, optional details in expansion tile, retry, close.
- Поведінка: barrierDismissible false.

### Confirmation Dialog

- Призначення: універсальне підтвердження дії.
- Елементи: title, message, cancel, confirm.
- Варіант: destructive confirm red.

## Auth dialogs and states

- Loading screen: `EmailCheckPage`.
- Login screen: Google sign-in.
- Access denied screen: no modal, але це full-screen blocking state.

## MainScaffold notifications

Файл: `lib/pages/main_scaffold.dart`

### Foreground Push Snackbar

- Trigger: push notification received while app is open.
- Елементи: icon by kind, title/body text, close icon, action.
- Action labels: `Відкрити` for lessons, `Переглянути` for group notifications.
- Duration: 6 seconds.

### Group Notification Snackbar

- Trigger: opening queued group notification.
- Content: title plus optional body.
- Background: blue.

### Push Error Snackbars

- `Не вдалося відкрити сповіщення для вибраної групи`.
- `Заняття зі сповіщення не знайдено`.

## Home / Dashboard popups

### FeedbackDialog

Файл: `lib/widgets/feedback_dialog.dart`

Призначення: зв'язок з підтримкою.

Стан форми:

- category: bug, feature, other;
- priority: only for bug;
- description;
- loading while sending;
- success view after sent.

Actions:

- close/cancel;
- send;
- close success.

Notifications:

- snackbar on send error.

### AbsenceRequestDialog

Файл: `lib/widgets/absence_request_dialog.dart`

Призначення: користувач створює запит на відсутність.

Поля:

- absence type: vacation/sick leave;
- start date;
- end date;
- reason;
- document number for sick leave;
- informational notice.

Actions:

- cancel;
- submit request.

Validation:

- reason required;
- start/end dates required;
- end date cannot be before start date.

Notifications:

- success snackbar after submit;
- error snackbar for validation/service errors.

### QuickReportDialog

Файл: `lib/services/reports/quick_report_dialog.dart`

Призначення: швидка генерація звітів із dashboard.

Очікувані UX-стани:

- вибір шаблону/періоду;
- loading generation;
- success/error;
- доступ до результату або повідомлення про помилку.

## Calendar popups

### Filter Loading Dialog

Файл: `lib/pages/calendar_page/calendar_page.dart`

- Blocking dialog while loading calendar filters.
- Text: `Завантажуємо фільтри...`.
- Cannot be dismissed by user.

### CalendarFiltersSheet

Тип: modal bottom sheet.

Controls:

- reset;
- show mine only switch;
- user multiselect chips/checkboxes;
- template filters;
- apply.

Error:

- snackbar if filters cannot be loaded.

### LessonDetailsDialog

Файл: `lib/pages/calendar_page/widgets/lesson_details_dialog.dart`

Core actions:

- take lesson;
- release lesson;
- assign instructor;
- register/unregister;
- create lesson at this time;
- edit;
- duplicate;
- delete;
- fill custom fields;
- acknowledge lesson.

Nested dialogs:

- assign instructor confirmation/selection;
- edit lesson form;
- duplicate lesson form;
- delete lesson confirmation;
- custom field edit dialog.

Notifications:

- success/error snackbars for take/release/register/unregister/delete/custom fields/acknowledge.

### LessonFormDialog

Файл: `lib/pages/calendar_page/widgets/lesson_form_dialog.dart`

Modes:

- create;
- edit;
- duplicate.

Sections:

- header;
- basic info;
- time;
- progress reminders;
- details;
- custom fields;
- instructor section;
- recurrence;
- tags;
- action buttons.

Nested dialogs:

- date picker;
- time picker;
- recurrence end date picker;
- custom field add/edit;
- instructor picker;
- external instructor dialog.

Notifications:

- save success/error snackbars.

## Profile popups

### Sign Out Confirmation

Файл: `lib/pages/profile_page.dart`

- Title: `Вихід з акаунту`.
- Message: asks if user is sure.
- Actions: `Скасувати`, `Вийти`.
- Destructive styling on confirm.

Notifications:

- profile load error;
- save success;
- save error;
- sign out error.

## Admin popups

### AbsencesGridTab

Файл: `lib/pages/admin_page/tabs/absences_grid_tab.dart`

Popups:

- cell menu;
- absence assignment dialog;
- edit absence dialog;
- lesson details dialog.

Notifications:

- load data errors;
- approve/reject/cancel success and errors.

### AbsenceAssignmentDialog

Файл: `lib/pages/admin_page/widgets/absence_assignment_dialog.dart`

Поля:

- instructor;
- absence type;
- start/end dates;
- reason;
- optional document fields/comments depending mode.

Actions:

- cancel;
- submit.

Notifications:

- floating success/error snackbars.

### GroupMembersTab

Файл: `lib/pages/admin_page/tabs/group_members_tab.dart`

Popups:

- add member dialog;
- remove member confirmation.

Fields:

- email;
- first name;
- last name;
- rank;
- position;
- phone;
- role dropdown.

Notifications:

- add/update/remove success/errors.

### NotificationsTab

Файл: `lib/pages/admin_page/tabs/notifications_tab.dart`

Popups:

- create notification dialog.

Fields:

- title;
- body;
- target/priority/type controls.

Notifications:

- create success/error;
- delete success/error.

### TemplatesTab

Файл: `lib/pages/admin_page/tabs/templates_tab.dart`

Popups:

- template editor dialog;
- delete template confirmation;
- sync lessons confirmation;
- migrate lessons confirmation;
- add autocomplete value dialog;
- custom field add/edit dialogs.

Notifications:

- save/delete/sync/migrate/autocomplete success/errors.

### ReportTemplatesTab

Файл: `lib/pages/admin_page/tabs/report_templates_tab.dart`

Popups:

- report template editor dialog;
- preview dialog;
- delete confirmation;
- export text dialog;
- import text dialog;
- AI info dialog.

Editor sections:

- metadata;
- columns;
- filters;
- group by;
- sort;
- calendar grid;
- totals.

Notifications:

- copy to clipboard;
- import/export feedback;
- publish/delete/save errors.

## Tools popups

### ToolDialog

Файл: `lib/pages/tools_page/tool_dialog.dart`

Призначення: створення/редагування embedded tool item.

Fields:

- title;
- description;
- embedded tool key;
- icon selector.

Nested:

- icon picker dialog.

### ToolTile Delete Confirmation

Файл: `lib/pages/tools_page/tool_tile.dart`

- Confirm before deleting tool.
- Destructive confirm.

Notifications:

- open/edit/delete errors;
- delete success.

### Icon Picker Dialog

Файл: `lib/pages/tools_page/tools_page.dart`

- Grid of Material icons.
- Cancel action.

## Embedded tool dialogs

### Contacts

Файл: `lib/pages/tools_page/embedded/contacts_tool_page.dart`

Dialogs:

- add department;
- edit department;
- delete department confirmation;
- add/edit contact;
- delete contact confirmation;
- reorder contacts.

Notifications:

- copy phone;
- open Signal/call errors;
- CRUD success/errors.

### Checklist Builder

Файли: `lib/pages/tools_page/embedded/checklist_builder/*`

Dialogs:

- delete config confirmation;
- add/edit user field;
- add section;
- add/edit info card;
- checklist item editor;
- template field editor;
- reset session confirmation.

Notifications:

- duplicated;
- deleted;
- imported/exported JSON;
- copied;
- reset session.

### Material Journals

Файли: `lib/pages/tools_page/embedded/material_journals/*`

Dialogs:

- journal create/edit;
- journal delete confirmation;
- item create/edit;
- item delete confirmation;
- write-off;
- replenish;
- transfer;
- condition change;
- correction;
- apply template;
- template create/edit/delete;
- templates sheet.

Important states:

- critical stock banners;
- grouped item list;
- history pages;
- loading empty states.

### Trip Tracking

Файли: `lib/pages/tools_page/embedded/trip_tracking/*`

Expected dialogs/states by tab:

- new trip form states;
- debts settlement/payment states;
- history details/filters;
- car management dialogs;
- people management dialogs.

## Redesign checklist for popups

- Кожен destructive action має однаковий confirm pattern.
- Кожна форма має loading state на submit.
- Всі snackbar-и треба привести до єдиної системи severity: success, info, warning, error.
- Bottom sheets варто використовувати для lightweight filters/actions; важкі форми краще залишати dialog/full-screen modal на mobile.
- Для mobile великі dialogs, зокрема LessonFormDialog і report template editor, варто розглядати як full-screen modal.
