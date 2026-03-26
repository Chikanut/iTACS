# GSPP Platform — Auth & File Management Overhaul

## What This Is

Flutter web-based platform for GSPP (group management system) where administrators and participants manage groups, materials, and files linked to Google Drive/Docs. The platform uses Firebase Authentication and Firestore for data, with Google Drive as file storage. Currently used across multiple browser sessions and devices.

## Core Value

Users can open any Google Doc/Drive file from the platform without re-authenticating, and see an up-to-date file list in real time regardless of which browser or tab they use.

## Requirements

### Validated

- ✓ Firebase Authentication (Google sign-in) — existing
- ✓ Firestore-backed group management — existing
- ✓ Google Drive file linking (fileId stored in Firestore) — existing
- ✓ Role-based access (admin/participant) — existing
- ✓ Materials/Tools section per group — existing

### Active

- [ ] Google OAuth token persists across browser restarts (no repeated Google login)
- [ ] Google Docs/Drive files open without re-auth after page reload
- [ ] File list syncs in real time across all tabs and browsers (Firestore listeners, no manual refresh needed)
- [ ] File upload/add accepts Google Drive URL (not raw file ID)
- [ ] File appears in the list immediately after adding (no page reload required)
- [ ] Admin can delete/replace files from the UI
- [ ] Clear feedback during file operations (loading states, success/error)

### Out of Scope

- Native mobile app — web-first, mobile deferred
- Offline file editing — read-only offline cache at most
- Direct file upload to Firebase Storage — Google Drive remains the storage layer

## Context

**Auth flow:** Google sign-in via `google_sign_in` package → Firebase Auth. A separate Google OAuth token (`GoogleSignInAccount`) is needed to call Drive/Docs APIs. This token is NOT persisted between sessions — the app calls `googleSignIn.signInSilently()` on startup, but this fails in web context if the user hasn't interacted yet or if tokens expired.

**File storage:** Files live in Google Drive. Firestore stores metadata (fileId, name, groupId, type). The Drive file ID is used to construct embed/open URLs.

**Caching issue:** Firestore data is fetched once on screen load and stored locally in widget state. Multiple browser tabs each maintain their own in-memory state — no shared real-time listener.

**Known pain points (from CONCERNS.md):**
- `GoogleSignIn` web implementation has known token persistence issues
- No Firestore `StreamBuilder` usage in materials/tools screens — data fetched once via `Future`
- File add dialog requires raw fileId input
- No optimistic UI updates after mutations

## Constraints

- **Tech stack**: Flutter web — must stay Flutter (no React rewrite)
- **Auth**: Must use Firebase Auth + Google Sign-In (OAuth scopes for Drive already partially configured)
- **Storage**: Files stay in Google Drive — no migration to Firebase Storage
- **No breaking changes**: Existing Firestore schema (groups, materials, tools collections) must be preserved

## Key Decisions

| Decision | Rationale | Outcome |
|----------|-----------|---------|
| Use `gapi` / `google_sign_in` token refresh on app start | Silently re-auth avoids repeated login prompts | — Pending |
| Switch materials/tools data to Firestore streams | Real-time sync eliminates per-browser cache divergence | — Pending |
| Accept Drive URL in file add dialog, extract ID client-side | Friendlier UX — users share links, not IDs | — Pending |
| Optimistic UI update on file add | File appears instantly, Firestore confirms in background | — Pending |

---
*Last updated: 2026-03-26 after initialization*
