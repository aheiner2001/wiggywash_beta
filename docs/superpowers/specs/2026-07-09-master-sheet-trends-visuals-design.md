# Master Sheet Trends Polish + Visual Settings — Design Spec

**Date:** 2026-07-09  
**Status:** Approved  
**Approach:** Enhance current Trends (`fl_chart` + stacked layout) — Approach 1

## Summary

Clean up Master Sheet chart axis labels and sparse single-day rendering, fix stacked layout so the spreadsheet is not height-crushed, and add a Trends-header **Visuals** gear with show/hide toggles for summary chips and charts (including two new optional charts). Prefs are device-local. Custom layout means any mix of built-in toggles — no freeform chart builder in v1.

## Goals

1. **Clean charts** — no overlapping Y-axis money labels; readable single-day revenue; consistent employee bars.
2. **Stacked layout height** — page scrolls as one column; sheet gets a solid min-height (~420px); Trends can collapse.
3. **Trends Visuals gear** — toggles for which visuals appear; panel mode Expanded / Chips only / Hidden.
4. **Optional visuals** — keep chips + revenue + by-employee; add BA % by employee and Memberships vs singles.
5. **Device prefs** — remember visibility + panel mode on-device.

## Non-Goals

- Score leaderboard chart (deferred)
- Per-chart style pickers (line vs bar) or freeform metric builder
- Moving visual settings to manager Settings tab or sheet tools toolbar
- Replacing `fl_chart` or rebuilding Trends as a separate dashboard module
- Changing spreadsheet freeze/columns/sort/filter behavior (already shipped)

---

## Decisions (from brainstorm)

| Topic | Choice |
|-------|--------|
| Visuals in scope | A–E: chips, revenue over time, by employee, BA % by employee, memberships vs singles |
| Settings location | Trends gear only (B) |
| Stacked height | Both: natural page scroll + min sheet height + collapse (C) |
| “Custom” | Show/hide mix of built-ins (A) — not freeform builder |
| Implementation approach | Enhance current Trends (1) |

---

## Section 1 — Chart polish + stacked layout

### Chart polish

- Y-axis money labels: compact format (e.g. `$1k`, `$500`, `$0`) with sufficient `reservedSize` so labels never collide or clip into chart area.
- Limit left-axis tick count (about 3–4); avoid drawing duplicate/overlapping titles.
- Single-day (or single-point) revenue series: remain readable (dot visible; optional short caption or tooltip with value) — do not rely on a curved line between one point.
- Employee bar chart: same compact money axis treatment; keep name truncation sensible.

### Stacked layout

- When layout is **vertical (stacked)** and width is not side-by-side:
  - Outer content scrolls as one column (trends + sheet).
  - Trends section uses **natural height** (not a fixed fraction that steals sheet space).
  - Spreadsheet region uses a **minimum height ~420px** (not `maxHeight * 0.55` of leftover viewport).
- Horizontal / side-by-side layout: keep existing split behavior; still apply chart polish.
- Collapse modes (chips-only / hidden) are controlled by the Visuals gear (Section 2) and further free sheet space when desired.

---

## Section 2 — Trends Visuals gear

### Control placement

- Gear / **Visuals** control on the **Trends** section header only.
- Not on the Master Sheet Columns/Sort/Filter/Density toolbar.
- Not on the manager Settings tab.

### Toggleable visuals

| Id | Visual | Default |
|----|--------|---------|
| `summary` | Period total / Shifts / Avg per shift chips | On |
| `revenueOverTime` | Revenue over time line chart | On |
| `byEmployee` | Revenue by employee bar chart | On |
| `baByEmployee` | BA % by employee (new) | On |
| `membershipMix` | Memberships vs singles (new) | On |

**Custom** = any combination of the above checkboxes. **Show all** / **Reset** restore defaults.

### Panel mode

| Mode | Behavior |
|------|----------|
| `expanded` | Show enabled visuals (default) |
| `chipsOnly` | Summary chips only (if summary enabled); hide charts |
| `hidden` | Hide entire Trends block (sheet gets maximum space) |

### New charts (v1)

**BA % by employee**

- Bar (or simple horizontal bars) of business average per employee for the current period/scope.
- Reuse period / team-member filters already driving Master Sheet stats.
- Y-axis as percent (0–100-ish with headroom); color optional (can stay navy for consistency with other charts, or light BA tint — prefer navy for v1 consistency).

**Memberships vs singles**

- Grouped or stacked bars: membership count vs single-wash count per employee (or period totals if employee breakdown is noisy — prefer **per employee** for the current scope, top N + Other if needed, matching existing employee chart pattern).

### Prefs

- Device-local `SharedPreferences` key (e.g. `ww_master_sheet_trends_visuals`) storing:
  - visibility map for each visual id
  - panel mode
- Same pattern as `ww_master_sheet_layout` / sheet tools prefs — not synced to Firestore.

### Architecture (sketch)

```
MasterSheetScreen
  └─ Trends header + Visuals gear
       ├─ TrendsVisualPrefs (load/save)
       └─ MasterSheetTrends(stats, prefs)
            ├─ summary chips (if on)
            ├─ revenue chart (if on)
            ├─ by-employee chart (if on)
            ├─ BA% chart (if on)      // new aggregates as needed
            └─ membership mix chart (if on)
```

Extend `master_sheet_stats` (or a small sibling helper) with BA-by-employee and membership/single counts so charts stay pure/presentation-only.

---

## Error handling & edge cases

- All visuals toggled off while panel is expanded: show a short empty hint + link/action to open Visuals / Show all.
- Panel `hidden`: no Trends chrome except a way to restore (e.g. small “Show Trends” text button above the sheet, or keep a minimal header with gear only — **prefer a slim “Trends (hidden) · Show” chip** so the gear remains reachable).
- Empty period: existing empty-chart messages; new charts follow the same pattern.
- Single employee / single day: charts remain valid and non-broken.

---

## Testing

- Unit tests for any new aggregate helpers (BA by employee, membership vs singles).
- Manual: stacked layout sheet ≥ ~420px tall; Y-axis labels do not overlap; toggles persist across restart; chips-only and hidden free sheet space; export/sheet tools unchanged.

---

## Success criteria

- Charts look clean (no `$1,000b`-style overlap).
- Stacked Master Sheet is usable without crushing the grid.
- Managers can show/hide visuals and collapse Trends from the Trends gear.
- BA % and membership mix are available as optional charts.
- Prefs remembered on device.

---

## Out of scope (deferred)

- Score leaderboard  
- Chart type pickers / freeform builder  
- Cloud-synced visual layouts  
- React rewrite  
