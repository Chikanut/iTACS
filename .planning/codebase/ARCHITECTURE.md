# Architecture

**Analysis Date:** 2026-03-26

## Pattern Overview

**Overall:** Multi-layered service-oriented architecture with centralized global state management and reactive UI layer

**Key Characteristics:**
- Singleton service pattern for cross-app state and data access
- Firebase backend with local-first caching strategy (Firestore + Hive)
- Role-based access control at session and feature levels
- Separation between page (UI) layer and service (business logic) layer
- Offline-first capability with sync management

## Layers

**Presentation (Pages & Widgets):**
- Purpose: Render UI and handle user interactions
- Location: `lib/pages/`, `lib/widgets/`
- Contains: StatefulWidget pages, dialog components, responsive views
- Depends on: Services (via Globals), Models
- Used by: Flutter framework

**Service Layer (Business Logic):**
- Purpose: Manage data operations, external integrations, and cross-cutting concerns
- Location: `lib/services/`
- Contains: Data fetching, Firebase operations, file management, authentication, notifications
- Depends on: Firebase, external APIs (Google Drive, Cloud Functions)
- Used by: Pages, other services

**Model Layer (Data Structures):**
- Purpose: Define domain objects and data contracts
- Location: `lib/models/`, `lib/pages/*/models/`
- Contains: Serializable data classes with Firestore and local storage mapping
- Depends on: Nothing (pure data classes)
- Used by: Services, Pages

**Global State (Singleton Manager):**
- Purpose: Centralized initialization and access to all services
- Location: `lib/globals.dart`
- Contains: Service instances, initialization logic, cleanup methods
- Depends on: All service classes
- Used by: Entire application

**Theme & Configuration:**
- Purpose: Styling, colors, and constants
- Location: `lib/theme/`
- Contains: Material design theme definitions, color palettes
- Depends on: Flutter
- Used by: Pages for consistent UI

## Data Flow

**Authentication & Session Flow:**

1. `main.dart` → Initialize Firebase, Hive, Globals
2. `AuthGate` watches Firebase auth state
3. `AppSessionController` bootstraps user data via `FirestoreManager`
4. `ProfileManager` caches user profile and group membership
5. User navigated to `MainScaffold` (authenticated) or `LoginPage` (signed out)

**Lesson/Calendar Data Flow:**

1. `CalendarPage` requests lessons for date range
2. `CalendarService.getLessonsForPeriod()` queries Firestore
3. Data cached in `AppSnapshotStore` (Hive-backed)
4. Subsequent requests served from cache until invalidated
5. UI rebuilds from cached data or new fetch

**Administrative Actions (Lessons, Templates, Absences):**

1. Page component (e.g., `LessonFormDialog`) collects user input
2. Service method called via `Globals` (e.g., `CalendarService.createLesson()`)
3. `FirestoreManager` writes to Firestore at path `collection/{groupId}/items/{docId}`
4. `ErrorNotificationManager` displays result to user
5. Cache invalidated; UI refreshed from new data

**File Operations:**

1. `FileManager` (entry point) routes to file subsystem
2. `FileDownloader` handles HTTP requests with `FileMetadataService`
3. Files cached in `FileCacheService` using Hive
4. `FileOpener` or `FileSharer` executes file actions
5. Platform-specific code (mobile/web) handles native file operations

**State Management:**

- **Session State:** `AppSessionController` (auth status, user profile, group context)
- **Snapshot Cache:** `AppSnapshotStore` (Hive-backed cache for Firestore queries)
- **Runtime State:** `AppRuntimeState` (in-memory transient state)
- **Error Handling:** `ErrorNotificationManager` (singleton, context-bound SnackBars)

## Key Abstractions

**FirestoreManager:**
- Purpose: Abstracts Firestore queries and operations
- Examples: `lib/services/firestore_manager.dart`
- Pattern: Direct collection/doc queries with group-scoped paths (`collection/{groupId}/items`)

**AppSnapshotStore:**
- Purpose: Caching layer for Firestore data
- Examples: `lib/services/app_snapshot_store.dart`
- Pattern: Hive-backed key-value store; keys include group context and date ranges

**Service Initialization:**
- Purpose: Lazy loading of expensive resources
- Examples: `ReportsService.initialize()`, `FileManager.ensureReady()`
- Pattern: Async initialization in background or on-demand

**Role-Based Access:**
- Purpose: Control feature visibility and write permissions
- Examples: `MainScaffold._hasAdminAccess`, `SessionBootstrapResult.rolesByGroup`
- Pattern: Compare `ProfileManager.currentRole` against 'admin' or 'instructor'

## Entry Points

**Application Entry:**
- Location: `lib/main.dart`
- Triggers: App launch
- Responsibilities: Firebase initialization, Hive setup, Globals initialization, app widget tree

**Session Entry:**
- Location: `lib/pages/auth_gate.dart`
- Triggers: App widget build
- Responsibilities: Auth state monitoring, screen routing (loading/login/authenticated/denied)

**Main Navigation:**
- Location: `lib/pages/main_scaffold.dart`
- Triggers: After successful authentication
- Responsibilities: Bottom tab navigation, page switching, user menu, admin panel conditional display

**Page Hierarchy (Post-Auth):**
- Home: `lib/pages/home_page.dart` - Dashboard with feed, absences, notifications
- Calendar: `lib/pages/calendar_page/calendar_page.dart` - Lesson grid/list views
- Tools: `lib/pages/tools_page/` - Report generation, quick actions
- Materials: `lib/pages/materials_page/` - File/content management
- Admin Panel: `lib/pages/admin_page/admin_panel_page.dart` - Role-restricted management
- Profile: `lib/pages/profile_page.dart` - User settings and group switching

## Error Handling

**Strategy:** Centralized SnackBar-based notification system with optional retry callbacks

**Patterns:**
- Services catch exceptions and return empty collections or throw contextual errors
- Pages wrap async operations in try/catch, log errors, show via `ErrorNotificationManager`
- Firebase errors mapped to user-friendly Ukrainian messages
- Offline operations degrade gracefully (use cached data or disable write features)

**Example Flow:**
```dart
try {
  final lessons = await CalendarService().getLessonsForPeriod(...);
} catch (e) {
  Globals.errorNotificationManager.showError('Помилка завантаження занять: $e');
}
```

## Cross-Cutting Concerns

**Logging:**
- Strategy: `debugPrint()` with prefixes (e.g., `[firestore]`, `[calendar]`)
- Visible only in debug builds; no production log aggregation

**Validation:**
- Strategy: Model classes define validation via `isValid` methods or factories
- Form validation in UI before submission; Firestore security rules as backup

**Authentication:**
- Strategy: Firebase Auth handles credential management; custom role system via Firestore
- Google Sign-In with Drive scopes for file access
- Token caching in `AuthService._cachedAccessToken`
- Offline fallback: cached session state from `AppSnapshotStore`

**Notifications:**
- Push: Via `PushNotificationsService` (Firebase Cloud Messaging)
- In-App: Via `ErrorNotificationManager` (SnackBars)
- Group Notifications: Via `GroupNotificationsService` (Firestore-backed)

**Caching Strategy:**
- Calendar lessons: `AppSnapshotStore` with cache key `lessons_{groupId}_{startDate}_{endDate}`
- Files: `FileCacheService` with expiration and size limits
- Session: `SharedPreferences` for non-sensitive auth state
- Reports: In-memory; regenerated on request

---

*Architecture analysis: 2026-03-26*
