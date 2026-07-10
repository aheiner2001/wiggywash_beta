# Themes v2 + Remove Dark Mode — Design Spec

**Date:** 2026-07-10  
**Status:** Approved (recommended defaults; A–F no permission gates)  
**Extends:** `docs/superpowers/specs/2026-07-09-polish-themes-design.md`

## Summary

Make company themes clearly distinct, add two lighter palettes, and remove personal dark mode (readability).

## Decisions

| Topic | Choice |
| --- | --- |
| Dark mode | Remove UI + prefs; always light |
| Existing themes | Keep Classic / Forest / Sky; strengthen contrast between them |
| New themes | Add **Sand** (warm light) and **Blush** (soft rose light) |
| Ownership | Still company-wide `themeId` |

## Theme identities (light only)

| Id | Feel | Accent direction |
| --- | --- | --- |
| classic | Red wash brand | Strong red accent, cool blue tallies |
| forest | Green ops | Deep green accent, mint headers |
| sky | Cool blue | Blue accent, icy fields |
| sand | Light warm | Amber/tan accent, cream surfaces |
| blush | Light soft | Rose accent, pale pink headers |

## Implementation notes

- `WiggyTokens.forId` / `buildAppTheme` drop `dark:` (or force `false`)
- Remove Settings dark toggle + `DarkModePrefs` usage
- Expand `AppThemeId` enum + settings chips
- Unknown/legacy `themeId` still falls back to classic

## Out of scope

Custom hex, per-user theme override, dark variants.
