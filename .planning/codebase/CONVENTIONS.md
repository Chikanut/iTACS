# Coding Conventions

**Analysis Date:** 2026-03-26

## Naming Patterns

**Files:**
- Snake case with underscores: `lesson_model.dart`, `calendar_service.dart`, `auth_gate.dart`
- Page files end with `_page.dart`: `login_page.dart`, `home_page.dart`, `profile_page.dart`
- Test files end with `_test.dart`: `custom_field_model_test.dart`, `lesson_acknowledgement_test.dart`
- Dialog/widget component files match their class name in snake_case: `lesson_card.dart`, `error_notification_manager.dart`
- Stub files use `_stub.dart` suffix: `html_stub.dart`, `web_push_environment_stub.dart`
- Platform-specific files use `_web.dart`, `_android.dart`, `_ios.dart` suffixes: `web_push_environment_web.dart`

**Classes:**
- PascalCase for all classes: `LessonModel`, `CalendarService`, `ErrorNotificationManager`
- State classes use underscore prefix pattern: `_AuthGateState`, `_HomePageState`, `_CustomFieldDefinitionDialog`
- Model classes use `Model` suffix: `LessonModel`, `CustomFieldModel`, `NotificationPreferences`
- Service classes use `Service` suffix: `CalendarService`, `AuthService`, `GoogleDriveService`
- Dialog/Widget classes use full name without suffix: `AuthGate`, `LoginPage`, `LessonCard`
- Mixin classes clearly indicate behavior: `LoadingStateMixin`
- Generated/generated classes use `.g.dart` extension: `file_cache_entry.g.dart`

**Functions and Methods:**
- camelCase for all functions: `getLessonsForPeriod()`, `signInWithGoogle()`, `getCachedLessonsForPeriod()`
- Private methods use underscore prefix: `_buildCompactCard()`, `_configureFirestorePersistence()`, `_parseNullableDateTime()`
- Getter methods are simple property-like: `get currentGoogleUser => _currentGoogleUser;`
- Factory constructors follow pattern: `LessonModel.fromMap()`, `LessonModel.fromFirestore()`
- Setter/builder methods use conventional naming: `copyWith()`, `toMap()`, `toFirestore()`

**Variables and Fields:**
- camelCase for all variables: `currentGroupId`, `startDate`, `isCompact`, `filledParticipants`
- Private static fields use underscore prefix: `_instance`, `_currentGoogleUser`, `_cachedAccessToken`
- Constants use UPPER_SNAKE_CASE: `_driveReadonlyScope`, `_driveFileScope`, `_acknowledgementResetFields`
- Boolean prefixes use `is`, `has`, `can`: `isCompact`, `isRegistered`, `hasLength`, `canModify`

**Types/Generics:**
- PascalCase: `List<LessonModel>`, `Map<String, dynamic>`, `Future<void>`
- Enums are PascalCase: `SessionScreen`, `CustomFieldType`
- Type aliases follow class naming: Not extensively used in this codebase

## Code Style

**Formatting:**
- Dart convention: 2-space indentation
- Line length: No explicit enforcement, but lines are kept reasonably short
- Trailing commas in multi-line collections and function parameters
- Spread operators used for readability in lists/maps
- Const constructors and const values throughout

**Linting:**
- `flutter_lints` package (version ^6.0.0) active via `package:flutter_lints/flutter.yaml`
- Many lint rules are explicitly ignored:
  - `avoid_print`: Set to `false` (allows `debugPrint` for logging)
  - `unused_element`, `unused_field`, `unused_import`, `unused_local_variable`: Ignored
  - `prefer_final_fields`: Ignored
  - `use_build_context_synchronously`: Ignored
  - `deprecated_member_use`: Ignored
- Note: Broad ignore scope suggests ongoing code cleanup (see `docs/ROADMAP.md` reference in `analysis_options.yaml`)

## Import Organization

**Order:**
1. Dart imports: `import 'dart:async';`, `import 'dart:async';`
2. Flutter imports: `import 'package:flutter/material.dart';`, `import 'package:flutter/foundation.dart';`
3. Third-party imports: Firebase, Cloud functions, etc.: `import 'package:firebase_auth/firebase_auth.dart';`
4. Local imports using relative paths: `import '../models/lesson_model.dart';`, `import '../globals.dart';`

**Path Aliases:**
- Relative imports preferred: `import '../models/lesson_model.dart'`
- No pub alias system used in existing codebase

## Error Handling

**Patterns:**
- Try-catch blocks with `debugPrint()` for logging caught exceptions
- No custom exception hierarchy observed; catches generic `Exception` and `Error`
- Methods return empty collections as fallback: `return const [];` or `return [];`
- Context-dependent error messages shown via `ScaffoldMessenger.of(context)?.showSnackBar()`
- `context.mounted` checks before UI updates after async operations to prevent memory leaks

**Example pattern from `calendar_service.dart`:**
```dart
try {
  debugPrint('CalendarService: Завантаження занять...');
  final querySnapshot = await _firestore.collection('lessons')...;
  return lessons;
} catch (e) {
  debugPrint('CalendarService: Помилка завантаження: $e');
  return getCachedLessonsForPeriod(...);
}
```

## Logging

**Framework:** `debugPrint()` exclusively for logging

**Patterns:**
- Module prefix in log messages: `'CalendarService: ...'`, `'🚫 Помилка входу: ...'`
- Emoji indicators for log levels: `'✅'` for success, `'❌'` for errors, `'⚠️'` for warnings, `'🚫'` for failures
- Conditional logging based on platform: Checks like `if (!kIsWeb)` before logging platform-specific operations
- No structured logging framework; plain string messages to console
- All logging is debug-only and doesn't persist

## Comments

**When to Comment:**
- Factory constructors documented: `/// Додатковий factory конструктор для Firestore`
- Methods with complex logic documented: `/// Отримати тип заняття (перший тег або 'Загальне')`
- Non-obvious calculations explained: `/// Тривалість заняття в хвилинах`
- State transitions and conditionals documented: `/// Чи заняття в минулому`
- Inline comments sparingly used; mostly avoided for obvious code

**JSDoc/TSDoc:**
- Triple-slash documentation (`///`) used for public methods and constructors
- Documentation in Ukrainian (Cyrillic) to match codebase language
- No parameter documentation observed; only method/property-level docs
- Format: `/// [Description in Ukrainian]` on line preceding method/property

**Example from `lesson_model.dart`:**
```dart
/// Чи заняття в майбутньому
bool get isUpcoming => DateTime.now().isBefore(startTime);

/// Отримати наступну дату повторення після заданої дати
DateTime? getNextRecurrenceAfter(DateTime date) { ... }
```

## Function Design

**Size:**
- Functions range from 5 to 100+ lines
- Complex functions often broken into private helper methods with underscore prefix
- Larger functions in service classes (e.g., `getLessonsForPeriod` with 30+ lines)
- Widget build methods delegated to private builders: `_buildCompactCard()`, `_buildFullCard()`

**Parameters:**
- Named parameters required for optional values
- `required` keyword used for mandatory parameters
- Default values provided for most optional named parameters: `isCompact = false`
- Single positional parameters rare; most are named

**Return Values:**
- Methods return specific types: `Future<List<LessonModel>>`, `Widget`, `Map<String, dynamic>`
- Empty collections returned as fallback: `return const [];` (immutable)
- Null-safety enforced: `String?` for potentially null values, `DateTime!` for guaranteed non-null
- No return statements in void callbacks unless needed

## Module Design

**Exports:**
- Files are self-contained; no barrel files (index.dart) observed in the codebase
- Each service exported as singleton via factory constructor: `factory CalendarService() => _instance;`
- Models imported directly from their files

**Barrel Files:**
- Not used in this codebase
- Imports are direct: `import '../models/lesson_model.dart';`

## Widget Structure

**StatelessWidget vs StatefulWidget:**
- Use `StatelessWidget` for purely presentational components: `LessonCard`, `LoadingIndicator`
- Use `StatefulWidget` for components with mutable state: `HomePage`, `AuthGate`, `LoginPage`
- State classes always have underscore-prefixed name: `class _HomePageState extends State<HomePage>`

**Widget Parameters:**
- Required properties marked with `required`: `required this.title`
- Optional properties with default values: `this.isCompact = false`
- Callback properties use `VoidCallback` or `Function` types: `final VoidCallback? onTap;`
- Builder properties use function signatures: `final Widget Function(BuildContext, SessionController) loadingBuilder;`

---

*Convention analysis: 2026-03-26*
