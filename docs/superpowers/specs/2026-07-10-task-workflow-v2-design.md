# Task Workflow v2 — Design Spec

**Date:** 2026-07-10  
**Status:** Approved (recommended defaults; user directed no further permission gates for A–F)  
**Extends:** `docs/superpowers/specs/2026-07-09-staff-task-assign-review-design.md`

## Summary

Tighten the assign → work → review loop: managers keep assigned tasks on To-do as **Pending** (with assignee), employees get an in-app Requests badge + highlight for new assigns and clear due times, and review supports **Approve/Close** or **Send back** with a manager revision note (employee sees **Revision requested** at top).

## Locked decisions

| Topic | Choice |
| --- | --- |
| Employee notify on assign | In-app only: badge on Requests icon + “new” highlight on My to-do |
| Push/SMS | Out of scope |
| Manager To-do after assign | Keep item; show **Pending** + assignee name (+ due if set) |
| Review actions | **Close** or **Send back** (manager note required) |
| Send-back employee UX | Returns to My to-do, top, red, label **Revision requested** + manager note |
| Due time | Always show `formatDueCaption` on employee + manager tiles when `dueAt` set |
| Reopen without note | Removed; use Send back with note |

## Status / board rules (delta)

| Status | Manager To-do? | Employee My to-do? | Label |
| --- | --- | --- | --- |
| `accepted` | Yes | No | Unassigned / with manager |
| `assigned` | Yes (non-personal only) | Yes | **Pending** (mgr) / To-do or Revision (emp) |
| `awaitingReview` | Yes | No | **Needs review** |
| `closed` / `dismissed` | No | No | — |

Personal (`employee_personal`) still filtered off manager boards.

### Send back

- From `awaitingReview` → `assigned`
- Require `revisionNote` (≤120)
- Set `revisionRequestedAt`; clear `reviewedAt`/`reviewedByUid`
- Leave prior `completionNote` until next employee complete overwrites
- Employee sort: revision-requested manager items first, then other manager-assigned by due, then personal

### New assignment “seen” tracking

- Device prefs set of request IDs the employee has opened/seen on Requests
- Unseen manager-assigned IDs → badge count on scorecard Requests icon
- Unseen tiles get a subtle highlight; opening Requests (or tapping the tile) marks seen

## Data fields (add)

| Field | Notes |
| --- | --- |
| `revisionNote` | string? manager send-back note |
| `revisionRequestedAt` | timestamp? |

## UI deltas

### Manager To-do

- Include `assigned` (non-personal) alongside `accepted` + `awaitingReview`
- Tile subtitle: assignee · Pending | Needs review | due line
- Assigned tiles: no Assign again required; optional Delete; no Mark complete while pending with employee (manager can still Delete)
- Review dialog: show employee completion note/preset; **Close** / **Send back…** (note field)

### Employee

- Scorecard Requests icon: `Badge` when unseen assigned count > 0
- My to-do: due line always when set; revision label + `revisionNote` when present; new-assign highlight when unseen
- Complete flow unchanged (note and/or completion preset)

## Out of scope (this spec)

Share preview (B), themes (C), dashboard grid (D), QR (E), branding (F), density (G), push notifications.

## Acceptance

- Assign keeps task on manager To-do as Pending with employee name
- Employee sees due time; badge/highlight for new assigns
- Complete → Review; Close ends; Send back requires note and returns to employee top with Revision requested
