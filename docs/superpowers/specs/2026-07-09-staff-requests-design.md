# Staff Requests Board — Design Spec (Spec B)

**Date:** 2026-07-09  
**Status:** Approved for write-up  
**Depends on:** Spec A polish/themes shipped; builds on location-scoped Store patterns

## Summary

Managers define short **preset request chips** for a location (e.g. “Out of soap”). Employees open a **Requests** screen from the profile menu, tap a preset or send an optional custom one-liner, and track status. Managers use a new **Requests** bottom-nav tab: Incoming → Accept (to-do) → Complete. Location-scoped only. No chat threads, push, or email in v1.

## Goals

1. **Fast employee asks** — one tap on a preset, or a short custom line, without leaving the employee flow for long.
2. **Manager board** — clear Incoming queue with Accept / Dismiss.
3. **To-do until done** — Accept moves work to a manager to-do; Complete closes it for employee and manager.
4. **Location isolation** — presets and requests belong to the active location.

## Non-Goals

- Freeform chat / reply threads
- Push, SMS, or email notifications
- Company-wide cross-location board
- Scorecard-embedded chip row (profile → Requests only)
- Attachments, photos, or @mentions
- Coach notes on submissions (separate Phase B plan if still desired)

---

## Decisions (from brainstorm)

| Topic | Choice |
|-------|--------|
| Employee entry | Profile menu → Requests screen |
| After Accept | Manager to-do until Mark complete; employee sees Accepted → Done |
| Custom text | Presets + optional custom one-liner (≤120 chars) |
| Manager UI | New Requests tab in bottom nav |
| Scope | Location-scoped (approach 1) |
| Chat | Deferred; status only |

---

## Product flow

### Employee

1. Profile menu → **Requests**.
2. See location presets as tappable chips.
3. Optional custom field (≤120 chars) + Send.
4. List of their requests with status: **Sent** (`pending`) → **Accepted** → **Done** (`completed`). Dismissed requests leave the open list (or show briefly as dismissed — implementation may hide dismissed from employee open list).
5. No thread UI.

### Manager

1. Bottom nav **Requests** tab (badge = count of `pending` for active location).
2. Sections/tabs: **Incoming** | **To-do** | **Presets**.
3. Incoming: **Accept** → status `accepted` (appears in To-do); **Dismiss** → `dismissed`.
4. To-do: **Mark complete** → `completed` (employee sees Done).
5. Presets: add / rename / delete / reorder labels for this location (soft cap ~20).

---

## Data model

Under `companies/{companyId}/locations/{locationId}/`:

### `requestPresets/{presetId}`

| Field | Type | Notes |
|-------|------|--------|
| `label` | string | Display text on chip |
| `sortOrder` | number | Ascending |
| `createdAt` | timestamp | |
| `createdByUid` | string | Manager uid |

### `staffRequests/{requestId}`

| Field | Type | Notes |
|-------|------|--------|
| `text` | string | Preset label copy or custom text |
| `presetId` | string? | Set when sent from a preset |
| `employeeName` | string | Display name at send time |
| `employeeProfileKey` | string? | Stable key if available (name/PIN identity) |
| `status` | string | `pending` \| `accepted` \| `completed` \| `dismissed` |
| `createdAt` | timestamp | |
| `acceptedAt` | timestamp? | |
| `acceptedByUid` | string? | |
| `completedAt` | timestamp? | |
| `completedByUid` | string? | |
| `dismissedAt` | timestamp? | |

**Status machine:** `pending` → `accepted` → `completed`, or `pending` → `dismissed`. No reopen in v1.

---

## Permissions (Firestore rules)

- **Presets:** managers of the company may create/update/delete; any signed-in user at the location may read (same bar as workers/config reads).
- **staffRequests create:** signed-in users may create with `status == pending` and required identity fields; cannot set accepted/completed fields on create.
- **staffRequests read:** managers read all for the location; employees read requests they created (match `employeeName` / profile key — plan picks the same identity key the scorecard already uses).
- **staffRequests update:** managers only for status transitions (accept / dismiss / complete) and related timestamps/uids.

Exact rule helpers should reuse `canManageCompany` / location patterns from existing `firestore.rules`.

---

## App surfaces

| Role | Surface |
|------|---------|
| Employee | Profile menu item → `EmployeeRequestsScreen` |
| Manager | New shell destination **Requests** → Incoming / To-do / Presets |
| Badge | Pending count on manager Requests tab |

Store: listen/create/update helpers parallel to submissions/workers for the active location.

---

## Error handling & limits

| Case | Behavior |
|------|----------|
| Empty custom send / empty preset label | Block; inline / store message |
| Rapid double-tap same preset | Debounce ~2s per preset |
| Network / permission failure | Store message (same pattern as invites) |
| Custom text | Max 120 characters |
| Presets per location | Soft cap ~20 |

---

## Testing

- Model round-trip for presets and requests; status transition helpers.
- Rules tests or documented rule cases: employee create pending; cannot accept; manager accept → complete.
- Widget/smoke: profile opens Requests; manager tab shows badge for pending.
- Debounce / empty validation unit tests where logic is pure.

---

## Implementation order (for the plan)

1. Models + status helpers + unit tests  
2. Firestore rules + indexes if needed  
3. Store CRUD / listeners  
4. Manager Requests tab (Incoming / To-do / Presets)  
5. Employee Requests screen + profile entry  
6. Badge on shell  
7. Manual QA checklist  

---

## Open implementation details (resolved in plan)

- Exact employee identity field for “own requests” queries (name vs profile key)  
- Whether dismissed items appear in a manager history section (v1 can omit history)  
- Shell tab order relative to Home / Sheet / Team / Prices / Settings
