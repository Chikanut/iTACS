# UI/UX Inventory для редизайну iTACS

Ця папка містить опис функціональності інтерфейсу iTACS перед глобальним редизайном.

## Файли

- `ui_functionality_inventory.md` - повна карта екранів, станів, дій користувача та залежностей.
- `dialogs_notifications_inventory.md` - окремий перелік діалогів, bottom sheets, snackbar/push-сповіщень і системних станів.
- `claude_design_brief.md` - стислий бриф, який можна передати в Claude Design або інший дизайн-інструмент для генерації шаблонів.

## Як користуватись

1. Спочатку прочитати `ui_functionality_inventory.md`, щоб зрозуміти всі користувацькі сценарії.
2. Передати `claude_design_brief.md` у Claude Design як основний prompt/context.
3. За потреби додати `dialogs_notifications_inventory.md`, якщо треба окремо пропрацювати попапи, модалки, snackbars і push-стани.

## Важливі припущення

- Документація зібрана за поточним Flutter-кодом у `lib/pages`, `lib/widgets`, `lib/services`.
- Це inventory функціональності, а не фінальна дизайн-специфікація.
- Під час редизайну важливо не втратити role-based доступ: `admin`, `editor`, `viewer`, а також read-only offline mode.
