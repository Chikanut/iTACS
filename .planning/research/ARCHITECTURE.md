# Architecture Patterns: Auth Persistence + Firestore Real-Time Data

**Domain:** Flutter web — Google OAuth persistence, Firestore real-time sync
**Researched:** 2026-03-26
**Overall Confidence:** HIGH (official Flutter/Firebase docs + direct codebase analysis)

---

## Scope

This document covers two architectural dimensions for the upcoming milestone:

1. **Auth layer** — how to make Google OAuth tokens survive browser restarts
2. **Data layer** — how to restructure MaterialsService and ToolsService to use Firestore real-time streams instead of one-time fetches

Both dimensions are informed by reading the actual source files:
`auth_service.dart`, `app_session_controller.dart`, `materials_service.dart`,
`tools_service.dart`, `materials_page.dart`, `auth_gate.dart`, `globals.dart`.

---

## Current State Diagnosis

### Auth Layer — What Is Broken

`AuthService` currently stores a single boolean flag (`google_signed_in`) in
`SharedPreferences` and relies on `_googleSignInWithDrive.signInSilently()` on
startup to re-acquire a `GoogleSignInAccount` and an access token. The in-memory
fields `_currentGoogleUser`, `_cachedAccessToken`, and `_tokenExpirationTime` are
static class-level variables that are wiped every time the browser tab is closed.

The failure mode is:

```
Browser restart
  → main.dart initializes Globals
  → AppSessionController.initialize()
  → _authService.restoreSession()
  → signInSilently() returns null   (GIS token is gone from browser memory)
  → _cachedAccessToken = null
  → next Drive API call fails with null token
  → GoogleDriveService throws MetadataException
  → Materials/Tools page shows error or empty list
```

Firebase Auth itself survives restarts because the Firebase SDK writes its own
persistence cookie/IndexedDB entry. Only the Google Sign-In OAuth layer loses
state because `google_sign_in_web` (currently v0.12.4) does not persist the
access token to any browser storage — it holds it only in the GIS JavaScript
library's in-memory state.

### Data Layer — What Is Broken

`MaterialsService.getMaterials()` and `ToolsService.getItems()` are `async`
methods that return `Future<List<Map<String, dynamic>>>`. Each call to
`MaterialsPage.fetchMaterials()` is a single snapshot fetch:

```
initState → fetchMaterials() called once
  → getMaterials() → Firestore.get() (one-time read)
  → setState(materials = data)
```

There is no Firestore listener. The page has a `RefreshIndicator` and a
pull-to-refresh mechanism, but no reactive subscription. If another user or
browser tab adds a file to Firestore, this page does not update until the user
manually refreshes.

`ToolsService` has the same structure, with `getItems()` returning a Future.

---

## Recommended Architecture

### Component Boundaries (Post-Redesign)

| Component | Responsibility | Key Change |
|-----------|---------------|------------|
| `AuthService` | Google OAuth lifecycle, token acquisition, silent re-auth | Must persist token refresh trigger durably; not just a boolean flag |
| `AppSessionController` | Session state machine, Firebase Auth listener | No change to the state machine; change is inside `restoreSession` |
| `MaterialsService` | Provide Firestore stream for overlay materials | Replace `Future<List>` with `Stream<List>` from Firestore snapshots |
| `ToolsService` | Provide Firestore stream for overlay items | Same as MaterialsService |
| `MaterialsPage` | React to stream; no manual fetch needed | Replace `fetchMaterials()` + `setState` with `StreamBuilder` |
| `GoogleDriveService` | Drive API calls with valid access token | No structural change; already has retry-on-401 logic |

---

## Auth Layer Architecture

### The Core Problem: Web Has No Persistent OAuth Token

On Flutter web with `google_sign_in` v6.x (current: `^6.1.5`) and
`google_sign_in_web` v0.12.x, the access token lives entirely in the Google
Identity Services (GIS) JavaScript library's in-memory state. When the browser
tab closes, that state is gone. `signInSilently()` will only succeed if the GIS
library can recover from the browser's own session storage — which it does
unreliably and only within the same browser session (not a cold restart).

**The access token expires after 3600 seconds (1 hour). There is no refresh
token available to client-side web apps — this is the OAuth 2.0 implicit/PKCE
constraint for web.** (Source: pub.dev google_sign_in package, confirmed HIGH
confidence.)

### Token Storage on Web: flutter_secure_storage vs shared_preferences

**flutter_secure_storage** uses the Web Crypto API on web, writing AES-encrypted
values to `localStorage`. It works on web but requires HTTPS and does not provide
meaningfully stronger protection than plain `localStorage` in a pure-Flutter web
context — the domain boundary already constrains who can read `localStorage`, and
XSS in a Flutter canvas app is not a typical attack vector. However, there is an
additional wrinkle: it cannot store the OAuth access token in a way that survives
the token expiring, because the token is time-limited regardless.

**shared_preferences** writes plain key-value pairs to `localStorage`. Currently
used by `AuthService` to store `google_signed_in` (a boolean). It is already
in `pubspec.yaml` (`^2.2.2`).

**Recommendation: do not try to persist the raw access token to either storage.**
A stored access token is only valid for 1 hour and has no refresh mechanism on
web. Storing it in `localStorage` or `flutter_secure_storage` provides no
meaningful benefit because:

- After 1 hour it is worthless regardless of where it is stored.
- The Drive API calls already have a retry-on-401 path in `_sendAuthorizedRequest`.
- The real goal is to avoid a full re-login prompt, not to avoid token fetch.

The correct solution is to **rely on Firebase Auth's own persistence** (which
survives restarts via its IndexedDB entry) and use `signInSilently()` as the
recovery path. When `signInSilently()` fails on cold restart, the user sees the
login screen — this is the correct UX for expired Google sessions.

### What Must Change in AuthService

The current `restoreSession()` already has the right structure. The problems are:

1. **`signInSilently()` is called too late** — it happens inside
   `_restoreAndValidate()` which runs after the offline shell is shown. If it
   returns null, there is no attempt to notify the data layer to skip Drive
   calls.

2. **`_cachedAccessToken` is class-level static state** — it is cleared on
   every browser restart (not a storage issue; it is in-memory). The retry
   path in `GoogleDriveService._sendAuthorizedRequest` (401 → `forceRefreshToken`)
   handles this correctly already. The issue is `signInSilently()` failing means
   `getAccessToken()` will also fail.

3. **The `google_signed_in` SharedPreferences boolean is a misleading hint** —
   it makes `restoreSession()` try `signInSilently()` even when the GIS session
   is truly gone. That is acceptable behavior (fail fast), but the error handling
   when it does fail is silent (`catch` that only logs), leaving
   `_currentGoogleUser = null`.

**Architectural change: separate the "Firebase Auth is valid" concern from the
"Drive token is available" concern.**

```
AppSessionController.initialize()
  → restoreSession() → signInSilently() attempt
     ├─ success: _currentGoogleUser set, Drive token will be available
     └─ failure: _currentGoogleUser = null (Drive unavailable, but Firebase OK)

MaterialsPage loads
  → Firestore stream is live (no Drive token needed for overlay materials)
  → Drive folder merge is skipped if _currentGoogleUser == null
  → UI shows overlay-only materials without error
```

The data layer must treat `_currentGoogleUser == null` as "Drive unavailable,
degrade gracefully" rather than as a fatal error. Drive integration is additive
over the Firestore overlay, so overlay materials should be shown regardless.

### google_sign_in v7 Migration Consideration

`google_sign_in` v7 (latest stable at time of research: 7.2.0) replaces
`signInSilently()` with `attemptLightweightAuthentication()` and introduces an
`authenticationEvents` stream. On web, `attemptLightweightAuthentication()` may
display a floating sign-in card (it is no longer guaranteed silent). This is a
breaking API change.

**Do not migrate to v7 in this milestone.** The current v6.1.5 is functional and
v7 requires meaningful refactoring of `AuthService` (the events stream replaces
the Future-returning API). Treat v7 migration as a separate future milestone.
Flag: the `google_sign_in_web` package pins to `0.12.4+4` in `pubspec.yaml`;
this pin is deliberate and correct — do not change it.

### Auth Data Flow (Post-Redesign)

```
Browser cold start
  │
  ├─ Firebase SDK restores auth state from IndexedDB (automatic)
  │
  ├─ AppSessionController.initialize()
  │     └─ authService.restoreSession()
  │           └─ _googleSignInWithDrive.signInSilently()
  │                 ├─ success → _currentGoogleUser set
  │                 └─ failure → _currentGoogleUser = null
  │                              (Drive unavailable, log it, do not throw)
  │
  ├─ Firebase currentUser != null → proceed to validateAuthenticatedUser
  │
  └─ UI renders:
        ├─ Firestore stream active → materials list renders from Firestore overlay
        └─ Drive merge: if _currentGoogleUser == null → skip Drive fetch, show overlay only
             else → merge Drive folder contents as normal
```

---

## Data Layer Architecture

### Firestore Stream Pattern for MaterialsService

The overlay materials (Firestore collection `materials/{groupId}/items`) are pure
Firestore documents — no Drive involvement. These are the records added manually
via the "Add material" dialog. They can and should be a real-time stream.

**The Drive merge layer (folder listing) cannot be a stream** — `listFolderChildren`
is a REST call that returns a `Future`. Drive does not push changes to clients.

**Recommended split:**

```
MaterialsService
  ├─ overlayStream(groupId) → Stream<List<Map>>   (Firestore snapshots)
  └─ fetchDriveFiles(folderId) → Future<List<GoogleDriveFile>>  (unchanged)

MaterialsPage
  ├─ StreamBuilder on overlayStream → always live
  └─ On stream event: if Drive folder configured, merge Drive files (cached)
```

This means the Firestore overlay reacts in real time. A new file added in
another tab appears immediately. Drive file listing is fetched once on page load
and on manual refresh (pull-to-refresh) — Drive does not support push, so this
is correct.

### Firestore Stream Construction

Both `CollectionReference` and `DocumentReference` expose a `.snapshots()`
method that returns a `Stream<QuerySnapshot>`. This is the official FlutterFire
pattern (confirmed HIGH confidence from firebase.flutter.dev).

```dart
// Inside MaterialsService
Stream<List<Map<String, dynamic>>> overlayStream({required String groupId}) {
  return Globals.firestoreManager
      .collectionForGroup(groupId: groupId, collection: 'materials')
      .orderBy('modifiedAt', descending: true)
      .snapshots()
      .map((snapshot) => snapshot.docs.map((doc) { ... }).toList());
}
```

The `FirestoreManager` currently exposes `getDocumentsForGroup()` which returns
a `Future<List<QueryDocumentSnapshot>>`. A new method must be added that returns
the underlying `Query` (or `Stream` directly) so callers can attach `.snapshots()`.

### StreamBuilder Pattern in MaterialsPage

Replace the `fetchMaterials()` / `setState` cycle with a `StreamBuilder`:

```dart
// _MaterialsPageState

Stream<List<Map<String, dynamic>>>? _overlayStream;

@override
void initState() {
  super.initState();
  final groupId = Globals.profileManager.currentGroupId;
  if (groupId != null) {
    _overlayStream = _materialsService.overlayStream(groupId: groupId);
  }
  // Drive files still fetched once via Future on initState
  _initDriveFiles();
}

@override
Widget build(BuildContext context) {
  return StreamBuilder<List<Map<String, dynamic>>>(
    stream: _overlayStream,
    builder: (context, snapshot) {
      if (snapshot.hasError) { /* show error */ }
      if (!snapshot.hasData) { return LoadingIndicator(); }
      final overlayItems = snapshot.data!;
      final merged = _mergeWithCachedDriveFiles(overlayItems);
      return _buildList(merged);
    },
  );
}
```

Key points:
- `StreamBuilder` disposes the stream subscription automatically when the widget
  is removed from the tree. No `StreamSubscription` management needed.
- The `_overlayStream` must be initialized once in `initState`, not inside
  `build` — creating it inside `build` would create a new subscription on every
  rebuild.
- Drive files are fetched once and cached locally in widget state. They are
  re-fetched on pull-to-refresh (keep `RefreshIndicator`).
- `snapshot.connectionState == ConnectionState.waiting` replaces the
  `isLoading('fetch_materials')` check for initial load.

### Hive Cache Interaction

Currently, `getMaterials()` writes to `AppSnapshotStore` (Hive) after each
fetch. With a stream, the cache write moves to a `StreamBuilder` side-effect:
when new overlay data arrives, write it to Hive for offline support. This keeps
the offline-first fallback intact.

The cache key `cache::materials::{groupId}` remains unchanged. On startup, the
app can hydrate the widget with cached data (as `_hydrateCachedMaterials()` does
today) and then the stream replaces it with live data.

### ToolsService — Same Pattern

`ToolsService.getItems()` has the same Future-based structure. The overlay
collection is `tools_by_group/{groupId}/items`. The same stream split applies:

- `overlayStream(groupId, parentId)` → Firestore `snapshots()`
- `fetchDriveFolder(folderId)` → unchanged Future

The `ToolsPage` (not fully read but same pattern as MaterialsPage based on
service structure) should receive the same StreamBuilder treatment.

### State Management: No Provider/Riverpod Addition Required

The codebase uses **no Provider or Riverpod** — it uses a custom singleton
service pattern via `Globals` and `ChangeNotifier` (`SessionController`). The
existing `AnimatedBuilder` on `_controller` in `AuthGate` is the only reactive
widget pattern in use.

**Do not introduce Provider or Riverpod in this milestone.** The `StreamBuilder`
widget is sufficient for the data layer redesign and fits the existing
architecture without adding a state management dependency. Adding Riverpod would
require wrapping the widget tree in `ProviderScope` and converting services to
providers — this is out of scope and contradicts the "no breaking changes"
constraint.

The `StreamBuilder` approach is the pattern recommended by FlutterFire's
official documentation and requires no additional packages.

---

## Anti-Patterns to Avoid

### Anti-Pattern 1: Persisting the Raw OAuth Access Token

**What:** Writing `_cachedAccessToken` to SharedPreferences or flutter_secure_storage.

**Why bad:** The token expires in 3600 seconds. On cold restart, the stored token
is likely expired. Retrieving it gives false confidence and the next Drive API
call fails with 401 anyway. The retry path in `_sendAuthorizedRequest` handles
401 correctly already.

**Instead:** Rely on `signInSilently()` to re-acquire a fresh token silently.
When that fails, degrade gracefully (show overlay materials without Drive merge).

### Anti-Pattern 2: Creating a StreamBuilder Stream Inside build()

**What:** `StreamBuilder(stream: _materialsService.overlayStream(...), ...)`
placed inside `Widget build(BuildContext context)`.

**Why bad:** Every rebuild creates a new `Stream` instance and a new Firestore
listener. This multiplies Firestore read counts and listener connections rapidly.

**Instead:** Initialize the stream once in `initState()` and assign to a field.
`StreamBuilder` re-subscribes automatically if the `stream` parameter reference
changes — so keep the reference stable.

### Anti-Pattern 3: Blocking UI on signInSilently()

**What:** Awaiting `signInSilently()` before showing any UI (as currently done
inside `_restoreAndValidate` which is on the critical path to showing the
offline shell).

**Why bad:** On web, `signInSilently()` can hang for several seconds or timeout.
The Firebase session is already established; making the whole app wait for a
Drive token is unnecessary.

**Instead:** `signInSilently()` should complete in the background. The
`restoreSession()` call already uses `unawaited()` in the offline shell path
but waits in the online path. Ensure Drive token recovery never blocks the
Firestore data path.

### Anti-Pattern 4: Merging Drive Files Inside the Stream Callback

**What:** Calling `listFolderChildren()` (a Drive REST call) every time the
Firestore snapshot emits.

**Why bad:** A Firestore stream can emit on any document change (including
metadata changes). Triggering a Drive REST call on every Firestore event
generates excessive Drive API traffic and makes the UI flicker on every edit.

**Instead:** Drive file listing is fetched once on mount, cached in widget state,
and refreshed only on user pull-to-refresh. The stream drives only the Firestore
overlay layer.

---

## Scalability Considerations

| Concern | Current (1 group, ~20 files) | Future (10 groups, ~200 files) |
|---------|------------------------------|-------------------------------|
| Firestore stream connections | 1 per open page per tab | N per open page per tab — add query limits |
| Drive API calls | 1 per page load | Same — no change, Drive is not streamed |
| Token re-auth prompts | Every browser restart | Still every restart — fundamental web OAuth constraint |
| Offline cache | Hive single-key per group | Same structure, scales fine |

---

## Build Order Implications for Roadmap

The two changes are largely independent but the auth layer should be stabilized
first because:

1. Drive file merging in `MaterialsService` depends on a valid access token.
   If the token acquisition logic is broken, merged Drive results will be
   unpredictable during development of the stream layer.

2. The stream layer only touches Firestore overlay data. It can be developed
   and tested without Drive tokens (overlay-only mode works without auth).

**Suggested phase order:**

1. **Auth stabilization** — fix `restoreSession()` to degrade gracefully when
   `signInSilently()` fails; ensure overlay materials render without Drive.
   Add Drive-unavailable UI state.

2. **Stream data layer** — add `overlayStream()` to `MaterialsService` and
   `ToolsService`; refactor `MaterialsPage` to `StreamBuilder`; update Hive
   write to be stream-triggered.

3. **File add UX** — URL parsing, optimistic insert, delete/replace (these
   build on top of a working stream so the new item appears immediately).

---

## Sources

- [google_sign_in package — pub.dev](https://pub.dev/packages/google_sign_in)
  (HIGH confidence — official package page, current version 7.2.0, v6 behavior documented)
- [Cloud Firestore FlutterFire usage](https://firebase.flutter.dev/docs/firestore/usage/)
  (HIGH confidence — official FlutterFire documentation, snapshots() StreamBuilder pattern)
- [signInSilently does not resolve on Web — flutter/flutter #138675](https://github.com/flutter/flutter/issues/138675)
  (HIGH confidence — official issue tracker confirming web signInSilently limitations)
- [google_sign_in does not silently re-auth after restart — flutter/flutter #174736](https://github.com/flutter/flutter/issues/174736)
  (HIGH confidence — official issue tracker)
- [Securely Storing JWTs in Flutter Web Apps](https://carmine.dev/posts/flutterwebjwt/)
  (MEDIUM confidence — well-cited community article on web localStorage security model)
- [flutter_secure_storage web behavior — pub.dev](https://pub.dev/packages/flutter_secure_storage)
  (HIGH confidence — official package documentation noting web uses localStorage + Web Crypto)
- [Google Sign-In v7 Migration Guide](https://isaacadariku.medium.com/google-sign-in-flutter-migration-guide-pre-7-0-versions-to-v7-version-cdc9efd7f182)
  (MEDIUM confidence — community migration guide confirmed against official changelog)
- [When to use Realtime Updates vs One-Time Reads in Flutter](https://codewithandrea.com/articles/realtime-updates-vs-one-time-reads-flutter/)
  (MEDIUM confidence — Andrea Bizzotto, widely cited Flutter architecture resource)
