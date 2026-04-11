---
phase: 2
slug: firebase-security-rules-rbac
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-04-11
---

# Phase 2 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | Firebase Emulator Suite + `@firebase/rules-unit-testing` (Node.js) |
| **Config file** | `firebase.json` (references `cloudstore_rules`) |
| **Quick run command** | `firebase emulators:exec --only firestore "node test/rules.test.js"` |
| **Full suite command** | `firebase emulators:exec --only firestore "node test/rules.test.js"` |
| **Estimated runtime** | ~30–60 seconds |

**Note:** No test directory for rules exists yet. Wave 0 must create `test/rules.test.js` and install `@firebase/rules-unit-testing`.

---

## Sampling Rate

- **After every task commit:** Run `firebase emulators:exec --only firestore "node test/rules.test.js"`
- **After every plan wave:** Run full suite
- **Before `/gsd:verify-work`:** Full suite must be green
- **Max feedback latency:** ~60 seconds

---

## Per-Task Verification Map

| Task ID | Plan | Wave | What it verifies | Test Type | Automated Command | Status |
|---------|------|------|-----------------|-----------|-------------------|--------|
| 2-01-W0 | 01 | 0 | Test infra exists, emulator runs | infra | `firebase emulators:exec --only firestore "node test/rules.test.js"` | ⬜ pending |
| 2-01-01 | 01 | 1 | files collection schema verified | manual | Firestore Console inspection | ⬜ pending |
| 2-01-02 | 01 | 1 | files rule patched and tests pass | automated | full suite | ⬜ pending |
| 2-01-03 | 01 | 2 | All 35+ role/op combos pass | automated | full suite | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Test Matrix (35+ combinations)

| Collection | Operation | Viewer | Editor | Admin | Unauth |
|------------|-----------|--------|--------|-------|--------|
| `allowed_users/{groupId}` | read | ALLOW | ALLOW | ALLOW | DENY |
| `allowed_users/{groupId}` | update members field | DENY | DENY | ALLOW | DENY |
| `allowed_users/{groupId}` | create/delete | DENY | DENY | DENY | DENY |
| `drive_catalog_by_group/{groupId}` | read | ALLOW | ALLOW | ALLOW | DENY |
| `drive_catalog_by_group/{groupId}` | write | DENY | DENY | ALLOW | DENY |
| `users/{userId}` | read | ALLOW | ALLOW | ALLOW | DENY |
| `users/{userId}` | write own doc | ALLOW | ALLOW | ALLOW | DENY |
| `users/{userId}` | write other's doc | DENY | DENY | DENY | DENY |
| `materials/{groupId}/items/{id}` | read (in-group) | ALLOW | ALLOW | ALLOW | DENY |
| `materials/{groupId}/items/{id}` | read (out-of-group) | DENY | DENY | DENY | DENY |
| `materials/{groupId}/items/{id}` | write | DENY | ALLOW | ALLOW | DENY |
| `tools_by_group/{groupId}/items/{id}` | read (in-group) | ALLOW | ALLOW | ALLOW | DENY |
| `tools_by_group/{groupId}/items/{id}` | write | DENY | ALLOW | ALLOW | DENY |
| `lessons/{groupId}/items/{id}` | read | ALLOW | ALLOW | ALLOW | DENY |
| `lessons/{groupId}/items/{id}` | create | DENY | ALLOW | ALLOW | DENY |
| `lessons/{groupId}/items/{id}` | update custom fields (assigned) | ALLOW | ALLOW | ALLOW | DENY |
| `lessons/{groupId}/items/{id}` | update custom fields (unassigned) | DENY | ALLOW | ALLOW | DENY |
| `lessons/{groupId}/items/{id}` | update other fields (viewer) | DENY | ALLOW | ALLOW | DENY |
| `lessons/{groupId}/items/{id}` | delete | DENY | ALLOW | ALLOW | DENY |
| `instructor_absences/{groupId}/items/{id}` | read | ALLOW | ALLOW | ALLOW | DENY |
| `instructor_absences/{groupId}/items/{id}` | create own vacation/sick (pending) | ALLOW | ALLOW | ALLOW | DENY |
| `instructor_absences/{groupId}/items/{id}` | create admin-type | DENY | DENY | ALLOW | DENY |
| `instructor_absences/{groupId}/items/{id}` | cancel own pending | ALLOW | ALLOW | ALLOW | DENY |
| `instructor_absences/{groupId}/items/{id}` | update arbitrary fields | DENY | DENY | ALLOW | DENY |
| `groups/{groupId}` | read | ALLOW | ALLOW | ALLOW | DENY |
| `groups/{groupId}` | write | DENY | ALLOW | ALLOW | DENY |
| `groups/{groupId}/templates/{id}` | write (with groupId field) | DENY | ALLOW | ALLOW | DENY |
| `groups/{groupId}/report_templates/{id}` | write | DENY | DENY | ALLOW | DENY |
| `groups/{groupId}/autocomplete_data/{id}` | write valid docId+shape | DENY | ALLOW | ALLOW | DENY |
| `groups/{groupId}/autocomplete_data/{id}` | write invalid docId | DENY | DENY | DENY | DENY |
| `groups/{groupId}/notifications/{id}` | read | ALLOW | ALLOW | ALLOW | DENY |
| `groups/{groupId}/notifications/{id}` | write | DENY | DENY | ALLOW | DENY |
| `files/{fileId}` (has groupId) | read in-group | ALLOW | ALLOW | ALLOW | DENY |
| `files/{fileId}` (has groupId) | read out-of-group | DENY | DENY | DENY | DENY |
| `files/{fileId}` | write | DENY | ALLOW | ALLOW | DENY |

---

## Wave 0 Requirements

- [ ] `test/rules.test.js` — full test suite covering the matrix above
- [ ] `package.json` (or `test/package.json`) — `@firebase/rules-unit-testing` dependency
- [ ] Firebase Emulator verified installable in local environment

---

## Manual-Only Verifications

| Behavior | Why Manual | Test Instructions |
|----------|------------|-------------------|
| `files` collection schema check | Cannot read Firestore Console from code | Open Firebase Console → Firestore → `files` collection → inspect a document for `groupId` field |

---

## Validation Sign-Off

- [ ] All tasks have automated verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 60s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
