# Sticky Login + Per-Location Billing — Design Spec

**Date:** 2026-07-10  
**Status:** Approved  
**Surface:** Flutter **web** (GitHub Pages); employee session is browser-local (SharedPreferences → local storage)  

## Summary

Improve employee login for hybrid multi-tenant scale (many companies; some with many locations, up to ~155 sites) by making return visits nearly zero-friction: after entering a company/site path once, the browser keeps session state as long as possible and boots straight to the scorecard. Add per-location seat billing with a soft paywall: unpaid or over-seat locations become **read-only** (view history, no new writes), without locking an entire multi-site brand.

## Goals

1. **Fewer login steps on return** — no re-entering company code when a valid local session exists.
2. **Long-lived local session** — persist company, location, and employee identity in the browser until the user explicitly switches or signs out, or the server-side identity becomes invalid.
3. **Scalable location pick** — searchable list + last-used/recent for large location counts; skip location step when only one site exists.
4. **Hybrid tenancy** — support both single-site companies and large multi-location brands under the existing `companies/{id}/locations/{id}` model.
5. **Per-location paywall** — bill by seats; over-limit / past-due locations are read-only; paid locations keep full access.
6. **Enforce paywall beyond UI** — Store gates writes; Firestore rules reject mutating ops when a location is read-only.

## Non-goals (this pass)

- Stripe Checkout, Customer Portal, or webhooks (phase 2 — same entitlement fields).
- Employee SSO / email-password accounts.
- Per-site QR / deep-link login.
- Cross-location live dashboards (manager still works one active location at a time).
- Changing the manager Google sign-in / invite / platform-admin approval flow (except billing admin hooks).

## Decisions locked

| Topic | Choice |
|-------|--------|
| Tenant shape | Hybrid — many companies; each 1…N locations |
| Login pain to fix first | Too many steps on return visits |
| Session | Sticky browser-local; keep as long as possible |
| Billing unit | Per-location seats |
| Unpaid / over-seat | Soft gate → **read-only** (not hard lockout of whole company) |
| Payments v1 | Manual / platform-admin (and manager Billing UI) sets seats & access; Stripe later |
| Product surface | Website (Flutter web) |

## Current baseline

- Employee flow: company code → location (if multi) → name → optional PIN (`CompanyLoginScreen` + `Store`).
- Device already persists `ww_active_company`, `ww_active_location`, `ww_employee_profile`, `ww_employee_company_code` via SharedPreferences (web → local storage).
- Company status `pending` / `active` / `suspended` already gates employee entry.
- No billing fields or Stripe today.

## Employee login & session

### First visit

1. Enter company code (normalize uppercase).
2. Reject pending/suspended companies with clear copy.
3. If multiple locations: searchable picker with **Last used** / **Recent** when available; if one location, auto-select.
4. Pick name from roster; PIN if `worker.requiresPin`.
5. Persist session keys; open scorecard.

### Return visit (happy path)

1. App boot loads prefs.
2. Re-validate: company exists and is `active`; location exists and is active; worker still on roster (by profile key/name).
3. Apply location entitlement (`active` / `trial` / `read_only`).
4. Route to **scorecard** without showing the company-code wizard.
5. If worker requires PIN: prompt **once per app/browser session launch** (not on every navigation).

### Explicit exits (always available from employee UI)

- **Switch person** — clear employee profile; keep company + location; show name picker.
- **Switch location** — clear location (+ optionally keep company); show searchable location list.
- **Sign out** — clear company, location, profile, and company code prefs; return to landing.

### Invalidation (partial, not scorched-earth)

| Condition | Behavior |
|-----------|----------|
| Company suspended / missing | Clear company-scoped prefs; landing + message |
| Location missing / inactive | Keep company; force location pick |
| Worker removed from roster | Keep company + location; force name pick |
| Location `read_only` | Stay signed in; scorecard/history viewable; writes disabled + banner |

### Web notes

- Persistence is per-browser profile (SharedPreferences on web). Clearing site data signs the employee out.
- No server-side employee auth session; anonymous Firebase auth (if used) remains for Firestore access rules as today.
- “As long as possible” means **no idle TTL** in v1; only explicit sign-out or invalidation above.

## Location picker (scale)

- Filter-as-you-type on location name (and city if present).
- Pin **Last used** at top when restoring a multi-site company without a valid location, or when switching location.
- Optional short list of recent location IDs in prefs (`ww_recent_locations` JSON list, capped ~5).
- Single-location companies never show the picker.

## Paywall & entitlements

### Company fields

- `purchasedSeats` (int). New companies default to `1`. Legacy active companies are backfilled to at least their current location count so nothing flips to read-only on deploy.
- Optional: `billingStatus` (`ok` | `past_due` | `trialing`) for display
- Phase 2: `stripeCustomerId`, `stripeSubscriptionId`

### Location fields

- `accessStatus`: `active` | `trial` | `read_only`
- `trialEndsAt` (optional timestamp) — when trial ends, treat as `read_only` until a seat is assigned

### Seat accounting

- Count locations with `accessStatus` in (`active`, `trial`) toward `purchasedSeats`.
- Managers/admins cannot set more locations to `active`/`trial` than `purchasedSeats` allows.
- **New locations (v1 default):** start as `trial` with `trialEndsAt` = now + 14 days; when trial ends, status becomes `read_only` until a seat is free and assigned.

### Read-only behavior

**Allowed:** view submissions, master sheet / history, tips, branding display.  
**Blocked:** create/update submissions (tallies/save), create staff requests / personal todos, mutating team/config writes from that location context.

UI: persistent banner — “This site is read-only. Ask your manager to update billing.”  
Managers on a read-only location see the same banner plus link/entry to Billing.

### Enforcement

1. `Store` checks `location.accessStatus` (and trial expiry) before mutating APIs; return a clear error string.
2. Firestore rules: deny create/update on location ops subcollections when that location’s `accessStatus == 'read_only'`. Trial expiry is reflected by flipping `accessStatus` to `read_only` (client/admin/Billing UI or a later scheduled job); rules trust the stored `accessStatus` field.

### v1 billing UX

- **Platform admin:** set `purchasedSeats`; set per-location `accessStatus`.
- **Company manager Billing screen:** show seats used vs purchased; toggle which locations consume seats (cannot enable more actives than seats); copy that Stripe self-serve comes later.
- Phase 2: Stripe Checkout to buy seats; webhooks update `purchasedSeats` / statuses.

## Architecture

```
Browser prefs (long-lived)
  companyId, companyCode, locationId, employeeProfile, recentLocations
        │
        ▼
Store.init / boot restore
  validate company → location → worker → entitlement
        │
        ├─ OK write     → AppView.employee (scorecard)
        ├─ OK read_only → AppView.employee + banner, writes no-op/blocked
        └─ invalid      → appropriate login step

Firestore
  companies/{id}     + purchasedSeats, billingStatus?
  locations/{id}     + accessStatus, trialEndsAt?
```

## Migration

- Existing active companies: set `purchasedSeats` high enough to cover current location count (or platform admin one-time backfill) so nothing suddenly goes read-only.
- Existing locations: default `accessStatus: active` if missing.
- No change to company codes or employee roster format.

## Success criteria

1. Returning employee on the same browser opens the site and lands on the scorecard without re-entering the company code.
2. Switch person / location / sign out work and are discoverable.
3. A company with 100+ locations can find a site via search in a few seconds.
4. A location marked `read_only` can view data but cannot save a new scorecard (UI + rules).
5. A multi-location company can keep paid sites fully working while extras are read-only.

## Testing (manual smoke)

- First-time login → refresh page → still on scorecard with same name/location.
- Sign out → must enter code again.
- Switch location on multi-site company → search works; last used appears.
- Set location `read_only` → Save/submit blocked; banner visible.
- Suspend company → employee kicked to landing on next boot/refresh.
