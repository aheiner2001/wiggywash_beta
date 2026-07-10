# Sticky Login + Per-Location Billing Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make employee return visits on the website land on the scorecard with a long-lived browser session, add searchable multi-site location pick, and enforce per-location seat billing with read-only paywall (manual seats in v1; Stripe later).

**Architecture:** Extend `Company` / `Location` with seat and `accessStatus` fields. Pure helpers decide write vs read-only. `Store.init` validates remembered prefs and routes to employee or the correct login step. UI adds Switch person/location/Sign out and a read-only banner. Firestore rules deny mutating ops when `accessStatus == 'read_only'`. Manager Billing + platform admin edit seats without Stripe in this pass.

**Tech Stack:** Flutter web, SharedPreferences, Cloud Firestore + security rules, existing `Store` / `CompanyLoginScreen` / `ManagerShell`.

**Spec:** `docs/superpowers/specs/2026-07-10-sticky-login-location-billing-design.md`

---

## File map

| File | Responsibility |
|------|----------------|
| `lib/models/location_access.dart` | `LocationAccessStatus` enum + parse/label helpers |
| `lib/utils/location_entitlement.dart` | Pure: effective access, seat counting, can-write |
| `lib/models/location.dart` | Add `accessStatus`, `trialEndsAt` |
| `lib/models/company.dart` | Add `purchasedSeats`, optional `billingStatus` |
| `lib/services/store.dart` | Session restore, switch APIs, recent locations, write gates, billing updates |
| `lib/screens/company_login_screen.dart` | Searchable location list + recent |
| `lib/widgets/employee_session_menu.dart` | Switch person / location / sign out |
| `lib/widgets/read_only_banner.dart` | Paywall banner |
| `lib/screens/scorecard_screen.dart` | Menu + banner; disable save when read-only |
| `lib/screens/billing_screen.dart` | Manager seats UI |
| `lib/widgets/manager_shell.dart` | Add Billing nav item |
| `lib/screens/platform_admin_screen.dart` | Edit seats / location access |
| `firestore.rules` | Block writes when location read-only |
| `test/models/location_access_test.dart` | Enum parse |
| `test/utils/location_entitlement_test.dart` | Seat + write logic |
| `test/models/location_test.dart` | Location fromMap defaults |
| `test/models/company_test.dart` | purchasedSeats parse |

---

### Task 1: Location access enum + entitlement helpers (TDD)

**Files:**
- Create: `lib/models/location_access.dart`
- Create: `lib/utils/location_entitlement.dart`
- Create: `test/models/location_access_test.dart`
- Create: `test/utils/location_entitlement_test.dart`

- [ ] **Step 1: Write failing tests**

```dart
// test/models/location_access_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:wiggywash/models/location_access.dart';

void main() {
  test('parse known values', () {
    expect(LocationAccessStatusX.parse('active'), LocationAccessStatus.active);
    expect(LocationAccessStatusX.parse('trial'), LocationAccessStatus.trial);
    expect(LocationAccessStatusX.parse('read_only'), LocationAccessStatus.readOnly);
  });

  test('null or unknown defaults to active', () {
    expect(LocationAccessStatusX.parse(null), LocationAccessStatus.active);
    expect(LocationAccessStatusX.parse('nope'), LocationAccessStatus.active);
  });
}
```

```dart
// test/utils/location_entitlement_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:wiggywash/models/location_access.dart';
import 'package:wiggywash/utils/location_entitlement.dart';

void main() {
  test('active and trial allow writes', () {
    expect(locationAllowsWrites(LocationAccessStatus.active), isTrue);
    expect(locationAllowsWrites(LocationAccessStatus.trial), isTrue);
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

  test('seatUsed counts active and trial only', () {
    expect(
      seatsUsed([
        LocationAccessStatus.active,
        LocationAccessStatus.trial,
        LocationAccessStatus.readOnly,
      ]),
      2,
    );
  });

  test('canActivateAnother is false when at capacity', () {
    expect(canActivateAnother(purchasedSeats: 2, seatsUsed: 2), isFalse);
    expect(canActivateAnother(purchasedSeats: 2, seatsUsed: 1), isTrue);
  });
}
```

- [ ] **Step 2: Run tests — expect FAIL**

Run: `flutter test test/models/location_access_test.dart test/utils/location_entitlement_test.dart`  
Expected: FAIL (library not found)

- [ ] **Step 3: Implement**

```dart
// lib/models/location_access.dart
enum LocationAccessStatus { active, trial, readOnly }

extension LocationAccessStatusX on LocationAccessStatus {
  String get firestoreValue => switch (this) {
        LocationAccessStatus.active => 'active',
        LocationAccessStatus.trial => 'trial',
        LocationAccessStatus.readOnly => 'read_only',
      };

  static LocationAccessStatus parse(String? raw) {
    switch (raw) {
      case 'trial':
        return LocationAccessStatus.trial;
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
    status == LocationAccessStatus.active || status == LocationAccessStatus.trial;

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

int seatsUsed(Iterable<LocationAccessStatus> statuses) =>
    statuses.where(locationAllowsWrites).length;

bool canActivateAnother({
  required int purchasedSeats,
  required int seatsUsed,
}) =>
    seatsUsed < purchasedSeats;
```

- [ ] **Step 4: Run tests — expect PASS**

Run: `flutter test test/models/location_access_test.dart test/utils/location_entitlement_test.dart`

- [ ] **Step 5: Commit**

```bash
git add lib/models/location_access.dart lib/utils/location_entitlement.dart \
  test/models/location_access_test.dart test/utils/location_entitlement_test.dart
git commit -m "feat: location access status and seat entitlement helpers"
```

---

### Task 2: Extend Company and Location models

**Files:**
- Modify: `lib/models/company.dart`
- Modify: `lib/models/location.dart`
- Modify: `test/models/company_test.dart`
- Create: `test/models/location_test.dart`

- [ ] **Step 1: Add company tests**

```dart
test('parses purchasedSeats default 1 when missing', () {
  final c = Company.fromMap('abc', {
    'name': 'Wiggy',
    'companyCode': 'WIGGY',
    'status': 'active',
  });
  expect(c.purchasedSeats, 1);
});

test('parses purchasedSeats', () {
  final c = Company.fromMap('abc', {
    'name': 'Wiggy',
    'companyCode': 'WIGGY',
    'status': 'active',
    'purchasedSeats': 12,
  });
  expect(c.purchasedSeats, 12);
});
```

- [ ] **Step 2: Add location tests**

```dart
// test/models/location_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:wiggywash/models/location.dart';
import 'package:wiggywash/models/location_access.dart';

void main() {
  test('missing accessStatus defaults to active', () {
    final loc = Location.fromMap('L1', {
      'name': 'Main',
      'city': 'Boise',
      'active': true,
    });
    expect(loc.accessStatus, LocationAccessStatus.active);
    expect(loc.trialEndsAt, isNull);
  });

  test('parses read_only and trialEndsAt', () {
    final loc = Location.fromMap('L1', {
      'name': 'Main',
      'accessStatus': 'read_only',
      'trialEndsAt': null,
    });
    expect(loc.accessStatus, LocationAccessStatus.readOnly);
  });
}
```

Note: If `Location` only has `fromDoc` today, add `Location.fromMap(String id, Map data)` mirroring `Company.fromMap`, and have `fromDoc` call it.

- [ ] **Step 3: Implement model fields**

On `Company`:
- `final int purchasedSeats;` default `1` when missing/invalid
- optional `final String? billingStatus;`
- include in `copyWith` / `toMap` / `fromMap`

On `Location`:
- `final LocationAccessStatus accessStatus;`
- `final DateTime? trialEndsAt;`
- parse Timestamp for `trialEndsAt`
- `toMap` writes `accessStatus.firestoreValue` and optional `trialEndsAt`

- [ ] **Step 4: Run tests**

Run: `flutter test test/models/company_test.dart test/models/location_test.dart`  
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add lib/models/company.dart lib/models/location.dart \
  test/models/company_test.dart test/models/location_test.dart
git commit -m "feat: company seats and location accessStatus fields"
```

---

### Task 3: Store session restore, switch APIs, write gate

**Files:**
- Modify: `lib/services/store.dart`
- Create: `test/utils/employee_session_prefs_test.dart` (optional pure prefs helper if extracted)

- [ ] **Step 1: Add prefs key and in-memory PIN unlock**

```dart
static const _kRecentLocations = 'ww_recent_locations';
bool _pinUnlockedThisLaunch = false;
```

Expose:
```dart
bool get locationAllowsWrites {
  final loc = activeLocation; // or resolve from _companyLocations / _activeLocation
  if (loc == null) return false;
  return locationAllowsWrites(
    effectiveAccess(loc.accessStatus, trialEndsAt: loc.trialEndsAt),
  );
}

String get readOnlyMessage =>
    'This site is read-only. Ask your manager to update billing.';
```

(Name the Store getter carefully to avoid clashing with the util — e.g. `bool get canWriteAtActiveLocation`.)

- [ ] **Step 2: Harden `signOutEmployee`**

Clear `_activeLocationId`, `_kActiveLocation`, recent optional keep or clear; match spec (full clear of company/location/profile/code).

- [ ] **Step 3: Add switch helpers**

```dart
Future<void> switchEmployeePerson() async {
  _employeeName = null;
  _employeeLocationId = null; // keep company+location ids in prefs
  _pinUnlockedThisLaunch = false;
  await _prefs?.remove(_kEmployeeProfile);
  // Keep _activeCompanyId and _activeLocationId
  notifyListeners();
}

Future<void> switchEmployeeLocation() async {
  _employeeName = null;
  _employeeLocationId = null;
  _pinUnlockedThisLaunch = false;
  await _prefs?.remove(_kEmployeeProfile);
  _activeLocationId = null;
  await _prefs?.remove(_kActiveLocation);
  notifyListeners();
}
```

Adjust `view` so:
- company remembered + location missing → still `landing` but login screen should open on location step (see Task 4), OR introduce `AppView.employeeResume` — **prefer:** keep `landing` and have `CompanyLoginScreen` read Store resume hints (`resumeCompanyId`, `resumeAtLocationStep`).

Minimal approach: after `switchEmployeePerson`, set flags so `CompanyLoginScreen` starts at name step with company+location already previewed. After `switchEmployeeLocation`, start at location step.

Add on Store:
```dart
enum EmployeeLoginResume { none, location, name }
EmployeeLoginResume employeeLoginResume = EmployeeLoginResume.none;
```

Set appropriately in switch methods; clear on full sign-out and successful `signInEmployee`.

- [ ] **Step 4: Boot validation in `init` (after prefs + auth ready)**

After loading employee profile + company/location ids:
1. If no employee name → leave as today.
2. If employee name set: fetch/ensure `_activeCompany` loaded; if missing/suspended → `signOutEmployee` (or partial clear per spec).
3. Ensure location in `companyLocations` / fetch; if missing → clear location + profile, set `employeeLoginResume = location`.
4. Ensure worker still on roster; if not → clear profile only, `employeeLoginResume = name`.
5. Push location id onto recent list (max 5).

- [ ] **Step 5: Gate mutating Store methods**

At the start of `addSubmission` / update submission, `createStaffRequest`, `createPersonalTodo`, `submitAssignedCompletion`, and other employee/manager ops that mutate location data when acting in a location context:

```dart
if (!canWriteAtActiveLocation) return readOnlyMessage;
```

Also flip expired trial opportunistically:
```dart
Future<void> refreshLocationAccessIfNeeded() async { /* if trial expired, set accessStatus read_only in Firestore when manager; employees just treat as read-only via effectiveAccess */ }
```

Employees do **not** need to write the flip; `effectiveAccess` is enough for UI/Store. Optional later admin job.

- [ ] **Step 6: Recent locations helpers**

```dart
List<String> loadRecentLocationIds();
Future<void> rememberRecentLocation(String id);
```

- [ ] **Step 7: Manual smoke via analyze**

Run: `flutter analyze lib/services/store.dart`  
Expected: No issues in changed APIs

- [ ] **Step 8: Commit**

```bash
git add lib/services/store.dart
git commit -m "feat: sticky employee session restore and write entitlement gate"
```

---

### Task 4: Searchable location step + resume in CompanyLoginScreen

**Files:**
- Modify: `lib/screens/company_login_screen.dart`

- [ ] **Step 1: On init, honor `Store.employeeLoginResume`**

If resume is `location` or `name` and company already set: `previewCompany` / `previewLocation` as needed; set `_step` accordingly; clear resume flag after applying.

- [ ] **Step 2: Replace flat location list with search**

Add `TextEditingController _locationQuery`. Filter `companyLocations` by name/city case-insensitive. Show section **Recent** (ids from Store that still exist) above full filtered list when query empty.

- [ ] **Step 3: On successful location + name sign-in, call `rememberRecentLocation`**

- [ ] **Step 4: Analyze**

Run: `flutter analyze lib/screens/company_login_screen.dart`

- [ ] **Step 5: Commit**

```bash
git add lib/screens/company_login_screen.dart
git commit -m "feat: searchable location pick and login resume steps"
```

---

### Task 5: Employee session menu + read-only banner on scorecard

**Files:**
- Create: `lib/widgets/employee_session_menu.dart`
- Create: `lib/widgets/read_only_banner.dart`
- Modify: `lib/screens/scorecard_screen.dart`
- Modify: other employee-facing screens that mutate if needed (`employee_requests_screen.dart`)

- [ ] **Step 1: Session menu widget**

Popup/menu with:
- Switch person → `Store.switchEmployeePerson()`
- Switch location → `Store.switchEmployeeLocation()` (only if `companyLocations.length > 1`)
- Sign out → `Store.signOutEmployee()`

- [ ] **Step 2: Read-only banner**

```dart
class ReadOnlyBanner extends StatelessWidget {
  // Uses Store.canWriteAtActiveLocation; if false, show Material banner / colored bar
}
```

- [ ] **Step 3: Wire scorecard**

- AppBar action: `EmployeeSessionMenu`
- Below app bar / top of body: `ReadOnlyBanner`
- Disable Save / share mutating actions when `!canWriteAtActiveLocation` (share preview of existing tallies can stay enabled if desired; **Save must be disabled**)
- PIN: if worker requires PIN and `!_pinUnlockedThisLaunch`, show dialog once then set Store flag

Check how PIN is validated today in `company_login_screen` — if PIN only at login, add unlock on scorecard open when profile has requiresPin and session was restored without re-entry.

- [ ] **Step 4: Gate employee requests mutations similarly**

- [ ] **Step 5: Analyze + commit**

```bash
git add lib/widgets/employee_session_menu.dart lib/widgets/read_only_banner.dart \
  lib/screens/scorecard_screen.dart lib/screens/employee_requests_screen.dart
git commit -m "feat: employee switch/sign-out menu and read-only banner"
```

---

### Task 6: Firestore rules — block writes when read-only

**Files:**
- Modify: `firestore.rules`

- [ ] **Step 1: Add helpers**

```javascript
function locationData(companyId, locationId) {
  return get(/databases/$(database)/documents/companies/$(companyId)/locations/$(locationId)).data;
}
function locationAllowsWrites(companyId, locationId) {
  let s = locationData(companyId, locationId).get('accessStatus', 'active');
  return s == 'active' || s == 'trial';
}
```

(If rules language version lacks map `.get`, use:
`!('accessStatus' in loc) || loc.accessStatus == 'active' || loc.accessStatus == 'trial'`.)

- [ ] **Step 2: Tighten mutating matches**

For `submissions`, `staffRequests` create/update, and other employee-writable collections under `locations/{locationId}`:

```
allow create, update: if signedIn() && locationAllowsWrites(companyId, locationId);
```

Keep `allow read: if signedIn();`  
Manager-only writes (workers, config, prices) may also require `locationAllowsWrites` **or** allow managers to still edit roster on read-only sites — **spec says mutating team/config blocked**. Apply the same write gate to those collections.

Exception: managers/platform admin updating `accessStatus` / `purchasedSeats` on company/location docs must remain allowed via `canManageCompany` (location doc update for billing).

- [ ] **Step 3: Deploy rules** (when user can approve)

Run: `firebase deploy --only firestore:rules`

- [ ] **Step 4: Commit**

```bash
git add firestore.rules
git commit -m "fix: block location writes when accessStatus is read_only"
```

---

### Task 7: New location defaults + company create seats

**Files:**
- Modify: `lib/services/store.dart` (create location / createPendingCompany paths)
- Modify: `lib/services/company_migration.dart` if it creates locations

- [ ] **Step 1: When creating a location**

Set:
```dart
'accessStatus': 'trial',
'trialEndsAt': Timestamp.fromDate(DateTime.now().add(const Duration(days: 14))),
```
Unless `canActivateAnother` with current seats — if no seat free, still create as `trial` (counts toward seats per spec) **or** as `read_only` if at capacity. Spec: new locations start trial 14 days. If that would exceed seats, create as `read_only` instead (no trial).

```dart
final used = seatsUsed(locations.map((l) => l.accessStatus));
final status = canActivateAnother(purchasedSeats: company.purchasedSeats, seatsUsed: used)
    ? LocationAccessStatus.trial
    : LocationAccessStatus.readOnly;
```

- [ ] **Step 2: New company `purchasedSeats: 1`**

- [ ] **Step 3: Commit**

```bash
git add lib/services/store.dart lib/services/company_migration.dart
git commit -m "feat: default trial/read_only on new locations and purchasedSeats"
```

---

### Task 8: Manager Billing screen + shell nav

**Files:**
- Create: `lib/screens/billing_screen.dart`
- Modify: `lib/widgets/manager_shell.dart`
- Modify: `lib/services/store.dart` — `updatePurchasedSeats` (admin), `setLocationAccessStatus`

- [ ] **Step 1: Store APIs**

```dart
Future<String?> setLocationAccessStatus({
  required String locationId,
  required LocationAccessStatus status,
  DateTime? trialEndsAt,
}) async { /* enforce canActivateAnother when enabling active/trial */ }

Future<String?> updatePurchasedSeats(int seats) async { /* manager or defer to admin only — spec: manager Billing shows seats; platform admin sets purchasedSeats. Manager cannot raise purchasedSeats in v1 without Stripe. */ }
```

v1: Manager Billing **displays** `purchasedSeats` and toggles which locations are active/trial/read_only within the seat cap. Only platform admin can change `purchasedSeats`.

- [ ] **Step 2: BillingScreen UI**

- Show “Seats used X / Y”
- List locations with dropdown or segmented control for access status
- On enable active/trial beyond cap → showStoreMessage error
- Note: “Self-serve billing (Stripe) coming later. Ask platform admin to add seats.”

- [ ] **Step 3: Add to ManagerShell**

Insert nav item “Billing” (icon `Icons.payments_outlined`) — index carefully so Settings stays last or Billing before Settings.

- [ ] **Step 4: Analyze + commit**

```bash
git add lib/screens/billing_screen.dart lib/widgets/manager_shell.dart lib/services/store.dart
git commit -m "feat: manager Billing screen for per-location seats"
```

---

### Task 9: Platform admin seat controls

**Files:**
- Modify: `lib/screens/platform_admin_screen.dart`
- Modify: `lib/services/store.dart` — `adminSetPurchasedSeats(companyId, seats)`

- [ ] **Step 1: Per company row/actions**

Allow editing `purchasedSeats` (number field + save). Optionally list locations with access status for that company.

- [ ] **Step 2: Commit**

```bash
git add lib/screens/platform_admin_screen.dart lib/services/store.dart
git commit -m "feat: platform admin purchasedSeats controls"
```

---

### Task 10: Verify + docs touch-up

- [ ] **Step 1: Full analyze and unit tests**

Run:
```bash
flutter analyze
flutter test
```
Expected: No issues; all tests pass

- [ ] **Step 2: Manual smoke (web)**

1. Login employee → refresh → still scorecard  
2. Sign out → code required  
3. Multi-location: search + switch location  
4. Set location `read_only` in admin → Save blocked + banner  
5. Suspend company → kicked to landing on refresh  

- [ ] **Step 3: Commit any fixes**

```bash
git commit -m "fix: sticky login / billing smoke fixes"
```

---

## Spec coverage check

| Spec requirement | Task |
|------------------|------|
| Sticky browser session / boot to scorecard | 3 |
| Switch person / location / sign out | 3, 5 |
| Partial invalidation | 3 |
| Searchable locations + recent | 3, 4 |
| purchasedSeats + accessStatus fields | 1, 2 |
| Read-only UI + Store gate | 3, 5 |
| Firestore rules | 6 |
| New location trial / seat overflow | 7 |
| Manager Billing | 8 |
| Platform admin seats | 9 |
| No Stripe this pass | — non-goal |
| Web / no idle TTL | 3 (documented behavior) |

## Out of scope reminders

Do not implement Stripe, QR deep links, or employee SSO in this plan.
