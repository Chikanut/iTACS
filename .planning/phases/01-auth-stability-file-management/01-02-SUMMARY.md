---
phase: 01-auth-stability-file-management
plan: "02"
subsystem: ui
tags: [google-drive, auth, firestore, streaming, real-time, materials, tools]
dependency_graph:
  requires:
    - AuthService.isDriveSessionAvailable (plan 01-01)
    - AuthService.reconnectDrive() (plan 01-01)
    - FirestoreManager.streamDocumentsForGroup() (plan 01-01)
  provides:
    - DriveSessionBanner widget (Globals.authService.isDriveSessionAvailable / reconnectDrive())
    - MaterialsService.streamOverlayMaterials() real-time stream
    - MaterialsPage real-time overlay subscription with dispose() cleanup
    - DriveSessionBanner integrated in MaterialsPage and ToolsPage
  affects:
    - MaterialsPage: real-time Firestore updates (changes appear across tabs within ~3s)
    - ToolsPage: Drive session recovery prompt visible when session is lost
tech_stack:
  added: []
  patterns:
    - StreamSubscription with dispose() cancellation (memory-leak-free)
    - Stream.listen() with onError for graceful degradation
    - Overlay+Drive merge pattern (Drive files augmented with Firestore metadata)
    - StatefulWidget with initState drive session check
key_files:
  created:
    - lib/widgets/drive_session_banner.dart
  modified:
    - lib/services/materials_service.dart
    - lib/pages/materials_page/materials_page.dart
    - lib/pages/tools_page/tools_page.dart
decisions:
  - fetchMaterials() retained for backward compat (RefreshIndicator + MaterialTile.onRefresh callbacks) but now delegates to _loadDriveFolderFiles(); overlay stream is always live
  - _mergeOverlayWithDrive() places Drive-folder files first then appends overlay-only items, sorted by modifiedAt descending
  - DriveSessionBanner checks isDriveSessionAvailable once in initState (not reactive) - sufficient since banner hides after successful reconnect
metrics:
  duration: "~7 minutes"
  completed: 2026-03-27
  tasks_completed: 4
  files_modified: 4
---

# Phase 01 Plan 02: Drive Session Banner and Real-Time Materials Streaming Summary

DriveSessionBanner widget with one-tap reconnect, MaterialsService Firestore streaming via StreamSubscription with dispose() cleanup, and banner integration in MaterialsPage and ToolsPage.

## Tasks Completed

| Task | Name | Commit | Files |
|------|------|--------|-------|
| 1 | Create DriveSessionBanner widget | 5e04e5f | lib/widgets/drive_session_banner.dart |
| 2 | Add streamOverlayMaterials() to MaterialsService | d9c2fc5 | lib/services/materials_service.dart |
| 3 | Integrate stream subscription and banner in MaterialsPage | b3e79ca | lib/pages/materials_page/materials_page.dart |
| 4 | Add DriveSessionBanner to ToolsPage | 9dcc369 | lib/pages/tools_page/tools_page.dart |

## What Was Built

**drive_session_banner.dart (new file):**
- `_visible` initialized from `Globals.authService.isDriveSessionAvailable` in `initState`
- Amber banner with cloud_off icon, descriptive text, and reconnect TextButton
- `_reconnect()` shows CircularProgressIndicator, calls `reconnectDrive()`, hides banner on success
- On failure shows error via `Globals.errorNotificationManager.showError()`
- Returns `SizedBox.shrink()` when Drive session is available

**materials_service.dart (2 additions):**
- `streamOverlayMaterials({required String groupId})`: returns `Stream<List<Map<String, dynamic>>>` via `streamDocumentsForGroup().map()`
- `_mapDocToMaterial(QueryDocumentSnapshot<Map<String, dynamic>> doc)`: shared transformation used by both `_getOverlayMaterials()` (Future path) and `streamOverlayMaterials()` (Stream path)
- `_getOverlayMaterials()` refactored to cast and use `_mapDocToMaterial()` — no duplication

**materials_page.dart (major restructure):**
- Added `StreamSubscription<List<Map<String, dynamic>>>? _overlaySubscription` field
- Added `_overlayMaterials` and `_driveFiles` as separate state lists
- `initState`: `_hydrateCachedMaterials()` → `_subscribeToOverlayStream()` → `unawaited(_loadDriveFolderFiles())`
- `dispose()` cancels `_overlaySubscription` to prevent memory leaks
- `_subscribeToOverlayStream()` updates `materials` via `_mergeOverlayWithDrive()` on each Firestore emission
- `_loadDriveFolderFiles()` fetches Drive folder separately, merges with current overlay state
- `_mergeOverlayWithDrive()` merges both sources (Drive items enriched with overlay metadata, then overlay-only items appended)
- `_rebuildTags()` recomputes sorted tag counts from merged materials
- `DriveSessionBanner` placed as first child in build Column, above search bar

**tools_page.dart (minor addition):**
- Import `drive_session_banner.dart` added
- `DriveSessionBanner` placed as first child in body Column (above breadcrumbs)
- `onReconnected` calls `unawaited(fetchItems())` to reload tools after Drive reconnect

## Decisions Made

1. **`fetchMaterials()` retained for backward compatibility** — RefreshIndicator and MaterialTile use this callback. After restructure, it updates role/canEdit state and delegates Drive loading to `_loadDriveFolderFiles()`. The Firestore overlay stream runs independently and handles real-time updates.

2. **`_mergeOverlayWithDrive()` merge strategy** — Drive folder items appear first (merged with overlay metadata when fileId matches), then overlay-only items (not present in Drive folder) are appended. Result sorted by `modifiedAt` descending. This matches the existing `_mergeDriveFilesWithOverlay()` pattern in `MaterialsService`.

3. **`DriveSessionBanner` checks session once in `initState`** — Not reactive to session changes after render. Sufficient because: (a) banner hides itself after `reconnectDrive()` success, (b) session loss is detected at next page load. A reactive approach would require a ChangeNotifier or stream on AuthService — deferred to future plan if needed.

## Deviations from Plan

**[Rule 2 - Missing functionality] Kept fetchMaterials() as reload method**
- **Found during:** Task 3
- **Issue:** Plan suggested removing `fetchMaterials()` if only called from `initState`, but it is also used in `RefreshIndicator.onRefresh`, `MaterialTile.onRefresh`, and `showAddMaterialDialog` callbacks
- **Fix:** Kept `fetchMaterials()` but restructured it to update role state and call `_loadDriveFolderFiles()` — overlay stream handles Firestore in real time, so this is correct behavior
- **Files modified:** lib/pages/materials_page/materials_page.dart

## Self-Check

**Files exist:**
- lib/widgets/drive_session_banner.dart - FOUND
- lib/services/materials_service.dart: streamOverlayMaterials() on line 72, _mapDocToMaterial() on line 80 - FOUND
- lib/pages/materials_page/materials_page.dart: StreamSubscription on line 26, _overlaySubscription?.cancel() on line 49, DriveSessionBanner on line 466 - FOUND
- lib/pages/tools_page/tools_page.dart: DriveSessionBanner on line 722 - FOUND

**Commits exist:**
- 5e04e5f: feat(01-02): create DriveSessionBanner widget - FOUND
- d9c2fc5: feat(01-02): add streamOverlayMaterials() and _mapDocToMaterial() to MaterialsService - FOUND
- b3e79ca: feat(01-02): integrate stream subscription and DriveSessionBanner in MaterialsPage - FOUND
- 9dcc369: feat(01-02): add DriveSessionBanner to ToolsPage - FOUND

## Self-Check: PASSED
