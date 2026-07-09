# Master Sheet Trends + Tips — Design Spec

**Date:** 2026-07-09  
**Status:** Approved  
**Stack decision:** Stay on Flutter web (no React rewrite)

## Summary

Improve the manager Master Sheet with trends/stats charts, a remembered vertical/horizontal layout preference, and light styling polish. Replace the obsolete “How to view the breakdown” help flow with short Tips that explain how to use the main nav and core features for managers and employees.

## Goals

1. **Trends / stats** — managers can see revenue over time, employee comparison, and period summary numbers on Master Sheet.
2. **Layout orientation** — Master Sheet can switch between stacked (vertical) and side-by-side (horizontal) chart + table layout; preference remembered on device.
3. **Tips instead of breakdown help** — replace annotated “full breakdown” walkthrough with basic how-to tips keyed to nav / main features.
4. **Styling polish** — tighten Master Sheet / Trends UI to match the existing white SaaS look (hierarchy: stats → chart → table).

## Non-Goals

- Full React (or hybrid React embed) rewrite
- Excel-like inline cell editing in the Master Sheet grid
- Heavy new filter/sort system beyond reusing existing period controls
- App-wide portrait/landscape lock (phone orientation)
- Dark mode or full visual rebrand
- Platform-admin Tips content (out of scope for this slice)

---

## Decision: Stay on Flutter

Flutter web first-load can be heavier than a lean React SPA, but the product is not “too slow,” and the real need is Master Sheet features + Tips. A React rewrite would re-implement auth, multi-tenant routing, scorecard, exports, and manager shell for months of delay. Spreadsheet libraries are stronger in React, but charts/trends and layout toggles are achievable in Flutter without abandoning the SaaS work already shipped.

**Later (optional, not this project):** revisit React only if Excel-like editing becomes a hard requirement and Flutter table packages prove insufficient.

---

## Tips (replace HelpScreen)

### Current state

`HelpScreen` teaches “How to view the breakdown” with annotated screenshots (`help_tap_total.png`, `help_full_breakdown.png`). Entry points: help icon on employee scorecard and manager dashboard.

### Target

Rename/repurpose to a **Tips** screen (same entry points). Drop breakdown walkthrough and annotated shots.

**Employee tips (short cards):**
- Sign in with company code → location → name (and PIN if required)
- Tally line items and submit a shift
- Check “Your total today” / open breakdown if still available in UI (one line max — not a screenshot guide)
- Switch user from the profile menu when sharing a device

**Manager tips (short cards, nav-focused):**
- **Dashboard** — live team totals and approvals
- **Master Sheet** — history, export, trends/stats
- **Team** — roster, company code for employees, locations
- **Prices** — membership / wash / shop pricing
- Share the company code (e.g. `WIGGY`) with employees — they do not use Google

Tone: one tip per feature, plain language, no long prose. Audience enum stays (`employee` | `manager`).

### Assets

Annotated help images can be removed from the Tips UI; delete unused assets in implementation if nothing else references them.

---

## Master Sheet — Trends / Stats

### Placement

On Master Sheet, above the existing table: **summary stats → chart → table**. Reuse existing period controls (day / week / month / custom date range) so chart and table stay in sync.

### Slice 1 content

1. **Summary chips** — period revenue total, number of approved shifts, average revenue per shift.
2. **Revenue over time** — bar or line chart with one point per day in the selected period.
3. **Employee comparison** — bar chart of totals by employee for the period (cap to top N if roster is large, e.g. top 8 + “Other”).

Data source: same approved submissions already loaded for Master Sheet (no new Firestore collections).

### Chart library

Prefer a maintained Flutter chart package (e.g. `fl_chart`) consistent with Material theming and the white SaaS palette. Keep charts readable on phone (scrollable Master Sheet body).

### Later (not Slice 1)

- Inline cell editing
- Extra filter dimensions beyond period
- More chart types (membership mix, shop vs wash, etc.)

---

## Layout orientation setting

**Scope:** Master Sheet Trends + table layout only — not global app orientation.

| Mode | Behavior |
|------|----------|
| **Vertical** (default) | Stats, then chart, then table stacked |
| **Horizontal** | On wide layouts (≥ ~900px): chart (or stats+chart) beside table; on narrow phones, fall back to stacked so content stays usable |

Control: segmented button or icon toggle in the Master Sheet app bar / toolbar. Persist with `SharedPreferences` (e.g. `masterSheetLayout = vertical | horizontal`).

---

## Styling polish

- Align Master Sheet / Trends spacing, typography, and card treatment with existing `theme.dart` / white SaaS surfaces.
- Clear visual hierarchy: summary stats → chart → table.
- Avoid new purple/glow aesthetics; stay within current brand blues and neutrals.
- No redesign of login, scorecard, or unrelated manager screens in this project.

---

## Architecture notes

| Unit | Responsibility |
|------|----------------|
| Tips screen (replaces HelpScreen) | Static tip cards by audience; opened from existing help actions |
| Master Sheet screen | Hosts period controls, layout toggle, stats, charts, table, export |
| Chart helpers | Pure functions: submissions + date range → series for revenue-by-day and totals-by-employee |
| Prefs | Read/write layout orientation key |

No Firestore schema changes. No new auth roles. Charts are client-side aggregates of data already in `Store`.

### Error / empty states

- No submissions in period → empty chart placeholder + zeroed summary stats (not an error).
- Chart package load failure → hide chart section; table and export still work.

### Testing

- Unit tests for aggregation helpers (revenue by day, employee totals, empty period).
- Widget/smoke: Tips shows manager vs employee content; layout pref restores after restart (prefs mock or integration note).

---

## Implementation order

1. Tips screen replace HelpScreen + wire entry points; remove obsolete breakdown copy/assets if unused.
2. Aggregation helpers + summary stats on Master Sheet.
3. Charts (revenue over time + employee comparison) wired to period controls.
4. Vertical / horizontal layout toggle + prefs.
5. Styling pass on Master Sheet / Trends.

---

## Success criteria

- Managers see period stats and two charts on Master Sheet without leaving Flutter.
- Layout preference survives reload on the same device.
- Help icon opens Tips about nav/features, not “how to view breakdown.”
- No React migration; existing multi-tenant login and export keep working.
