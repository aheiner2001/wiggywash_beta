# Task Workflow v2 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Keep assigned tasks on manager To-do as Pending, add send-back with revision notes, show due times clearly, and badge/highlight new assignments for employees in-app.

**Architecture:** Extend existing `staffRequests` + Store; add `revisionNote` / `revisionRequestedAt`; expand manager To-do filter to include `assigned`; SharedPreferences for unseen assignment IDs; badge on scorecard Requests icon.

**Tech Stack:** Flutter, Firestore, SharedPreferences (same pattern as clear-prefs).

**Spec:** `docs/superpowers/specs/2026-07-10-task-workflow-v2-design.md`

---

## File map

| File | Responsibility |
|------|----------------|
| `lib/models/staff_request.dart` | revision fields |
| `lib/utils/staff_request_logic.dart` | sort with revision-first; validate revision note |
| `lib/utils/staff_request_seen_prefs.dart` | unseen assignment IDs |
| `test/utils/staff_request_logic_test.dart` | sort + validation |
| `test/utils/staff_request_seen_prefs_test.dart` | prefs round-trip |
| `lib/services/store.dart` | `sendBackStaffRequest` |
| `lib/screens/manager_requests_screen.dart` | To-do includes assigned; review send-back |
| `lib/screens/employee_requests_screen.dart` | revision UI + mark seen |
| `lib/screens/scorecard_screen.dart` | Requests badge |

---

### Task 1: Model + logic + seen prefs (TDD)

- [ ] Add `revisionNote`, `revisionRequestedAt` to `StaffRequest` fromMap/toMap
- [ ] `validateRevisionNote` (non-empty, ≤120)
- [ ] Update `sortEmployeeTodos`: revisionRequested first among manager items
- [ ] `canTransition(awaitingReview → assigned)` already true — keep
- [ ] Create `StaffRequestSeenPrefs` load/addIds (mirror clear prefs)
- [ ] Tests; commit

### Task 2: Store send-back

- [ ] `sendBackStaffRequest({id, revisionNote})` → status assigned, set revision fields, clear reviewed*
- [ ] Commit

### Task 3: Manager UI

- [ ] To-do filter: `accepted | assigned | awaitingReview` (non-personal via `isManagerBoardVisible`)
- [ ] Tile labels: Pending / Needs review; show assignee
- [ ] Assigned: Delete only (no Mark complete / Assign unless product wants reassign — v2: Delete only)
- [ ] Review: Close + Send back dialog with note field calling `sendBackStaffRequest`
- [ ] Commit

### Task 4: Employee UI + badge

- [ ] Show revision label + note; due always when set
- [ ] Highlight unseen; mark all assigned seen on screen open (or per-tile)
- [ ] Scorecard Requests `Badge` from unseen count (listen Store + prefs)
- [ ] Commit

### Task 5: Verify + push

- [ ] analyze + tests
- [ ] push mybranch; deploy rules only if rules changed (likely not)
