# Phase 2: Firebase Security Rules & RBAC - Research

**Researched:** 2026-04-11
**Domain:** Firestore security rules, role-based access control
**Confidence:** HIGH

---

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

- **files collection read:** Restrict to `isInGroup(resource.data.groupId)` — but only after confirming that `files` documents have a `groupId` field. If they don't, fallback is to keep `request.auth != null` and add a TODO comment.
- **files collection write:** Editor+ only (`hasEditorRights(groupId)`).
- **allowed_users read:** Keep `request.auth != null` — circular dependency prevents using `isInGroup()` here.
- **allowed_users create/delete:** Remain `false` — groups are provisioned via Admin SDK only.
- **Existing rules confirmed correct, no changes needed:** `lessons`, `materials`, `tools_by_group`, `users/{userId}`, `instructor_absences`, `groups`, `templates`, `report_templates`, `autocomplete_data`, `notifications`.

### Claude's Discretion

- If `files` documents lack a `groupId` field, choose the least-breaking fallback (e.g., keep current rule and add a TODO comment, or propose schema change).
- Field-level write restrictions on `users/{userId}` — current full-write-own is acceptable; no need to lock individual fields unless code review reveals a specific risk.

### Deferred Ideas (OUT OF SCOPE)

- Migrating roles to Firebase Custom Claims — significant auth refactor.
- Field-level write locks on `users/{userId}` — no evidence this is exploitable via client.
</user_constraints>

---

## Summary

This phase is a pure `cloudstore_rules` file audit and patch. No schema migrations, no UI changes, no new services. The existing rules are well-structured with reusable helper functions (`isInGroup`, `hasEditorRights`, `hasAdminRights`, `getUserRole`) that cover all collections the app actually reads or writes.

The primary open question is the `files` collection: the rule exists (`allow read: if request.auth != null`) but neither the Flutter app nor the Cloud Functions reference this collection via the client SDK — it appears to be a legacy or unused collection. There is no write rule, meaning writes are implicitly denied by Firestore's default-deny stance. The decision from CONTEXT.md is to tighten the read rule to `isInGroup(resource.data.groupId)` if the schema supports it, but this must be verified against actual Firestore documents before the change is made.

Two backend-only collections (`function_events`, `lesson_reminder_jobs`) are written exclusively by Cloud Functions using the Admin SDK, which bypasses all Firestore security rules. No client-side read or write access is needed for these, and they have no match block in the rules file — this is correct behaviour (Admin SDK is not subject to rules; clients are denied by default in production).

**Primary recommendation:** The only rule change needed is on the `files` collection — tighten read and add write. All other rules are confirmed correct against the role matrix. The work is one targeted patch, not a full rewrite.

---

## Standard Stack

### Core
| Tool | Version | Purpose | Why Standard |
|------|---------|---------|--------------|
| Firestore Security Rules | rules_version = '2' | Declarative server-side access control | Only mechanism for enforcing access on Firestore directly |
| Firebase CLI | Installed via npm | Deploy rules with `firebase deploy --only firestore:rules` | Official deployment pathway |

### Supporting
| Pattern | Purpose | When to Use |
|---------|---------|-------------|
| `resource.data.diff(request.resource.data).affectedKeys().hasOnly([...])` | Field-level write restriction | When a role can update only specific fields |
| `get(/databases/$(database)/documents/...)` | Cross-document lookup in rules | When role data lives in another document (e.g., `allowed_users`) |
| `exists(/databases/$(database)/documents/...)` | Guard before `get()` | Prevents null-dereference when document may not exist |

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| `allowed_users` role lookup | Firebase Custom Claims | Claims eliminate the cross-document read but require a backend auth flow to set them — deferred out of scope |

**Deploy command:**
```bash
firebase deploy --only firestore:rules
```

---

## Architecture Patterns

### Existing Helper Function Pattern

All role checks go through the four helper functions already defined at the bottom of the rules file. Never inline role logic in a match block — always call a helper.

```
cloudstore_rules
  match /collection/{docId} {
    allow read:   if isInGroup(groupId);
    allow write:  if hasEditorRights(groupId);
  }

  // helpers at bottom of rules block
  function isInGroup(groupId) { ... }
  function hasEditorRights(groupId) { ... }
  function hasAdminRights(groupId) { ... }
  function getUserRole(groupId) { ... }
```

### Pattern 1: Group-scoped subcollection path
**What:** Collections use `/{groupId}/items/{docId}` so `groupId` is always available as a path variable.
**When to use:** All group-owned data (lessons, materials, tools, absences, templates, etc.)
**Example:**
```
match /lessons/{groupId}/items/{lessonId} {
  allow read: if isInGroup(groupId);
  allow write: if hasEditorRights(groupId);
}
```

### Pattern 2: Field-level diff check
**What:** Restrict which fields a viewer-role user can update.
**When to use:** When a role can perform some but not all updates on a document.
**Example (already in rules — canInstructorUpdateCustomFields):**
```
request.resource.data.diff(resource.data).affectedKeys()
  .hasOnly(['customFieldValues', 'updatedAt'])
```

### Pattern 3: `resource.data` field in a flat collection
**What:** When a collection is NOT group-scoped by path (e.g., `files/{fileId}`), the groupId must come from the document itself: `resource.data.groupId`.
**Risk:** If a document lacks the `groupId` field, `resource.data.groupId` evaluates to `null`. `isInGroup(null)` will call `get(.../allowed_users/null)` and either fail or produce unexpected results.
**Mitigation:** Guard with `resource.data.keys().hasAll(['groupId'])` before calling `isInGroup`.

**Proposed safe pattern for `files`:**
```
match /files/{fileId} {
  allow read: if resource.data.keys().hasAll(['groupId']) &&
                 isInGroup(resource.data.groupId);
  // write omitted until schema confirmed — currently denied by default
}
```

### Anti-Patterns to Avoid
- **Calling `isInGroup()` inside `allowed_users` match block:** Causes recursive `get()` — confirmed circular dependency. Keep `allowed_users` read as `request.auth != null`.
- **Adding match blocks for Admin SDK-only collections:** `function_events` and `lesson_reminder_jobs` are written by Cloud Functions with Admin SDK. Adding client-accessible rules would give clients unexpected read paths.
- **Omitting `exists()` guard before `get()`:** If the document doesn't exist, `get()` returns a resource with empty data, and field access will evaluate to `null`, not throw — but the logic silently fails.

---

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Role resolution | Custom role field on every document | `getUserRole(groupId)` helper + `allowed_users` lookup | Already implemented, cross-document get is cached within a rules evaluation |
| Field-level access | Separate collection per role | `affectedKeys().hasOnly([...])` diff check | Built into Firestore rules DSL, no extra collections needed |
| Audit logging | Custom rules-side logging | Firebase Audit Logs (Cloud Logging) | Rules cannot write; audit is handled at the GCP layer |

---

## Common Pitfalls

### Pitfall 1: `resource.data.groupId` on documents that lack the field
**What goes wrong:** `isInGroup(resource.data.groupId)` is called with `null`. `get()` on `/allowed_users/null` silently returns an empty document; `members[email]` is `null`; `isInGroup` returns `false`. Read is denied — no error, but legitimate users also get denied.
**Why it happens:** Flat collections (not path-scoped) require the groupId to live in the document itself. Legacy documents may pre-date this field.
**How to avoid:** Use `resource.data.keys().hasAll(['groupId'])` guard, OR verify all documents have the field before deploying the new rule.
**Warning signs:** Clients start receiving permission-denied errors on reads that previously worked.

### Pitfall 2: `rules_version = '2'` required for `hasOnly()`, `hasAll()`, `toSet()`
**What goes wrong:** Methods like `.affectedKeys().hasOnly()` and `.toSet()` only exist in rules version 2. If the version line is removed or set to '1', these calls produce parse errors at deploy time.
**How to avoid:** Never remove `rules_version = '2';` from the top of the file.

### Pitfall 3: Multiple `allow create` blocks on the same path
**What goes wrong:** The current `instructor_absences` match uses two separate `allow create:` blocks (one for viewer, one for admin). Firestore evaluates all allow statements with OR logic — if ANY passes, access is granted. This is intentional here but can be confusing.
**Risk:** Adding a third `allow create:` with a typo or weaker condition would silently grant extra create access.
**How to avoid:** When auditing, check every collection's full set of allow statements, not just the first one.

### Pitfall 4: `allowed_users` update is admin-only but only for `members` field
**What goes wrong:** The current update rule uses `hasAdminRights(groupId)` AND `affectedKeys().hasOnly(['members'])`. This means an admin cannot update any other field (e.g., `groupName`) via the client — they'd need the Admin SDK. This is correct for security but may surprise developers adding new group-level fields.
**How to avoid:** When adding new fields to `allowed_users` that admins need to update client-side, extend the `hasOnly` list explicitly.

### Pitfall 5: `canInstructorManageOwnLessonAssignment` allows any group member to self-assign
**What goes wrong:** `canInstructorManageOwnLessonAssignment` only checks `isInGroup(groupId)` (not `hasEditorRights`). Any viewer can take or release a lesson assignment on themselves. This is intentional per the role matrix ("assign teachers to lessons" — viewers can assign themselves), but must not be widened.
**How to avoid:** If this function is ever refactored, confirm the group membership check is preserved exactly.

---

## Code Examples

### Current `files` rule (existing — needs patching)
```javascript
// Source: cloudstore_rules (repo root)
match /files/{fileId} {
  allow read: if request.auth != null;
  // No write rule — denied by default
}
```

### Target `files` rule (post-patch, if schema confirmed)
```javascript
match /files/{fileId} {
  // Read: group members only — requires documents to have a groupId field
  allow read: if resource.data.keys().hasAll(['groupId']) &&
                 isInGroup(resource.data.groupId);
  // Fallback if schema unconfirmed: keep request.auth != null + TODO comment
}
```

### Target `files` rule (fallback — schema unconfirmed)
```javascript
match /files/{fileId} {
  // TODO: tighten to isInGroup(resource.data.groupId) once files documents
  // are confirmed to have a groupId field. Tracked: Phase 2 open question.
  allow read: if request.auth != null;
}
```

### Helper function reference (DO NOT modify)
```javascript
// Source: cloudstore_rules — bottom of match block
function isInGroup(groupId) {
  return request.auth != null &&
    exists(/databases/$(database)/documents/allowed_users/$(groupId)) &&
    get(/databases/$(database)/documents/allowed_users/$(groupId))
      .data.members[request.auth.token.email] != null;
}
```

---

## Collection Audit Results

Complete inventory of all collections used in the app, mapped against the rules file.

| Collection | App Uses? | Functions Uses? | Rule Exists? | Assessment |
|------------|-----------|-----------------|--------------|------------|
| `allowed_users` | Yes (read) | Yes (read, Admin SDK write) | Yes | Correct — read = auth only, write = admin+field-lock |
| `users/{userId}` | Yes | Yes (Admin SDK) | Yes | Correct — read = auth, write = own doc |
| `users/{userId}/devices` | Yes | Yes (Admin SDK read) | Yes | Correct — own UID only |
| `materials/{groupId}/items` | Yes | No | Yes | Correct — isInGroup read, editor+ write |
| `tools_by_group/{groupId}/items` | Yes | No | Yes | Correct — isInGroup read, editor+ write |
| `lessons/{groupId}/items` | Yes | Yes (trigger, no write) | Yes | Correct — complex viewer update rules confirmed |
| `instructor_absences/{groupId}/items` | Yes | No | Yes | Correct — viewer create own, admin full |
| `groups/{groupId}` | Yes | No | Yes | Correct — isInGroup read, editor+ write |
| `groups/{groupId}/templates` | Yes | No | Yes | Correct — editor+ with groupId field check |
| `groups/{groupId}/report_templates` | Yes | No | Yes | Correct — admin only |
| `groups/{groupId}/autocomplete_data` | Yes | No | Yes | Correct — editor+ with docId + shape check |
| `groups/{groupId}/notifications` | Yes | Yes (trigger) | Yes | Correct — admin+ write, isInGroup read |
| `drive_catalog_by_group/{groupId}` | Yes | No | Yes | Correct — isInGroup read, admin write |
| `files/{fileId}` | **No** | **No** | Yes (incomplete) | **NEEDS PATCH** — read too permissive, no write rule |
| `function_events` | No | Yes (Admin SDK only) | **No** | Correct — Admin SDK bypasses rules, no client access |
| `lesson_reminder_jobs` | No | Yes (Admin SDK only) | **No** | Correct — Admin SDK bypasses rules, no client access |

**Conclusion:** The ONLY collection needing a rule change is `files`. All others are confirmed correct.

---

## `files` Collection — Schema Investigation

**Finding (HIGH confidence):** Zero calls to `FirebaseFirestore.instance.collection('files')` exist anywhere in the Dart source (`lib/`). The Cloud Functions (`functions/index.js`) also make no reference to `files`. The collection appears to be legacy or populated by an external process.

**Implication:** Because the client never reads or writes `files`, the current rule (`allow read: if request.auth != null`) causes no real-world access issue even if overly permissive. However, the security principle requires tightening it.

**What we cannot confirm without Firestore Console access:** Whether existing documents in the `files` collection have a `groupId` field.

**Decision path (per CONTEXT.md):**
- If documents have `groupId` → apply `isInGroup(resource.data.groupId)` read rule.
- If documents lack `groupId` → keep `request.auth != null`, add TODO comment, mark for schema migration.

The implementer must check the Firestore Console or run a one-time query to sample `files` documents before choosing which branch to apply.

---

## Validation Architecture

`nyquist_validation` is enabled in `.planning/config.json`.

### Test Framework

| Property | Value |
|----------|-------|
| Framework | Firebase Emulator Suite + `@firebase/rules-unit-testing` (Node.js) |
| Config file | `firebase.json` (references `cloudstore_rules`) |
| Quick run command | `firebase emulators:exec --only firestore "node test/rules.test.js"` |
| Full suite command | `firebase emulators:exec --only firestore "node test/rules.test.js"` |

**Note:** No existing test directory for rules was found in the repo. A `test/` directory and `test/rules.test.js` must be created in Wave 0. The Firebase Emulator Suite is the standard approach for Firestore rules unit testing — it runs rules locally without hitting production.

### What to Test (Per Collection, Per Role)

| Collection | Operation | Viewer | Editor | Admin | Unauthenticated |
|------------|-----------|--------|--------|-------|-----------------|
| `allowed_users/{groupId}` | read | ALLOW | ALLOW | ALLOW | DENY |
| `allowed_users/{groupId}` | update (members field) | DENY | DENY | ALLOW | DENY |
| `allowed_users/{groupId}` | update (other field) | DENY | DENY | DENY | DENY |
| `allowed_users/{groupId}` | create | DENY | DENY | DENY | DENY |
| `allowed_users/{groupId}` | delete | DENY | DENY | DENY | DENY |
| `drive_catalog_by_group/{groupId}` | read | ALLOW | ALLOW | ALLOW | DENY |
| `drive_catalog_by_group/{groupId}` | write | DENY | DENY | ALLOW | DENY |
| `users/{userId}` | read (any auth user) | ALLOW | ALLOW | ALLOW | DENY |
| `users/{userId}` | write (own doc) | ALLOW | ALLOW | ALLOW | DENY |
| `users/{userId}` | write (other's doc) | DENY | DENY | DENY | DENY |
| `materials/{groupId}/items/{id}` | read (in-group) | ALLOW | ALLOW | ALLOW | DENY |
| `materials/{groupId}/items/{id}` | read (out-of-group) | DENY | DENY | DENY | DENY |
| `materials/{groupId}/items/{id}` | write | DENY | ALLOW | ALLOW | DENY |
| `tools_by_group/{groupId}/items/{id}` | read (in-group) | ALLOW | ALLOW | ALLOW | DENY |
| `tools_by_group/{groupId}/items/{id}` | write | DENY | ALLOW | ALLOW | DENY |
| `lessons/{groupId}/items/{id}` | read | ALLOW | ALLOW | ALLOW | DENY |
| `lessons/{groupId}/items/{id}` | create | DENY | ALLOW | ALLOW | DENY |
| `lessons/{groupId}/items/{id}` | update (custom fields only, assigned) | ALLOW | ALLOW | ALLOW | DENY |
| `lessons/{groupId}/items/{id}` | update (custom fields, unassigned) | DENY | ALLOW | ALLOW | DENY |
| `lessons/{groupId}/items/{id}` | update (non-custom fields, viewer) | DENY | ALLOW | ALLOW | DENY |
| `lessons/{groupId}/items/{id}` | delete | DENY | ALLOW | ALLOW | DENY |
| `instructor_absences/{groupId}/items/{id}` | read | ALLOW | ALLOW | ALLOW | DENY |
| `instructor_absences/{groupId}/items/{id}` | create (own, pending, user_request, vacation/sick) | ALLOW | ALLOW | ALLOW | DENY |
| `instructor_absences/{groupId}/items/{id}` | create (admin-type) | DENY | DENY | ALLOW | DENY |
| `instructor_absences/{groupId}/items/{id}` | cancel own pending | ALLOW | ALLOW | ALLOW | DENY |
| `instructor_absences/{groupId}/items/{id}` | update arbitrary fields | DENY | DENY | ALLOW | DENY |
| `groups/{groupId}` | read | ALLOW | ALLOW | ALLOW | DENY |
| `groups/{groupId}` | write | DENY | ALLOW | ALLOW | DENY |
| `groups/{groupId}/templates/{id}` | read | ALLOW | ALLOW | ALLOW | DENY |
| `groups/{groupId}/templates/{id}` | write (editor, with groupId field) | DENY | ALLOW | ALLOW | DENY |
| `groups/{groupId}/report_templates/{id}` | write | DENY | DENY | ALLOW | DENY |
| `groups/{groupId}/autocomplete_data/{id}` | write (valid docId, valid shape) | DENY | ALLOW | ALLOW | DENY |
| `groups/{groupId}/autocomplete_data/{id}` | write (invalid docId) | DENY | DENY | DENY | DENY |
| `groups/{groupId}/notifications/{id}` | read | ALLOW | ALLOW | ALLOW | DENY |
| `groups/{groupId}/notifications/{id}` | write | DENY | DENY | ALLOW | DENY |
| `files/{fileId}` (post-patch, doc has groupId) | read (in-group) | ALLOW | ALLOW | ALLOW | DENY |
| `files/{fileId}` (post-patch, doc has groupId) | read (out-of-group) | DENY | DENY | DENY | DENY |
| `files/{fileId}` (doc lacks groupId) | read | DENY | DENY | DENY | DENY |

### How to Test

**Firebase Emulator Suite** is the standard tool. It runs a local Firestore instance that enforces security rules without touching production.

```bash
# Install (once, in project root)
npm install --save-dev @firebase/rules-unit-testing

# Run emulator with test
firebase emulators:exec --only firestore "node test/rules.test.js"
```

**Test structure pattern (Node.js, `@firebase/rules-unit-testing` v2):**
```javascript
const { initializeTestEnvironment, assertFails, assertSucceeds } = require('@firebase/rules-unit-testing');
const fs = require('fs');

let testEnv;
beforeAll(async () => {
  testEnv = await initializeTestEnvironment({
    projectId: 'gspp-9e089',
    firestore: {
      rules: fs.readFileSync('cloudstore_rules', 'utf8'),
      host: '127.0.0.1',
      port: 8080,
    },
  });
});

afterAll(() => testEnv.cleanup());

// Example: viewer can read materials in own group
test('viewer reads own group materials', async () => {
  const viewer = testEnv.authenticatedContext('viewer-uid', { email: 'viewer@example.com' });
  // seed allowed_users and materials doc via testEnv.withSecurityRulesDisabled()
  await assertSucceeds(
    viewer.firestore().collection('materials').doc('groupA').collection('items').doc('m1').get()
  );
});
```

### Sampling Rate

- **Per task commit:** Run the specific collection's test slice: `firebase emulators:exec --only firestore "node test/rules.test.js --grep <collection>"`
- **Per wave merge:** Full suite: `firebase emulators:exec --only firestore "node test/rules.test.js"`
- **Phase gate:** Full suite green before `/gsd:verify-work`

### What Constitutes Passing

- Every ALLOW cell in the test matrix above succeeds (`assertSucceeds`).
- Every DENY cell fails with permission-denied (`assertFails`).
- `firebase deploy --only firestore:rules` completes without parse errors.
- No regression: all previously-passing cells still pass after `files` patch.

### Wave 0 Gaps

- [ ] `test/rules.test.js` — full rules test suite (covers all collections above)
- [ ] `test/helpers.js` — shared fixtures: seed `allowed_users` with viewer/editor/admin members
- [ ] Install test dependency: `npm install --save-dev @firebase/rules-unit-testing` (run from project root)
- [ ] Verify Firebase Emulator installed: `firebase emulators:start --only firestore` must succeed

---

## Open Questions

1. **Do `files` documents have a `groupId` field?**
   - What we know: The collection exists in rules, neither app nor Cloud Functions access it client-side. It is likely legacy.
   - What's unclear: Whether any documents exist and what fields they have.
   - Recommendation: Before implementing the patch, open Firestore Console → `files` collection, sample 5–10 documents, confirm presence/absence of `groupId`. If empty collection, apply the `isInGroup(resource.data.groupId)` rule — no risk. If documents exist without `groupId`, use the fallback + TODO path.

2. **Is the `files` collection used by any Cloud Function not yet examined?**
   - What we know: `functions/index.js` references `function_events`, `lesson_reminder_jobs`, `users`, `allowed_users`, `lessons`, `groups/notifications` — no `files`.
   - What's unclear: Whether a separate Cloud Function file or a future function uses it.
   - Recommendation: Confirm there is only one Cloud Functions entry file (`functions/index.js`) before finalising the rule patch. The current glob of `functions/src/` returned nothing, confirming no additional source files exist.

---

## Sources

### Primary (HIGH confidence)
- `cloudstore_rules` (repo root) — full rules file read and audited line by line
- `functions/index.js` — all Cloud Function collection references extracted
- `lib/services/*.dart` — all `collection()` calls extracted via grep; no `files` references found
- `firebase.json` — confirms `"rules": "cloudstore_rules"` and no Storage rules configured

### Secondary (MEDIUM confidence)
- Firebase documentation on `rules_version = '2'` requirements for `hasOnly`, `toSet`, `hasAll` methods — consistent with existing rules usage in the repo
- `@firebase/rules-unit-testing` v2 API — standard library for Firestore rules testing with emulator

### Tertiary (LOW confidence)
- None — all findings are based on direct code inspection

---

## Metadata

**Confidence breakdown:**
- Collection audit: HIGH — direct grep of all Dart services and Cloud Functions source
- `files` schema: LOW — cannot be confirmed without Firestore Console access; implementer must verify
- Existing rules correctness: HIGH — cross-referenced each match block against role matrix from CONTEXT.md
- Validation architecture: MEDIUM — `@firebase/rules-unit-testing` v2 API verified against repo's Node.js version (22), but no existing test infra to base patterns on

**Research date:** 2026-04-11
**Valid until:** 2026-05-11 (stable domain — Firebase rules DSL does not change frequently)
