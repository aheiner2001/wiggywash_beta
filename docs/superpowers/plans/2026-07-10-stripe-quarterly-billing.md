# Stripe Quarterly Billing + Comp Seats Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add per-location `comp` access and correct seat math (only `active` consumes seats), then wire Stripe Checkout + Customer Portal + webhooks so parent companies buy quarterly location seats without the app ever storing card data.

**Architecture:** Phase A is pure Flutter/Firestore: extend `LocationAccessStatus`, fix `seatsUsed`, allow writes for `comp`, lock billing fields in rules, and expose Comp in Platform Admin. Phase B adds a new `functions/` Cloud Functions package (Checkout, Portal, webhook → `purchasedSeats`) and Billing CTAs via `cloud_functions` + `url_launcher`. Phase C (past-due auto demote) is out of scope.

**Tech Stack:** Flutter web, Cloud Firestore + rules, Firebase Cloud Functions (Node 20), Stripe (Checkout, Billing Portal, webhooks), existing `Store` / `BillingScreen` / `PlatformAdminScreen`.

**Spec:** `docs/superpowers/specs/2026-07-10-stripe-quarterly-billing-design.md`

**Out of scope:** Phase C past-due grace automation; per-location Stripe customers; custom card forms; employee billing UI.

**Commit tip:** If `git commit` fails with `unknown option trailer`, use `/usr/local/bin/git commit -F /tmp/ww-commit-msg.txt` (or plain `-m` without wrappers).

---

## File map

| File | Responsibility |
|------|----------------|
| `lib/models/location_access.dart` | Add `comp`; parse / firestoreValue |
| `lib/utils/location_entitlement.dart` | Writes for comp; `seatsUsed` = active only; over-allocated helper |
| `lib/models/company.dart` | `stripeCustomerId`, `stripeSubscriptionId` (Phase B) |
| `lib/services/store.dart` | Seat checks only for `active`; always-trial create; admin comp; Stripe callables |
| `lib/screens/billing_screen.dart` | Badges, over-seat warning, Stripe CTAs (no manager Comp toggle) |
| `lib/screens/platform_admin_screen.dart` | Per-location access including Comp; show Stripe ids |
| `firestore.rules` | Allow `comp` writes; lock seat/Stripe company fields; Comp status admin-only |
| `functions/` | Checkout, Portal, webhook (new package) |
| `firebase.json` | Register functions |
| `pubspec.yaml` | `cloud_functions`, `url_launcher` |
| `test/models/location_access_test.dart` | Parse `comp` |
| `test/utils/location_entitlement_test.dart` | Seat + write rules |
| `test/models/company_test.dart` | Stripe field parse |

---

## Phase A — Comp + seat math

### Task 1: Comp enum + entitlement helpers (TDD)

**Files:**
- Modify: `lib/models/location_access.dart`
- Modify: `lib/utils/location_entitlement.dart`
- Modify: `test/models/location_access_test.dart`
- Modify: `test/utils/location_entitlement_test.dart`

- [ ] **Step 1: Update tests to the new contract**

Replace `test/models/location_access_test.dart` with:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:wiggywash/models/location_access.dart';

void main() {
  test('parse known values', () {
    expect(LocationAccessStatusX.parse('active'), LocationAccessStatus.active);
    expect(LocationAccessStatusX.parse('trial'), LocationAccessStatus.trial);
    expect(LocationAccessStatusX.parse('comp'), LocationAccessStatus.comp);
    expect(
      LocationAccessStatusX.parse('read_only'),
      LocationAccessStatus.readOnly,
    );
  });

  test('null or unknown defaults to active', () {
    expect(LocationAccessStatusX.parse(null), LocationAccessStatus.active);
    expect(LocationAccessStatusX.parse('nope'), LocationAccessStatus.active);
  });

  test('firestoreValue for comp', () {
    expect(LocationAccessStatus.comp.firestoreValue, 'comp');
  });
}
```

Replace `test/utils/location_entitlement_test.dart` with:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:wiggywash/models/location_access.dart';
import 'package:wiggywash/utils/location_entitlement.dart';

void main() {
  test('active, trial, and comp allow writes', () {
    expect(locationAllowsWrites(LocationAccessStatus.active), isTrue);
    expect(locationAllowsWrites(LocationAccessStatus.trial), isTrue);
    expect(locationAllowsWrites(LocationAccessStatus.comp), isTrue);
  });

  test('readOnly blocks writes', () {
    expect(locationAllowsWrites(LocationAccessStatus.readOnly), isFalse);
  });

  test('effectiveAccess flips expired trial to readOnly', () {
    final past = DateTime.now().subtract(const Duration(days: 1));
    expect(
      effectiveAccess(LocationAccessStatus.trial, trialEndsAt: past),
      LocationAccessStatus.readOnly,
    );
  });

  test('effectiveAccess leaves comp unchanged', () {
    expect(
      effectiveAccess(LocationAccessStatus.comp),
      LocationAccessStatus.comp,
    );
  });

  test('seatsUsed counts active only', () {
    expect(
      seatsUsed([
        LocationAccessStatus.active,
        LocationAccessStatus.trial,
        LocationAccessStatus.comp,
        LocationAccessStatus.readOnly,
      ]),
      1,
    );
  });

  test('canActivateAnother is false when at capacity', () {
    expect(canActivateAnother(purchasedSeats: 2, seatsUsed: 2), isFalse);
    expect(canActivateAnother(purchasedSeats: 2, seatsUsed: 1), isTrue);
  });

  test('isOverAllocated when used exceeds purchased', () {
    expect(isOverAllocated(purchasedSeats: 2, seatsUsed: 3), isTrue);
    expect(isOverAllocated(purchasedSeats: 2, seatsUsed: 2), isFalse);
  });
}
```

- [ ] **Step 2: Run tests — expect FAIL**

Run: `flutter test test/models/location_access_test.dart test/utils/location_entitlement_test.dart`

Expected: FAIL (missing `comp`, wrong seat count, missing `isOverAllocated`)

- [ ] **Step 3: Implement**

```dart
// lib/models/location_access.dart
enum LocationAccessStatus { active, trial, comp, readOnly }

extension LocationAccessStatusX on LocationAccessStatus {
  String get firestoreValue => switch (this) {
        LocationAccessStatus.active => 'active',
        LocationAccessStatus.trial => 'trial',
        LocationAccessStatus.comp => 'comp',
        LocationAccessStatus.readOnly => 'read_only',
      };

  String get label => switch (this) {
        LocationAccessStatus.active => 'Active',
        LocationAccessStatus.trial => 'Trial',
        LocationAccessStatus.comp => 'Comp',
        LocationAccessStatus.readOnly => 'Read-only',
      };

  static LocationAccessStatus parse(String? raw) {
    switch (raw) {
      case 'trial':
        return LocationAccessStatus.trial;
      case 'comp':
        return LocationAccessStatus.comp;
      case 'read_only':
        return LocationAccessStatus.readOnly;
      case 'active':
      default:
        return LocationAccessStatus.active;
    }
  }
}
```

```dart
// lib/utils/location_entitlement.dart
import '../models/location_access.dart';

bool locationAllowsWrites(LocationAccessStatus status) =>
    status == LocationAccessStatus.active ||
    status == LocationAccessStatus.trial ||
    status == LocationAccessStatus.comp;

LocationAccessStatus effectiveAccess(
  LocationAccessStatus status, {
  DateTime? trialEndsAt,
  DateTime? now,
}) {
  final n = now ?? DateTime.now();
  if (status == LocationAccessStatus.trial &&
      trialEndsAt != null &&
      !trialEndsAt.isAfter(n)) {
    return LocationAccessStatus.readOnly;
  }
  return status;
}

/// Only paid `active` locations consume a seat (trial/comp/read_only do not).
int seatsUsed(Iterable<LocationAccessStatus> statuses) =>
    statuses.where((s) => s == LocationAccessStatus.active).length;

bool canActivateAnother({
  required int purchasedSeats,
  required int seatsUsed,
}) =>
    seatsUsed < purchasedSeats;

bool isOverAllocated({
  required int purchasedSeats,
  required int seatsUsed,
}) =>
    seatsUsed > purchasedSeats;
```

- [ ] **Step 4: Run tests — expect PASS**

Run: `flutter test test/models/location_access_test.dart test/utils/location_entitlement_test.dart`

- [ ] **Step 5: Commit**

```bash
git add lib/models/location_access.dart lib/utils/location_entitlement.dart \
  test/models/location_access_test.dart test/utils/location_entitlement_test.dart
git commit -m "feat: add comp access status and active-only seat math"
```

---

### Task 2: Store seat gates + always-trial create + admin comp

**Files:**
- Modify: `lib/services/store.dart` (`createLocation`, `setLocationAccessStatus`; add `adminSetLocationAccessStatus`)

- [ ] **Step 1: Change `createLocation` to always start as trial**

In `createLocation`, remove the `canSeat` / `read_only` branch. New locations always get `accessStatus: trial` and `trialEndsAt: now + 14 days` (spec: trial does not consume seats).

```dart
Future<String?> createLocation(String name,
    {String city = '', String siteCode = ''}) async {
  final trimmed = name.trim();
  if (trimmed.isEmpty) return null;
  try {
    final trialEnd = DateTime.now().add(const Duration(days: 14));
    final ref = _locationsCol.doc();
    await ref.set(
      Location(
        id: ref.id,
        name: trimmed,
        city: city.trim(),
        siteCode: siteCode.trim(),
        accessStatus: LocationAccessStatus.trial,
        trialEndsAt: trialEnd,
      ).toMap(),
    );
    await previewCompany(_activeCompanyId!);
    return ref.id;
  } catch (e) {
    debugPrint('createLocation error: $e');
    return null;
  }
}
```

- [ ] **Step 2: Seat-check only when setting `active`; block manager `comp`**

Replace the capacity block in `setLocationAccessStatus` so:

1. If `status == LocationAccessStatus.comp` → return `'Only a platform admin can mark a site as comp.'` (managers use Billing; admins use `adminSetLocationAccessStatus`).
2. If `status == LocationAccessStatus.active` → compute `seatsUsed` on **other** locations’ effective statuses and call `canActivateAnother`.
3. Do **not** seat-check `trial` or `readOnly`.

```dart
Future<String?> setLocationAccessStatus({
  required String locationId,
  required LocationAccessStatus status,
  DateTime? trialEndsAt,
}) async {
  final company = _activeCompany;
  if (company == null) return 'No active company.';
  if (status == LocationAccessStatus.comp) {
    return 'Only a platform admin can mark a site as comp.';
  }
  if (status == LocationAccessStatus.active) {
    final others = _companyLocations.where((l) => l.id != locationId).map(
          (l) => entitlement.effectiveAccess(
            l.accessStatus,
            trialEndsAt: l.trialEndsAt,
          ),
        );
    final used = entitlement.seatsUsed(others);
    if (!entitlement.canActivateAnother(
      purchasedSeats: company.purchasedSeats,
      seatsUsed: used,
    )) {
      return 'No seats left. Buy more seats or ask platform admin.';
    }
  }
  try {
    final data = <String, dynamic>{
      'accessStatus': status.firestoreValue,
    };
    if (status == LocationAccessStatus.trial) {
      data['trialEndsAt'] = Timestamp.fromDate(
        trialEndsAt ?? DateTime.now().add(const Duration(days: 14)),
      );
    } else {
      data['trialEndsAt'] = FieldValue.delete();
    }
    await _locationsCol.doc(locationId).set(data, SetOptions(merge: true));
    if (_activeCompanyId != null) {
      await previewCompany(_activeCompanyId!);
    }
    notifyListeners();
    return null;
  } catch (e) {
    debugPrint('setLocationAccessStatus error: $e');
    return 'Could not update location access.';
  }
}
```

- [ ] **Step 3: Add admin path that allows all statuses including `comp`**

Add near `adminSetPurchasedSeats`:

```dart
Future<String?> adminSetLocationAccessStatus({
  required String companyId,
  required String locationId,
  required LocationAccessStatus status,
  DateTime? trialEndsAt,
}) async {
  try {
    final data = <String, dynamic>{
      'accessStatus': status.firestoreValue,
    };
    if (status == LocationAccessStatus.trial) {
      data['trialEndsAt'] = Timestamp.fromDate(
        trialEndsAt ?? DateTime.now().add(const Duration(days: 14)),
      );
    } else {
      data['trialEndsAt'] = FieldValue.delete();
    }
    await _companiesCol
        .doc(companyId)
        .collection('locations')
        .doc(locationId)
        .set(data, SetOptions(merge: true));
    if (_activeCompanyId == companyId) {
      await previewCompany(companyId);
    }
    notifyListeners();
    return null;
  } catch (e) {
    debugPrint('adminSetLocationAccessStatus error: $e');
    return 'Could not update location access.';
  }
}

Future<List<Location>> locationsForCompany(String companyId) async {
  final snap = await _companiesCol
      .doc(companyId)
      .collection('locations')
      .orderBy('name')
      .get();
  return snap.docs.map(Location.fromDoc).toList();
}
```

- [ ] **Step 4: Manual smoke (no automated Store test required)**

In a debug session or after UI tasks: create location → status `trial`; set `active` until seats full → next `active` fails; `adminSetLocationAccessStatus(..., comp)` succeeds and writes work.

- [ ] **Step 5: Commit**

```bash
git add lib/services/store.dart
git commit -m "feat: gate seats on active only; admin comp location access"
```

---

### Task 3: Firestore rules — comp writes + lock billing fields

**Files:**
- Modify: `firestore.rules`

- [ ] **Step 1: Allow `comp` in `locationAllowsWrites`**

```javascript
function locationAllowsWrites(companyId, locationId) {
  let loc = locationData(companyId, locationId);
  return !('accessStatus' in loc)
    || loc.accessStatus == 'active'
    || loc.accessStatus == 'trial'
    || loc.accessStatus == 'comp';
}
```

- [ ] **Step 2: Lock company billing fields to platform admin (Admin SDK bypasses rules)**

Replace company `allow update` with:

```javascript
function companyBillingKeys() {
  return ['purchasedSeats', 'stripeCustomerId', 'stripeSubscriptionId', 'billingStatus'];
}

function companyBillingUnchanged() {
  return !request.resource.data.diff(resource.data)
    .affectedKeys().hasAny(companyBillingKeys());
}

match /companies/{companyId} {
  allow read: if signedIn();
  allow create: if isRealUser();
  allow update: if isPlatformAdmin()
    || (canManageCompany(companyId) && companyBillingUnchanged());
  allow delete: if isPlatformAdmin();
  // ... locations unchanged except Step 3
}
```

- [ ] **Step 3: Only platform admin may set or clear `comp` on a location**

Inside `match /locations/{locationId}`, replace `allow update` with:

```javascript
function locationCompChangeOk() {
  let prev = resource.data.get('accessStatus', 'active');
  let next = request.resource.data.get('accessStatus', prev);
  let touchesComp = prev == 'comp' || next == 'comp';
  return !touchesComp || isPlatformAdmin();
}

allow update: if (canManageCompany(companyId) || isPlatformAdmin())
  && locationCompChangeOk();
```

- [ ] **Step 4: Deploy rules**

Run: `firebase deploy --only firestore:rules`

Expected: deploy success for project `wiggywash-expanded`.

- [ ] **Step 5: Commit**

```bash
git add firestore.rules
git commit -m "fix: allow comp writes; lock company billing fields to admin"
```

---

### Task 4: Billing screen — badges, over-allocation, no Comp toggle

**Files:**
- Modify: `lib/screens/billing_screen.dart`

- [ ] **Step 1: Update UI**

Requirements:

1. Keep Active / Trial / Read-only segmented control for managers.
2. If effective status is `comp`, show a non-editable Comp badge and disable the segmented control (managers cannot change comps).
3. Show `isOverAllocated` warning when `seatsUsed > purchasedSeats`.
4. Replace Stripe “coming later” copy with: seats are managed here; Stripe self-serve arrives in Phase B (or keep short “Ask platform admin for seats” until Task 9 wires CTAs).

Skeleton for the location row:

```dart
final effective = entitlement.effectiveAccess(
  loc.accessStatus,
  trialEndsAt: loc.trialEndsAt,
);
final isComp = effective == LocationAccessStatus.comp;

// In children:
if (isComp) ...[
  Chip(label: Text(LocationAccessStatus.comp.label)),
  const Text(
    'Comp site — full access, no seat. Only platform admin can change.',
    style: TextStyles.caption,
  ),
] else
  SegmentedButton<LocationAccessStatus>(
    segments: const [
      ButtonSegment(value: LocationAccessStatus.active, label: Text('Active')),
      ButtonSegment(value: LocationAccessStatus.trial, label: Text('Trial')),
      ButtonSegment(
        value: LocationAccessStatus.readOnly,
        label: Text('Read-only'),
      ),
    ],
    selected: {effective},
    onSelectionChanged: _busy ? null : (s) => _setAccess(loc, s.first),
  ),
```

Above the list, if over-allocated:

```dart
if (entitlement.isOverAllocated(
  purchasedSeats: purchased,
  seatsUsed: used,
))
  Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Text(
      'Over allocated: $used active sites but only $purchased seats. Move extras to read-only or buy seats.',
      style: TextStyle(color: AppColors.warning, fontWeight: FontWeight.w700),
    ),
  ),
```

- [ ] **Step 2: Analyzer clean on the file**

Run: `dart analyze lib/screens/billing_screen.dart`

Expected: no errors.

- [ ] **Step 3: Commit**

```bash
git add lib/screens/billing_screen.dart
git commit -m "feat: billing UI for comp badge and over-seat warning"
```

---

### Task 5: Platform Admin — per-location access including Comp

**Files:**
- Modify: `lib/screens/platform_admin_screen.dart` (`_CompanyCard`)

- [ ] **Step 1: Load locations and add access dropdown**

On `_CompanyCardState`:

- Add `List<Location> _locations = []` and load via `Store.instance.locationsForCompany(widget.company.id)` in `initState` / after seat save.
- Below Save seats, list each location with a `DropdownButton<LocationAccessStatus>` of all four values.
- On change, call `Store.instance.adminSetLocationAccessStatus(companyId:, locationId:, status:)`.
- Show `billingStatus` / Stripe ids when present (Phase B fields may be null until then — use `c.stripeCustomerId` only after Task 6; until then show nothing).

Example handler:

```dart
Future<void> _setLocAccess(Location loc, LocationAccessStatus status) async {
  final err = await Store.instance.adminSetLocationAccessStatus(
    companyId: widget.company.id,
    locationId: loc.id,
    status: status,
  );
  if (!mounted) return;
  showStoreMessage(
    context,
    err ?? '${loc.displayName} → ${status.label}',
    error: err != null,
  );
  if (err == null) {
    final list =
        await Store.instance.locationsForCompany(widget.company.id);
    if (mounted) setState(() => _locations = list);
  }
}
```

- [ ] **Step 2: Manual check**

Platform admin sets a location to Comp → employee at that site can save; seats used unchanged.

- [ ] **Step 3: Commit**

```bash
git add lib/screens/platform_admin_screen.dart lib/services/store.dart
git commit -m "feat: platform admin can set location access including comp"
```

---

## Phase B — Stripe Checkout + Portal + webhooks

### Task 6: Company Stripe fields (TDD)

**Files:**
- Modify: `lib/models/company.dart`
- Modify: `test/models/company_test.dart`

- [ ] **Step 1: Add tests**

Append to `test/models/company_test.dart`:

```dart
test('parses stripe ids and billingStatus', () {
  final c = Company.fromMap('abc', {
    'name': 'Wiggy',
    'companyCode': 'WIGGY',
    'status': 'active',
    'purchasedSeats': 10,
    'stripeCustomerId': 'cus_x',
    'stripeSubscriptionId': 'sub_y',
    'billingStatus': 'ok',
  });
  expect(c.stripeCustomerId, 'cus_x');
  expect(c.stripeSubscriptionId, 'sub_y');
  expect(c.billingStatus, 'ok');
});
```

- [ ] **Step 2: Run — expect FAIL**

Run: `flutter test test/models/company_test.dart`

- [ ] **Step 3: Add fields to `Company`**

Add optional `String? stripeCustomerId` and `String? stripeSubscriptionId` to constructor, fields, `copyWith`, `toMap` (only if non-null), and `fromMap` (trim empty → null). Keep existing `billingStatus`.

- [ ] **Step 4: Run — expect PASS**

Run: `flutter test test/models/company_test.dart`

- [ ] **Step 5: Commit**

```bash
git add lib/models/company.dart test/models/company_test.dart
git commit -m "feat: company stripe customer and subscription fields"
```

---

### Task 7: Scaffold Cloud Functions package

**Files:**
- Create: `functions/package.json`
- Create: `functions/index.js`
- Create: `functions/.gitignore`
- Modify: `firebase.json`

- [ ] **Step 1: Create package**

`functions/package.json`:

```json
{
  "name": "wiggywash-functions",
  "description": "Wiggy Wash Cloud Functions (Stripe billing)",
  "engines": { "node": "20" },
  "main": "index.js",
  "scripts": {
    "serve": "firebase emulators:start --only functions",
    "deploy": "firebase deploy --only functions"
  },
  "dependencies": {
    "firebase-admin": "^12.6.0",
    "firebase-functions": "^6.0.1",
    "stripe": "^17.0.0"
  },
  "private": true
}
```

`functions/.gitignore`:

```
node_modules/
```

- [ ] **Step 2: Register in `firebase.json`**

Merge (keep existing firestore + flutter keys):

```json
{
  "functions": [
    {
      "source": "functions",
      "codebase": "wiggywash",
      "ignore": ["node_modules", ".git", "firebase-debug.log", "*.local"]
    }
  ]
}
```

- [ ] **Step 3: Placeholder export**

`functions/index.js`:

```js
const { initializeApp } = require('firebase-admin/app');
initializeApp();

// Stripe callables + webhook added in Tasks 8–9.
exports.health = require('firebase-functions/v2/https').onRequest((req, res) => {
  res.status(200).send('ok');
});
```

- [ ] **Step 4: Install**

Run: `cd functions && npm install`

Expected: `node_modules` created; no errors.

- [ ] **Step 5: Commit** (do not commit `node_modules`)

```bash
git add functions/package.json functions/package-lock.json functions/index.js \
  functions/.gitignore firebase.json
git commit -m "chore: scaffold Cloud Functions package for Stripe"
```

---

### Task 8: Checkout + Portal callables

**Files:**
- Modify: `functions/index.js`

**Ops prerequisite (document in commit message / README comment at top of file):** Create Stripe Product “Wiggy Wash location seat” + quarterly Price in **test mode**; set secrets:

```bash
firebase functions:secrets:set STRIPE_SECRET_KEY
firebase functions:secrets:set STRIPE_PRICE_ID
```

App return URLs (GitHub Pages): use `https://<your-pages-host>/#/billing` or the actual manager Billing route query the app uses. Until deep-link exists, use the site origin + `?billing=1` and have BillingScreen read nothing special (user is enough).

- [ ] **Step 1: Implement callables**

Replace `functions/index.js` with (keep structure; fill secrets via `defineSecret`):

```js
const { initializeApp } = require('firebase-admin/app');
const { getFirestore } = require('firebase-admin/firestore');
const { onCall, HttpsError } = require('firebase-functions/v2/https');
const { defineSecret } = require('firebase-functions/params');
const Stripe = require('stripe');

initializeApp();
const db = getFirestore();

const stripeSecret = defineSecret('STRIPE_SECRET_KEY');
const stripePriceId = defineSecret('STRIPE_PRICE_ID');

function assertAuthed(request) {
  if (!request.auth) {
    throw new HttpsError('unauthenticated', 'Sign in required.');
  }
}

async function assertCanBillCompany(uid, companyId) {
  const user = (await db.collection('users').doc(uid).get()).data();
  if (!user) throw new HttpsError('permission-denied', 'No user profile.');
  const role = user.role;
  const ok =
    role === 'platformAdmin' ||
    role === 'superAdmin' ||
    ((role === 'companyManager' || role === 'manager') &&
      user.companyId === companyId);
  if (!ok) throw new HttpsError('permission-denied', 'Not allowed.');
  return user;
}

exports.createCheckoutSession = onCall(
  { secrets: [stripeSecret, stripePriceId] },
  async (request) => {
    assertAuthed(request);
    const companyId = request.data.companyId;
    const quantity = Number(request.data.quantity);
    if (!companyId || !Number.isInteger(quantity) || quantity < 1) {
      throw new HttpsError('invalid-argument', 'companyId and quantity >= 1 required.');
    }
    await assertCanBillCompany(request.auth.uid, companyId);

    const companyRef = db.collection('companies').doc(companyId);
    const companySnap = await companyRef.get();
    if (!companySnap.exists) {
      throw new HttpsError('not-found', 'Company not found.');
    }
    const company = companySnap.data();
    const stripe = new Stripe(stripeSecret.value());
    const priceId = stripePriceId.value();
    const origin = request.data.returnOrigin; // e.g. https://user.github.io/wiggywash_beta
    if (!origin || typeof origin != 'string') {
      throw new HttpsError('invalid-argument', 'returnOrigin required.');
    }

    let customerId = company.stripeCustomerId;
    if (!customerId) {
      const customer = await stripe.customers.create({
        name: company.name,
        metadata: { companyId },
      });
      customerId = customer.id;
      await companyRef.set({ stripeCustomerId: customerId }, { merge: true });
    }

    // If already subscribed, update quantity instead of a second subscription.
    if (company.stripeSubscriptionId) {
      const sub = await stripe.subscriptions.retrieve(company.stripeSubscriptionId);
      const itemId = sub.items.data[0].id;
      await stripe.subscriptions.update(company.stripeSubscriptionId, {
        items: [{ id: itemId, quantity }],
        proration_behavior: 'create_prorations',
      });
      await companyRef.set(
        { purchasedSeats: quantity, billingStatus: 'ok' },
        { merge: true },
      );
      return { updated: true, purchasedSeats: quantity };
    }

    const session = await stripe.checkout.sessions.create({
      mode: 'subscription',
      customer: customerId,
      line_items: [{ price: priceId, quantity }],
      success_url: `${origin}?billing=success`,
      cancel_url: `${origin}?billing=cancel`,
      client_reference_id: companyId,
      metadata: { companyId },
      subscription_data: { metadata: { companyId } },
    });
    return { url: session.url };
  },
);

exports.createPortalSession = onCall(
  { secrets: [stripeSecret] },
  async (request) => {
    assertAuthed(request);
    const companyId = request.data.companyId;
    if (!companyId) throw new HttpsError('invalid-argument', 'companyId required.');
    await assertCanBillCompany(request.auth.uid, companyId);

    const company = (await db.collection('companies').doc(companyId).get()).data();
    if (!company?.stripeCustomerId) {
      throw new HttpsError(
        'failed-precondition',
        'No Stripe customer yet. Buy seats first.',
      );
    }
    const origin = request.data.returnOrigin;
    if (!origin || typeof origin != 'string') {
      throw new HttpsError('invalid-argument', 'returnOrigin required.');
    }
    const stripe = new Stripe(stripeSecret.value());
    const session = await stripe.billingPortal.sessions.create({
      customer: company.stripeCustomerId,
      return_url: `${origin}?billing=portal`,
    });
    return { url: session.url };
  },
);
```

- [ ] **Step 2: Commit**

```bash
git add functions/index.js
git commit -m "feat: Stripe Checkout and Customer Portal callables"
```

---

### Task 9: Stripe webhook → sync seats

**Files:**
- Modify: `functions/index.js`
- Secrets: `STRIPE_WEBHOOK_SECRET`

- [ ] **Step 1: Add webhook HTTP function**

Append to `functions/index.js`:

```js
const { onRequest } = require('firebase-functions/v2/https');
const webhookSecret = defineSecret('STRIPE_WEBHOOK_SECRET');

async function applySubscriptionToCompany(subscription) {
  const companyId = subscription.metadata?.companyId;
  if (!companyId) {
    console.warn('subscription missing companyId metadata', subscription.id);
    return;
  }
  const quantity = subscription.items.data[0]?.quantity ?? 1;
  let billingStatus = 'ok';
  if (subscription.status === 'past_due') billingStatus = 'past_due';
  if (subscription.status === 'canceled') billingStatus = 'canceled';
  if (subscription.status === 'trialing') billingStatus = 'trialing';

  await db.collection('companies').doc(companyId).set(
    {
      purchasedSeats: quantity,
      stripeCustomerId: subscription.customer,
      stripeSubscriptionId: subscription.id,
      billingStatus,
    },
    { merge: true },
  );
}

exports.stripeWebhook = onRequest(
  { secrets: [stripeSecret, webhookSecret] },
  async (req, res) => {
    const stripe = new Stripe(stripeSecret.value());
    let event;
    try {
      event = stripe.webhooks.constructEvent(
        req.rawBody,
        req.headers['stripe-signature'],
        webhookSecret.value(),
      );
    } catch (err) {
      console.error('Webhook signature failed', err.message);
      res.status(400).send(`Webhook Error: ${err.message}`);
      return;
    }

    const eventRef = db.collection('stripeEvents').doc(event.id);
    if ((await eventRef.get()).exists) {
      res.json({ received: true, duplicate: true });
      return;
    }

    try {
      switch (event.type) {
        case 'checkout.session.completed': {
          const session = event.data.object;
          if (session.mode === 'subscription' && session.subscription) {
            const sub = await stripe.subscriptions.retrieve(session.subscription);
            if (!sub.metadata?.companyId && session.metadata?.companyId) {
              await stripe.subscriptions.update(sub.id, {
                metadata: { companyId: session.metadata.companyId },
              });
              sub.metadata = { companyId: session.metadata.companyId };
            }
            await applySubscriptionToCompany(sub);
          }
          break;
        }
        case 'customer.subscription.updated':
        case 'customer.subscription.deleted': {
          await applySubscriptionToCompany(event.data.object);
          break;
        }
        default:
          break;
      }
      await eventRef.set({ type: event.type, at: Date.now() });
      res.json({ received: true });
    } catch (e) {
      console.error(e);
      res.status(500).send('Handler error');
    }
  },
);
```

Add Firestore rule deny-all for `stripeEvents` (clients must not read/write):

```javascript
match /stripeEvents/{id} {
  allow read, write: if false;
}
```

- [ ] **Step 2: Deploy functions + rules; configure Stripe webhook URL**

```bash
firebase deploy --only functions,firestore:rules
```

In Stripe Dashboard (test mode): endpoint `https://<region>-wiggywash-expanded.cloudfunctions.net/stripeWebhook`, events: `checkout.session.completed`, `customer.subscription.updated`, `customer.subscription.deleted`. Set `STRIPE_WEBHOOK_SECRET` from the endpoint signing secret.

- [ ] **Step 3: Commit**

```bash
git add functions/index.js firestore.rules
git commit -m "feat: Stripe webhook syncs purchasedSeats and billingStatus"
```

---

### Task 10: Flutter Billing CTAs (Checkout + Portal)

**Files:**
- Modify: `pubspec.yaml` — add `cloud_functions` and `url_launcher`
- Modify: `lib/services/store.dart` — callable wrappers
- Modify: `lib/screens/billing_screen.dart` — buttons + quantity dialog
- Modify: `lib/screens/platform_admin_screen.dart` — show Stripe ids if present

- [ ] **Step 1: Dependencies**

```yaml
  cloud_functions: ^5.6.0
  url_launcher: ^6.3.1
```

Run: `flutter pub get`

- [ ] **Step 2: Store methods**

```dart
Future<String?> startSeatCheckout({required int quantity}) async {
  final company = _activeCompany;
  if (company == null) return 'No active company.';
  try {
    final callable =
        FirebaseFunctions.instance.httpsCallable('createCheckoutSession');
    final origin = Uri.base.origin; // web
    final result = await callable.call(<String, dynamic>{
      'companyId': company.id,
      'quantity': quantity,
      'returnOrigin': origin,
    });
    final data = Map<String, dynamic>.from(result.data as Map);
    if (data['updated'] == true) {
      await previewCompany(company.id);
      return null; // seats updated in place
    }
    final url = data['url'] as String?;
    if (url == null || url.isEmpty) return 'No checkout URL returned.';
    final ok = await launchUrl(Uri.parse(url), webOnlyWindowName: '_self');
    if (!ok) return 'Could not open Stripe Checkout.';
    return null;
  } catch (e) {
    debugPrint('startSeatCheckout error: $e');
    return 'Could not start checkout. Is Stripe configured?';
  }
}

Future<String?> openBillingPortal() async {
  final company = _activeCompany;
  if (company == null) return 'No active company.';
  try {
    final callable =
        FirebaseFunctions.instance.httpsCallable('createPortalSession');
    final result = await callable.call(<String, dynamic>{
      'companyId': company.id,
      'returnOrigin': Uri.base.origin,
    });
    final url = (result.data as Map)['url'] as String?;
    if (url == null || url.isEmpty) return 'No portal URL returned.';
    final ok = await launchUrl(Uri.parse(url), webOnlyWindowName: '_self');
    if (!ok) return 'Could not open billing portal.';
    return null;
  } catch (e) {
    debugPrint('openBillingPortal error: $e');
    return 'Buy seats once before managing payment methods.';
  }
}
```

Add imports: `cloud_functions`, `url_launcher`.

- [ ] **Step 3: Billing UI buttons**

Above the location list:

- **Buy / update seats** → dialog with int field defaulting to `max(purchased, used)` → `Store.instance.startSeatCheckout(quantity:)`.
- **Manage payment & invoices** → `Store.instance.openBillingPortal()`.
- On success with in-place update, show “Seats updated to N”.

- [ ] **Step 4: Platform admin — display Stripe ids**

Under seat row, if `c.stripeCustomerId != null`:

```dart
Text(
  'Stripe: ${c.stripeCustomerId}'
  '${c.stripeSubscriptionId != null ? ' · ${c.stripeSubscriptionId}' : ''}'
  '${c.billingStatus != null ? ' · ${c.billingStatus}' : ''}',
  style: TextStyles.caption,
)
```

- [ ] **Step 5: Test mode smoke**

1. Manager opens Billing → Buy seats quantity 3 → Checkout test card `4242…` → webhook sets `purchasedSeats: 3`.
2. Portal opens and shows invoices.
3. Invalid webhook signature returns 400 (optional curl check).

- [ ] **Step 6: Commit**

```bash
git add pubspec.yaml pubspec.lock lib/services/store.dart \
  lib/screens/billing_screen.dart lib/screens/platform_admin_screen.dart
git commit -m "feat: Billing Checkout and Portal CTAs via Cloud Functions"
```

---

### Task 11: Spec status + Phase A/B verification checklist

**Files:**
- Modify: `docs/superpowers/specs/2026-07-10-stripe-quarterly-billing-design.md` — set **Status: Approved**

- [ ] **Step 1: Update status line**

Change header Status from “Approved (pending user review…)” to `Approved`.

- [ ] **Step 2: Run unit tests**

Run: `flutter test test/models/location_access_test.dart test/utils/location_entitlement_test.dart test/models/company_test.dart`

Expected: all PASS.

- [ ] **Step 3: Commit**

```bash
git add docs/superpowers/specs/2026-07-10-stripe-quarterly-billing-design.md
git commit -m "docs: mark Stripe quarterly billing spec approved"
```

---

## Self-review (plan vs spec)

| Spec requirement | Task |
|------------------|------|
| `comp` access + full writes | 1, 2, 3, 5 |
| Seat count = `active` only | 1, 2, 4 |
| Trial does not consume seats; new sites trial | 1, 2 |
| Manager Billing assign active within seats | 2, 4 |
| Platform admin comps + seat override | 2, 5 (override already exists) |
| Lock Stripe / purchasedSeats client writes | 3 |
| Quarterly Checkout + quantity | 7, 8, 10 |
| Customer Portal | 8, 10 |
| Webhook → purchasedSeats / ids / billingStatus | 6, 9 |
| No PAN storage | 8–10 (Checkout/Portal only) |
| Over-seat warning, no auto-demote | 4 |
| Phase C past-due grace | Explicitly out of scope |

No TBD placeholders. Types consistent: `LocationAccessStatus.comp`, `adminSetLocationAccessStatus`, `createCheckoutSession` / `createPortalSession` / `stripeWebhook`.
