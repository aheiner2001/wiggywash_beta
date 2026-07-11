# Portfolio README + Cleaned Screenshots — Design Spec

**Date:** 2026-07-11  
**Status:** Approved (pending user review of written spec)  
**Surface:** GitHub repository `wiggywash_beta` — root `README.md` + `docs/portfolio/` assets  

## Summary

Turn this repo into a shareable **resume / portfolio item** for hiring managers: a polished README lead-in with cleaned product screenshots and employer-facing tech highlights (Flutter web, Firebase Auth/Firestore, Cloud Functions, Stripe), while keeping existing run/build docs below the fold.

## Goals

1. One link to share (this GitHub repo) that reads as intentional portfolio work.
2. Screenshots that look professional and portfolio-safe (anonymized, no billing banners / browser chrome clutter).
3. Surface integrations employers care about: Firebase, Firestore, Google auth, Stripe, Cloud Functions, multi-tenant design.
4. Keep the repo usable as a real project (dev instructions remain, demoted below the showcase).

## Non-goals

- Separate marketing microsite or second deploy URL.
- Changing app product code solely for prettier screenshots (README + image assets only).
- Fabricating fake case-study PDFs or inventing metrics not visible in UI.
- Dual-audience company sales landing (audience is hiring managers).

## Decisions locked

| Topic | Choice |
|-------|--------|
| Audience | Hiring managers / recruiters |
| Approach | README showcase gallery (Approach 1) |
| Cleaning level | Portfolio-safe anonymization + polish |
| Image location | `docs/portfolio/*.png` embedded from root README |
| Live demo | Link to existing GitHub Pages app URL |

## README structure

### Above the fold (portfolio)

1. **Title + one-line pitch** — digital sales scorecard / multi-location car wash ops SaaS (Flutter web).
2. **Live demo** — `https://aheiner2001.github.io/wiggywash_beta/` (or current Pages URL).
3. **Screenshot gallery** — 4 images with short captions:
   - Employee scorecard
   - Master Sheet (charts + spreadsheet)
   - Team Dashboard
   - Requests / task workflow
4. **Built with** — bullet list of stack/integrations (see below).
5. **What I built** — concise feature bullets showing systems judgment (tenancy, auth split, billing seats, analytics).

### Below the fold (project docs)

Preserve (and lightly refresh if outdated) existing sections: run locally, build web, PWA, cloud sync / Firebase notes. Do not delete operational docs.

## Employer-facing highlights (must appear)

- Flutter web (PWA)
- Firebase Authentication (Google sign-in for managers / platform admin)
- Cloud Firestore (multi-tenant `companies` → `locations`)
- Firestore security rules (roles, read-only entitlement gates)
- Cloud Functions (Stripe Checkout, Customer Portal, webhooks)
- Stripe (quarterly location-seat subscriptions)
- Optional short “architecture at a glance” (tenant → entitlements → writes)

## Screenshot set + cleanup rules

**Source:** user-provided captures (scorecard, master sheet, team dashboard, requests).

**Include**

| File (target) | Source intent |
|---------------|---------------|
| `docs/portfolio/scorecard.png` | My Scorecard — filled tally UI |
| `docs/portfolio/master-sheet.png` | Master Sheet with trends + table (prefer data-rich month/team view) |
| `docs/portfolio/team-dashboard.png` | Team Dashboard |
| `docs/portfolio/requests.png` | Requests manager view |

**Prefer not to feature** empty $0 “No submissions yet” as a hero shot unless cleaned into a deliberate empty state; prefer data-rich Master Sheet / scorecard.

**Per-image cleanup**

1. Crop browser chrome / OS UI when present.
2. Anonymize employee names → generic (Alex, Jordan, Sam, …).
3. Remove “This site is read-only. Ask your manager to update billing.” banner.
4. Replace or remove odd preset labels (e.g. nonsense chips / typos) with neutral ops labels.
5. Soften or anonymize site names if they read as private customer data; product branding (Wiggy Wash) may remain.
6. Export reasonably compressed PNGs suitable for GitHub.

## File map

```
docs/portfolio/
  scorecard.png
  master-sheet.png
  team-dashboard.png
  requests.png
README.md                 # portfolio lead-in + embeds + existing docs below
docs/superpowers/specs/2026-07-11-portfolio-readme-screenshots-design.md
```

## Success criteria

1. Opening the GitHub repo shows screenshots and stack highlights without scrolling into setup noise first.
2. No obvious PII / billing-error chrome in featured images.
3. Live demo link works.
4. Existing local run instructions still present further down the README.

## Testing (manual)

- Preview README on github.com (or locally via raw markdown viewer).
- Click live demo link.
- Spot-check image paths load on GitHub.
