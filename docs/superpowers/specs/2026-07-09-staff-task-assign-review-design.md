# Staff Task Assign + Review — Design Spec

**Date:** 2026-07-09  
**Status:** Approved for write-up  
**Depends on:** Staff Requests board + employee Requests UI polish  
**Extends:** `docs/superpowers/specs/2026-07-09-staff-requests-design.md`

## Summary

Managers can delete or assign items from their To-do list to a Team worker (optional due time). Employees get a personal to-do list on Requests; manager-assigned work appears in red at the top. When an employee completes assigned work, they leave a short note or completion preset. The manager sees that on To-do via **Review**, then **Close** or **Reopen**.

Built by extending the existing `staffRequests` collection (Approach 1), not a second task system.

## Goals

1. Manager To-do: **Delete** and **Assign to…** as separate actions.
2. Optional **due by** on assigned / manager-created work.
3. Employee **My to-do**: personal add/remove + manager-assigned (red, top).
4. Completion requires note and/or completion preset; manager **Review** → Close / Reopen.
5. Keep floor-ask Incoming flow working.

## Non-Goals

- Push / SMS / email
- Photos or attachments
- Multi-assignee or chat threads
- Employee nav badge
- Cross-location board
- Manager visibility into employee personal todos

## Decisions

| Topic | Choice |
| --- | --- |
| Architecture | Extend `staffRequests` |
| Manager To-do | Delete + Assign separate |
| Due | Optional date+time |
| Completion | Note and/or completion preset (at least one) |
| After employee completes | `awaitingReview` on manager To-do |
| Review | Close or Reopen |
| Personal todos | Employee-only; not on manager board |
| Manager self-complete | `accepted` → `closed` with no employee note |

---

## Status flow & ownership

| Status | Meaning |
| --- | --- |
| `pending` | Employee ask — manager Incoming |
| `accepted` | On manager To-do (unassigned / with manager) |
| `assigned` | On employee open list |
| `awaitingReview` | Employee done + note; manager Review |
| `closed` | Manager closed after review (or manager self-complete) |
| `dismissed` | Deleted/dismissed; hidden from open lists |

Legacy `completed` is treated as `closed` in clients.

### Flows

1. **Floor ask:** Send → `pending` → Accept → `accepted`. To-do: **Delete** → `dismissed`, or **Assign to…** → `assigned` (+ optional `dueAt`).
2. **Manager creates work:** Text + employee + optional due → starts `assigned`, `source: manager_assign`.
3. **Employee personal todo:** `source: employee_personal`, status `assigned` to self; manager never sees.
4. **Employee completes assigned (non-personal):** Completion sheet → `awaitingReview`.
5. **Manager review:** Show note/preset → **Close** (`closed`) or **Reopen** (`assigned`, still red/top).

### List ownership

- **Manager Incoming:** `pending` only (`source: employee_ask`).
- **Manager To-do:** `accepted` + `awaitingReview`.
- **Employee open My to-do:** own `assigned` (manager-assigned first/red, then personal); hide `closed` / `dismissed` / cleared.
- **Employee floor asks:** existing Sent / Accepted / Done list for `employee_ask` (non-todo statuses) remains; assigned work lives in My to-do.

---

## Screens & actions

### Manager Requests

- **Incoming:** Dismiss / Add to to-do (unchanged).
- **To-do (`accepted`):** **Delete**, **Assign to…** (Team worker picker), **Mark complete** (manager finishes → `closed`, no note).
- **To-do (`awaitingReview`):** **Needs review** → **Review** dialog (note + preset label) → **Close** / **Reopen**.
- **Assign / create:** optional Due by. AppBar or empty-state **Assign task**: text + employee + optional due.
- **Presets:** keep request presets; add **Completion presets** (soft cap ~10).

### Employee Requests

- Title may stay **Requests**; page includes **My to-do** + quick/custom asks.
- **My to-do:** manager-assigned (red accent, due-soon then newest) above personal; add/remove personal; **Complete** on manager-assigned opens sheet (preset and/or note ≤120).
- Due line: `Due · h:mm a` (include date when not today).
- Clear finished / closed items via existing clear pattern where applicable.

### Badges

- Manager shell Requests badge = count of `pending` + `awaitingReview`.
- No employee badge in v1.

---

## Data model

Under `companies/{companyId}/locations/{locationId}/`:

### `staffRequests/{id}` — new/updated fields

| Field | Type | Notes |
| --- | --- | --- |
| `source` | string | `employee_ask` \| `manager_assign` \| `employee_personal` |
| `assigneeName` | string? | Open-work owner |
| `assigneeProfileKey` | string? | Lowercase trimmed name key |
| `assignedAt` | timestamp? | |
| `assignedByUid` | string? | |
| `dueAt` | timestamp? | Optional |
| `completionNote` | string? | ≤120 |
| `completionPresetId` | string? | |
| `completionPresetLabel` | string? | Snapshot at complete time |
| `reviewedAt` | timestamp? | |
| `reviewedByUid` | string? | |
| `status` | string | Includes `assigned`, `awaitingReview`, `closed` |

Existing ask fields (`text`, `employeeName`, `employeeProfileKey`, `presetId`, accept/dismiss timestamps) remain. For asks, `employeeName` is the requester; after assign, `assignee*` is the worker who must do it (may match requester or differ).

### `completionPresets/{id}`

Same shape as `requestPresets`: `label`, `sortOrder`, `createdAt`, `createdByUid`. Soft cap ~10.

---

## Rules

- **Managers:** CRUD completion presets; all status transitions; assign; delete/dismiss; close/reopen; create `manager_assign`.
- **Employees (signed-in):** create `employee_ask` and `employee_personal`; update **own** `assigned` → `awaitingReview` with note and/or preset; delete/remove **own** personal only.
- Employees cannot assign, dismiss, close, or reopen others’ items.
- Personal todos (`employee_personal`) are readable by managers in raw data if rules allow location read today; **product UI must not show them on manager boards**. Prefer rules that restrict manager list queries if practical; otherwise client filter is required and documented.

---

## Errors & edge cases

- Assign with empty Team → message to add workers first.
- Complete requires note **or** completion preset (at least one).
- Reopen → `assigned`; clear review timestamps; keep text, due, assignee; keep completion note visible to manager history optional — v1 may leave last note on doc until next complete overwrites.
- Missing `dueAt` → no due line.
- Manager **Mark complete** on `accepted` skips review (direct `closed`).

---

## Testing

- Pure logic: allowed transitions; sort (manager-assigned before personal; due ascending); due/caption formatting; legacy `completed` → `closed`.
- Manual: assign → employee complete with note → review close; reopen; personal add/remove; delete from manager to-do; manager self-complete.

## Out of scope

Push/email, photos, multi-assignee, chat, employee badge, cross-location, shared widget extraction beyond what’s needed.
