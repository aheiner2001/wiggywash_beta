# Staff Requests Board (Spec B) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Let employees send location preset/custom staff requests from a profile Requests screen, and let managers triage them on a Requests tab (Incoming → To-do → Complete) with a pending badge.

**Architecture:** Location-scoped Firestore collections `requestPresets` and `staffRequests` under `companies/{id}/locations/{id}/`. Store listens and mutates like workers/submissions. Employee identity for “my requests” is `employeeName` (display name) plus `employeeProfileKey` = lowercase trimmed name (same idea as draft keys). Because employees share anonymous Auth, rules allow signed-in read/create of pending requests; only company managers update status. Client filters the employee list by name. Manager shell gains a Requests tab (after Sheet) with a pending badge.

**Tech Stack:** Flutter web, Cloud Firestore, existing `Store` / `ManagerShell` / `ProfileAction`, `firestore.rules` (+ indexes if queries require them).

**Spec:** `docs/superpowers/specs/2026-07-09-staff-requests-design.md`

**Out of scope:** Chat threads, push/email, company-wide board, scorecard chips, dismissed history UI, coach notes.

**Locked product details:**
- Shell order: Home → Sheet → **Requests** → Team → Prices → Settings
- Custom text max **120** chars; presets soft cap **20**
- Preset double-tap debounce **2s**
- No manager dismissed/history section in v1
- Employee open list hides `dismissed`; shows `pending` / `accepted` / recent `completed` (last 24h optional — v1 shows `pending`+`accepted`+`completed` from today only via client filter on `createdAt` same calendar day, or simply show non-dismissed and let list grow — **v1: show all non-dismissed for this employeeName, newest first**)

---

## File map

| File | Responsibility |
|------|----------------|
| `lib/models/request_preset.dart` | Preset model |
| `lib/models/staff_request.dart` | Request model + status enum |
| `lib/utils/staff_request_logic.dart` | Validate text, status transitions, profile key, debounce helper |
| `test/models/request_preset_test.dart` | Preset parse |
| `test/models/staff_request_test.dart` | Request parse / status |
| `test/utils/staff_request_logic_test.dart` | Validation + transitions |
| `firestore.rules` | Preset + staffRequest rules |
| `firestore.indexes.json` | Composite indexes if needed |
| `lib/services/store.dart` | Listeners + CRUD |
| `lib/screens/manager_requests_screen.dart` | Incoming / To-do / Presets |
| `lib/screens/employee_requests_screen.dart` | Chips + custom + my list |
| `lib/widgets/manager_shell.dart` | Tab + badge |
| `lib/widgets/profile_menu.dart` | Requests entry for employees |

---

### Task 1: Models + pure logic (TDD)

**Files:**
- Create: `lib/models/request_preset.dart`
- Create: `lib/models/staff_request.dart`
- Create: `lib/utils/staff_request_logic.dart`
- Create: `test/models/request_preset_test.dart`
- Create: `test/models/staff_request_test.dart`
- Create: `test/utils/staff_request_logic_test.dart`

- [ ] **Step 1: Write failing tests**

```dart
// test/utils/staff_request_logic_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:wiggywash/models/staff_request.dart';
import 'package:wiggywash/utils/staff_request_logic.dart';

void main() {
  test('profileKey lowercases and trims', () {
    expect(staffRequestProfileKey('  Alex  '), 'alex');
  });

  test('validateRequestText rejects empty and over 120', () {
    expect(validateRequestText(''), isNotNull);
    expect(validateRequestText('x' * 121), isNotNull);
    expect(validateRequestText('Out of soap'), isNull);
  });

  test('canAccept only from pending', () {
    expect(canTransition(StaffRequestStatus.pending, StaffRequestStatus.accepted), isTrue);
    expect(canTransition(StaffRequestStatus.accepted, StaffRequestStatus.completed), isTrue);
    expect(canTransition(StaffRequestStatus.pending, StaffRequestStatus.dismissed), isTrue);
    expect(canTransition(StaffRequestStatus.completed, StaffRequestStatus.accepted), isFalse);
  });
}
```

Also add `RequestPreset.fromMap` / `StaffRequest.fromMap` round-trip tests in the model test files (status string parse; unknown status → treat as pending or fail explicitly — **use pending fallback**).

- [ ] **Step 2: Run tests — expect FAIL**

Run: `flutter test test/utils/staff_request_logic_test.dart test/models/request_preset_test.dart test/models/staff_request_test.dart`  
Expected: FAIL (missing libraries)

- [ ] **Step 3: Implement models + logic**

`lib/models/request_preset.dart`:

```dart
class RequestPreset {
  const RequestPreset({
    required this.id,
    required this.label,
    required this.sortOrder,
    this.createdAt,
    this.createdByUid,
  });
  final String id;
  final String label;
  final int sortOrder;
  final DateTime? createdAt;
  final String? createdByUid;
  // fromMap / toMap with Timestamp handling like other models
}
```

`lib/models/staff_request.dart`:

```dart
enum StaffRequestStatus { pending, accepted, completed, dismissed }

class StaffRequest {
  // fields per spec; fromMap/toMap; copyWith for status updates
}
```

`lib/utils/staff_request_logic.dart`:

```dart
const kStaffRequestMaxLen = 120;
const kStaffRequestPresetCap = 20;
const kStaffRequestDebounce = Duration(seconds: 2);

String staffRequestProfileKey(String name) => name.trim().toLowerCase();

String? validateRequestText(String raw) {
  final t = raw.trim();
  if (t.isEmpty) return 'Enter a short request.';
  if (t.length > kStaffRequestMaxLen) return 'Keep it under $kStaffRequestMaxLen characters.';
  return null;
}

bool canTransition(StaffRequestStatus from, StaffRequestStatus to) {
  return switch ((from, to)) {
    (StaffRequestStatus.pending, StaffRequestStatus.accepted) => true,
    (StaffRequestStatus.pending, StaffRequestStatus.dismissed) => true,
    (StaffRequestStatus.accepted, StaffRequestStatus.completed) => true,
    _ => false,
  };
}
```

- [ ] **Step 4: Run tests — expect PASS**

Run: `flutter test test/utils/staff_request_logic_test.dart test/models/request_preset_test.dart test/models/staff_request_test.dart`

- [ ] **Step 5: Commit**

```bash
git add lib/models/request_preset.dart lib/models/staff_request.dart lib/utils/staff_request_logic.dart \
  test/models/request_preset_test.dart test/models/staff_request_test.dart test/utils/staff_request_logic_test.dart
git commit -m "feat: staff request and preset models with status helpers"
```

---

### Task 2: Firestore rules (+ indexes)

**Files:**
- Modify: `firestore.rules`
- Modify: `firestore.indexes.json` (only if composite queries need it)

- [ ] **Step 1: Add rules under `match /locations/{locationId}` inside companies**

```
match /requestPresets/{presetId} {
  allow read: if signedIn();
  allow create, update, delete: if canManageCompany(companyId);
}

match /staffRequests/{requestId} {
  allow read: if signedIn();
  allow create: if signedIn()
    && request.resource.data.status == 'pending'
    && request.resource.data.keys().hasAll(['text', 'employeeName', 'status', 'createdAt'])
    && request.resource.data.text is string
    && request.resource.data.text.size() > 0
    && request.resource.data.text.size() <= 120
    && !('acceptedByUid' in request.resource.data)
    && !('completedByUid' in request.resource.data);
  allow update: if canManageCompany(companyId);
  allow delete: if canManageCompany(companyId);
}
```

Note: `createdAt` may be `request.time` / server timestamp — if create uses `FieldValue.serverTimestamp()`, adjust `hasAll` to not require client `createdAt`, or allow missing createdAt on create. **Prefer:** require `text`, `employeeName`, `status`; allow optional `presetId`, `employeeProfileKey`; set `createdAt` server-side. Update the create rule accordingly:

```
allow create: if signedIn()
  && request.resource.data.status == 'pending'
  && request.resource.data.text is string
  && request.resource.data.text.size() > 0
  && request.resource.data.text.size() <= 120
  && request.resource.data.employeeName is string
  && request.resource.data.employeeName.size() > 0;
```

- [ ] **Step 2: Indexes**

If Store queries `where('status', isEqualTo: …).orderBy('createdAt')`, add composite indexes on `staffRequests` for `status` ASC + `createdAt` DESC (or ASC — match query).  
If only `orderBy('createdAt')` and filter client-side, **skip new indexes** (YAGNI). **Plan default:** listen all recent requests for the location ordered by `createdAt` desc (limit 100) and filter by status in memory — **no new composite index required**.

- [ ] **Step 3: Commit**

```bash
git add firestore.rules firestore.indexes.json
git commit -m "feat: Firestore rules for requestPresets and staffRequests"
```

Remind in commit body / PR: deploy rules with `firebase deploy --only firestore:rules`.

---

### Task 3: Store listeners + CRUD

**Files:**
- Modify: `lib/services/store.dart`

- [ ] **Step 1: Add state**

```dart
List<RequestPreset> _requestPresets = [];
List<StaffRequest> _staffRequests = [];
StreamSubscription? _presetsSub;
StreamSubscription? _staffRequestsSub;

List<RequestPreset> get requestPresets => List.unmodifiable(_requestPresets);
List<StaffRequest> get staffRequests => List.unmodifiable(_staffRequests);
int get pendingStaffRequestCount =>
    _staffRequests.where((r) => r.status == StaffRequestStatus.pending).length;
```

- [ ] **Step 2: Wire listen/teardown with location changes**

When active location company path is available (same place workers/submissions attach), subscribe:

```dart
_locCol.doc(locationId).collection('requestPresets').orderBy('sortOrder').snapshots()
_locCol.doc(locationId).collection('staffRequests').orderBy('createdAt', descending: true).limit(100).snapshots()
```

Clear lists and cancel subs when location clears.

- [ ] **Step 3: CRUD methods**

```dart
Future<String?> addRequestPreset(String label);
Future<String?> updateRequestPreset({required String id, required String label, int? sortOrder});
Future<String?> deleteRequestPreset(String id);

Future<String?> createStaffRequest({
  required String text,
  String? presetId,
}); // uses profile!.name, staffRequestProfileKey, status pending

Future<String?> acceptStaffRequest(String id);
Future<String?> dismissStaffRequest(String id);
Future<String?> completeStaffRequest(String id);
```

Each status method: find local request, check `canTransition`, write merge update with timestamps + manager uid from `_appUser?.uid`, map errors with `mapFirestoreUserError` where useful.  
`addRequestPreset`: reject if `_requestPresets.length >= kStaffRequestPresetCap`; validate non-empty label (reuse validate or trim).  
`createStaffRequest`: `validateRequestText`; return error string if invalid.

- [ ] **Step 4: Analyzer smoke**

Run: `dart analyze lib/services/store.dart`  
Expected: No issues

- [ ] **Step 5: Commit**

```bash
git add lib/services/store.dart
git commit -m "feat: Store listeners and CRUD for staff requests"
```

---

### Task 4: Manager Requests screen

**Files:**
- Create: `lib/screens/manager_requests_screen.dart`

- [ ] **Step 1: Build screen with DefaultTabController (3 tabs)**

Tabs: Incoming | To-do | Presets

**Incoming:** list `staffRequests` where `pending`; each row shows text, employeeName, time; actions Accept / Dismiss calling Store.

**To-do:** status `accepted`; action Mark complete.

**Presets:** list presets; TextField + Add; edit/delete icons; enforce cap message via Store error.

Use `AnimatedBuilder(animation: Store.instance, …)` and existing `AppCard` / `TextStyles` / `showStoreMessage`.

- [ ] **Step 2: Manual layout check** — empty states: “No incoming requests”, “No open to-dos”, “Add presets employees can tap”.

- [ ] **Step 3: Commit**

```bash
git add lib/screens/manager_requests_screen.dart
git commit -m "feat: manager Requests board with Incoming To-do Presets"
```

---

### Task 5: Wire ManagerShell tab + badge

**Files:**
- Modify: `lib/widgets/manager_shell.dart`

- [ ] **Step 1: Insert Requests at index 2**

Update `_destinations` / `_mobileLabels` / `_page`:

```dart
static const _destinations = [
  (icon: Icons.dashboard_rounded, label: 'Dashboard'),
  (icon: Icons.table_chart_outlined, label: 'Master Sheet'),
  (icon: Icons.campaign_outlined, label: 'Requests'),
  (icon: Icons.group_outlined, label: 'Team'),
  (icon: Icons.sell_outlined, label: 'Prices'),
  (icon: Icons.settings_outlined, label: 'Settings'),
];

static const _mobileLabels = [
  'Home', 'Sheet', 'Requests', 'Team', 'Prices', 'Settings',
];

Widget _page(int index) => switch (index) {
  0 => const ManagerScreen(),
  1 => const MasterSheetScreen(),
  2 => const ManagerRequestsScreen(),
  3 => const TeamScreen(),
  4 => const PricingScreen(),
  5 => const SettingsScreen(),
  _ => const ManagerScreen(),
};
```

- [ ] **Step 2: Badge helper** (mirror `_sheetIcon`)

```dart
Widget _requestsIcon({required bool selected}) {
  return AnimatedBuilder(
    animation: Store.instance,
    builder: (context, _) {
      final n = Store.instance.pendingStaffRequestCount;
      final icon = Icon(selected ? Icons.campaign_rounded : Icons.campaign_outlined);
      return Badge(isLabelVisible: n > 0, label: Text('$n'), child: icon);
    },
  );
}
```

Use for destination index `2` (was Sheet-only special case at `1` — keep Sheet badge at `1`, Requests badge at `2`).

- [ ] **Step 3: Commit**

```bash
git add lib/widgets/manager_shell.dart
git commit -m "feat: Requests tab and pending badge in manager shell"
```

---

### Task 6: Employee Requests screen + profile entry

**Files:**
- Create: `lib/screens/employee_requests_screen.dart`
- Modify: `lib/widgets/profile_menu.dart`

- [ ] **Step 1: Employee screen**

- Load presets as `ActionChip` / `FilterChip` wrap; onPressed → `createStaffRequest(text: preset.label, presetId: preset.id)` with **debounce**: keep `Map<String, DateTime> _lastTapByPreset` in State; ignore if within `kStaffRequestDebounce`.
- Custom `TextField` (maxLength 120) + Send button → `createStaffRequest(text: …)`.
- List: filter `staffRequests` where `employeeProfileKey == staffRequestProfileKey(profile.name)` OR `employeeName` equals profile name; exclude `dismissed`; show status label Sent / Accepted / Done.

- [ ] **Step 2: Profile menu entry**

In `ProfileAction` sheet, when `isEmployee || acting`, add before sign-out:

```dart
OutlinedButton.icon(
  onPressed: () {
    Navigator.pop(ctx);
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const EmployeeRequestsScreen()),
    );
  },
  icon: const Icon(Icons.campaign_outlined),
  label: const Text('Requests'),
),
const SizedBox(height: 12),
```

Use outer `context` for push after pop (same pattern as other navigations).

- [ ] **Step 3: Widget smoke test (optional but preferred)**

```dart
// test/screens/employee_requests_screen_test.dart — pump MaterialApp with fake empty Store if hard;
// otherwise skip and rely on manual QA. Prefer a small test that validateRequestText still gates Send.
```

If Store singleton makes widget tests hard, skip widget test; keep logic tests.

- [ ] **Step 4: Commit**

```bash
git add lib/screens/employee_requests_screen.dart lib/widgets/profile_menu.dart
git commit -m "feat: employee Requests screen and profile entry"
```

---

### Task 7: Verification

- [ ] **Step 1: Automated**

```bash
flutter test test/utils/staff_request_logic_test.dart \
  test/models/request_preset_test.dart \
  test/models/staff_request_test.dart
dart analyze lib/models/request_preset.dart lib/models/staff_request.dart \
  lib/utils/staff_request_logic.dart lib/services/store.dart \
  lib/screens/manager_requests_screen.dart lib/screens/employee_requests_screen.dart \
  lib/widgets/manager_shell.dart lib/widgets/profile_menu.dart
```

Expected: tests PASS; analyzer clean (no issues / no infos that fail CI).

- [ ] **Step 2: Deploy rules** (human or agent with firebase login)

```bash
firebase deploy --only firestore:rules
```

- [ ] **Step 3: Manual QA**

1. Manager → Requests → Presets → add “Out of soap”.
2. Employee profile → Requests → tap preset → appears Incoming for manager; employee sees Sent.
3. Manager Accept → employee Accepted; item in To-do.
4. Manager Complete → employee Done.
5. Custom line works; empty custom blocked; 121 chars blocked.
6. Double-tap preset within 2s does not create two (or second blocked).
7. Badge shows pending count; clears when none pending.
8. Dismiss removes from Incoming; employee list hides dismissed.

- [ ] **Step 4: Push branch / merge per user**

---

## Spec coverage self-check

| Spec item | Task |
|-----------|------|
| Preset chips + custom ≤120 | Tasks 1, 3, 6 |
| Employee profile → Requests | Task 6 |
| Status Sent → Accepted → Done | Tasks 1, 3, 4, 6 |
| Manager Incoming / To-do / Presets | Task 4 |
| Location-scoped data + rules | Tasks 2–3 |
| Pending badge on Requests tab | Task 5 |
| Debounce + validation | Tasks 1, 6 |
| No chat / push / scorecard chips | Out of scope |

## Consistency self-check

- Status enum names match Firestore strings: `pending|accepted|completed|dismissed`
- Shell index 2 = Requests everywhere (`_page`, badges, labels)
- `createStaffRequest` always writes `employeeProfileKey` via `staffRequestProfileKey`
- Soft cap `kStaffRequestPresetCap` enforced in Store add
