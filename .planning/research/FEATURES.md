# Feature Landscape: Google Drive File Management UX

**Domain:** Drive-integrated file management in a Flutter web group-management platform
**Researched:** 2026-03-26
**Overall confidence:** HIGH (codebase fully read; Drive API docs fetched; Firestore patterns verified)

---

## Context: What Already Exists

Reading the codebase before researching avoids inventing features the app already has. The current state:

| Capability | Status |
|------------|--------|
| Drive URL accepted in dialog (`_validateUrl` / `extractFileId`) | PARTIAL — works for `drive.google.com/file/d/` and `open?id=` but misses `docs.google.com` workspace URLs |
| File list shown after add | NO — `onRefresh` callback calls `fetchMaterials()` which does a full async reload, no optimistic insert |
| Real-time list sync across tabs | NO — `Future`-based fetch on init; no `StreamBuilder` |
| Admin delete/replace | PARTIAL — `GoogleDriveService.deleteItem()` and `updateFileContent()` exist at service layer; UI path unclear |
| Loading/success/error feedback | YES — `LoadingStateMixin`, `errorNotificationManager.showSuccess/showError` in place |
| Drive scopes configured | YES — `drive.readonly` + `drive.file` already in `_googleSignInScopes` |

---

## Table Stakes

Features users of Drive-integrated web apps universally expect. Absence makes the product feel broken.

| Feature | Why Expected | Complexity | Current Gap |
|---------|--------------|------------|-------------|
| Paste any Drive/Docs URL, get file linked | Users copy share links from Drive; they never see a raw fileId | Low | Regex misses `docs.google.com` workspace URLs (Docs, Sheets, Slides, Forms) |
| File appears in list immediately after "Add" | Standard SaaS UX: submit a form, see the result | Low | Callback triggers full async reload; optimistic insert is absent |
| Delete with a single confirmation step | Users expect a destructive action guard, nothing more | Low | UI path for delete not confirmed in `material_tile.dart` (needs verification) |
| Replace/edit file — same record, new content | Admins update materials without losing history | Medium | `updateFileContent()` exists in service; dialog has "Замінити файл" button |
| Error message when link is invalid or inaccessible | Paste a private-to-someone-else file → clear feedback | Low | `_urlError` fires for regex failure but not for Drive 403/404 after save |
| List updates when another admin adds a file | Multi-tab/multi-user usage is the stated core value | Medium | No Firestore stream listener; each tab is isolated |
| Visual distinction: Google Workspace doc vs uploaded binary | Users treat Docs differently from PDFs | Low | `isGoogleWorkspaceDocument` already on model; tile icon not verified |

---

## Differentiators

Features not universally expected but meaningfully valuable for this audience (group admins and instructors managing training materials).

| Feature | Value Proposition | Complexity | Notes |
|---------|-------------------|------------|-------|
| Tag-based filtering (already built) | Instructors categorize by lesson topic; filter without search | Low | Already implemented; keep and extend |
| Inline Drive file name auto-populated as title | Removes manual title entry when linking an existing Drive file | Low | Call `GoogleDriveService.getFile(fileId)` after URL validates; populate `titleController` if blank |
| "Open in Drive" vs "Download" action split | Workspace files should open in browser; binary files should download | Low | `isGoogleWorkspaceDocument` flag is ready; tile action needs branching |
| Modified-date shown on tile | Instructors need to know if a document is current | Low | `modifiedAt` already stored in Firestore map; surface it in tile |
| Soft-delete / trash instead of hard-delete | Admins panic when they delete the wrong file | Medium | Call `files.trash` API endpoint instead of `files.delete`; Drive recycle bin handles recovery |
| Optimistic insert with Firestore confirmation | File appears in 0 ms; Firestore write happens in background | Medium | Insert a local placeholder into `materials` list state immediately, replace/remove on Firestore response |

---

## Anti-Features

Things that create confusion, support burden, or conflicts with the current architecture. Do not build these.

| Anti-Feature | Why Avoid | What to Do Instead |
|--------------|-----------|-------------------|
| Raw fileId input field (the current "legacy-link" mode) | Non-technical users cannot tell a fileId from a filename | Accept only full URLs; extract the ID silently on save; hide ID everywhere in the UI |
| "Upload mode" toggle ("Використати legacy-посилання") | The switch adds a mode the user must mentally model; it leaks implementation detail | Default to Drive URL input; show file-picker upload only when a `materialsFolderId` is configured and keep the UI path linear |
| Drive Picker (Google Picker API) as a replacement for URL input | Picker requires additional OAuth scope (`drive.readonly` already in use, but Picker needs `https://www.googleapis.com/auth/drive.file` _and_ the Picker script loaded separately); adds JS interop complexity on Flutter web | URL paste is simpler and users already have the link from Drive "Share" |
| Showing raw Drive API error JSON to users | Exposes internals; confuses non-technical instructors | Map Drive status codes to user-friendly Ukrainian strings (403 → "Немає доступу до файлу", 404 → "Файл не знайдено або видалено") — the service already does this for some paths |
| Per-material Drive permission management | Sharing settings live in Drive itself; replicating them in the app creates a second source of truth | Link to the file's Drive share settings page if the user needs to change permissions |
| Pagination / infinite scroll for materials list | Groups have tens of materials, not thousands; pagination adds navigation overhead | Keep a flat list; filtering and search are sufficient |
| Separate "sync now" button | Real-time Firestore streams make manual sync unnecessary once implemented | Switch to `StreamBuilder`; remove the manual refresh FAB or reduce it to a fallback |

---

## URL-to-ID Extraction: Complete Pattern Mapping

The current regex in `file_manager.dart` (`extractFileId`):

```
r'd(?:/|rive/folders/|/file/d/|/open\?id=|/uc\?id=)([a-zA-Z0-9_-]{10,})'
```

**Formats it handles:**
- `drive.google.com/file/d/{ID}/view`
- `drive.google.com/drive/folders/{ID}`
- `drive.google.com/open?id={ID}`
- `drive.google.com/uc?id={ID}`

**Formats it MISSES (users paste these constantly):**
- `docs.google.com/document/d/{ID}/edit` — Google Docs
- `docs.google.com/spreadsheets/d/{ID}/edit` — Google Sheets
- `docs.google.com/presentation/d/{ID}/edit` — Google Slides
- `docs.google.com/forms/d/{ID}/edit` — Google Forms
- `drive.google.com/file/d/{ID}/view?usp=sharing` — sharing links (already matched by the existing pattern, `usp=` is a query param after the path)

**Recommended comprehensive pattern** (MEDIUM confidence — derived from multiple community sources and the existing pattern logic):

```dart
static String? extractFileId(String url) {
  // Handles: /d/{ID}, /folders/{ID}, open?id={ID}, uc?id={ID}, export?id={ID}
  final pattern = RegExp(
    r'(?:'
    r'/d/([a-zA-Z0-9_-]{15,})'       // /d/{ID} — covers docs, sheets, slides, drive/file
    r'|/folders/([a-zA-Z0-9_-]{15,})' // /folders/{ID}
    r'|[?&]id=([a-zA-Z0-9_-]{15,})'  // ?id= or &id=
    r')',
  );
  for (final match in pattern.allMatches(url)) {
    for (int i = 1; i <= match.groupCount; i++) {
      final group = match.group(i);
      if (group != null && group.isNotEmpty) {
        return group;
      }
    }
  }
  return null;
}
```

Minimum ID length raised to 15 to avoid matching short path segments. Google Drive IDs are 25–33 characters; the existing 10-char minimum is too permissive.

---

## Real-Time List Update Patterns

### Problem
`MaterialsPage` calls `getMaterials()` once at init (with a Hive cache fallback). Each browser tab is independent. Adding a material in one tab does not appear in another.

### Solution: Switch to Firestore Stream

The recommended pattern (HIGH confidence — from FlutterFire official docs and community):

```dart
// In MaterialsService
Stream<List<Map<String, dynamic>>> watchMaterials({required String groupId}) {
  return Globals.firestoreManager
      .collectionStreamForGroup(groupId: groupId, collection: 'materials')
      .map((snapshot) => snapshot.docs.map((doc) {
            final data = Map<String, dynamic>.from(doc.data() as Map);
            return {...data, 'id': doc.id, 'overlayId': doc.id};
          }).toList());
}
```

Use `StreamBuilder` in `MaterialsPage` instead of `FutureBuilder`-equivalent pattern. The stream automatically delivers updates from any source (other tabs, other admins, server-side changes).

### Optimistic Insert (for Add)

When the user taps "Додати" and the dialog closes:

1. Immediately prepend a placeholder item to the local `materials` list with a generated temporary ID and `isOptimistic: true` flag.
2. Fire the Firestore write.
3. The Firestore stream delivers the confirmed document within ~100-300 ms; remove the placeholder by matching `overlayId`.
4. On error, remove the placeholder and show the error SnackBar.

This gives the perception of instant insert while the Firestore stream provides eventual consistency across all tabs.

---

## Drive API Permission Scopes Needed

**Already configured in `auth_service.dart`:**

| Scope | URI | Purpose |
|-------|-----|---------|
| `drive.readonly` | `https://www.googleapis.com/auth/drive.readonly` | Read file metadata and content |
| `drive.file` | `https://www.googleapis.com/auth/drive.file` | Create/update files the app uploaded |

**Assessment:** These two scopes cover all operations needed for this milestone:
- Listing folder children: `drive.readonly`
- `files.get` metadata: `drive.readonly`
- Upload new file: `drive.file`
- Update file content: `drive.file`
- Delete/trash file: `drive.file` (for files the app created) OR `drive` (for externally-created files)

**Critical constraint:** `drive.file` only grants access to files created by this app. If an admin links a Drive file that pre-exists (pasted URL from a file they own), the app cannot delete or update it — only the owner through Drive can. This is the correct behavior for the URL-linking flow (the app should only manage files it created via upload; linked-by-URL files are managed in Drive directly).

**No new scopes required for this milestone.** The existing `drive.readonly` + `drive.file` combination is correct.

**Verification level note:** `drive.readonly` is a restricted scope (per Google's classification) and requires OAuth App Verification if the app is published publicly. For an internal tool with a limited set of authorized users this is acceptable. (MEDIUM confidence — based on official Google docs; verification thresholds depend on app publication status.)

---

## Feature Dependencies

```
URL-to-ID extraction fix
  → inline Drive filename auto-populate (requires getFile() call after extraction)
  → remove legacy-link toggle (URL extraction must be complete first)

Firestore StreamBuilder for list
  → remove manual pull-to-refresh as primary update mechanism
  → enable optimistic insert (stream cancels the placeholder naturally)

Delete action in tile UI
  → confirm current MaterialTile implementation has delete button
  → wire to GoogleDriveService.deleteItem() (for uploaded files) OR just Firestore doc delete (for linked files)
```

---

## MVP Recommendation

Prioritize for this milestone in order:

1. **Fix URL extraction regex** — covers `docs.google.com` workspace URLs. One-line change with high user-visible impact. Zero risk.

2. **Auto-populate title from Drive filename** — call `getFile(fileId)` after regex validates; fill `titleController` if empty. Removes the most common friction step.

3. **Optimistic insert after "Add"** — insert local placeholder immediately, let Firestore stream confirm. Works even before full StreamBuilder migration.

4. **StreamBuilder migration for materials list** — replace `Future`-based fetch with `collectionChanges` stream. This is the structural change; do it as a single commit.

5. **Delete confirmation in MaterialTile** — confirm the action button is wired to service layer with a confirmation dialog. Low code, high admin value.

Defer:
- **Soft-delete (trash instead of hard-delete):** Requires Drive `files.update` with `trashed: true`; adds API complexity. Build after core flow is stable.
- **"Open in Drive" vs "Download" split action:** Needs tile redesign; not blocking the primary add/view/delete loop.

---

## Sources

- FlutterFire official Firestore docs: https://firebase.flutter.dev/docs/firestore/usage/
- Firebase Firestore real-time listeners: https://firebase.google.com/docs/firestore/query-data/listen
- Google Drive API OAuth scopes (official): https://developers.google.com/workspace/drive/api/guides/api-specific-auth
- Google Drive URL format reference: https://community.zapier.com/show-tell-5/gdrive-file-link-formats-gsheets-gdocs-gslides-25077
- Drive URL extraction patterns (community): https://github.com/dandyraka/GDriveRegex
- Optimistic UI pattern: https://crystallize.com/answers/tech-dev/what-is-optimistic-ui
- Delete/undo UX patterns: https://medium.com/@ogonzal87/a-cheatsheet-of-the-most-common-interaction-patterns-delete-b95f355d8331
- Real-time Flutter/Firestore 2026 guide: https://medium.com/@saadalidev/building-real-time-flutter-apps-with-firebase-firestore-2026-complete-guide-4f12338b0c50
