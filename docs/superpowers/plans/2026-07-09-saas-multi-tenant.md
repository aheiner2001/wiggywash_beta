# SaaS Multi-Tenant Platform Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Transform Wiggy Wash into a multi-tenant SaaS product with company-code employee login, platform-admin approval workflow, and `.xlsx` Master Sheet export — delivered in three incremental slices.

**Architecture:** Introduce a `companies/{companyId}` tenant layer above locations. All Firestore paths move to `companies/{companyId}/locations/{locationId}/...`. Roles become `platformAdmin`, `companyManager`, `employee`. Employee sessions remain device-local (no accounts); managers/platform admins use Google sign-in.

**Tech Stack:** Flutter 3.12+, Firestore, Firebase Auth, `google_fonts` (Inter), `excel` package for `.xlsx`, existing `shared_preferences` fallback.

**Design spec:** `docs/superpowers/specs/2026-07-09-saas-multi-tenant-design.md`

---

## File Map

| File | Responsibility |
|------|----------------|
| `lib/models/company.dart` | `Company` model + `CompanyStatus` enum |
| `lib/models/profile.dart` | Rename roles to `platformAdmin` / `companyManager`; backward-compat parsing |
| `lib/models/app_user.dart` | Add `companyId` field |
| `lib/models/location.dart` | Remove `siteCode` (company code replaces it) |
| `lib/services/store.dart` | Company-scoped paths, lookup, migration, auth routing |
| `lib/services/company_migration.dart` | One-time legacy → company migration (extracted from store) |
| `firestore.rules` | Tenant-scoped security rules |
| `lib/screens/company_login_screen.dart` | White landing + 3-step employee wizard (replaces `site_code_screen.dart`) |
| `lib/screens/manager_auth_screen.dart` | Signup form + pending waiting screen |
| `lib/screens/platform_admin_screen.dart` | Tenant approval console (replaces `super_admin_screen.dart`) |
| `lib/screens/pending_approval_screen.dart` | Manager waiting state |
| `lib/widgets/step_indicator.dart` | Wizard progress dots |
| `lib/widgets/status_badge.dart` | pending/active/suspended badge |
| `lib/widgets/company_header.dart` | White-label header (logo or initials) |
| `lib/widgets/manager_shell.dart` | Desktop sidebar + mobile bottom nav |
| `lib/utils/xlsx.dart` | Master Sheet → `.xlsx` builder |
| `lib/utils/exporter.dart` | Add `exportXlsx` alongside `exportCsv` |
| `lib/theme.dart` | White scaffold default, Inter via google_fonts |
| `lib/main.dart` | Route to new screens, new `AppView` cases |
| `test/models/company_test.dart` | Company model unit tests |
| `test/models/profile_test.dart` | Role backward-compat tests |

**Delete after migration:** `lib/screens/site_code_screen.dart`, `lib/screens/super_admin_screen.dart` (replaced by new files).

---

## Slice 1 — Company Model + Company-Code Login + Migration

### Task 1: Company model + role rename

**Files:**
- Create: `lib/models/company.dart`
- Modify: `lib/models/profile.dart`
- Modify: `lib/models/app_user.dart`
- Create: `test/models/company_test.dart`
- Create: `test/models/profile_test.dart`

- [ ] **Step 1: Write failing tests**

`test/models/company_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:wiggywash/models/company.dart';

void main() {
  test('Company.fromMap parses status and code', () {
    final c = Company.fromMap('abc', {
      'name': 'Wiggy Wash',
      'companyCode': 'WIGGY',
      'status': 'active',
    });
    expect(c.id, 'abc');
    expect(c.companyCode, 'WIGGY');
    expect(c.status, CompanyStatus.active);
    expect(c.isActive, isTrue);
  });

  test('normalizeCode uppercases and trims', () {
    expect(Company.normalizeCode('  wiggy '), 'WIGGY');
  });
}
```

`test/models/profile_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:wiggywash/models/profile.dart';

void main() {
  test('roleFromString accepts legacy superAdmin', () {
    expect(roleFromString('superAdmin'), UserRole.platformAdmin);
  });

  test('roleFromString accepts new companyManager', () {
    expect(roleFromString('companyManager'), UserRole.companyManager);
  });
}
```

- [ ] **Step 2: Run tests to verify they fail**

```bash
flutter test test/models/company_test.dart test/models/profile_test.dart
```

Expected: FAIL — files/classes not found.

- [ ] **Step 3: Implement models**

`lib/models/company.dart`:

```dart
import 'package:cloud_firestore/cloud_firestore.dart';

enum CompanyStatus { pending, active, suspended }

extension CompanyStatusLabel on CompanyStatus {
  String get firestoreValue => name;

  static CompanyStatus? fromString(String? v) {
    if (v == null) return null;
    for (final s in CompanyStatus.values) {
      if (s.name == v) return s;
    }
    return null;
  }
}

class Company {
  const Company({
    required this.id,
    required this.name,
    required this.companyCode,
    this.status = CompanyStatus.pending,
    this.logoUrl,
    this.primaryColor,
    this.createdAt,
    this.approvedAt,
    this.approvedBy,
  });

  final String id;
  final String name;
  final String companyCode;
  final CompanyStatus status;
  final String? logoUrl;
  final String? primaryColor;
  final DateTime? createdAt;
  final DateTime? approvedAt;
  final String? approvedBy;

  bool get isActive => status == CompanyStatus.active;

  static String normalizeCode(String raw) => raw.trim().toUpperCase();

  Map<String, dynamic> toMap() => {
        'name': name,
        'companyCode': normalizeCode(companyCode),
        'status': status.firestoreValue,
        if (logoUrl != null) 'logoUrl': logoUrl,
        if (primaryColor != null) 'primaryColor': primaryColor,
        'createdAt': createdAt != null
            ? Timestamp.fromDate(createdAt!)
            : FieldValue.serverTimestamp(),
        if (approvedAt != null) 'approvedAt': Timestamp.fromDate(approvedAt!),
        if (approvedBy != null) 'approvedBy': approvedBy,
      };

  factory Company.fromMap(String id, Map<String, dynamic> data) {
    final ts = data['createdAt'];
    final ats = data['approvedAt'];
    return Company(
      id: id,
      name: data['name'] as String? ?? id,
      companyCode: data['companyCode'] as String? ?? '',
      status: CompanyStatusLabel.fromString(data['status'] as String?) ??
          CompanyStatus.pending,
      logoUrl: data['logoUrl'] as String?,
      primaryColor: data['primaryColor'] as String?,
      createdAt: ts is Timestamp ? ts.toDate() : null,
      approvedAt: ats is Timestamp ? ats.toDate() : null,
      approvedBy: data['approvedBy'] as String?,
    );
  }

  factory Company.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) =>
      Company.fromMap(doc.id, doc.data() ?? {});
}
```

`lib/models/profile.dart` — replace enum and parser:

```dart
enum UserRole { platformAdmin, companyManager, employee }

extension UserRoleLabel on UserRole {
  String get label => switch (this) {
        UserRole.platformAdmin => 'Platform Admin',
        UserRole.companyManager => 'Manager',
        UserRole.employee => 'Employee',
      };

  /// Firestore value written to users/{uid}.role
  String get firestoreValue => name;
}

UserRole? roleFromString(String? value) {
  if (value == null) return null;
  // Backward compatibility with pre-SaaS role names.
  final normalized = switch (value) {
    'superAdmin' => 'platformAdmin',
    'manager' => 'companyManager',
    _ => value,
  };
  for (final r in UserRole.values) {
    if (r.name == normalized) return r;
  }
  return null;
}
```

`lib/models/app_user.dart` — add `companyId`:

```dart
// Add field:
final String? companyId;

// In constructor, copyWith, fromDoc — mirror locationId pattern:
companyId: data['companyId'] as String?,
```

- [ ] **Step 4: Run tests**

```bash
flutter test test/models/company_test.dart test/models/profile_test.dart
```

Expected: PASS

- [ ] **Step 5: Fix compile errors from role rename across codebase**

Run `flutter analyze` and replace:
- `UserRole.superAdmin` → `UserRole.platformAdmin`
- `UserRole.manager` → `UserRole.companyManager`
- `AppView.superAdmin` → `AppView.platformAdmin` (in `store.dart` + `main.dart`)

- [ ] **Step 6: Commit**

```bash
git add lib/models/ test/models/ lib/main.dart lib/services/store.dart
git commit -m "feat: add Company model and rename roles for SaaS tenancy"
```

---

### Task 2: Store — company-scoped Firestore paths

**Files:**
- Modify: `lib/services/store.dart`
- Create: `lib/services/company_migration.dart`

- [ ] **Step 1: Add company state fields to Store**

At top of `Store` class, add:

```dart
static const _kCompanies = 'companies';
static const _kActiveCompany = 'ww_active_company';
static const _kEmployeeCompanyCode = 'ww_employee_company_code';

String? _activeCompanyId;
Company? _activeCompany;
List<Location> _companyLocations = [];
```

Add getters:

```dart
String? get activeCompanyId => _activeCompanyId;
Company? get activeCompany => _activeCompany;
List<Location> get companyLocations => List.unmodifiable(_companyLocations);
```

- [ ] **Step 2: Replace `_locationsCol` references with company-scoped helpers**

```dart
CollectionReference<Map<String, dynamic>> get _companiesCol =>
    _db.collection(_kCompanies);

DocumentReference<Map<String, dynamic>>? get _companyRef =>
    _activeCompanyId == null ? null : _companiesCol.doc(_activeCompanyId);

CollectionReference<Map<String, dynamic>> get _locationsCol {
  final ref = _companyRef;
  if (ref == null) {
    // Legacy fallback during migration window.
    return _db.collection('locations');
  }
  return ref.collection('locations');
}
```

Update `_bindLocation` — no change needed if `_locationsCol` is already scoped.

- [ ] **Step 3: Add `lookupCompanyCode`**

```dart
Future<Company?> lookupCompanyCode(String code) async {
  final clean = Company.normalizeCode(code);
  if (clean.isEmpty) return null;
  try {
    final snap = await _companiesCol
        .where('companyCode', isEqualTo: clean)
        .limit(1)
        .get();
    if (snap.docs.isNotEmpty) return Company.fromDoc(snap.docs.first);
    // Case-insensitive fallback for small datasets.
    final all = await _companiesCol.get();
    for (final d in all.docs) {
      final c = Company.fromDoc(d);
      if (Company.normalizeCode(c.companyCode) == clean) return c;
    }
    return null;
  } catch (e) {
    debugPrint('lookupCompanyCode error: $e');
    return null;
  }
}
```

- [ ] **Step 4: Add `previewCompany` and `loadCompanyLocations`**

```dart
Future<void> previewCompany(String companyId) async {
  _activeCompanyId = companyId;
  final doc = await _companiesCol.doc(companyId).get();
  _activeCompany = doc.exists ? Company.fromDoc(doc) : null;
  final locSnap = await _locationsCol.orderBy('name').get();
  _companyLocations = locSnap.docs.map(Location.fromDoc).toList();
  notifyListeners();
}
```

- [ ] **Step 5: Update `signInEmployee` to cache company code**

```dart
Future<void> signInEmployee({
  required String companyId,
  required String locationId,
  required String name,
  required String companyCode,
}) async {
  _employeeName = name;
  _employeeLocationId = locationId;
  _activeCompanyId = companyId;
  _activeLocationId = locationId;
  await _prefs?.setString(
    _kEmployeeProfile,
    jsonEncode({
      'name': name,
      'locationId': locationId,
      'companyId': companyId,
      'companyCode': Company.normalizeCode(companyCode),
    }),
  );
  await _prefs?.setString(_kActiveCompany, companyId);
  await _prefs?.setString(_kActiveLocation, locationId);
  await _prefs?.setString(_kEmployeeCompanyCode, Company.normalizeCode(companyCode));
  _bindLocation(locationId);
  notifyListeners();
}
```

Update `_loadEmployeeProfile` to restore `companyId` and auto-resume session.

- [ ] **Step 6: Create migration helper**

`lib/services/company_migration.dart`:

```dart
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/company.dart';

/// Copies root-level locations (and their subcollections) into
/// companies/{companyId}/locations/. Safe to run once.
Future<String?> migrateToCompany({
  required FirebaseFirestore db,
  required String companyId,
  required String companyName,
  required String companyCode,
}) async {
  try {
    final companyRef = db.collection('companies').doc(companyId);
    await companyRef.set(Company(
      id: companyId,
      name: companyName,
      companyCode: companyCode,
      status: CompanyStatus.active,
      createdAt: DateTime.now(),
    ).toMap());

    final legacyLocs = await db.collection('locations').get();
    for (final locDoc in legacyLocs.docs) {
      final dest = companyRef.collection('locations').doc(locDoc.id);
      await dest.set(locDoc.data());
      for (final sub in ['submissions', 'workers', 'config']) {
        final subSnap = await locDoc.reference.collection(sub).get();
        final batch = db.batch();
        for (final d in subSnap.docs) {
          batch.set(dest.collection(sub).doc(d.id), d.data());
        }
        await batch.commit();
      }
    }
    return null;
  } catch (e) {
    return 'Company migration failed: $e';
  }
}
```

Expose via `Store.migrateToCompany()` wrapper.

- [ ] **Step 7: Run analyze**

```bash
flutter analyze
```

Expected: 0 errors (warnings OK).

- [ ] **Step 8: Commit**

```bash
git add lib/services/
git commit -m "feat: scope Store paths under companies collection"
```

---

### Task 3: Firestore security rules (company-scoped)

**Files:**
- Modify: `firestore.rules`

- [ ] **Step 1: Replace Wiggy Wash location rules with company-scoped rules**

```javascript
function userDoc() {
  return get(/databases/$(database)/documents/users/$(request.auth.uid)).data;
}
function isPlatformAdmin() {
  return signedIn() && userDoc().role == 'platformAdmin';
}
function isCompanyManager(companyId) {
  return signedIn()
    && userDoc().role == 'companyManager'
    && userDoc().companyId == companyId;
}
function canManageCompany(companyId) {
  return isPlatformAdmin() || isCompanyManager(companyId);
}

match /companies/{companyId} {
  allow read: if signedIn();
  allow create: if isRealUser(); // manager self-signup
  allow update: if canManageCompany(companyId) || isPlatformAdmin();
  allow delete: if isPlatformAdmin();

  match /locations/{locationId} {
    allow read: if signedIn();
    allow create, update: if canManageCompany(companyId);
    allow delete: if isPlatformAdmin();

    match /submissions/{doc} {
      allow read, create, update: if signedIn();
      allow delete: if canManageCompany(companyId);
    }
    match /workers/{doc} {
      allow read: if signedIn();
      allow write: if canManageCompany(companyId);
    }
    match /config/{doc} {
      allow read: if signedIn();
      allow write: if canManageCompany(companyId);
    }
    match /challenges/{doc} {
      allow read: if signedIn();
      allow write: if canManageCompany(companyId);
    }
  }
}
```

Keep legacy `locations/` and flat collections rules for migration window.

- [ ] **Step 2: Deploy rules (manual)**

```bash
firebase deploy --only firestore:rules
```

- [ ] **Step 3: Commit**

```bash
git add firestore.rules
git commit -m "feat: add company-scoped Firestore security rules"
```

---

### Task 4: Shared UI widgets (StepIndicator, CompanyHeader, theme)

**Files:**
- Create: `lib/widgets/step_indicator.dart`
- Create: `lib/widgets/company_header.dart`
- Modify: `lib/theme.dart`
- Modify: `pubspec.yaml`

- [ ] **Step 1: Add dependencies**

`pubspec.yaml`:

```yaml
dependencies:
  google_fonts: ^6.2.1
```

```bash
flutter pub get
```

- [ ] **Step 2: Update theme for white landing + Inter**

`lib/theme.dart` — in `buildTheme()`:

```dart
import 'package:google_fonts/google_fonts.dart';

// Inside buildTheme():
final base = ThemeData(
  useMaterial3: true,
  colorScheme: scheme,
  scaffoldBackgroundColor: Colors.white, // was AppColors.background
  fontFamily: GoogleFonts.inter().fontFamily,
  textTheme: GoogleFonts.interTextTheme(),
);
```

Keep `AppColors.background` for inner cards/dashboards where needed.

- [ ] **Step 3: Create StepIndicator**

`lib/widgets/step_indicator.dart`:

```dart
import 'package:flutter/material.dart';
import '../theme.dart';

class StepIndicator extends StatelessWidget {
  const StepIndicator({super.key, required this.step, required this.total});
  final int step; // 1-based
  final int total;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(total, (i) {
        final active = i + 1 == step;
        final done = i + 1 < step;
        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 4),
          width: active ? 24 : 8,
          height: 8,
          decoration: BoxDecoration(
            color: done || active ? AppColors.navy : AppColors.hairline,
            borderRadius: BorderRadius.circular(4),
          ),
        );
      }),
    );
  }
}
```

- [ ] **Step 4: Create CompanyHeader**

`lib/widgets/company_header.dart`:

```dart
import 'package:flutter/material.dart';
import '../models/company.dart';
import '../theme.dart';
import 'brand_header.dart';

class CompanyHeader extends StatelessWidget {
  const CompanyHeader({super.key, this.company});
  final Company? company;

  @override
  Widget build(BuildContext context) {
    if (company == null) return const BrandHeader();
    final initials = company!.name
        .split(' ')
        .where((w) => w.isNotEmpty)
        .take(2)
        .map((w) => w[0].toUpperCase())
        .join();
    return Column(
      children: [
        if (company!.logoUrl != null)
          Image.network(company!.logoUrl!, height: 72)
        else
          CircleAvatar(
            radius: 36,
            backgroundColor: AppColors.blueSoft,
            child: Text(initials,
                style: const TextStyle(
                    fontSize: 24, fontWeight: FontWeight.w800, color: AppColors.navy)),
          ),
        const SizedBox(height: 8),
        Text(company!.name,
            style: TextStyles.subheading, textAlign: TextAlign.center),
        const SizedBox(height: 4),
        const Text('Sales Scorecard', style: TextStyles.caption),
      ],
    );
  }
}
```

- [ ] **Step 5: Commit**

```bash
git add pubspec.yaml pubspec.lock lib/theme.dart lib/widgets/
git commit -m "feat: white landing theme, Inter font, step indicator widgets"
```

---

### Task 5: Company login screen (replaces site code screen)

**Files:**
- Create: `lib/screens/company_login_screen.dart`
- Modify: `lib/main.dart`
- Delete: `lib/screens/site_code_screen.dart` (after wiring)

- [ ] **Step 1: Create 3-step wizard screen**

`lib/screens/company_login_screen.dart` — state machine:

```dart
enum _LoginStep { companyCode, location, name }

class CompanyLoginScreen extends StatefulWidget { ... }
```

**Step companyCode:**
- White `Scaffold`
- `CompanyHeader()` (no company yet → `BrandHeader` via null)
- `TextField` for company code
- Inline `_codeError` string (not toast)
- On submit: `Store.instance.lookupCompanyCode(code)`
  - null → `_codeError = 'Code not found — check with your manager'`
  - `status == suspended` → `_codeError = 'This company account is suspended.'`
  - `status == pending` → `_codeError = 'This company isn\'t active yet.'`
  - `active` → `previewCompany(id)`, advance step
- `StepIndicator(step: 1, total: 3)`
- `TextButton`: "Manager? Sign in with Google" → `Store.instance.openManagerAuth()`

**Step location:**
- Skip entirely if `_companyLocations.length == 1` (auto-select and advance)
- List of location tiles (same style as name tiles)
- Back button → step 1
- `StepIndicator(step: 2, total: 3)`

**Step name:**
- Reuse worker list pattern from old `_NamePickerCard`
- Large tiles, 48px min height, initials circle
- PIN field inline when `worker.requiresPin`
- On continue: `signInEmployee(companyId:, locationId:, name:, companyCode:)`
- `StepIndicator(step: 3, total: 3)`

- [ ] **Step 2: Wire main.dart**

```dart
import 'screens/company_login_screen.dart';
// ...
case AppView.landing:
  return const CompanyLoginScreen();
```

- [ ] **Step 3: Update Store.view routing**

Ensure `_loadEmployeeProfile` restores session when `companyId` + `locationId` + `name` are cached → `AppView.employee` without landing.

- [ ] **Step 4: Delete old screen and fix imports**

Remove `site_code_screen.dart`. Grep for `SiteCodeScreen` — should be zero.

- [ ] **Step 5: Manual test**

```bash
flutter run -d chrome
```

1. Enter `WIGGY` (after migration) → see locations → pick name → scorecard
2. Reload page → should resume scorecard directly
3. Profile menu → Switch person → back to name step

- [ ] **Step 6: Commit**

```bash
git add lib/screens/company_login_screen.dart lib/main.dart lib/services/store.dart
git rm lib/screens/site_code_screen.dart
git commit -m "feat: company-code login wizard with remember-me"
```

---

### Task 6: Run Wiggy Wash migration + update manager routing

**Files:**
- Modify: `lib/services/store.dart`
- Modify: `lib/screens/platform_admin_screen.dart` (temporary migration button)

- [ ] **Step 1: Add one-time migration trigger**

In `Store.init()`, after Firebase connects, check if `companies/wiggy-wash` exists. If not AND legacy `locations/` has docs, log a debug message. Migration runs manually from platform admin console (don't auto-run in prod).

- [ ] **Step 2: Update manager `users/{uid}` docs**

After migration, existing managers need `companyId: 'wiggy-wash'` and `role: 'companyManager'`.

- [ ] **Step 3: Run migration in Firebase console or via admin button**

Call `Store.migrateToCompany(companyId: 'wiggy-wash', companyName: 'Wiggy Wash', companyCode: 'WIGGY')`.

- [ ] **Step 4: Verify employee + manager flows still work**

```bash
flutter analyze
flutter test
```

- [ ] **Step 5: Commit**

```bash
git commit -m "feat: Wiggy Wash legacy data migration to company tenant"
```

**Slice 1 complete.** App works as multi-tenant with company-code login. Deploy and validate before Slice 2.

---

## Slice 2 — Self-Service Signup + Platform Admin Approval

### Task 7: StatusBadge + pending approval screen

**Files:**
- Create: `lib/widgets/status_badge.dart`
- Create: `lib/screens/pending_approval_screen.dart`
- Modify: `lib/services/store.dart` (`AppView.pendingApproval`)

- [ ] **Step 1: Create StatusBadge**

```dart
class StatusBadge extends StatelessWidget {
  const StatusBadge({super.key, required this.status});
  final CompanyStatus status;

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (status) {
      CompanyStatus.pending => ('Pending', AppColors.warning),
      CompanyStatus.active => ('Active', AppColors.success),
      CompanyStatus.suspended => ('Suspended', AppColors.danger),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(label,
          style: TextStyle(color: color, fontWeight: FontWeight.w700, fontSize: 12)),
    );
  }
}
```

- [ ] **Step 2: Create PendingApprovalScreen**

Shows checkmark "Account created", clock "Waiting for approval", company name, company code, message. Sign-out button.

- [ ] **Step 3: Route pending managers in Store.view**

```dart
if (role == UserRole.companyManager && _activeCompany?.status == CompanyStatus.pending) {
  return AppView.pendingApproval;
}
```

- [ ] **Step 4: Commit**

```bash
git commit -m "feat: pending approval waiting screen for new managers"
```

---

### Task 8: Manager self-signup flow

**Files:**
- Modify: `lib/screens/manager_auth_screen.dart`
- Modify: `lib/services/store.dart`

- [ ] **Step 1: Remove admin password from create flow**

Replace `_createStep` with company creation form:
- Company name
- Company code (call `Store.isCompanyCodeAvailable(code)`)
- First location name
- City (optional)

- [ ] **Step 2: Add `createPendingCompany` to Store**

```dart
Future<String?> createPendingCompany({
  required String companyName,
  required String companyCode,
  required String locationName,
  String city = '',
}) async {
  final user = _appUser;
  if (user == null) return 'Sign in first.';
  final code = Company.normalizeCode(companyCode);
  if (code.length < 4) return 'Code must be at least 4 characters.';
  if (!await isCompanyCodeAvailable(code)) return 'That code is taken — try another.';

  final companyRef = _companiesCol.doc();
  final locRef = companyRef.collection('locations').doc();
  final batch = _db.batch();
  batch.set(companyRef, Company(
    id: companyRef.id,
    name: companyName.trim(),
    companyCode: code,
    status: CompanyStatus.pending,
  ).toMap());
  batch.set(locRef, Location(id: locRef.id, name: locationName.trim(), city: city.trim()).toMap());
  batch.set(_usersCol.doc(user.uid), {
    'role': UserRole.companyManager.firestoreValue,
    'companyId': companyRef.id,
    'locationId': locRef.id,
    'email': user.email,
    'displayName': user.displayName,
  }, SetOptions(merge: true));
  await batch.commit();
  _activeCompanyId = companyRef.id;
  _activeLocationId = locRef.id;
  return null;
}
```

- [ ] **Step 3: Returning manager sign-in**

Google sign-in only (no password). `Store.view` routes by role + company status.

- [ ] **Step 4: Remove `signInSuperAdmin` password flow from landing**

Delete admin password dialog from old site code screen (already deleted). Remove master code redemption for superAdmin from manager auth — platform admin is seeded via Firestore only.

- [ ] **Step 5: Test signup flow**

1. Sign in with Google as new user
2. Create company → see pending screen
3. Employee cannot log in with that company code yet

- [ ] **Step 6: Commit**

```bash
git commit -m "feat: manager self-signup creates pending company"
```

---

### Task 9: Platform Admin console

**Files:**
- Create: `lib/screens/platform_admin_screen.dart`
- Delete: `lib/screens/super_admin_screen.dart`
- Modify: `lib/main.dart`, `lib/services/store.dart`

- [ ] **Step 1: Add Store methods**

```dart
Stream<List<Company>> watchCompanies({CompanyStatus? filter});
Future<String?> approveCompany(String companyId);
Future<String?> rejectCompany(String companyId, {String? reason});
Future<String?> suspendCompany(String companyId, bool suspended);
```

`approveCompany` sets `status: active`, `approvedAt`, `approvedBy`.

- [ ] **Step 2: Build PlatformAdminScreen**

Tabs: `Pending | Active | All` using `DefaultTabController`.

Each company card:
- `StatusBadge`
- Company name + code
- Manager email (query `users` where `companyId` + `role == companyManager`, or store `createdBy` on company doc during signup)
- Location count
- Actions: Approve / Reject (pending) or View / Suspend (active)

"View" → `setActiveCompany` + navigate to `ManagerScreen`.

- [ ] **Step 3: Remove per-location creation from platform admin**

Location management moves to company manager dashboard only. Keep migration button for one-time legacy use.

- [ ] **Step 4: Update main.dart routing**

```dart
case AppView.platformAdmin:
  return const PlatformAdminScreen();
```

- [ ] **Step 5: Seed platform admin**

Document in commit message: set `users/{uid}.role = 'platformAdmin'` in Firestore for delegated admin.

- [ ] **Step 6: Commit**

```bash
git rm lib/screens/super_admin_screen.dart
git add lib/screens/platform_admin_screen.dart
git commit -m "feat: platform admin console with approve/reject workflow"
```

---

### Task 10: Manager dashboard — location management + shell nav

**Files:**
- Create: `lib/widgets/manager_shell.dart`
- Modify: `lib/screens/manager_screen.dart`
- Modify: `lib/screens/team_screen.dart` (wrap in shell if needed)

- [ ] **Step 1: Create ManagerShell**

Desktop (≥900px): `NavigationRail` with Dashboard, Master Sheet, Team, Prices.
Mobile: `NavigationBar` bottom tabs.

```dart
class ManagerShell extends StatelessWidget {
  const ManagerShell({super.key, required this.selected, required this.child, required this.onSelect});
  // ...
}
```

- [ ] **Step 2: Add KPI cards to manager dashboard top**

Revenue, Memberships, BA %, Active employees — reuse existing aggregation from `ManagerScreen`.

- [ ] **Step 3: Location add/edit from manager settings**

Remove site code field from location create dialog. Locations only need name + city.

- [ ] **Step 4: Commit**

```bash
git commit -m "feat: manager sidebar nav and location management without site codes"
```

**Slice 2 complete.**

---

## Slice 3 — Excel Export + Master Sheet Polish

### Task 11: XLSX export utility

**Files:**
- Create: `lib/utils/xlsx.dart`
- Modify: `lib/utils/exporter.dart`
- Create: `lib/utils/exporter_xlsx_io.dart` + `lib/utils/exporter_xlsx_web.dart`
- Modify: `pubspec.yaml`
- Create: `test/utils/xlsx_test.dart`

- [ ] **Step 1: Add excel package**

```yaml
dependencies:
  excel: ^4.0.6
```

```bash
flutter pub get
```

- [ ] **Step 2: Write failing test**

`test/utils/xlsx_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:wiggywash/models/submission.dart';
import 'package:wiggywash/utils/xlsx.dart';

void main() {
  test('buildMasterSheetXlsx returns non-empty bytes', () {
    final subs = [
      Submission(
        id: '1',
        employeeName: 'Alex',
        baGoal: 40,
        counts: const {},
        submittedAt: DateTime(2026, 3, 8),
        approved: true,
      ),
    ];
    final bytes = buildMasterSheetXlsx(
      submissions: subs,
      title: 'Wiggy Wash · Mar 8, 2026',
      viewLabel: 'Team',
    );
    expect(bytes.isNotEmpty, isTrue);
    // XLSX files start with PK zip header
    expect(bytes[0], 0x50);
    expect(bytes[1], 0x4B);
  });
}
```

- [ ] **Step 3: Implement `lib/utils/xlsx.dart`**

```dart
import 'dart:typed_data';
import 'package:excel/excel.dart';
import '../models/scorecard_config.dart';
import '../models/submission.dart';
import '../theme.dart';

Uint8List buildMasterSheetXlsx({
  required List<Submission> submissions,
  required String title,
  required String viewLabel,
}) {
  final excel = Excel.createExcel();
  final sheet = excel['Master Sheet'];
  excel.delete('Sheet1');

  var row = 0;
  sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row))
    ..value = TextCellValue('$title · $viewLabel');
  row += 2;

  final items = kLineItems;
  // Header row
  final headers = ['Name', 'Talked', ...items.map((i) => i.label), 'VIP', 'Abv Eco', 'BA %', 'Score', 'Revenue'];
  for (var c = 0; c < headers.length; c++) {
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: c, rowIndex: row))
      ..value = TextCellValue(headers[c])
      ..cellStyle = CellStyle(backgroundColorHex: ExcelColor.fromHexString('1B2A4A'),
          fontColorHex: ExcelColor.fromHexString('FFFFFF'), bold: true);
  }
  row++;

  // Point value row
  sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row))
    ..value = TextCellValue('Point value');
  sheet.cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: row))
    ..value = IntCellValue(kTalkedToPoints);
  for (var i = 0; i < items.length; i++) {
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 2 + i, rowIndex: row))
      ..value = IntCellValue(pointOf(items[i]));
  }
  row++;

  // Data rows
  for (final s in submissions) {
    var col = 0;
    void setCell(dynamic v) {
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: col++, rowIndex: row))
        ..value = v is int ? IntCellValue(v) : TextCellValue('$v');
    }
    setCell(s.employeeName);
    setCell(s.talkedTo);
    for (final i in items) {
      setCell(s.countOf(i.id));
    }
    setCell(s.totalMemberships);
    setCell(s.aboveEco);
    final ba = s.businessAverage;
    final goal = s.baGoal > 0 ? s.baGoal : 40.0;
    final baCell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: col++, rowIndex: row));
    baCell.value = TextCellValue('${ba.toStringAsFixed(0)}%');
    baCell.cellStyle = CellStyle(
      backgroundColorHex: ExcelColor.fromHexString(
        _baHex(ba, goal).substring(1),
      ),
    );
    setCell(s.overallScore);
    setCell(s.grandTotalRevenue.toStringAsFixed(0));
    row++;
  }

  final bytes = excel.encode();
  return Uint8List.fromList(bytes ?? []);
}

String _baHex(double actual, double goal) {
  final c = baColor(actual, goal);
  return '#${c.toARGB32().toRadixString(16).substring(2).toUpperCase()}';
}
```

- [ ] **Step 4: Add platform exporters**

Mirror `exporter_io.dart` / `exporter_web.dart` pattern for `.xlsx` MIME type `application/vnd.openxmlformats-officedocument.spreadsheetml.sheet`.

- [ ] **Step 5: Run test**

```bash
flutter test test/utils/xlsx_test.dart
```

Expected: PASS

- [ ] **Step 6: Commit**

```bash
git commit -m "feat: Master Sheet xlsx builder and export"
```

---

### Task 12: Master Sheet UI polish + export menu

**Files:**
- Modify: `lib/screens/master_sheet_screen.dart`

- [ ] **Step 1: Replace download IconButton with PopupMenuButton**

```dart
PopupMenuButton<_ExportFormat>(
  icon: const Icon(Icons.download_rounded),
  tooltip: 'Export',
  onSelected: (f) => _export(format: f),
  itemBuilder: (_) => [
    const PopupMenuItem(value: _ExportFormat.xlsx, child: Text('Excel (.xlsx)')),
    const PopupMenuItem(value: _ExportFormat.csv, child: Text('CSV (.csv)')),
    const PopupMenuItem(value: _ExportFormat.clipboard, child: Text('Copy to clipboard')),
  ],
)
```

- [ ] **Step 2: Add export preview bar above grid**

```dart
if (_scope.isNotEmpty)
  Padding(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
    child: Text(
      'Exporting ${_scope.length} rows · ${_rangeLabel()} · ${_view.name}',
      style: TextStyles.caption,
    ),
  ),
```

- [ ] **Step 3: Sticky header + first column**

Wrap grid in custom scroll view using `StickyHeader` pattern or split table into fixed header `Table` + scrollable body. Simpler approach: use two stacked tables — header table fixed at top, body in `SingleChildScrollView`.

- [ ] **Step 4: Row hover on web**

```dart
final hover = kIsWeb ? MouseRegion(
  onEnter: (_) => setState(() => _hoveredId = s.id),
  onExit: (_) => setState(() => _hoveredId = null),
  child: row,
) : row;
```

- [ ] **Step 5: Optional date range picker**

Add `_customRange` nullable `(DateTime, DateTime)` toggled by "Custom range" chip. Filter `_scope` when set.

- [ ] **Step 6: Manual test**

1. Open Master Sheet with approved data
2. Export `.xlsx` → open in Excel → verify headers, point row, BA colors
3. CSV fallback still works
4. Copy to clipboard pastes into Sheets

- [ ] **Step 7: Commit**

```bash
git commit -m "feat: Master Sheet export menu, sticky headers, and polish"
```

**Slice 3 complete.**

---

## Final Verification

- [ ] **Run full test suite**

```bash
flutter analyze
flutter test
```

- [ ] **Manual QA checklist (from design spec)**

| Check | Slice |
|-------|-------|
| Company code login + remember-me | 1 |
| Multi-location picker | 1 |
| Wiggy Wash data migrated | 1 |
| White landing background | 1 |
| Manager self-signup → pending | 2 |
| Platform admin approve/reject | 2 |
| Employee blocked on pending company | 2 |
| `.xlsx` opens correctly in Excel | 3 |
| Sticky headers on web | 3 |

- [ ] **Deploy**

```bash
flutter build web --release
firebase deploy --only firestore:rules,hosting
```

---

## Spec Coverage Self-Review

| Spec requirement | Task |
|-----------------|------|
| Company Firestore model | Task 1, 2 |
| Role rename platformAdmin/companyManager | Task 1 |
| Company code employee login wizard | Task 5 |
| Remember me on device | Task 2, 5 |
| Migration to wiggy-wash tenant | Task 6 |
| White landing background | Task 4 |
| Inter font | Task 4 |
| White-label CompanyHeader | Task 4, 5 |
| Manager self-signup | Task 8 |
| Pending approval screen | Task 7 |
| Platform admin console | Task 9 |
| Delegated admin (no landing password) | Task 8, 9 |
| Manager sidebar nav | Task 10 |
| Location without site codes | Task 10 |
| `.xlsx` export | Task 11, 12 |
| CSV fallback + clipboard | Task 12 |
| Sticky headers + hover | Task 12 |
| Custom date range | Task 12 |
| Firestore tenant rules | Task 3 |
| Error handling (inline messages) | Task 5, 8 |

No placeholders. All spec items mapped.

---

## Manual Setup (owner)

1. Deploy Firestore rules after Task 3.
2. Run Wiggy Wash migration (Task 6) once in production.
3. Set `users/{uid}.role = 'platformAdmin'` for delegated admin.
4. Add Firebase Auth authorized domains if new hosting URL.
