# Front-of-House Visual System + Coach Notes — Design Spec

**Date:** 2026-07-09  
**Status:** Approved  
**Approach:** One umbrella spec; two implementation plans (Phase A look & feel, Phase B coach loop)

## Summary

Ship a coherent front-of-house visual pass (brand-first login, clearer dashboard hierarchy, app-wide density, purposeful motion, one-thumb scorecard) and a manager coach-note loop on submissions. Phase A owns the look & feel package; Phase B adds coach notes on the same visual language. No inline Master Sheet editing, logo upload beyond existing `logoUrl`, push/email, or threaded replies.

## Goals

1. **Brand-first entry** — login/landing reads as this company, not a generic form (#14).
2. **One-job dashboard** — period → team total → people; less competing chrome (#17).
3. **Shared density** — Comfortable / Compact beyond Master Sheet (dashboard + scorecard + login) (#15).
4. **Purposeful motion** — exactly three transitions: tab change, approve, scorecard save (#16).
5. **One-thumb scorecard** — larger steppers, sticky totals, less scroll on phone (#8).
6. **Coach notes** — managers leave a short comment on a submission; employees read on Reports (#4).

## Non-Goals

- Inline Master Sheet cell editing
- Logo upload / white-label kit beyond existing company `logoUrl` and accent `primaryColor`
- Full theme recolor or dark mode
- Push, email, or @mentions for notes
- Employee reply threads or acknowledgement workflow
- Offline sync redesign (local draft already exists)
- Forced sync of Master Sheet density with app density
- Showing coach notes on the live mid-shift scorecard canvas (v1 is Reports-only for employees)

---

## Decisions (from brainstorm)

| Topic | Choice |
|-------|--------|
| Idea set | 4, 8, 14, 15, 16, 17 |
| Packaging | Approach 1 — one umbrella spec, Phase A then Phase B plans |
| Phase A | 14, 17, 15, 16, 8 |
| Phase B | 4 (coach notes) |
| App density vs sheet density | Independent; app covers dashboard + scorecard + login |
| Employee note surface | Reports only (not live tally) |
| Note model | One overwritten note per submission (280 chars), not a thread |
| Other employees | Do not see coaching notes even if “see team submissions” is on |

---

## Phasing

| Phase | Ships | Implementation plan |
|-------|--------|---------------------|
| **A — Front-of-house** | #14, #17, #15, #16, #8 | Separate plan after this spec |
| **B — Coach loop** | #4 | Second plan; may reuse Phase A tokens |

**Recommended ship order inside Phase A:** tokens + density → login brand + dashboard hierarchy → scorecard one-thumb → motion polish.  
**Phase B** after Phase A lands (or sequential in the same branch only if review stays manageable).

---

## Shared visual tokens (Phase A foundation)

Extend `theme.dart` and a small density prefs util; do not invent a second palette.

- **Chrome:** navy text/buttons; company `primaryColor` for accents only (existing Settings brand color).
- **BA status:** green / amber / red only via existing `baColor` — not decorative accent.
- **Density:** Comfortable (today’s spacing) | Compact (tighter padding; scorecard hit targets still ≥44px, prefer ~48 on phone).
- **Storage:** SharedPreferences key `ww_ui_density` (`comfortable` | `compact`). Corrupt/missing → Comfortable.
- **Scope:** dashboard people list/cards, scorecard tallies, login form padding. Master Sheet density remains independent (existing sheet tools prefs).
- **Motion:** ~200–280ms ease-out; no perpetual loops. Only the three listed interactions animate in this project.

Control placement for density: Settings tab (preferred home for appearance) and/or a compact control near dashboard tools — same pref either way.

---

## Phase A — Feature details

### #14 Brand-first login

**Surfaces:** `CompanyLoginScreen`, `CompanyHeader`, `BrandHeader`.

- **Before company code resolves:** product mark + “Sales Scorecard” secondary; form is clearly second to brand.
- **After code resolves:** company name (and `logoUrl` if present) is the **hero** — larger than step titles (“Enter company code”, pick location, pick name). Step UI lives below the brand block.
- Manager Google sign-in stays at the bottom of the code step; no competing hero cards.

### #17 Dashboard hierarchy

**Surface:** `ManagerScreen` Team Dashboard first viewport.

Top → bottom composition:

1. App bar / period controls (compact)
2. **One team total** (revenue + BA) as the dominant number
3. People section (existing List / Cards toggle)

Challenge promo, trends blurb, export / see-all chrome stay available but **do not compete** with the team total in the first viewport — tighten, collapse, or push below the fold as needed. Do not delete those features in this project.

### #15 Density app-wide

- Toggle: **Comfortable | Compact** reading/writing `ww_ui_density`.
- Apply spacing/font scale tokens to dashboard people rows/cards, scorecard `TallyRow` vertical rhythm, and login card padding.
- Master Sheet density unchanged and independently persisted.

### #16 Motion (exactly three)

1. **Manager tab change** — fade/slide of tab body content.
2. **Approve** (pending approval) — brief success flash / chip animation.
3. **Scorecard Save** — polish timing of the existing “Saved” flash (keep behavior; improve feel).

No other decorative motion in Phase A.

### #8 One-thumb scorecard

**Surface:** `ScorecardScreen`, `TallyRow`; primarily phone width (`< ~600` logical px).

- Larger `+/-` hit targets (~48px minimum on phone).
- **Sticky bottom bar:** Talked-to / BA / $ total always visible with Save (grow the existing bottom summary strip; reduce need to scroll for status).
- Slightly denser section headers; keep rose Memberships / Singles / Shop sections.
- Tablet/desktop: same structure; Comfortable stepping unless Compact density is on.

---

## Phase B — Coach notes (#4)

### Data model

Optional fields on `Submission` (Firestore + JSON):

| Field | Type | Meaning |
|-------|------|---------|
| `coachNote` | `String?` | Plain text; trim empty → treat as cleared (`null`) |
| `coachNoteBy` | `String?` | Manager display name |
| `coachNoteAt` | `DateTime?` | Last write |

- Max **280** characters.
- **One note per submission** — overwrite, not a thread; no attachments.
- Employee **Save** and manager tally edits that do not touch the note **must preserve** coach fields (merge / `copyWith` so updates never wipe notes by omission).
- Clear note = set fields to `null` / omit on write.

### Permissions (product rules)

| Role | Capability |
|------|------------|
| Manager | Add, edit, clear |
| Owning employee | Read only |
| Other employees | No access to notes (even if team submissions visibility is on) |

No push, email, or @mentions.

### Write UI (managers)

1. `showSubmissionEditor` — “Coach note” field below tallies.
2. Pending approval — optional one-line compose; can save with Approve or separately.
3. Master Sheet day editor — same submission editor path.

### Read UI

- **Employees:** soft banner/card on **Reports** for a selected day when `coachNote` is set (“Coach: …” + manager name / date). Not on the live tally canvas in v1.
- **Managers:** small note icon on pending list / employee breakdown when a note exists; open editor for full text.

### Errors

- Over 280 chars: inline validation; block save.
- Persist failures: existing `showStoreMessage` pattern.

---

## Architecture (files / flows)

| Area | Touchpoints |
|------|-------------|
| Tokens + density | `theme.dart`, new/extended density prefs util, Settings (and/or dashboard control) |
| Brand login | `company_login_screen.dart`, `company_header.dart`, `brand_header.dart` |
| Dashboard | `manager_screen.dart` |
| Scorecard | `scorecard_screen.dart`, `tally_row.dart` |
| Motion | Tab scaffold, pending approval UI, scorecard save status |
| Coach data | `submission.dart` (+ Store serialize/update paths) |
| Coach UI | `submission_editor.dart`, pending UI, Reports screen, glance icons on manager lists |

### Coach data flow

Manager writes note → Store update → Firestore submission doc → employee Reports reads the same fields. All non-note updates merge so coach fields survive.

### Error handling (shared)

- Bad density pref → Comfortable.
- Note validation before write.
- Network/persist errors → existing store message UX.

---

## Testing

- **Unit:** `Submission` JSON round-trip with and without coach fields; empty/whitespace note → cleared; employee-style update preserves coach fields when omitted from form.
- **Unit:** density token helpers (padding / row metrics).
- **Manual:** brand hierarchy after company resolve; dashboard first viewport; phone scorecard thumb targets + sticky totals; three motions; notes survive employee Save; other employee cannot see notes in team views.

---

## Success criteria

- Login after code resolve fails the “another brand” test if company name/logo is removed.
- Dashboard first viewport leads with team total before people detail clutter.
- Density toggle visibly changes dashboard + scorecard + login spacing without breaking Master Sheet prefs.
- Only the three listed motions are introduced.
- Phone scorecard totals/Save remain visible without hunting.
- Managers can leave a ≤280-char note; employees see it on Reports; notes are not wiped by employee Save.
