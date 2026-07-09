# Dashboard Cards + Brand Color Settings — Design Spec

**Date:** 2026-07-09  
**Status:** Approved  
**Approach:** Dashboard List/Cards toggle + company-wide accent color via Settings (Approach 1)

## Summary

Add a List ↔ Cards toggle on the manager Team Dashboard so managers can glance at mini scorecards in a grid (each tallied line item on its own row). Add a Settings tab with a brand color picker that saves `companies/{id}.primaryColor` and tints accents company-wide (managers and employees), matching the white-label direction already in the SaaS multi-tenant design.

## Goals

1. **Dashboard layout choice** — switch between stacked list and grid of mini scorecards above the people section.
2. **Glanceable breakdowns** — Cards mode shows scorecard-like sections with one row per non-zero line item.
3. **Company brand color** — managers pick a color in Settings; it applies as an accent across the company.
4. **Settings home** — new manager nav destination for appearance (and room for future prefs).

## Non-Goals

- Logo upload / full white-label kit beyond `primaryColor`
- Full background / text recolor (accent-only)
- Per-user or device-only brand colors
- Changing Master Sheet layout in this project
- Inline Excel editing, React rewrite
- Platform-admin branding UI

---

## Decisions (from brainstorm)

| Topic | Choice |
|-------|--------|
| People layout | Toggle List ↔ Cards (not cards-only) |
| Color scope | Accent only (buttons, active nav, toggles, chart accents, key chips) |
| Color picker location | New **Settings** nav tab |
| Who sees the color | Whole company (employees + managers) |
| Implementation approach | Dashboard toggle + company `primaryColor` via Settings |

Reference mockups: `.superpowers/brainstorm/` (dashboard cards, settings brand color). User reference image: green “Springville” style accent on white surfaces.

---

## Feature 1 — Dashboard List / Cards

### Placement

Manager **Team Dashboard** (`ManagerScreen`), above the per-employee people section (after period bar, challenge, see-all, team totals, trends).

### Control

Segmented control: **List** | **Cards**.

- Default: **List** (current stacked `_EmployeeCard` behavior).
- Persist on device: `SharedPreferences` key e.g. `ww_dashboard_people_layout` (`list` | `cards`).
- Does not sync across devices or users.

### List mode

Keep existing stacked employee cards: summary row + expandable “Full breakdown.”

### Cards mode

Responsive grid:

| Width | Columns |
|-------|---------|
| Phone | 2 |
| Tablet / desktop | 3–4 (fit available width; not a fixed 3×3 / 4×4 board) |

Each mini card shows:

- Employee name + BA badge (same BA coloring rules as today)
- Section headers (Memberships / Singles / Shop) in scorecard-like rose style
- **One row per tallied line item** (label + count); hide zero-count items
- Period revenue total for that employee

Data: same period-scoped approved submissions as the list, grouped by `employeeName`.

### Empty / loading

Same empty and skeleton behavior as today when there are no submissions.

---

## Feature 2 — Settings + brand color

### Navigation

Extend `ManagerShell` destinations:

Dashboard · Master Sheet · Team · Prices · **Settings**

Wide: NavigationRail; narrow: bottom NavigationBar (may need scrollable/compact labels if five items feel tight — prefer keeping all five visible).

### Settings screen (v1)

- **Brand color** section: preset swatches (including default navy) + free color picker (`+`)
- Live preview: primary button, chip, note that nav/toggles/charts follow
- Save → update Firestore `companies/{companyId}.primaryColor` (hex string, e.g. `#2E7D52`)
- Only company managers (and platform admin acting on a company if applicable) can write; employees read via company doc

`Company.primaryColor` already exists on the model — wire UI + theme; no schema invention required.

### Accent application

`buildTheme` (or equivalent) accepts optional primary `Color` derived from `Store.activeCompany?.primaryColor`.

Tint:

- Elevated / filled buttons
- Selected nav / segmented control
- Switches
- Chart accent series
- Selected chips / key badges where navy is used as brand (not BA success/warning/danger semantics)

Do **not** recolor:

- App background / white surfaces as the main canvas
- Body text to low-contrast colors
- BA status colors (green/amber/red meaning)

Invalid or missing hex → fall back to current navy (`AppColors.navy`).

### Propagation

When company doc updates (existing listen / reload), theme rebuilds so employees and other managers see the new accent without a special sync path.

---

## Architecture

| Unit | Responsibility |
|------|----------------|
| `ManagerScreen` layout toggle + grid | List/Cards UI and prefs |
| Mini scorecard card widget | Compact per-employee breakdown (reusable from dashboard) |
| `ManagerShell` | Fifth Settings destination |
| `SettingsScreen` | Brand color picker + save |
| `Store` | `updateCompanyPrimaryColor` (or merge into existing company update) |
| `theme.dart` / `MaterialApp` | Theme from company primary |
| Prefs | Dashboard layout key only |

### Error handling

- Color save failure → snackbar; keep previous color in UI until success
- Malformed `primaryColor` in Firestore → treat as unset (navy)

### Testing

- Unit: parse hex → Color; invalid → null/fallback
- Unit/widget: line-item rows hide zeros; layout pref round-trip (prefs mock)
- Manual: Settings save visible on employee session after refresh; Cards grid on phone and wide

### Implementation order

1. Dashboard List/Cards toggle + mini scorecard grid  
2. Settings nav + Settings screen + save `primaryColor`  
3. Theme wiring for accent-only company color  
4. Polish (nav five-item layout, presets matching Springville-style green example)

---

## Success criteria

- Managers can switch List ↔ Cards and see per-line-item mini scorecards in a grid.
- Layout choice survives app reload on the same device.
- Settings tab exists; picking a color updates the company and accents the app for that company’s users.
- Default navy still works when `primaryColor` is null.
