# Portfolio README + Screenshots Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add cleaned portfolio screenshots under `docs/portfolio/` and rewrite the root `README.md` so hiring managers see a showcase (demo link, gallery, Firebase/Stripe/stack highlights) before setup docs.

**Architecture:** README-only + static PNGs. No app code changes. Source captures live in Cursor assets; clean via GenerateImage with those files as `reference_image_paths`, save outputs into `docs/portfolio/`, then prepend a portfolio section to `README.md` while retaining (lightly refreshed) run/build docs below.

**Tech Stack:** Markdown, PNG assets, Cursor GenerateImage (reference-image edit), git.

**Spec:** `docs/superpowers/specs/2026-07-11-portfolio-readme-screenshots-design.md`

**Commit tip:** If `git commit` fails with `unknown option trailer`, use `/usr/local/bin/git commit -m "..."` .

---

## File map

| File | Responsibility |
|------|----------------|
| `docs/portfolio/scorecard.png` | Cleaned employee scorecard |
| `docs/portfolio/master-sheet.png` | Cleaned Master Sheet (data-rich) |
| `docs/portfolio/team-dashboard.png` | Cleaned Team Dashboard |
| `docs/portfolio/requests.png` | Cleaned Requests screen |
| `README.md` | Portfolio lead-in + embeds + existing docs below |

**Source captures (already on disk):**

| Target | Preferred source path |
|--------|------------------------|
| scorecard | `/Users/aaronheiner/.cursor/projects/Users-aaronheiner-Documents-Sandbox-wiggywash-beta/assets/Screenshot_2026-07-11_at_1.28.55_PM-cddc9e93-fa39-4809-85ba-8ee0f5588e91.png` (or full-browser `...1.28.48_PM-aba0d304...` if needed for crop) |
| master-sheet | `.../Screenshot_2026-07-11_at_1.30.19_PM-178f4299-c8f4-470f-a24d-2a7a5d2e6f66.png` (month view with charts; better than single-day sparse) |
| team-dashboard | `.../Screenshot_2026-07-11_at_1.28.34_PM-89a14534-6edd-4e7c-b42a-02efec5dca7c.png` |
| requests | `.../Screenshot_2026-07-11_at_1.30.27_PM-d73f435f-26b1-404c-b243-dc6709090e67.png` |

---

### Task 1: Create `docs/portfolio/` + cleaned scorecard

**Files:**
- Create: `docs/portfolio/scorecard.png`

- [ ] **Step 1: Generate cleaned scorecard**

Use GenerateImage with `reference_image_paths` pointing at the scorecard source PNG.

**Description (pass to GenerateImage):**
```
Edit this app screenshot for a portfolio README. Keep the same Wiggy Wash Flutter UI layout, colors, and typography. Crop out any browser chrome, OS menu bar, and bookmarks. Remove the beige banner that says the site is read-only / ask manager to update billing. Change the employee name from Jacob to Alex. Keep membership tallies, BA goal/actual, cars talked to, and totals looking realistic and sharp. No unreadably tiny text. Output a clean product UI screenshot only, no fake browser frame.
```

**filename:** `scorecard.png`  
Then copy/move the generated file into `docs/portfolio/scorecard.png` if the tool writes elsewhere:

```bash
mkdir -p docs/portfolio
# If GenerateImage wrote to another path, cp it:
# cp <generated-path> docs/portfolio/scorecard.png
ls -la docs/portfolio/scorecard.png
```

- [ ] **Step 2: Visual check**

Open `docs/portfolio/scorecard.png` — confirm no read-only banner, name is Alex (or similar generic), no browser chrome.

- [ ] **Step 3: Commit**

```bash
git add docs/portfolio/scorecard.png
git commit -m "docs: add portfolio scorecard screenshot"
```

---

### Task 2: Cleaned Master Sheet screenshot

**Files:**
- Create: `docs/portfolio/master-sheet.png`

- [ ] **Step 1: Generate cleaned master-sheet**

GenerateImage with reference = month-view Master Sheet source (`...1.30.19_PM...`).

**Description:**
```
Edit this Master Sheet screenshot for a hiring-manager portfolio. Preserve the sidebar, charts (revenue over time, by employee, BA %), data table, and Pending panel. Crop browser/OS chrome if any. Anonymize all employee names to generic ones (Alex, Jordan, Sam, Riley, Casey, Morgan). Keep numbers and chart shapes; do not redesign the UI. Sharp, readable product screenshot only.
```

**filename:** `master-sheet.png` → ensure at `docs/portfolio/master-sheet.png`

- [ ] **Step 2: Visual check** — no real names like Jacob/mike; UI intact.

- [ ] **Step 3: Commit**

```bash
git add docs/portfolio/master-sheet.png
git commit -m "docs: add portfolio master sheet screenshot"
```

---

### Task 3: Cleaned Team Dashboard screenshot

**Files:**
- Create: `docs/portfolio/team-dashboard.png`

- [ ] **Step 1: Generate cleaned team-dashboard**

Reference = Team Dashboard source (`...1.28.34_PM...`). Empty $0 state is weak for portfolio; produce a **clean, realistic filled demo day** that matches this UI chrome (same nav, header, cards) using plausible car-wash scorecard metrics (not marketing fluff).

**Description:**
```
Edit this Team Dashboard screenshot for a portfolio README. Keep the exact Wiggy Wash manager shell: left nav (Dashboard active, Master Sheet, Requests, Team, Prices, Billing, Settings), header Team Dashboard. Change the site subtitle from Springville to Lakeside. Replace the empty $0 / No submissions state with a realistic filled day view consistent with this product: team revenue summary cards and a few employee submission cards with anonymized names (Alex, Jordan), BA badges, and dollar totals. Crop any browser chrome. Sharp UI screenshot only, same visual language as the reference.
```

**filename:** `team-dashboard.png` → `docs/portfolio/team-dashboard.png`

- [ ] **Step 2: Visual check** — not empty; site not “Springville”; names generic.

- [ ] **Step 3: Commit**

```bash
git add docs/portfolio/team-dashboard.png
git commit -m "docs: add portfolio team dashboard screenshot"
```

---

### Task 4: Cleaned Requests screenshot

**Files:**
- Create: `docs/portfolio/requests.png`

- [ ] **Step 1: Generate cleaned requests**

Reference = Requests source (`...1.30.27_PM...`).

**Description:**
```
Edit this Requests screenshot for a portfolio README. Keep layout: Incoming / To-do empty states, Presets, Completion presets. Replace odd preset labels with clean ops labels: Out of soap, More towels, Need change. Replace completion presets with: Done, Completed for you, All set. Remove typos and nonsense chips. Crop browser chrome if any. Same UI style, sharp and professional.
```

**filename:** `requests.png` → `docs/portfolio/requests.png`

- [ ] **Step 2: Visual check**

- [ ] **Step 3: Commit**

```bash
git add docs/portfolio/requests.png
git commit -m "docs: add portfolio requests screenshot"
```

---

### Task 5: Rewrite README portfolio lead-in

**Files:**
- Modify: `README.md`

- [ ] **Step 1: Replace README with portfolio-first content**

Write the full file as follows (keeps practical docs below; updates paths from outdated `wiggywash/reference/app` to repo root):

```markdown
# Wiggy Wash

Flutter web SaaS for multi-location car washes — employee sales scorecards, live manager dashboards, and seat-based billing.

**Live demo:** [aheiner2001.github.io/wiggywash_beta](https://aheiner2001.github.io/wiggywash_beta/)

---

## Screenshots

### Employee scorecard
![Employee scorecard](docs/portfolio/scorecard.png)

Shift tallies, BA goal vs actual, membership and wash line items, live totals.

### Master Sheet
![Master Sheet](docs/portfolio/master-sheet.png)

Manager analytics: trends, per-employee breakdown, spreadsheet-style history.

### Team Dashboard
![Team Dashboard](docs/portfolio/team-dashboard.png)

Live team revenue and per-employee submission cards for the selected day.

### Requests
![Requests](docs/portfolio/requests.png)

Floor asks, assignable to-dos, and preset chips for fast ops communication.

---

## Built with

- **Flutter web (PWA)** — one codebase for phone and desktop
- **Firebase Authentication** — Google sign-in for managers and platform admins
- **Cloud Firestore** — multi-tenant data model (`companies` → `locations` → submissions, roster, config)
- **Firestore security rules** — role-based access and per-location read-only entitlement gates
- **Cloud Functions** — server-side Stripe Checkout, Customer Portal, and webhooks
- **Stripe** — quarterly location-seat subscriptions (quantity = paid sites; comps supported)

### Architecture at a glance

Parent companies buy **location seats**. Each site is `active`, `trial`, `comp`, or `read_only`. Employees use a sticky browser session (company code → scorecard); managers use Google. Writes are blocked when a location is read-only (UI + Store + rules). Stripe webhooks sync `purchasedSeats` into Firestore.

---

## What I built

- Multi-tenant SaaS tenancy (company approval, locations, manager invites)
- Employee sticky login vs manager Google auth
- Scorecard tallies, team dashboard, Master Sheet + trends
- Staff requests / task workflow with presets
- Seat billing, comps, Stripe Checkout + Customer Portal + webhooks

---

## Run locally

```bash
flutter pub get
flutter run -d chrome
```

## Build web

```bash
flutter build web --release --base-href "/wiggywash_beta/"
```

Output: `build/web/`.

## Deploy

GitHub Pages is configured via `.github/workflows/deploy-pages.yml` (builds on push to `mybranch` / `main`).

Firebase project: Firestore + Auth + Functions for billing (`functions/`).

---

## Project layout

```
lib/
  models/      company, location, submission, scorecard config, …
  services/    store.dart (auth, tenancy, entitlements, Stripe callables)
  screens/     scorecard, manager shell, master sheet, billing, …
  widgets/     shared UI
functions/     Stripe Checkout, Portal, webhook
docs/portfolio/  README screenshots
```
```

- [ ] **Step 2: Verify image paths resolve**

```bash
test -f docs/portfolio/scorecard.png \
  && test -f docs/portfolio/master-sheet.png \
  && test -f docs/portfolio/team-dashboard.png \
  && test -f docs/portfolio/requests.png \
  && echo OK
```

Expected: `OK`

- [ ] **Step 3: Update spec status**

In `docs/superpowers/specs/2026-07-11-portfolio-readme-screenshots-design.md`, set:

`**Status:** Approved`

- [ ] **Step 4: Commit**

```bash
git add README.md docs/superpowers/specs/2026-07-11-portfolio-readme-screenshots-design.md
git commit -m "docs: portfolio README showcase with stack highlights"
```

---

### Task 6: Final check

- [ ] **Step 1: Manual checklist**

1. Open `README.md` — portfolio section is first; screenshots embed with relative paths.
2. Confirm Built with lists Firebase Auth, Firestore, rules, Functions, Stripe.
3. Live demo URL is correct.
4. Images have no read-only banner / obvious real customer names.

- [ ] **Step 2: Optional push** (only if user asks)

```bash
git push origin mybranch
```

Then view on github.com so Pages/README rendering can be confirmed.

---

## Self-review (plan vs spec)

| Spec requirement | Task |
|------------------|------|
| `docs/portfolio/` images | 1–4 |
| Portfolio-safe cleanup rules | 1–4 descriptions |
| README gallery + captions | 5 |
| Built with / architecture / what I built | 5 |
| Live demo link | 5 |
| Keep run/build docs below | 5 |
| No app code changes | All tasks docs-only |
