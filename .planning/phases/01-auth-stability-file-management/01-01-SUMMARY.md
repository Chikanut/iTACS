---
phase: 01-auth-stability-file-management
plan: "01"
subsystem: auth
tags: [google-drive, auth, firestore, error-handling]
dependency_graph:
  requires: []
  provides:
    - AuthService.isDriveSessionAvailable getter
    - AuthService.reconnectDrive() method
    - AuthService.getAccessToken() with allowInteractiveRecovery: true
    - FirestoreManager.streamDocumentsForGroup() real-time stream
  affects:
    - plan 01-02 (DriveSessionBanner uses isDriveSessionAvailable and reconnectDrive)
    - plan 01-02 (MaterialsService uses streamDocumentsForGroup)
tech_stack:
  added: []
  patterns:
    - GoogleSignIn interactive recovery on user gesture
    - Firestore .snapshots() stream with .map() projection
    - debugPrint error logging with context strings
key_files:
  created: []
  modified:
    - lib/services/auth_service.dart
    - lib/services/firestore_manager.dart
    - lib/pages/materials_page/material_dialogs.dart
decisions:
  - allowInteractiveRecovery: true in getAccessToken() is safe because _getAccessTokenForScopes only calls signIn() when user is Firebase-authenticated and it is user-gesture-initiated
  - streamDocumentsForGroup uses same path pattern (collection/groupId/items) as getDocumentsForGroup to maintain consistency
  - _loadCatalogConfig catch sets _useManualLink=true as fallback so dialog remains functional when Drive config cannot be loaded
metrics:
  duration: "~2 minutes"
  completed: 2026-03-27
  tasks_completed: 3
  files_modified: 3
---

# Phase 01 Plan 01: Auth Foundation and Error Logging Summary

Fixed Google Drive token loss on page reload by enabling interactive recovery in `getAccessToken()`, added Drive session reconnect capability with `isDriveSessionAvailable`/`reconnectDrive()`, added Firestore real-time streaming, and replaced all silent `catch (_) {}` blocks with logged error handling.

## Tasks Completed

| Task | Name | Commit | Files |
|------|------|--------|-------|
| 1 | Add isDriveSessionAvailable, reconnectDrive(), fix getAccessToken() | ff40262 | lib/services/auth_service.dart |
| 2 | Add streamDocumentsForGroup() to firestore_manager.dart | b71acb2 | lib/services/firestore_manager.dart |
| 3 | Fix silent catch blocks in material_dialogs.dart | c526c6c | lib/pages/materials_page/material_dialogs.dart |

## What Was Built

**auth_service.dart (3 changes):**
- `isDriveSessionAvailable` getter: returns `_currentGoogleUser != null`, enabling UI to check Drive status without triggering auth
- `reconnectDrive()` method: interactive sign-in that caches token and saves state on success, returns bool
- `getAccessToken()` `allowInteractiveRecovery` changed from `false` to `true`: existing `_getAccessTokenForScopes` logic already handles this safely (only triggers popup when Firebase user is authenticated and call is user-initiated)

**firestore_manager.dart (1 addition):**
- `streamDocumentsForGroup()`: real-time counterpart to `getDocumentsForGroup()`, uses `.snapshots().map()` pattern on the `collection/groupId/items` sub-collection path, returns `Stream<List<QueryDocumentSnapshot<Map<String, dynamic>>>>`

**material_dialogs.dart (5 catch block replacements):**
- `_loadSuggestedTags`: `catch (e)` with `debugPrint('MaterialDialog: failed to load suggested tags: $e')`
- `_loadCatalogConfig`: `catch (e)` with log + `_useManualLink = true` fallback (dialog stays functional)
- `_pasteFromClipboard`: `catch (e)` with `debugPrint('MaterialDialog: clipboard read failed: $e')`
- `_saveMaterial` existing file metadata: `catch (e)` with fileId context in log message
- `_saveMaterial` manual URL metadata: `catch (e)` with comment noting DateTime.now() fallback

## Decisions Made

1. **`allowInteractiveRecovery: true` is safe for `getAccessToken()`** — The existing `_getAccessTokenForScopes` implementation already gates the interactive popup behind two conditions: `account == null` (silent sign-in failed) AND `Globals.firebaseAuth.currentUser != null` (user is authenticated in Firebase). The method is only called from user-gesture-driven code paths (file open, reconnect button), so browser popup blockers will not fire.

2. **`streamDocumentsForGroup` uses identical sub-collection path** as `getDocumentsForGroup` (`collection/groupId/items`) for consistency. The stream version intentionally omits the `orderBy`/`whereEqual` parameters present in the fetch version — filtering can be added later if needed per plan 01-02 requirements.

3. **`_loadCatalogConfig` fallback** sets `_useManualLink = true` on error so the dialog remains fully usable even when Drive catalog config cannot be fetched. This preserves the existing UX pattern where missing config falls back to manual link mode.

## Deviations from Plan

None - plan executed exactly as written.

## Self-Check

**Files exist:**
- lib/services/auth_service.dart: isDriveSessionAvailable getter on line 37, reconnectDrive() method on line 304, allowInteractiveRecovery: true on line 132 - FOUND
- lib/services/firestore_manager.dart: streamDocumentsForGroup() on line 95 - FOUND
- lib/pages/materials_page/material_dialogs.dart: zero bare catch (_) blocks - CONFIRMED

**Commits exist:**
- ff40262: feat(01-auth-01): add isDriveSessionAvailable, reconnectDrive(), fix getAccessToken - FOUND
- b71acb2: feat(01-auth-01): add streamDocumentsForGroup() to FirestoreManager - FOUND
- c526c6c: fix(01-auth-01): replace silent catch blocks with debugPrint logging in material_dialogs.dart - FOUND

## Self-Check: PASSED
