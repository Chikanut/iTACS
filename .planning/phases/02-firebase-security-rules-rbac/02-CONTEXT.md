# Phase 2: Firebase Security Rules & RBAC - Context

**Gathered:** 2026-04-11
**Status:** Ready for planning

<domain>
## Phase Boundary

Review and harden the Firestore security rules in `cloudstore_rules` so each user role has access only to the collections and operations it is permitted to use. No UI changes, no schema migrations — rules file only.

Role matrix:
- **Viewer (teacher):** read lessons, fill custom fields on assigned lessons, submit and cancel own absence/sick-leave requests, read materials and tools (download/view), read and write own profile page
- **Editor:** create/edit lessons, add/delete materials and resources, manage tools, assign teachers to lessons
- **Admin:** full access to all collections and the admin panel data

</domain>

<decisions>
## Implementation Decisions

### files collection
- Restrict read to group members only: `allow read: if isInGroup(resource.data.groupId)`
- **Prerequisite:** Must verify that file documents in Firestore have a `groupId` field. If they don't, the rule cannot use `isInGroup(resource.data.groupId)` — fallback is to add the field or keep `request.auth != null` until schema is confirmed.
- Write (create/update/delete): editor+ only (`hasEditorRights(groupId)`) — viewers are read-only
- No app-wide public files — all files are group-scoped

### allowed_users read access
- Desired restriction: group members only (`isInGroup(groupId)`)
- **Circular dependency:** `isInGroup()` itself reads `allowed_users/{groupId}` via `get()`. Restricting reads using `isInGroup()` would make the helper call itself and break auth.
- **Decision:** Keep `allow read: if request.auth != null` for now. Accept that member emails + roles are readable by any authenticated app user. The data (emails + viewer/editor/admin roles) is low-sensitivity.
- create/delete: keep as `false` — groups are provisioned via backend/Admin SDK, not client-side

### Existing rules — confirmed correct, no changes needed
- `lessons`: read = isInGroup ✓, custom fields update = assigned instructor only ✓, absence create/cancel = any group member with correct fields ✓
- `materials`, `tools_by_group`: read = isInGroup ✓, write = editor+ ✓
- `users/{userId}`: read = any auth user ✓, write = own document only (`request.auth.uid == userId`) ✓
- `instructor_absences`: viewer can create vacation/sick_leave with status=pending ✓, can cancel own pending ✓, admin has full write ✓
- `groups`, `templates`, `report_templates`, `autocomplete_data`, `notifications`: editor/admin gates ✓

### Claude's Discretion
- If `files` documents lack a `groupId` field, choose the least-breaking fallback (e.g., keep current rule and add a TODO comment, or propose schema change)
- Field-level write restrictions on `users/{userId}` — current full-write-own is acceptable; no need to lock individual fields unless code review reveals a specific risk

</decisions>

<code_context>
## Existing Code Insights

### Reusable Assets
- `cloudstore_rules` — single file at repo root; all changes go here
- `isInGroup()`, `hasEditorRights()`, `hasAdminRights()`, `getUserRole()` — existing helper functions; reuse, don't rewrite
- `firebase.json` — references the rules file for deployment

### Established Patterns
- Role check pattern: helper functions (`isInGroup`, `hasEditorRights`, `hasAdminRights`) are referenced in all match blocks — follow same pattern for any new rules
- Field-level restriction pattern: `request.resource.data.diff(resource.data).affectedKeys().hasOnly([...])` — already used for custom fields, absence status, etc.
- Circular dependency workaround: `allowed_users` is read by `isInGroup()` so its own read rule must stay at `request.auth != null`

### Integration Points
- `firebase.json` → `"rules": "cloudstore_rules"` — deploying rules via `firebase deploy --only firestore:rules`
- The Firestore `files` collection is defined in rules but the app code does not reference it directly via `FirebaseFirestore.instance.collection('files')` — verify whether it's legacy or used by a Cloud Function

</code_context>

<specifics>
## Specific Ideas

- The `files` collection schema must be verified before tightening its rule — specifically whether documents have a `groupId` field
- The circular dependency in `allowed_users` is a known trade-off; low-sensitivity data makes `request.auth != null` acceptable

</specifics>

<deferred>
## Deferred Ideas

- Migrating roles to Firebase Custom Claims (eliminates `allowed_users` read dependency and enables tighter Firestore rules) — significant auth refactor, out of scope for this phase
- Field-level write locks on `users/{userId}` (e.g. prevent users from changing their own role field) — no evidence this is exploitable via client; revisit if needed

</deferred>

---

*Phase: 02-firebase-security-rules-rbac*
*Context gathered: 2026-04-11*
