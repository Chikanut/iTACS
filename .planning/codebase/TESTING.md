# Testing Patterns

**Analysis Date:** 2026-03-26

## Test Framework

**Runner:**
- `flutter_test` (from Flutter SDK)
- Config: No explicit test configuration file (uses Flutter defaults)

**Assertion Library:**
- `package:flutter_test` built-in matchers and assertions
- Uses: `expect()`, `hasLength()`, `contains()`, `findsOneWidget()`, `findsWidgets()`

**Run Commands:**
```bash
flutter test                    # Run all tests
flutter test --watch          # Watch mode (if supported)
flutter test --coverage       # Run with coverage reporting
flutter test test/lesson_acknowledgement_test.dart  # Run specific test file
```

## Test File Organization

**Location:**
- Co-located in `test/` directory at project root, separate from `lib/`
- Test files mirror source structure when applicable, but flatten hierarchy

**Naming:**
- Files follow pattern `[feature]_test.dart`
- Examples: `custom_field_model_test.dart`, `lesson_acknowledgement_test.dart`, `widget_test.dart`

**Structure:**
```
test/
├── custom_field_model_test.dart
├── lesson_acknowledgement_test.dart
├── lesson_progress_reminder_test.dart
├── lesson_status_utils_test.dart
├── notification_preferences_test.dart
└── widget_test.dart
```

## Test Structure

**Suite Organization:**

```dart
void main() {
  group('Custom field definitions', () {
    test('serializes and deserializes template definitions', () {
      // Arrange
      final template = GroupTemplate.fromJson({...});

      // Act & Assert
      expect(template.customFieldDefinitions, hasLength(2));
      expect(template.customFieldDefinitions.first.label, '№ наказу');
    });

    test('rejects duplicated codes and labels', () {
      // ...
    });
  });

  group('Lesson custom field values', () {
    test('supports lookup by code and label', () {
      // ...
    });
  });
}
```

**Patterns:**

1. **Group-based organization:** Tests grouped by feature using `group()` blocks
   - Top-level groups describe main functionality
   - Nested groups for sub-features (rarely used)

2. **Arrange-Act-Assert (AAA) pattern:**
   - Setup phase with test data
   - Execution phase
   - Verification with expectations

3. **Test method naming:** Descriptive names using string literals
   - Example: `test('serializes and deserializes reminder lists in lesson model', () {...})`
   - Names explain the behavior being tested in plain English/Ukrainian-influenced English

4. **Widget tests use `testWidgets()`:**
   ```dart
   testWidgets('shows login when there is no active session', (WidgetTester tester) async {
     final controller = FakeSessionController(initialScreen: SessionScreen.signedOut);
     await tester.pumpWidget(buildHarness(controller));
     await tester.pump();
     expect(find.text('LOGIN'), findsOneWidget);
   });
   ```

5. **Async/await for async tests:**
   - Mark test functions as `async`
   - Await future-returning operations
   - Use `await tester.pumpWidget()` to rebuild after state changes in widget tests

## Mocking

**Framework:**
- No external mocking library (like `mockito` or `mocktail`) currently used
- Manual fakes created as test helper classes

**Patterns:**

1. **Fake implementations extend abstract classes:**
   ```dart
   class FakeSessionController extends SessionController {
     FakeSessionController({
       required SessionScreen initialScreen,
       this.onInitialize,
       this.isReadOnlyOffline = false,
       this.lastSuccessfulSyncAt,
     }) : _screen = initialScreen;

     final Future<void> Function(FakeSessionController controller)? onInitialize;
     SessionScreen _screen;
     int signOutCalls = 0;

     @override
     SessionScreen get screen => _screen;

     @override
     Future<void> initialize() async {
       if (onInitialize != null) {
         await onInitialize!(this);
       }
     }

     void setScreen(SessionScreen nextScreen) {
       _screen = nextScreen;
       notifyListeners();
     }
   }
   ```

2. **Factory methods for test data:**
   ```dart
   LessonModel _buildLesson({
     List<LessonCustomFieldDefinition> customFieldDefinitions = const [],
     Map<String, LessonCustomFieldValue> customFieldValues = const {},
   }) {
     return LessonModel(
       id: 'lesson-id',
       title: 'Тактика',
       // ... other fields with sensible defaults
     );
   }
   ```

3. **Helper builders for widget harness:**
   ```dart
   Widget buildHarness(FakeSessionController controller) {
     return MaterialApp(
       home: AuthGate(
         controller: controller,
         loadingBuilder: (context, sessionController) =>
             const Scaffold(body: Center(child: Text('LOADING'))),
         // ... other builders
       ),
     );
   }
   ```

**What to Mock:**
- External service dependencies: `FakeSessionController` for `SessionController`
- Controllers and managers passed to widgets
- Async operations that would require Firebase or real networking

**What NOT to Mock:**
- Model serialization/deserialization (test real `fromMap()`, `toMap()` methods)
- Validation logic (test actual validation rules)
- Widget rendering and interaction (test real widget behavior with test doubles for dependencies)

## Fixtures and Factories

**Test Data:**

1. **Inline data in test methods:**
   ```dart
   final lesson = LessonModel.fromMap({
     'id': 'lesson-1',
     'title': 'Тактика',
     'startTime': DateTime(2026, 3, 20, 9, 0).toIso8601String(),
     // ... other fields
   });
   ```

2. **Builder functions at end of test file:**
   ```dart
   LessonModel _buildLesson({...}) { ... }
   ```

3. **Constants for repeated test data:**
   - Not heavily used; data constructed inline for test clarity

**Location:**
- Helper functions defined at bottom of test file, after `void main()` block
- Private scope with underscore prefix: `_buildLesson()`, `_buildTemplate()`
- Accessible to all tests in the file

## Coverage

**Requirements:**
- No explicit coverage requirements enforced
- Test framework supports coverage but not mandated in current setup

**View Coverage:**
```bash
flutter test --coverage
# Generates coverage/lcov.info (if coverage tool installed)
# Run `genhtml coverage/lcov.info -o coverage/html` to view HTML report
```

## Test Types

**Unit Tests:**
- **Scope:** Model serialization, validation, data transformation
- **Approach:** Test individual classes in isolation
- **Framework:** `test()` function from `flutter_test`
- **Examples:**
  - `custom_field_model_test.dart`: Tests model serialization/deserialization
  - `lesson_acknowledgement_test.dart`: Tests lesson acknowledgement parsing and logic
  - `lesson_progress_reminder_test.dart`: Tests reminder model serialization

**Integration Tests:**
- **Scope:** Model interactions with services, complex workflows
- **Not explicitly present:** No `test/integration/` directory observed
- **Could be added:** Testing calendar service with multiple models, cross-service workflows

**Widget/Component Tests:**
- **Scope:** UI widget rendering, user interactions, state changes
- **Framework:** `testWidgets()` function from `flutter_test`
- **File:** `test/widget_test.dart`
- **Examples:**
  - AuthGate routing tests
  - Session state transitions
  - Logout button interaction

**E2E Tests:**
- **Not used:** No `integration_test/` directory observed
- **Could be added:** Full app flow testing on real/emulated devices

## Common Patterns

**Async Testing:**

```dart
testWidgets('opens home after bootstrap with a restored session', (
  WidgetTester tester,
) async {
  final controller = FakeSessionController(
    initialScreen: SessionScreen.loading,
    onInitialize: (controller) async {
      controller.setScreen(SessionScreen.authenticated);
    },
  );

  await tester.pumpWidget(buildHarness(controller));
  await tester.pump();

  expect(find.text('HOME'), findsOneWidget);
});
```

**Key patterns:**
- Mark test as `async`
- Use `await tester.pumpWidget()` to render initial widget
- Use `await tester.pump()` to rebuild after async operations complete
- Use `await tester.tap()` for user interactions
- Use `await tester.pump()` after interactions to rebuild UI

**Error/Validation Testing:**

```dart
test('rejects duplicated codes and labels', () {
  final duplicatedCode = LessonCustomFieldDefinition.validateDefinitions([
    const LessonCustomFieldDefinition(
      code: 'order_number',
      label: '№ наказу',
      type: CustomFieldType.string,
    ),
    const LessonCustomFieldDefinition(
      code: 'order_number',
      label: 'Дата наказу',
      type: CustomFieldType.date,
    ),
  ]);

  expect(duplicatedCode, contains('дублюється'));
});
```

**Patterns:**
- Call validation method with test data
- Assert error messages contain expected strings using `contains()`
- Test multiple error scenarios separately

**Model Roundtrip Testing:**

```dart
test('serializes and deserializes reminder lists in lesson model', () {
  final lesson = LessonModel(...);

  final restored = LessonModel.fromMap(lesson.toMap());

  expect(restored.progressReminders, hasLength(1));
  expect(restored.progressReminders.first.id, 'r-1');
  expect(restored.progressReminders.first.progressPercent, 90);
});
```

**Patterns:**
- Create test instance with known data
- Serialize to intermediate format (Map, JSON)
- Deserialize back to object
- Assert all fields preserved correctly

## Test Quality Notes

**Strengths:**
- Unit tests cover critical model serialization/deserialization
- Tests verify edge cases (legacy data parsing, field validation)
- Widget tests verify auth routing logic
- Mocks created as reusable classes, not inline
- Builder functions parameterized for test flexibility

**Gaps:**
- Service layer not directly unit tested
- No integration tests between services
- No E2E tests for full user workflows
- Coverage not enforced/tracked
- No performance/load tests

---

*Testing analysis: 2026-03-26*
