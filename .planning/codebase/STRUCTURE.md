# Codebase Structure

**Analysis Date:** 2026-03-26

## Directory Layout

```
flutter_application_1/
├── lib/
│   ├── main.dart                       # App entry point, Firebase init
│   ├── globals.dart                    # Service singletons and global state
│   ├── pages/                          # UI screens (stateful widgets)
│   │   ├── auth_gate.dart             # Auth routing, session bootstrap
│   │   ├── login_page.dart            # Google Sign-In UI
│   │   ├── email_check_page.dart      # Loading/email verification screen
│   │   ├── main_scaffold.dart         # Bottom nav, page switching
│   │   ├── home_page.dart             # Dashboard feed, absences, notifications
│   │   ├── profile_page.dart          # User settings, group switching
│   │   ├── access_denied_page.dart    # Insufficient permissions
│   │   ├── admin_page/                # Admin-only features
│   │   │   ├── admin_panel_page.dart # Main admin view with tabs
│   │   │   ├── tabs/                 # Tab pages (absence, members, templates, etc.)
│   │   │   └── widgets/              # Admin-specific dialogs and components
│   │   ├── calendar_page/             # Lesson calendar views
│   │   │   ├── calendar_page.dart    # Calendar container and state
│   │   │   ├── calendar_utils.dart   # Date logic, helper functions
│   │   │   ├── models/               # Calendar-specific models (event, filters)
│   │   │   └── widgets/              # Calendar components (grid, cells, dialogs)
│   │   │       └── views/            # Responsive view implementations
│   │   ├── materials_page/            # Materials/files management
│   │   └── tools_page/                # Report generation, bulk actions
│   ├── services/                      # Business logic and data access
│   │   ├── app_session_controller.dart        # Auth state, session management
│   │   ├── app_snapshot_store.dart            # Hive-based cache layer
│   │   ├── app_runtime_state.dart             # In-memory transient state
│   │   ├── auth_service.dart                  # Google Sign-In, token management
│   │   ├── firestore_manager.dart             # Firestore query abstractions
│   │   ├── profile_manager.dart               # User profile, group context
│   │   ├── calendar_service.dart              # Lesson queries and updates
│   │   ├── absences_service.dart              # Absence records
│   │   ├── templates_service.dart             # Lesson templates
│   │   ├── group_notifications_service.dart   # In-app notifications
│   │   ├── push_notifications_service.dart    # FCM integration
│   │   ├── reports_service.dart               # Report generation
│   │   ├── report_templates_service.dart      # Template CRUD
│   │   ├── dashboard_service.dart             # Home page data
│   │   ├── materials_service.dart             # Materials/documents
│   │   ├── google_drive_service.dart          # Google Drive API client
│   │   ├── drive_catalog_service.dart         # Drive catalog caching
│   │   ├── firebase_options.dart              # Firebase config (generated)
│   │   ├── error_notification_manager.dart    # SnackBar notifications
│   │   ├── startup_telemetry.dart             # App startup metrics
│   │   ├── tools_service.dart                 # Bulk tools
│   │   ├── file_manager/                      # File operations subsystem
│   │   │   ├── file_manager.dart             # Main facade
│   │   │   ├── file_downloader.dart          # HTTP download
│   │   │   ├── file_cache_service.dart       # Local file caching
│   │   │   ├── file_metadata_service.dart    # File info retrieval
│   │   │   ├── file_opener.dart              # Open file actions
│   │   │   ├── file_sharer.dart              # Share file actions
│   │   │   ├── file_exceptions.dart          # Error types
│   │   │   ├── file_cache_entry.dart         # Cache entry model
│   │   │   └── file_metadata.dart            # File metadata model
│   │   ├── reports/                           # Report type implementations
│   │   │   ├── base_report.dart              # Abstract report class
│   │   │   ├── calendar_grid_report.dart     # Calendar export
│   │   │   └── lessons_list_report.dart      # Lessons list export
│   │   └── web_push_environment*.dart         # Web-specific push setup
│   ├── models/                        # Domain models
│   │   ├── lesson_model.dart                 # Lesson data class (~850 lines)
│   │   ├── custom_field_model.dart           # Custom field definitions
│   │   ├── report_template_model.dart        # Report template structure
│   │   ├── instructor_absence.dart           # Absence records
│   │   ├── group_notification.dart           # Notification model
│   │   ├── notification_preferences.dart     # User notification settings
│   │   └── lesson_progress_reminder.dart     # Progress reminder model
│   ├── widgets/                       # Shared UI components
│   │   ├── loading_indicator.dart           # Loading spinner
│   │   ├── absence_request_dialog.dart      # Absence request form
│   │   ├── custom_fields_dialogs.dart       # Custom field editors
│   │   ├── lesson_progress_reminder_editor.dart
│   │   └── web_push_install_banner.dart
│   ├── theme/
│   │   └── app_theme.dart             # Material colors, text styles, theme definition
│   └── mixins/
│       └── loading_state_mixin.dart    # Reusable loading state logic
├── assets/
│   └── icon/
│       └── app_icon.png
├── android/                           # Android native code
├── ios/                               # iOS native code (if applicable)
├── web/                               # Web entrypoint (if applicable)
├── pubspec.yaml                       # Dependencies
├── pubspec.lock                       # Dependency lock
├── analysis_options.yaml              # Lint rules
├── firebase.json                      # Firebase config
└── cloudstore_rules                   # Firestore security rules
```

## Directory Purposes

**lib/pages/:**
- Purpose: Screen-level widgets that users navigate between
- Contains: StatefulWidget pages, full-screen views, navigation logic
- Key files: `main_scaffold.dart` routes between these

**lib/services/:**
- Purpose: Business logic, data access, external integrations
- Contains: Database queries, Firebase operations, API clients, state management
- Key organization: Service per feature (calendar, absences, reports, etc.)

**lib/models/:**
- Purpose: Data classes representing domain objects
- Contains: Serialization to/from Firestore, local storage, copyWith methods
- Key features: fromMap(), toMap(), toFirestore() factories

**lib/widgets/:**
- Purpose: Reusable UI components shared across pages
- Contains: Dialogs, form fields, custom widgets
- Example: `absence_request_dialog.dart` used in multiple pages

**lib/theme/:**
- Purpose: Centralized styling and design tokens
- Contains: Color definitions, text themes, Material theme config
- Used by: MaterialApp theme parameter in main.dart

**lib/services/file_manager/:**
- Purpose: Subsystem for file operations (download, cache, open, share)
- Contains: Layered file operations with caching and platform abstraction
- Key classes: `FileManager` (facade), `FileDownloader`, `FileCacheService`

**lib/services/reports/:**
- Purpose: Report generation implementations
- Contains: Different report formats (calendar grid, lessons list)
- Base class: `BaseReport` with export logic

## Key File Locations

**Entry Points:**
- `lib/main.dart`: App initialization, Firebase setup, Globals init, theme config
- `lib/pages/auth_gate.dart`: Session routing, auth state observation
- `lib/pages/main_scaffold.dart`: Main app navigation hub

**Core Services:**
- `lib/globals.dart`: Service singleton registry and app-wide initialization
- `lib/services/firestore_manager.dart`: Database query abstraction
- `lib/services/app_snapshot_store.dart`: Cache layer (Hive-backed)
- `lib/services/profile_manager.dart`: User context and group state

**Data Models:**
- `lib/models/lesson_model.dart`: Core lesson domain object
- `lib/models/custom_field_model.dart`: Custom field definitions
- `lib/models/report_template_model.dart`: Report templates

**Authentication:**
- `lib/services/auth_service.dart`: Google Sign-In, token management
- `lib/services/app_session_controller.dart`: Session state machine

**Error Handling:**
- `lib/services/error_notification_manager.dart`: SnackBar notifications

**Configuration:**
- `lib/theme/app_theme.dart`: Design tokens and Material theme
- `lib/services/firebase_options.dart`: Firebase config (auto-generated)

## Naming Conventions

**Files:**
- Pages: `snake_case.dart` at top level of pages directory, or in feature subdirectories
  - Example: `home_page.dart`, `admin_page.dart`, `calendar_page/calendar_page.dart`
- Services: `snake_case_service.dart` in `lib/services/`
  - Example: `calendar_service.dart`, `auth_service.dart`
- Models: `snake_case_model.dart` or descriptive singular names
  - Example: `lesson_model.dart`, `instructor_absence.dart`
- Components/Widgets: `descriptive_name.dart` or `descriptive_widget.dart`
  - Example: `lesson_form_dialog.dart`, `calendar_grid.dart`
- Utility/Helper files: `descriptive_utils.dart` or `descriptive_helper.dart`
  - Example: `calendar_utils.dart`

**Directories:**
- Feature-based: `feature_name/` containing related pages, widgets, models
  - Example: `calendar_page/`, `admin_page/`
- Service subsystems: Nested under `services/`
  - Example: `file_manager/`, `reports/`
- Test files: Co-located with implementation (not present in current structure)

## Where to Add New Code

**New Feature (e.g., "Attendance Tracking"):**
- Primary code: `lib/services/attendance_service.dart` (business logic)
- Data model: `lib/models/attendance_model.dart`
- UI page: `lib/pages/attendance_page/attendance_page.dart`
- Components: `lib/pages/attendance_page/widgets/`
- Feature models: `lib/pages/attendance_page/models/`
- Wire into: `lib/globals.dart` (service singleton), `lib/pages/main_scaffold.dart` (nav)

**New Shared Widget:**
- Location: `lib/widgets/new_widget_name.dart`
- Register: Import in pages that need it

**New Admin Feature (e.g., "Settings Management"):**
- Main tab: `lib/pages/admin_page/tabs/settings_tab.dart`
- Tab widgets: `lib/pages/admin_page/widgets/settings_*.dart`
- Service: `lib/services/admin_settings_service.dart`
- Integrate: Add to tab list in `lib/pages/admin_page/admin_panel_page.dart`

**New Report Type:**
- Base: `lib/services/reports/new_report_type.dart` (extends `BaseReport`)
- Integrate: Register in `lib/services/reports_service.dart`

**Utilities/Helpers:**
- Shared utility: `lib/utils/helper_name.dart`
- Feature-specific: `lib/pages/feature_name/feature_utils.dart`

**Theme or Constants:**
- App-wide: Add to `lib/theme/app_theme.dart`
- Feature-specific: Create `lib/pages/feature_name/feature_theme.dart` or constants file

## Special Directories

**`.dart_tool/`:**
- Purpose: Generated build artifacts
- Generated: Yes (by Flutter)
- Committed: No (in .gitignore)

**`build/`:**
- Purpose: Compiled app binaries and intermediates
- Generated: Yes (by Flutter)
- Committed: No (in .gitignore)

**`.firebase/`:**
- Purpose: Firebase CLI cache
- Generated: Yes (by Firebase)
- Committed: No (in .gitignore)

**`android/`, `ios/`, `web/`:**
- Purpose: Platform-specific native code and resources
- Generated: Partially (gradle, pods, etc.)
- Committed: Yes (configuration), No (build artifacts)

---

*Structure analysis: 2026-03-26*
