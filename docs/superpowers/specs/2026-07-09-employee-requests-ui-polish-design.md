# Employee Requests UI polish

**Date:** 2026-07-09  
**Status:** Approved for planning

## Goal

Make the employee Requests experience easier to find and visually closer to the manager Requests board, without copying the manager two-column workflow. Add consistent timestamps on both employee and manager request tiles.

## Decisions

| Topic | Choice |
| --- | --- |
| Nav entry | App bar icon next to Account on the employee scorecard (option A) |
| Layout approach | Light restyle of the existing single-scroll employee page (approach 1) |
| Timestamps | Both sides, time-only `h:mm a` (e.g. `3:42 PM`) |
| Bottom nav / shell | Out of scope |
| Shared widget extraction | Out of scope |

## Navigation

- On `ScorecardScreen` AppBar actions, add a Requests icon (`Icons.campaign_outlined`) beside `ProfileAction`.
- Tap pushes `EmployeeRequestsScreen` (same route as Account → Requests today).
- Keep the Account sheet **Requests** button; do not remove it.

## Employee Requests layout

Match manager visual language on a single scroll page:

1. Soft gray page background (`#F7F8FA`), padding similar to manager (`16` mobile / slightly wider if useful).
2. **Quick requests** — section title + short caption; preset chips remain tappable to send.
3. **Custom request** — white card with message field + Send (existing validation/debounce behavior unchanged).
4. **Your requests** — section title + count badge; **Clear finished** when completed items are visible; list inside a bordered board panel with white tiles.
5. Empty state — large muted inbox-style icon + “Nothing sent yet”.
6. Each tile — request text; caption `Status · 3:42 PM` using `createdAt` and existing `employeeLabel` for status.

Behavior unchanged: create from preset/custom, filter dismissed + locally cleared completed, clear finished via device prefs.

## Timestamps

- Format: `DateFormat('h:mm a')` (same as manager today).
- **Employee:** show under each visible request with status.
- **Manager:** keep existing time on tiles (`name · time`); no date/relative formatting in this change.
- If `createdAt` is null, omit the time segment (status only on employee; name only on manager).

## Out of scope

- Employee bottom navigation / shell
- Two-column Open | Done board
- Extracting shared board widgets into a common library
- Firestore schema or rules changes
- Changing clear-finished semantics

## Acceptance

- Employee can open Requests from the scorecard AppBar without opening Account.
- Employee Requests page uses manager-like section titles, board panel, white tiles, and empty state.
- Employee tiles show status and time; manager tiles still show time.
- Clear finished and send flows still work.
