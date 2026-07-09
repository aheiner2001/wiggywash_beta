# Master Sheet Spreadsheet Feel — Design Spec

**Date:** 2026-07-09  
**Status:** Approved  
**Stack decision:** Enhance current Flutter `_SpreadsheetTable` (no React grid, no inline editing)

## Summary

Make the manager Master Sheet feel more like a real spreadsheet: freeze panes, show/hide columns, sort & filter, row density, and visual polish that reduces navy-on-navy fatigue. All sheet tools live in the Master Sheet toolbar and persist on-device. Inline cell editing stays deferred.

## Goals

1. **Freeze panes** — sticky header row + sticky first column (Name or Date) while scrolling.
2. **Show / hide columns** — toggle metric columns; Name/Date always visible; remember on device.
3. **Sort & filter** — sort by key metrics; filter by employee / min BA% / min revenue; totals from visible rows.
4. **Density** — Comfortable / Compact / Dense row heights.
5. **Visual polish** — stronger gridlines, soft zebra, clearer totals, light header (not solid navy), brand accent only on chrome/selection.
6. **Toolbar-only settings** — no manager Settings tab for these controls.

## Non-Goals

- Inline Excel-like cell editing
- React / AG Grid / hybrid embed
- Column drag-resize in v1
- Syncing sheet prefs to Firestore (device-local only)
- Changing BA color rules (green / amber / red stay as today)
- Changing export contents to match hidden/filtered view (export remains full period data)
- Manager Settings tab for sheet tools

---

## Approach

**Enhance `_SpreadsheetTable` in `master_sheet_screen.dart`** plus a small device-prefs helper (same pattern as `ww_master_sheet_layout`).

Implement in slices within one plan:

1. Freeze panes + visual polish (incl. less navy fatigue)
2. Show / hide columns
3. Sort & filter
4. Density + toolbar overflow polish

---

## Section 1 — Freeze panes + visual polish

### Freeze

- Sticky **header** (column labels) while vertical scrolling.
- Sticky **first column** (Name in team/member views, Date in month view) while horizontal scrolling.
- Existing dual-scroll / split-header patterns may be extended; behavior should match “Excel freeze panes” for the first column + header.

### Visual polish

- Stronger gridlines and soft zebra striping on body rows.
- Totals row: clear emphasis (soft blue wash, bold type) — pinned at bottom, not sorted.
- **Reduce navy-on-navy fatigue:**
  - Header: light gray wash (`#F4F6FA`-class) with muted label text — **not** a solid navy bar.
  - Body text: navy for readability.
  - Brand `primaryColor`: toolbar / selected controls only — not the whole header.
- BA % colors unchanged (green / amber / red).
- Point-value row stays a light secondary band under the header.

---

## Section 2 — Show / hide columns

### Control

- **Columns** menu on the Master Sheet toolbar (checklist popover / bottom sheet on narrow).

### Rules

| Column | Toggleable? |
|--------|-------------|
| Name / Date (first column) | Always on (frozen) |
| Total Talked | Yes |
| Each line item | Yes (per item) |
| Total VIP | Yes |
| Above Eco | Yes |
| BA % | Yes |
| Score | Yes |
| Revenue | Yes |

- Point-value row only shows cells for visible columns.
- **Show all** and **Reset** (defaults) actions in the menu.
- Default: all columns visible (current behavior).

### Export

Hide is **view-only**. CSV/XLSX export still includes the full column set for the period.

### Prefs

Device-local (`SharedPreferences`), e.g. under a Master Sheet sheet-tools key namespace.

---

## Section 3 — Sort & filter

### Sort (v1)

- Keys: **Name/Date** (default), **Revenue**, **BA %**, **Score**, **Total Talked**.
- Direction: Asc / Desc toggle.
- Totals row always stays at the bottom (never sorted into the middle).
- Active sort reflected lightly in toolbar (and optionally on the sorted column header label).

### Filter (v1)

- **Employee** multi-select (team view) — hide people not selected.
- Optional **min BA %** threshold.
- Optional **min revenue** threshold.
- Toolbar shows active filter state (e.g. “Filter · N active”) + one-tap **Clear**.
- Totals recompute from **visible** rows only.

### Scope

- Composes with existing period controls and Team / Member / Month views.
- Sort/filter are **view-only**; export ignores them (full period data), same as column hide.

### Prefs

Remember last sort key/direction and filter thresholds on device (employee multi-select may reset per session if storing large name lists is awkward — prefer remembering thresholds + sort; employee filter can be session-only if needed for simplicity).

**Decision (explicit):** Remember sort key/dir, min BA%, min revenue, and density/columns across sessions. Employee multi-select filter is **session-only** (clears on leave Master Sheet) to avoid stale roster names.

---

## Section 4 — Density + toolbar UX

### Density

| Mode | Approx. row height | Default? |
|------|--------------------|----------|
| Comfortable | ~40px | Yes |
| Compact | ~32px | |
| Dense | ~26px | |

Header height may scale slightly with density but stays readable (rotated labels remain usable).

### Toolbar

Order (left → right conceptually):

1. Existing view / period / member controls  
2. **Columns** · **Sort** · **Filter** · **Density**  
3. Export (and any existing actions)

- Light chrome: white / outline buttons; brand primary only for active/selected state.
- Narrow screens: fold sheet tools into a **Sheet tools** overflow menu if the bar wraps poorly.

### Prefs blob

Device-local keys (or one JSON blob) for:

- Visible column ids  
- Sort key + direction  
- Min BA% / min revenue (not employee multi-select)  
- Density  

Same pattern as `ww_master_sheet_layout` — not synced to Firestore. Not exposed on the manager Settings tab.

---

## Architecture

```
MasterSheetScreen
  ├─ existing trends / period / view controls
  ├─ Sheet tools toolbar (Columns, Sort, Filter, Density)
  ├─ SheetToolsPrefs (SharedPreferences load/save)
  └─ _SpreadsheetTable
       ├─ visible column set
       ├─ sorted + filtered row list
       ├─ density metrics
       ├─ freeze: sticky header + first column
       └─ light header / zebra / totals styling
```

- Prefer a small pure helper for sort/filter of `List<Submission>` (unit-testable) rather than burying logic only in widgets.
- Column visibility maps to existing header/body builders so point row, data rows, and totals stay aligned.

---

## Error handling & edge cases

- Hiding all toggleable columns: still show Name/Date; empty metric area is allowed but **Reset** / **Show all** remain available.
- Filter matches zero rows: empty state message + Clear filter; totals show zeros / em dash as appropriate.
- Month view: first column is Date; employee filter may be hidden or no-op in month aggregate view if rows are not per-person.
- Member view: employee filter redundant — hide or disable employee multi-select when already drilled to one member.

---

## Testing

- Unit tests for sort/filter helper (order, totals from visible rows, totals pinned).
- Widget/smoke: column hide removes cells from header + body + point row consistently.
- Manual: freeze panes on web scroll; density switches; prefs survive hot restart; export still full data with columns hidden / filters on.

---

## Out of scope (deferred)

- Inline cell editing  
- Column drag-resize  
- Click-header-to-sort on every column (v1 uses toolbar Sort; header click can be a later nicety)  
- Cloud-synced per-user sheet layouts  
- React spreadsheet rewrite  

---

## Success criteria

- Manager can scroll a wide sheet and still see Name/Date + headers.
- Manager can hide noisy columns and get a tighter view that persists on that device.
- Manager can sort by revenue/BA and filter underperformers; totals match what they see.
- Sheet no longer feels like a solid navy block; BA colors remain the main color signal in the grid.
- No Settings-tab clutter; tools live on Master Sheet only.
