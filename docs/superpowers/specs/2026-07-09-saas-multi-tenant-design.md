# SaaS Multi-Tenant Platform — Design Spec

**Date:** 2026-07-09  
**Status:** Approved (pending user review of written spec)  
**Approach:** Phased company-layer SaaS (Approach C)

## Summary

Transform Wiggy Wash from a single-brand app into a multi-tenant SaaS product where each car wash company is an isolated tenant. Improve employee login convenience (company code + name + PIN), add manager self-signup with platform-admin approval, and ship real `.xlsx` export for the Master Sheet. Includes a visual design refresh with a clean white landing experience.

## Goals

1. **Multi-tenant SaaS** — different car wash companies operate in fully isolated data silos.
2. **Simpler employee login** — company code replaces per-site codes; remember returning users on device.
3. **Delegated platform admin** — a trusted person approves new company signups (not the developer day-to-day).
4. **Better spreadsheet workflow** — real Excel export matching the Master Sheet layout; grid UI polish.
5. **Product-grade design** — white landing pages, white-label branding, improved manager navigation.

## Non-Goals (this project)

- Inline cell editing in the Master Sheet grid
- Email-based employee accounts (Google/Apple invite flow)
- Dark mode
- Billing / subscription management
- Per-company custom domains or subdomains

---

## Architecture & Data Model

### Firestore structure

```
companies/{companyId}
  name: string
  companyCode: string          // unique, 4–8 chars, case-insensitive lookup
  status: pending | active | suspended
  logoUrl: string?             // optional white-label logo
  primaryColor: string?        // optional hex accent
  createdAt: timestamp
  approvedAt: timestamp?
  approvedBy: string?          // platformAdmin uid

  locations/{locationId}/
    name, city, active, createdAt
    submissions/{submissionId}
    workers/{workerId}
    config/prices
    config/settings
    challenges/{challengeId}

users/{uid}
  email: string
  displayName: string
  role: platformAdmin | companyManager | employee
  companyId: string?           // set for companyManager
  locationId: string?          // manager's primary location (optional)
  createdAt: timestamp
```

### Roles

| Role | Who | Access |
|------|-----|--------|
| `platformAdmin` | Delegated platform operator | Approve/suspend companies; read all tenants |
| `companyManager` | Car wash owner/manager | Own company's locations, roster, Master Sheet, settings |
| `employee` | Floor staff | Scorecard only via device session (no personal account) |

### Store changes

- Add `activeCompanyId` above `activeLocationId`.
- All reads/writes route through `companies/{companyId}/locations/{locationId}/...`.
- Company code lookup replaces root-level site code lookup.
- Employee session caches: `companyCode`, `locationId`, `employeeName` in local storage.

### Migration

- Create `companies/wiggy-wash` with status `active`, company code `WIGGY`.
- Run existing migration helper to copy root `locations/` into `companies/wiggy-wash/locations/`.
- Existing manager `users/{uid}` docs get `role: companyManager`, `companyId: wiggy-wash`.

### Security rules (summary)

- `platformAdmin`: read/write all `companies/` docs.
- `companyManager`: read/write only their `companyId` subtree.
- Anonymous/authenticated employees: read workers roster for bound location; read/write own submissions only.
- Pending companies (`status: pending`): employees cannot sign in; managers see waiting screen only.

---

## Phased Delivery

### Slice 1 — Company model + company-code login + migration

**Employee flow (3-step wizard with progress indicator):**

1. Enter company code → validate → show company name/logo ("Welcome to Wiggy Wash")
2. Pick location → only if company has 2+ sites; auto-skip for single-site
3. Pick name → large tap targets; PIN field inline when required

**Remember me:** Device caches company + location + name. Return visits skip to scorecard. Profile menu offers "Switch person" and "Sign out."

**Manager flow (returning):** Google sign-in on landing → route to dashboard if `companyManager` with active company.

**Landing screen:** Single entry point — company code card + "Manager? Sign in with Google" link below. No exposed admin password button.

### Slice 2 — Self-service signup + platform admin approval

**New manager signup:**

1. Google sign-in
2. Create company form: company name, company code (uniqueness validated), first location name
3. Status set to `pending` → waiting screen shown

**Pending state UI:**

- Checkmark: account created
- Clock: waiting for approval
- Company code displayed (for sharing with employees once approved)
- Estimated timeline message

**Platform Admin console:**

- Tabs: Pending | Active | All
- Pending cards: company name, code, manager email, signup date, location count
- Actions: Approve (one tap → `active`) | Reject (optional reason)
- Active cards: View | Suspend
- No per-location management here (that's the company manager's job)

**Platform admin seeding:** Manually set `role: platformAdmin` on a `users/{uid}` doc. That user signs in with Google — no master password on landing page.

**Company manager post-approval:**

- Add/edit locations from manager dashboard (name, city — no per-site employee codes)
- Manage roster per location (names + optional PINs)

### Slice 3 — Excel export + Master Sheet polish

**Export:**

- Primary: `.xlsx` via `excel` package
- Fallback: `.csv` (existing)
- Bonus: copy to clipboard

**Excel layout matches on-screen Master Sheet:**

- Title row: company name + date range + view type
- Rotated column headers
- Point-value row
- Data rows with BA % color fills (green/amber/red)
- Totals row

**Export menu replaces single download icon:**

```
Export ▾
  Excel (.xlsx)      ← default
  CSV (.csv)
  Copy to clipboard
```

**Grid improvements:**

- Sticky header row (columns stay visible on vertical scroll)
- Sticky first column (names stay visible on horizontal scroll)
- Row hover highlight on desktop
- Export preview bar: "Exporting 14 rows · Mar 8, 2026 · Team view"
- Optional custom date range picker (e.g. Mar 1–7)

**Deferred:** inline cell editing, collaborative editing, pivot tables.

---

## Visual Design

### Landing & auth screens

- **Background: clean white (`#FFFFFF`)** — no gradients, no dark overlays
- Centered card on white: subtle border + light shadow for depth (card floats on white)
- Max-width 400px, 32px padding
- App logo at top; after company code validated, switch to company name/logo (white-label)
- Google sign-in: standard white pill button with Google logo
- Step wizard with `StepIndicator` and back navigation
- Large name tiles: full-width, optional initials circle, 48px+ tap targets
- Inline error messages (not toast-only)

### Typography

- Primary font: **Inter** (fallback: system sans)
- Hierarchy: 28px page titles, 18px subheadings, 15px body, 12px labels

### White-label branding

- Company `logoUrl` in header after code entry (fallback: initials avatar)
- Company `primaryColor` tints buttons/accents per tenant
- App default palette (navy, rose, blue) remains the platform fallback

### Manager dashboard

- Desktop (≥900px): sidebar nav — Dashboard · Master Sheet · Team · Prices · Settings
- Mobile: bottom nav with same destinations
- KPI cards at top: Revenue, Memberships, BA %, Active employees

### Scorecard (employee)

- Layout unchanged; polish only: 48px +/- buttons, optional haptic feedback on mobile

### Shared components (new)

- `StatusBadge` — pending (amber), active (green), suspended (red)
- `StepIndicator` — login wizard + manager signup
- Extended `EmptyState` for consistent empty views

### Dark mode

Not in scope.

---

## Error Handling

| Scenario | Behavior |
|----------|----------|
| Invalid company code | Inline: "Code not found — check with your manager" |
| Company suspended | Inline: "This company account is suspended. Contact support." |
| Company pending (employee) | Inline: "This company isn't active yet. Check back soon." |
| Duplicate company code on signup | Inline: "That code is taken — try another" |
| Export with no data | Toast: "Nothing to export for this period" |
| Firebase unavailable | Fall back to local storage; show banner |

---

## Testing

- **Slice 1:** Company code login works; multi-location picker; remember-me; migration preserves Wiggy Wash data; `flutter analyze` clean.
- **Slice 2:** Signup creates pending company; platform admin approve/reject; approved manager can add locations; pending company blocks employee login.
- **Slice 3:** `.xlsx` opens in Excel/Sheets with correct layout and colors; sticky headers work on web; CSV fallback still works.
- **Security:** Firestore rules deny cross-tenant reads; employees cannot access other companies' data.
- **Visual:** Landing page is white background; company branding appears after code entry.

---

## Files Expected to Change

| Area | Files |
|------|-------|
| Models | `lib/models/company.dart` (new), `lib/models/profile.dart`, `lib/models/location.dart` |
| Data layer | `lib/services/store.dart`, `firestore.rules` |
| Auth screens | `lib/screens/site_code_screen.dart` → refactor to company login wizard |
| Manager auth | `lib/screens/manager_auth_screen.dart` → signup + pending state |
| Platform admin | `lib/screens/super_admin_screen.dart` → platform admin console |
| Master Sheet | `lib/screens/master_sheet_screen.dart`, `lib/utils/xlsx.dart` (new) |
| Theme | `lib/theme.dart`, `lib/widgets/brand_header.dart` |
| Widgets | `lib/widgets/step_indicator.dart`, `lib/widgets/status_badge.dart` (new) |
| Manager nav | `lib/screens/manager_screen.dart` — sidebar layout |
| Migration | `lib/services/store.dart` — company migration helper |

---

## Open Questions (resolved)

| Question | Decision |
|----------|----------|
| Business model | SaaS — each car wash company is a tenant |
| Employee sign-in | Company code + name + optional PIN |
| Spreadsheet priority | `.xlsx` export first; keep grid UI |
| Onboarding | Self-service signup + approval gate |
| Platform admin | Delegated Super Admin (not developer) |
| Landing background | Clean white, no gradient |
| Architecture | Phased company-layer (Approach C) |
