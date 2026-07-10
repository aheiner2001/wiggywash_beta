# Polish Fixes + Company Themes — Design Spec (Spec A)

**Date:** 2026-07-09  
**Status:** Approved for write-up  
**Approach:** Spec A now (fixes + appearance); Spec B later (preset employee requests / manager board)

## Summary

Fix three polish problems (stale employee tip, weak display-density feedback, broken/unclear manager invite errors), then replace freeform brand-color hex with a small set of company-wide curated themes. Each theme ships with a light and dark variant; anyone can toggle dark mode on their own device. Messaging / preset “out of soap” requests are explicitly out of scope here and belong in Spec B.

## Goals

1. **Honest tips** — employee Tips never describe UI that does not exist.
2. **Obvious density** — Comfortable vs Compact is clearly visible on dashboard and scorecard (Master Sheet density stays separate).
3. **Reliable manager invites** — inviting a manager either succeeds with clear next-step copy, or fails with a useful error (not a silent/opaque failure).
4. **Company themes** — managers pick among curated palettes (keep Classic / original); Team, Sheet, Scorecard, and related shells follow the same theme.
5. **Personal dark mode** — separate Settings section; this device only; flips the dark variant of the company theme.

## Non-Goals

- Custom hex / freeform brand color (removed in favor of curated themes)
- Company-wide dark mode forced on all devices
- Per-employee company theme override
- Spec B: manager-preset quick requests, notification board, accept → todo workflow, freeform chat
- Push notifications, email for invites or requests
- Changing Master Sheet’s own density prefs model (still independent)

---

## Decisions (from brainstorm)

| Topic | Choice |
|-------|--------|
| Packaging | Approach 1 — Spec A (fixes + appearance), then Spec B (requests board) |
| Theme ownership | Company-wide (`themeId` on company) |
| Dark mode | Personal / this device only |
| Brand color hex | Replace with curated themes only |
| Theme direction | Option B — fewer themes (Classic + Forest + optional third), each with light + dark baked in |
| Messaging this round | Out of Spec A; Spec B = preset taps → manager board → accept/todo |

---

## Part 1 — Polish fixes

### 1.1 Employee tip #3

**Problem:** Tips claim you can tap “Your total today” for a line-by-line breakdown. That control does not exist on the scorecard.

**Change:** Rewrite or replace tip #3 so it matches real scorecard behavior (e.g. how tallies, save, or submit work). Audit other employee tips for the same class of stale copy.

### 1.2 Display density

**Problem:** Settings copy promises Comfortable / Compact for dashboard, scorecard, and login, but the visual delta is hard to notice.

**Change:**

- Increase the real spacing / control-size delta between Comfortable and Compact on dashboard and scorecard (and login where density already applies).
- Keep Master Sheet density independent (existing sheet prefs).
- If after a stronger delta Compact still feels pointless in QA, remove the app-density control and keep a single density — prefer fixing the delta first.

### 1.3 Add manager invite

**Problem:** Invite failed with an error the user could not recall; flow feels broken or opaque.

**Change:**

- Diagnose create path: Firestore rules for `managerInvites`, indexes, and Store error handling.
- Surface a clear, user-facing reason when safe (permission, duplicate email, network/unavailable).
- On success: confirm invite saved and tell the manager the invitee must sign in with **that Google email**.
- Do not invent a new invite product; fix and clarify the existing one.

---

## Part 2 — Appearance

### 2.1 Company theme picker

Managers (Settings) choose a **theme id**, not a hex:

| Id | Role |
|----|------|
| `classic` | Current Wiggy Wash look (default / migration target) |
| `forest` | Deep green palette, readable light + dark variants |
| Optional third (e.g. `sky`) | Only if Classic + Forest feel too few in implementation; max three for Spec A |

Each theme defines tokens for: scaffold background, surface, primary button, AppBar, section headers, tally accents, primary/muted text, hairlines — with **light and dark** variants.

**Applies to:** Team, Master Sheet chrome, Scorecard, manager dashboard / shell, login where themed today.

**Removed:** Brand color presets + custom hex UI and the mental model of “one accent overrides everything.”

### 2.2 Personal dark mode

- Separate Settings section (available to anyone who can open Settings on that device/session).
- Stored in local prefs (same pattern as app density).
- When on, `buildTheme(themeId, dark: true)` uses that theme’s dark token set.
- Does not write to the company document.

### 2.3 Data model

**Company document**

- Add `themeId` (string). Allowed values: `classic` | `forest` | (`sky` if shipped).
- Missing / unknown → treat as `classic`.
- Stop relying on `primaryColor` for theming. Existing `primaryColor` may remain in Firestore for backward compatibility but is ignored once themes ship (or cleared on first theme save — implementation plan picks one; default: ignore).

**Device prefs**

- `darkMode: bool` (default false).
- Existing density prefs unchanged in shape.

**Theme engine**

- Central map `themeId` → `{ light: tokens, dark: tokens }`.
- App root rebuilds `ThemeData` when company `themeId` or local `darkMode` changes.

### 2.4 Migration

- Companies with only `primaryColor` → UI and runtime behave as `classic`.
- No batch migration required for Spec A.

---

## Error handling

| Action | Behavior |
|--------|----------|
| Save `themeId` | Same pattern as former brand-color save: message on failure; update local company only after Firestore succeeds |
| Toggle dark mode | Local only; no network path |
| Invite manager | Explicit success or mapped error; never silent |

---

## Testing

- Employee tip #3 (and audit) does not mention a non-existent “tap Your total today” control.
- Density: Comfortable vs Compact produce clearly different padding / control metrics on scorecard (and dashboard).
- `Company.fromMap` parses `themeId`; missing/unknown → `classic`.
- Theme builder: given `classic`/`forest` + dark flag, brightness and key colors differ as expected.
- Invite: existing invite unit tests remain green; add/adjust coverage if Store error strings change.

---

## Spec B (parked — not this document)

Manager-defined **preset request chips** (e.g. “We are out of soap”). Employee taps a chip → request appears on a **manager notification board**. Manager **accepts** → closes on the employee side and lands on a **manager todo** until marked complete. Either-side freeform chat is deferred unless Spec B needs a tiny optional note on a request. Design Spec B in a separate brainstorm after Spec A ships.

---

## Implementation order (for the plan)

1. Tip copy fix  
2. Density delta (or remove if still useless)  
3. Manager invite diagnose + clearer errors/success  
4. Theme token system + `themeId` on company  
5. Settings: theme picker (managers) + dark mode section (anyone)  
6. Wire Team / Sheet / Scorecard / shell to theme  
7. Remove brand-color hex UI  

---

## Open implementation details (resolved in plan, not product questions)

- Exact third theme name/colors if Classic + Forest need a sibling  
- Whether to delete `primaryColor` on first theme save vs leave orphan field  
- Exact employee tip #3 replacement wording (must match live scorecard)
