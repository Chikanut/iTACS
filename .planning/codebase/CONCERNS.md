# Codebase Concerns

**Analysis Date:** 2026-03-26

## Tech Debt

**Linter Configuration - Overly Permissive Analysis Rules:**
- Issue: `analysis_options.yaml` disables 14 important linting rules including `unused_import`, `unused_field`, `prefer_final_fields`, `use_build_context_synchronously`, and `deprecated_member_use`. This creates technical debt by allowing problematic patterns to accumulate without warnings.
- Files: `analysis_options.yaml` (lines 17-34)
- Impact: Dead imports and unused code accumulate; deprecated APIs remain in use; deprecated members go unnoticed; build context usage violations can cause runtime crashes
- Fix approach: Gradually enable rules one-by-one; run `flutter analyze` and fix violations per rule before enabling next rule; prioritize `use_build_context_synchronously` (critical for setState safety) and `deprecated_member_use`

**Silent Error Handling with Empty Catch Blocks:**
- Issue: 10+ locations catch exceptions and silently discard them using `catch (_) {}` without logging or fallback behavior. This hides failures and makes debugging extremely difficult.
- Files:
  - `lib/services/firestore_manager.dart` (lines 996, 1007)
  - `lib/pages/materials_page/material_dialogs.dart` (lines 108, 129, 181, 243, 262)
  - `lib/pages/tools_page/tools_page.dart` (line 49)
  - `lib/pages/tools_page/tool_dialog.dart` (line 145)
- Impact: Failures go undetected; users don't know why operations fail; debugging is nearly impossible; data inconsistencies occur silently
- Fix approach: Replace all `catch (_) {}` blocks with at least `debugPrint()` logging; add metrics/telemetry for catch events; implement proper error recovery with fallbacks

**Large Component Files with Mixed Concerns:**
- Issue: Multiple files exceed 1300+ lines with diverse responsibilities (UI rendering, state management, business logic, dialog handling all in one file).
- Files:
  - `lib/pages/calendar_page/widgets/lesson_form_dialog.dart` (1504 lines)
  - `lib/pages/home_page.dart` (1500 lines)
  - `lib/pages/admin_page/tabs/absences_grid_tab.dart` (1372 lines)
  - `lib/pages/admin_page/tabs/report_templates_tab.dart` (1325 lines)
  - `lib/pages/calendar_page/widgets/lesson_details_dialog.dart` (1316 lines)
- Impact: Hard to understand, test, and modify; increases cognitive load; makes refactoring risky; violates single responsibility principle
- Fix approach: Extract separate concerns into dedicated classes (form logic, state management, display logic); use composition over inheritance; consider BLoC/Provider pattern for state

**Debug Code Left in Production:**
- Issue: Extensive debug output throughout file manager, calendar utils, and other services with emoji-decorated console logs intended for development.
- Files:
  - `lib/services/file_manager/file_manager.dart` (lines 554-576, 608-835)
  - `lib/pages/calendar_page/calendar_utils.dart` (line 826)
- Impact: Performance overhead from string formatting and console I/O; potential information leaks in release builds (user data being logged); unprofessional console output
- Fix approach: Create logging abstraction; wrap all `debugPrint()` in `kDebugMode` guards; remove emoji markers; implement structured logging system for production analytics

**Hardcoded Colors Throughout Codebase:**
- Issue: 543+ hardcoded color values using `Colors.*`, `Color(0xFF...)`, and hex values directly in widgets instead of centralized theme system.
- Files: Across 25+ widget files including `calendar_utils.dart` (21 colors), `absences_grid_tab.dart` (52+ colors), various UI components
- Impact: Theming becomes impossible; dark mode support is broken; rebranding requires touching 25+ files; inconsistent color palette across app; color accessibility not managed centrally
- Fix approach: Migrate all colors to `lib/theme/app_theme.dart` as named constants; use `AppTheme.color(context)` pattern; implement semantic color names (e.g., `successGreen`, `warningOrange`)

**Missing Input Validation:**
- Issue: No assertions or validation of user inputs before using in operations. Example: `lesson_form_dialog.dart` accepts form data without validating field values, duration constraints, or data consistency.
- Files: Multiple form dialogs and input handlers throughout pages
- Impact: Invalid data enters system; database constraints may be violated; users confused by cryptic error messages
- Fix approach: Add validators at form submission; implement domain model validation; add custom form field validators

## Known Bugs

**Potential Null Reference in Lesson Form:**
- Symptoms: Line 1146 in `lib/pages/calendar_page/widgets/lesson_form_dialog.dart` calls `.first` on `_resolvedInstructorIds()` and `_resolvedInstructorNames()` without checking if lists are empty
- Files: `lib/pages/calendar_page/widgets/lesson_form_dialog.dart` (lines 1146, 1149)
- Trigger: Creating/editing lesson with no instructors assigned causes crash when accessing `.first` on empty list
- Workaround: Ensure at least one instructor is always selected before form submission

**Clipboard Access Silent Failure:**
- Symptoms: Material dialog attempts to read clipboard but silently fails if permission denied or clipboard empty
- Files: `lib/pages/materials_page/material_dialogs.dart` (lines 179-182)
- Trigger: User taps "paste URL from clipboard" on platform with clipboard permission denied
- Workaround: Manually enter URL instead of using paste function

**HTML Injection Debug Mode Enabled in Production:**
- Symptoms: JavaScript console logs and `window.debugUserData()` function remain active in HTML file injection code
- Files: `lib/services/file_manager/file_manager.dart` (lines 611, 832-835)
- Trigger: Opening any HTML file triggers console logging of user profile data
- Workaround: None; user data is logged to browser console for any HTML file

**Offline Mode Read-Only Restriction Not Consistently Enforced:**
- Symptoms: Some operations blocked in offline mode (`createLesson`, `updateLesson`) while others may not be
- Files: `lib/services/calendar_service.dart` (lines 157, 258, 289, 316, 373, 777)
- Trigger: User in offline mode may attempt write operations that are inconsistently blocked
- Workaround: Only sync data before going offline; read-only offline mode is intentional but UI feedback could be clearer

## Security Considerations

**Unvalidated File Metadata Injection into HTML:**
- Risk: User profile data (name, position, unit) injected directly into HTML documents without escaping or sanitization. Could allow XSS if user data contains malicious content.
- Files: `lib/services/file_manager/file_manager.dart` (lines 550-577, 608-848)
- Current mitigation: JavaScript injection happens in trusted context (local app), user data comes from authenticated Firebase
- Recommendations:
  - HTML-escape all user data before injection: `name.replaceAll('&', '&amp;').replaceAll('<', '&lt;')`
  - Validate that profile fields contain only safe characters (alphanumeric, spaces, common punctuation)
  - Remove console logging of user data (lines 832-835 debug function)
  - Document XSS risks in comments

**Firebase Configuration Exposed in Source:**
- Risk: `lib/services/firebase_options.dart` contains Firebase API keys, project IDs, and auth domains which are technically public keys but could be used to identify the Firebase project
- Files: `lib/services/firebase_options.dart`
- Current mitigation: Firebase rules should restrict access via authentication; API keys in Flutter are standard practice
- Recommendations:
  - Verify Firestore security rules are properly restrictive
  - Add domain whitelisting if possible
  - Monitor Firebase console for unusual activity
  - Consider using Firebase App Check for additional layer (currently not implemented)

**Incomplete Permission Handling:**
- Risk: Only Firebase Messaging requests permissions; file operations may silently fail if permissions denied
- Files: `lib/services/push_notifications_service.dart` (line 201)
- Current mitigation: File operations degrade gracefully with exceptions
- Recommendations:
  - Add permission checks before file operations
  - Provide user feedback when permissions denied
  - Request permissions with context (explain why needed)

**No HTTPS Certificate Pinning:**
- Risk: Google Drive API calls over HTTP without certificate pinning; vulnerable to MITM attacks
- Files: `lib/services/google_drive_service.dart` (lines 209, 242, 287, 305, 328, 361)
- Current mitigation: OAuth 2.0 provides some protection via token validation
- Recommendations:
  - Implement certificate pinning for Google APIs
  - Use `http` package with certificate validation
  - Consider using official Google API client library instead of raw HTTP

## Performance Bottlenecks

**No Pagination in List Queries:**
- Problem: Calendar service loads all lessons for date range without pagination. Large date ranges or groups with many lessons cause memory spikes and UI freezes.
- Files: `lib/services/calendar_service.dart` (lines 63-73)
- Cause: `orderBy('startTime').get()` loads entire collection subset into memory
- Improvement path: Implement cursor-based pagination with page size limits (e.g., 100 lessons per request); lazy-load as user scrolls

**Expensive String Concatenation in Loops:**
- Problem: Calendar grid building concatenates strings in loops for formatting (multiple `+` operations)
- Files: `lib/pages/calendar_page/calendar_utils.dart` (lines 550-630)
- Cause: String `+` creates new string object on each concatenation instead of using StringBuffer
- Improvement path: Use StringBuffer for building formatted strings; pre-allocate capacity

**Repeated File Metadata Queries:**
- Problem: `file_manager.dart` fetches metadata synchronously (blocking), once per file open; no caching between calls
- Files: `lib/services/file_manager/file_manager.dart` (lines 63-65)
- Cause: No persistent cache of metadata; cache service not checked first time
- Improvement path: Ensure cache is checked before API call; implement time-based cache invalidation

**Multiple Nested StreamBuilders/FutureBuilders:**
- Problem: Pages with cascading dependencies (user data → group data → lessons) use multiple builders creating rebuild chains
- Files: Multiple pages with builder patterns
- Cause: Inefficient rebuild propagation through widget tree
- Improvement path: Consider Provider or BLoC pattern for state management to reduce rebuilds

**HTML Injection JavaScript Overhead:**
- Problem: Large JavaScript payload injected into HTML files for each open; string interpolation + encoding is expensive
- Files: `lib/services/file_manager/file_manager.dart` (lines 608-835)
- Cause: ~2KB+ JavaScript injected on every HTML file open
- Improvement path: Cache compiled JavaScript template; only inject data, not entire script; consider lazy loading

## Fragile Areas

**Calendar Utility Functions - Timezone and Date Handling:**
- Files: `lib/pages/calendar_page/calendar_utils.dart` (1070 lines)
- Why fragile: Complex date arithmetic with manual Duration calculations; timezone-aware operations mixed with naive dates; DST handling not explicit
- Safe modification: Add unit tests for date functions before modification; use `DateTime` in UTC internally; consider using `timezone` package for DST handling
- Test coverage: Debug output present but no automated tests found

**Lesson Model Serialization:**
- Files: `lib/models/lesson_model.dart` (974 lines)
- Why fragile: Complex `fromMap`, `toMap`, `fromFirestore` methods with deeply nested optional fields; changes to one method easily break others
- Safe modification: Add golden tests for serialization round-trips; add integration test for Firestore sync; extract serialization to separate class
- Test coverage: No serialization tests found

**Profile and Group Context Management:**
- Files: `lib/globals.dart`, `lib/services/profile_manager.dart`
- Why fragile: Globals holds mutable state across app; `currentGroupId`, `currentGroupName` change during operations and can become stale
- Safe modification: Implement proper state management with change notifications; add guards to prevent operations during group switching; test group transitions explicitly
- Test coverage: No transition state tests found

**Offline Mode State Machine:**
- Files: `lib/services/app_session_controller.dart` (SessionScreen enum), `lib/services/calendar_service.dart` (multiple offline checks)
- Why fragile: Offline mode represented by boolean flag scattered across services; state transitions not atomic; could be in inconsistent state
- Safe modification: Implement proper state machine with explicit transitions; use `enum` with sealed class pattern; add state transition tests
- Test coverage: No state transition tests found

**Absence Grid Cell Rendering:**
- Files: `lib/pages/admin_page/widgets/absence_grid_cell.dart` (8 colors, complex conditional rendering)
- Why fragile: Hard to reason about color selection logic with multiple inline conditionals; any change to absence types breaks formatting
- Safe modification: Extract color logic to function with clear parameters; add tests for each absence type and status combination
- Test coverage: No rendering tests found

## Test Coverage Gaps

**No Unit Tests for Serialization:**
- What's not tested: `LessonModel.fromMap()`, `fromFirestore()`, `toMap()` round-trip serialization and deserialization
- Files: `lib/models/lesson_model.dart`
- Risk: Silent data corruption during Firestore sync; changes to model break serialization without detection
- Priority: High

**No Integration Tests for Offline→Online Sync:**
- What's not tested: Transitioning from offline to online mode; syncing cached data with server state; conflict resolution
- Files: `lib/services/app_snapshot_store.dart`, `lib/services/calendar_service.dart`
- Risk: Data loss or corruption when going offline then online; users unaware of sync failures
- Priority: High

**No Tests for Calendar Timezone Handling:**
- What's not tested: Date calculations with different timezones; DST transitions; week start/end calculations
- Files: `lib/pages/calendar_page/calendar_utils.dart`
- Risk: Lessons appear on wrong dates for users in different timezones; DST transitions cause scheduling errors
- Priority: High

**No Widget Tests for Large Dialogs:**
- What's not tested: Form validation in dialogs; state changes affecting form display; error messages rendering
- Files: `lib/pages/calendar_page/widgets/lesson_form_dialog.dart`, `lib/pages/admin_page/tabs/absences_grid_tab.dart`
- Risk: Form bugs only discovered by manual testing; regressions in form validation go unnoticed
- Priority: Medium

**No Tests for Permission Handling:**
- What's not tested: Behavior when permissions denied; graceful degradation; user-facing error messages
- Files: File manager services, push notification service
- Risk: Crashes on permission denial; confusing errors for users with restricted permissions
- Priority: Medium

**No Tests for File Cache Invalidation:**
- What's not tested: Cache expiration; manual cache clearing; cache corruption recovery
- Files: `lib/services/file_manager/file_cache_service.dart`
- Risk: Stale files served to users; disk space grows unbounded; cache becomes corrupted
- Priority: Medium

## Scaling Limits

**File Cache No Size Limits:**
- Current capacity: Unbounded disk usage; Hive box grows indefinitely
- Limit: Mobile devices may run out of storage; file cache can consume GB of disk
- Scaling path: Implement LRU cache eviction; set max cache size limit (e.g., 500MB); add manual cache clear UI; periodic cache cleanup on app start
- Files: `lib/services/file_manager/file_cache_service.dart`

**Firestore Subcollection Queries Without Limits:**
- Current capacity: Loading all lessons for large date ranges; all absences for group; all notifications
- Limit: Queries timeout or crash with 10,000+ documents; Firebase billing based on reads
- Scaling path: Implement pagination with cursor-based limits; use `limit(100)` clauses; implement server-side aggregation for summaries
- Files: `lib/services/calendar_service.dart`, `lib/services/absences_service.dart`

**No Rate Limiting on API Calls:**
- Current capacity: Multiple simultaneous requests to Firebase; Google Drive API calls unbounded
- Limit: Firebase rules may throttle; Google Drive quota exhaustion possible
- Scaling path: Implement request queue with backoff; cache results aggressively; batch operations
- Files: Multiple service files making direct Firebase/Google Drive calls

**Absence Grid Rendering Performance:**
- Current capacity: Grid renders all days for all staff; complex color/status calculation per cell
- Limit: 50+ staff × 365 days = 18,000+ cells; UI freezes on render or scroll
- Scaling path: Virtual scrolling for grid; memoized cell rendering; lazy-load month/week at a time
- Files: `lib/pages/admin_page/tabs/absences_grid_tab.dart`

## Dependencies at Risk

**Deprecated Firebase Auth 4.17.0:**
- Risk: Firebase Auth ^4.17.0 is older version; latest is 5.x with breaking changes not yet implemented
- Impact: May have known vulnerabilities; newer SDKs likely drop support
- Migration plan: Plan migration to firebase_auth ^5.0.0; test Google Sign-In compatibility; update Firebase Core and Cloud Firestore in sync
- Files: `pubspec.yaml` (line 37)

**No Platform Abstraction for File Operations:**
- Risk: File operations handle web/mobile differently; platform-specific code scattered across services
- Impact: Desktop support would require rewriting file handling; web-specific bugs hard to isolate
- Migration plan: Create `FileSystemAbstraction` interface; implement platform-specific adapters; centralize platform detection
- Files: Multiple file manager services

## Missing Critical Features

**No Automated Testing Setup:**
- Problem: 96 Dart files with 0 test files; no test framework configured; no CI/CD testing
- Blocks: Confident refactoring; catching regressions; deployment safety
- Recommendation: Add `flutter_test` to dev_dependencies; create basic unit tests for services; configure pre-commit hooks to run tests

**No Error Reporting to Development Team:**
- Problem: Exceptions logged to console but not sent to backend or error tracking service
- Blocks: Production issues go unnoticed; no data on common failures; can't prioritize fixes
- Recommendation: Integrate Sentry or Firebase Crashlytics; send crash reports with context; add analytics for common errors

**No User Feedback for Long Operations:**
- Problem: Database operations lack progress indicators for slow network; users unaware if app is working
- Blocks: Users think app froze; users can't tell if operation succeeded
- Recommendation: Add loading dialogs for long-running operations; implement operation timeout with user notification; add network status indicator

**No Offline-First Sync Queue:**
- Problem: Offline mode is read-only; users can't queue changes to sync later
- Blocks: Users frustrated by read-only limitation; data entry workflow broken in offline scenarios
- Recommendation: Implement change queue stored locally; sync when online; implement conflict resolution strategy

**No Localization System for Error Messages:**
- Problem: Many error messages hardcoded in English; some in Ukrainian in code
- Blocks: App not truly bilingual; users see inconsistent language
- Recommendation: Migrate all strings to localization system (already partially done with .arb files); use AppLocalizations for all user-facing text

---

*Concerns audit: 2026-03-26*
