# GSPP Platform — Roadmap

## Milestone 1: Auth Stability & File Management Overhaul

**Goal:** Stabilise authentication, real-time file sync, and role-based access control so all user roles interact only with the features they are permitted to use.

---

### Phase 1: Auth Stability & File Management UX

**Goal:** Persistent Google Auth across reloads, real-time Firestore streams for materials/tools, optimistic UI on file add/delete.

**Depends on:** —

**Plans:**
- 01-01: Auth persistence & Drive token recovery
- 01-02: Real-time materials streaming & Drive session banner

**Status:** Completed ✓

---

### Phase 2: Firebase Security Rules & Role-Based Access Control

**Goal:** Review and harden Firebase security rules so each user role has access only to the features and data it is permitted to use. Viewer (teacher): read lessons, fill custom fields, submit leave/sick requests, download and view resources and tools, view and edit own profile page. Editor: create/edit lessons, add materials and resources, assign teachers. Admin: full access to admin panel.

**Depends on:** Phase 1

**Plans:** 3 plans

Plans:
- [ ] 02-01-PLAN.md — Create Firestore rules test infrastructure (Wave 0: helpers, full 35+ case test suite, npm install)
- [ ] 02-02-PLAN.md — Verify files schema and patch cloudstore_rules, deploy to Firebase (Wave 1: checkpoint + rule patch)
- [ ] 02-03-PLAN.md — Run full test suite, confirm all 35+ role/operation combinations pass, mark validation complete (Wave 2)

---
