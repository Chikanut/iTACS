# External Integrations

**Analysis Date:** 2026-03-26

## APIs & External Services

**Google OAuth & Identity:**
- Google Sign-In - User authentication and identity
  - SDK: `google_sign_in` 6.1.5 + `google_sign_in_web` 0.12.4+4
  - Auth: OAuth 2.0 flow with Google account
  - Implementation: `lib/services/auth_service.dart`
  - Scopes requested: `email`, `drive.readonly`, `drive.file`
  - Token caching: 1-hour TTL with automatic refresh

**Google Drive API:**
- Google Drive v3 REST API - File operations for materials and tools
  - Client: Direct HTTP via `http` package 1.2.1
  - Auth: Bearer token (OAuth 2.0 access token from Google Sign-In)
  - Endpoints:
    - `/drive/v3/files` - List/get file metadata
    - `/drive/v3/files/{fileId}/export` - Export/download files
    - `/drive/v3/files` - Upload files
    - `/drive/v3/files/{fileId}` - Delete files
  - Implementation: `lib/services/google_drive_service.dart`
  - Scopes:
    - `drive.readonly` - Read-only access (default for all users)
    - `drive.file` - Write access (requested for admin/editor roles only)
  - Usage: Materials and tools pages fetch real-time file listings directly from Drive

**Firebase Authentication:**
- Firebase Auth - Account creation and session management
  - SDK: `firebase_auth` 4.17.0
  - Auth: OAuth credential exchange (Google token → Firebase user)
  - Implementation: `lib/services/auth_service.dart`, `lib/pages/auth_gate.dart`
  - Persistence:
    - Mobile: Automatic session persistence
    - Web: Explicit `setPersistence(Persistence.LOCAL)` for trusted device login
  - Fallback: Silent sign-in with `signInSilently()` for auto-login

## Data Storage

**Primary Database:**
- Firestore (Cloud Firestore) - NoSQL document database
  - Provider: Google Cloud / Firebase
  - Connection: `cloud_firestore` 4.17.0 SDK
  - Persistence:
    - Mobile: Offline persistence enabled via `settings = Settings(persistenceEnabled: true)`
    - Web: Multi-tab safe persistence via `enablePersistence(PersistenceSettings(synchronizeTabs: true))`
  - Collections:
    - `users/{uid}` - User profiles and preferences
    - `users/{uid}/devices/{deviceId}` - FCM tokens for push notifications
    - `allowed_users/{groupId}` - Group membership and role assignments
    - `groups/{groupId}` - Group metadata, templates, notifications
    - `groups/{groupId}/templates/{templateId}` - Lesson template definitions
    - `groups/{groupId}/report_templates/{templateId}` - Report template definitions
    - `groups/{groupId}/autocomplete_data/{docId}` - Autocomplete data (locations, units, tags)
    - `groups/{groupId}/notifications/{notificationId}` - Group notifications
    - `lessons/{groupId}/items/{lessonId}` - Lesson records (schedule, assignments, custom fields)
    - `materials/{groupId}/items/{materialId}` - Material metadata
    - `tools_by_group/{groupId}/items/{itemId}` - Tool metadata
    - `instructor_absences/{groupId}/items/{absenceId}` - Absence requests
    - `drive_catalog_by_group/{groupId}` - Google Drive folder IDs for group materials/tools
    - `files/{fileId}` - File metadata (read-only for authenticated users)
  - Rules: `cloudstore_rules` file (Firestore security rules)
  - Implementation: `lib/services/firestore_manager.dart`

**Local Storage (Client-side Caching):**
- Hive - Encrypted local persistent storage
  - Package: `hive` 2.2.3 + `hive_flutter` 1.1.0
  - Storage location: App documents directory
  - Web: Uses IndexedDB via `hive_web`
  - Implementation: Initialized in `lib/main.dart`
  - Purpose: Offline snapshot caching of profiles, lessons, materials, tools, notifications

- SharedPreferences - Simple key-value store
  - Package: `shared_preferences` 2.2.2
  - Usage: Sign-in state flags (e.g., `google_signed_in` boolean)
  - Implementation: `lib/services/auth_service.dart`, `lib/services/app_session_controller.dart`

- Flutter Cache Manager - HTTP response caching
  - Package: `flutter_cache_manager` 3.3.1
  - Purpose: File download caching to disk

**File Storage:**
- Google Drive (primary) - Material and tool file storage
  - No direct Firebase Cloud Storage usage for user files
  - Access via Google Drive API (see above)
  - Folder structure: `drive_catalog_by_group/{groupId}` documents define root folders for materials and tools
  - Direct download: Bearer token authorization via Google Drive API

**Caching:**
- In-memory snapshots: Dashboard service, calendar service, absence service cache Firestore data
- Methods: `getCachedDashboardFeed()`, `getCachedLessonsForPeriod()`, `getCachedNotifications()`
- Invalidation: Manual refresh on page focus or user action

## Authentication & Identity

**Auth Provider:**
- Google OAuth 2.0 (primary)
- Firebase Auth (secondary verification)

**Implementation Approach:**
- `lib/services/auth_service.dart` - Central auth orchestration
  - Google Sign-In initialization with required scopes
  - Token caching and expiration tracking
  - Credential exchange to Firebase
  - Silent restore for auto-login
  - Scope negotiation for Google Drive access

- `lib/pages/auth_gate.dart` - Session router
  - Routes authenticated vs. unauthenticated users
  - Triggers offline mode detection

- `lib/services/app_session_controller.dart` - Bootstrap and logout
  - Global initialization of Firebase and auth services
  - Logout cleanup (FCM token removal, session clearing)

**Authorization:**
- Firestore rules-based (server-side validation)
- User role from `allowed_users/{groupId}` collection: `viewer`, `editor`, or `admin`
- Role checked via Firestore security rules before data access

## Monitoring & Observability

**Error Tracking:**
- Not detected - No third-party error tracking service integrated
- Local error handling via `lib/services/error_notification_manager.dart`
- Errors displayed as SnackBar notifications in UI

**Logs:**
- Console/debugPrint - Local debugging only
- No centralized logging infrastructure
- Firebase Functions logs available via Firebase Console

**Analytics:**
- Google Analytics measurement ID configured in `lib/services/firebase_options.dart`: `G-26J77QXPDF` (web), `G-1VWPSRZLT6` (windows)
- Not actively integrated into app code (configuration present but SDK integration not found)

## CI/CD & Deployment

**Hosting:**
- Firebase Hosting - Web app deployment
  - Site: `gspp-9e089`
  - Deployment target: `build/web` directory
  - SPA rewrite configured (`**` → `/index.html`)

**Cloud Functions:**
- Firebase Cloud Functions (Node.js 22)
  - Deployed via `firebase deploy --only functions`
  - Requires Google Cloud Blaze plan (paid) for deployment
  - Development: `firebase emulators:start --only functions`
  - Location: `functions/` directory
  - Main entry: `functions/index.js`

**Build & Deployment Scripts:**
- `flutter build web` - Build web version
- `firebase deploy --only hosting` - Deploy web app
- `firebase deploy --only firestore:rules` - Deploy Firestore rules
- `firebase deploy --only functions` - Deploy Cloud Functions
- VS Code tasks: `DeployFirebase` (automated web build + hosting + rules), `DeployFunctionsBlaze` (separate functions deploy)

**CI Pipeline:**
- Not detected - No GitHub Actions, GitLab CI, or external CI service integrated
- Local manual deployment via Firebase CLI

## Environment Configuration

**Required Environment Variables:**
- Firebase API keys - Embedded in `lib/services/firebase_options.dart` per platform
- FCM Web VAPID key - Can be overridden via `--dart-define=FCM_WEB_VAPID_KEY=...` (default public key hard-coded)
- Google Drive API key - Derived from Firebase API key via `apiKeyForDrive` extension

**Secrets Location:**
- Firebase credentials: `lib/services/firebase_options.dart` (auto-generated by FlutterFire CLI, committed to repo)
- Android: `android/app/google-services.json` (committed)
- iOS/macOS: Xcode configuration (not in version control)
- Private FCM VAPID key: Firebase Console only (not in repo)

**Platform-Specific Configs:**
- `android/app/google-services.json` - Android Firebase project configuration
- `ios/Runner/GoogleService-Info.plist` - iOS Firebase configuration
- `lib/services/firebase_options.dart` - Cross-platform Firebase options (web, android, ios, macos, windows)

## Webhooks & Callbacks

**Incoming Webhooks:**
- Not detected - No public webhook endpoints

**Outgoing Webhooks/Events:**
- Firebase Cloud Messaging (FCM) - Push notifications
  - Triggered by: Firestore document changes via Cloud Functions
  - Targets: User devices via FCM tokens stored in `users/{uid}/devices/{deviceId}`
  - Implementation: Cloud Functions scheduled and event-driven triggers

- Cloud Functions Event Listeners:
  - Firestore triggers: Document changes on notifications, lessons, absences
  - Scheduled tasks: Minute-based reminder delivery
  - HTTP callable functions: Report generation, template preview

**Notification Flow:**
- Firestore document write (e.g., new group notification)
- Cloud Functions trigger (`functions/index.js`)
- Functions query user devices and call FCM API
- FCM delivers push to all user devices
- App receives via `firebase_messaging` and displays via `flutter_local_notifications`
- Payload structure: `PushNavigationRequest` (kind, title, body, groupId, lessonId, notificationId)

**Deep Links:**
- Push notifications include query parameters: `pushKind`, `pushGroupId`, `pushLessonId`, `pushNotificationId`
- App routes to specific page based on push kind (lesson acknowledgement or group notification)

## Report Generation Pipeline

**Callable Functions:**
- Cloud Functions: `functions/report_templates.js` - Safe report DSL evaluation and Excel generation
- Client calls via `cloud_functions` SDK: `CloudFunctions.instance.httpsCallable('generateReport')`
- Input: Template definition, lesson data, group metadata
- Output: `.xlsx` file binary data or preview HTML

**Report Processing:**
- `lib/services/report_templates_service.dart` - CRUD and callable function orchestration
- Templates stored in Firestore: `groups/{groupId}/report_templates/{templateId}`
- Preview mode: Return HTML without file download
- Generation mode: Return binary Excel file for download
- Safe execution: Custom DSL prevents arbitrary code execution

---

*Integration audit: 2026-03-26*
