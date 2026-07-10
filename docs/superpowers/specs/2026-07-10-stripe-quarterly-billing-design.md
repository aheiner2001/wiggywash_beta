# Stripe Quarterly Billing + Comp Seats — Design Spec

**Date:** 2026-07-10  
**Status:** Approved  
**Surface:** Flutter web; Firebase (Firestore + Cloud Functions); Stripe Checkout + Customer Portal  
**Depends on:** [Sticky Login + Per-Location Billing](./2026-07-10-sticky-login-location-billing-design.md) entitlement fields (`purchasedSeats`, `accessStatus`, read-only gates)

## Summary

Parent companies pay for **location seats** on a **quarterly** Stripe subscription. Site managers use the app; the parent (company manager / billing contact) pays. Platform admins can mark individual locations as **comp** (full access, no seat charge) for test sites or gifted manager access. Cards never touch Wiggy Wash servers — Stripe holds payment methods; webhooks sync seat quantity into Firestore.

This is the Phase 2 payments design referenced by the sticky-login billing spec. Manual seat edits remain valid until Stripe is live, and as an admin override afterward.

## Goals

1. **Quarterly seat billing** — one Stripe subscription per company; quantity = paid seats.
2. **Parent pays, sites operate** — one customer for ~155 locations under different site branding is fine; billing is company-scoped.
3. **Comp seats** — platform admin can grant full access to specific locations without increasing `purchasedSeats`.
4. **Safe card handling** — no PAN storage; Checkout + Customer Portal only; webhook-driven entitlement sync.
5. **Preserve soft paywall** — over-seat / unpaid sites stay `read_only`; paid and comp sites keep full write access.
6. **Phased delivery** — ship comp + corrected seat math before Stripe wiring if needed.

## Non-goals (v1 of this work)

- Per-location invoices or per-site Stripe customers.
- Storing card numbers or building a custom card form.
- Employee-facing billing UI.
- Whole-company comps as the only free model (comps are **per location**).
- Automatic past-due → company-wide lockout (optional later; see Phase 3).
- Changing employee sticky login or Google manager auth beyond Billing / Admin hooks.

## Decisions locked

| Topic | Choice |
|-------|--------|
| Who pays | Parent company (one Stripe customer per `companies/{id}`) |
| Cadence | Quarterly |
| Unit | Location seats (`purchasedSeats` ↔ subscription quantity) |
| Free access | **Comp seats** (per location), not whole-company-only comps |
| Approach | Stripe Checkout + seat quantity + webhook sync (Approach 1) |
| Cards | Stay in Stripe; never store PANs in Firebase/app |
| Until Stripe live | Manual `purchasedSeats` + platform-admin access toggles OK |
| Unpaid / over seat | Soft gate → location `read_only` (existing behavior) |

## Product model

### Location access statuses

| `accessStatus` | Meaning | Consumes a paid seat? | Writes |
|----------------|---------|----------------------|--------|
| `active` | Paid full access | **Yes** | Allowed |
| `trial` | Time-limited full access until `trialEndsAt` | **No** | Allowed until expiry → then `read_only` |
| `comp` | Platform-admin gift / test site | **No** | Allowed |
| `read_only` | Soft paywall | **No** | Blocked (UI + Store + rules) |

**Supersedes sticky-login seat math:** trial locations **do not** count toward `purchasedSeats`. Only `active` locations consume seats. Comp is a first-class status (not a parallel boolean on `active`).

### Seat accounting

```
seatsUsed     = count(locations where accessStatus == 'active')
purchasedSeats = Stripe subscription quantity (or manual admin value)
available     = purchasedSeats - seatsUsed
```

Rules:

- Managers may set a location to `active` only if `seatsUsed < purchasedSeats` (after the change).
- New locations default to `trial` (14 days) as today; when trial ends → `read_only` until a seat is assigned or the site is marked `comp`.
- Platform admin may set `comp` regardless of seat pool.
- Deleting / deactivating a location frees its seat if it was `active`.

### Who uses what

| Actor | Billing actions |
|-------|-----------------|
| Company manager | Billing tab: seats used vs purchased; open Checkout to buy/increase seats; open Customer Portal for card/invoice; assign which locations are `active` within seat limit |
| Platform admin | Set/override `purchasedSeats`; toggle location `comp` / `active` / `trial` / `read_only`; view Stripe IDs for support |
| Site manager / employee | No billing UI; see read-only banner when gated |

## Stripe architecture

```
Manager Billing UI
  → Cloud Function: createCheckoutSession(companyId, quantity)
  → Stripe Checkout (quarterly price × quantity)
  → success_url / cancel_url back to app

Manager Billing UI
  → Cloud Function: createPortalSession(companyId)
  → Stripe Customer Portal (update card, invoices, cancel)

Stripe webhooks (signed)
  → Cloud Function: stripeWebhook
  → Update companies/{id}: purchasedSeats, stripeCustomerId,
     stripeSubscriptionId, billingStatus
```

### Company fields (additions)

| Field | Purpose |
|-------|---------|
| `purchasedSeats` | Entitlement quantity (source of truth for app gates) |
| `stripeCustomerId` | Stripe Customer id |
| `stripeSubscriptionId` | Active subscription id |
| `billingStatus` | `ok` \| `past_due` \| `canceled` \| `trialing` (display + Phase 3) |

### Security

- Secret keys and webhook signing secret live only in Cloud Functions config / Secret Manager — never in the Flutter client.
- Checkout and Portal sessions created server-side; client only opens the returned URL.
- Webhook handler verifies Stripe signature; ignores unknown events; is idempotent on `event.id`.
- Firestore rules: clients **cannot** write `stripeCustomerId`, `stripeSubscriptionId`, or freely raise `purchasedSeats` (platform admin + webhook/Admin SDK only). Managers may still assign location `accessStatus` within seat rules enforced in app + preferably rules/helpers.
- Protect Stripe Dashboard 2FA and Firebase project admin access (ops, not app code).

### Price / product

- One Stripe Product: “Wiggy Wash location seat”.
- One recurring Price: **quarterly**, unit amount set in Stripe Dashboard (not hardcoded in client).
- Subscription `quantity` = paid seats.

## UX

### Manager Billing (existing tab, extended)

- Show: seats used / purchased, list of locations with status badges (`active` / `trial` / `comp` / `read_only`).
- **Buy / update seats** → Checkout (prefill quantity ≥ current `purchasedSeats` or current used, product decision at implement time: default to `max(purchasedSeats, seatsUsed)`).
- **Manage payment method / invoices** → Customer Portal.
- Copy when Stripe not configured: keep manual messaging (“Contact support to change seats”) if Functions/env missing.

### Platform Admin

- Per company: view/edit `purchasedSeats` (override).
- Per location: set `accessStatus` including **Comp**.
- Optional read-only display of Stripe customer/subscription ids for support.

## Rollout phases

### Phase A — Comp + seat math (can ship without Stripe)

1. Add `comp` to `accessStatus` union in models, Store entitlement checks, banners, Billing toggles, Platform Admin.
2. Change seat counting to **only** `active` (trial and comp excluded).
3. Backfill: existing locations stay `active` unless already `read_only` / `trial`; no mass flip to read-only.
4. Manual `purchasedSeats` remains the control plane.

### Phase B — Stripe Checkout + Portal + webhooks

1. Create Stripe product/price (quarterly); test mode first.
2. Cloud Functions: Checkout session, Portal session, webhook → sync `purchasedSeats` + Stripe ids + `billingStatus`.
3. Wire Billing CTAs; keep admin override for comps and emergency seat edits.
4. Production keys + webhook endpoint after test-mode smoke.

### Phase C — Past-due grace (optional, later)

- On `invoice.payment_failed` / `customer.subscription.updated` → `billingStatus: past_due`.
- Grace period (e.g. 7–14 days) with banner; then optionally force non-comp locations toward `read_only` while preserving data.
- Exact grace length chosen at Phase C planning time.

## Error handling

| Case | Behavior |
|------|----------|
| Checkout canceled | Return to Billing; no seat change |
| Webhook delayed | UI may lag briefly; refresh shows updated seats after sync |
| Portal with no customer yet | Prompt Checkout first to create customer + subscription |
| Quantity decrease in Stripe | Lower `purchasedSeats`; if `seatsUsed > purchasedSeats`, do **not** auto-demote in v1 — Billing shows over-allocated warning; manager must move extras to `read_only` (or admin comps). Phase C may automate |
| Comp removed | Location becomes `read_only` unless a free paid seat exists and manager sets `active` |

## Testing

**Phase A**

- Mark location `comp` → full writes; does not increase seats used.
- Trial location → writes OK; seats used unchanged.
- More `active` than `purchasedSeats` blocked in Billing UI.

**Phase B (Stripe test mode)**

- Checkout with quantity N → webhook sets `purchasedSeats` to N.
- Portal updates card without app storing card data.
- Invalid webhook signature rejected.
- Manager without `stripeCustomerId` can complete first Checkout.

## Success criteria

1. A parent company can pay quarterly for N seats via Stripe without sharing card data with the app.
2. Comp locations have full access and do not consume paid seats.
3. Over-seat sites remain read-only; paid and comp sites write normally.
4. Platform admin can gift/test a single site without buying an extra seat.
5. Manual seat override still works for support during and after Stripe launch.

## Relationship to prior spec

| Prior (sticky-login billing) | This spec |
|------------------------------|-----------|
| Phase 2 Stripe deferred | Phase B defines Checkout / Portal / webhooks |
| Seat count: `active` + `trial` | Seat count: **`active` only** |
| `accessStatus`: active \| trial \| read_only | Adds **`comp`** |
| Manual seats v1 | Remains Phase A; Stripe becomes source of truth for quantity when subscribed |
