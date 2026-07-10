# Manager Invites + Sign-in Instructions Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Clear manager Google sign-in copy, plus email invite lists so company managers and platform admins can add/edit/remove managers; matching Google sign-in claims `companyManager`.

**Architecture:** Store invites under `companies/{id}/managerInvites`. On Google sign-in with no role, collection-group query by email and grant role when exactly one eligible invite exists. Team + Platform Admin share a Managers list UI. Tighten Firestore rules so users cannot self-assign `companyManager` without an invite.

**Tech Stack:** Flutter web, Cloud Firestore (collection group + rules), existing `Store` / `AppUser` / `ManagerAuthScreen` / `TeamScreen` / `PlatformAdminScreen`.

**Spec:** `docs/superpowers/specs/2026-07-09-manager-invites-design.md`

**Out of scope:** Email sending, self-serve join requests, employee Google accounts, multi-company managers.

**Commit tip:** Prefer `/usr/local/bin/git commit -F /tmp/ww-commit-msg.txt` if the default `git` rejects unknown options.

---

## File map

| File | Responsibility |
|------|----------------|
| `lib/models/manager_invite.dart` | Invite model + email normalize helper |
| `test/models/manager_invite_test.dart` | Normalize, parse, last-manager guard helpers |
| `lib/utils/manager_invite_logic.dart` | Pure eligibility / last-manager helpers (easy to unit test) |
| `test/utils/manager_invite_logic_test.dart` | Claim eligibility + last-manager tests |
| `firestore.rules` | Invites CRUD; constrain role self-write |
| `firestore.indexes.json` | Collection group index on `managerInvites.email` |
| `lib/services/store.dart` | Invite CRUD, claim on auth, create-company invite |
| `lib/screens/manager_auth_screen.dart` | Sign-in / create / not-invited copy |
| `lib/widgets/managers_section.dart` | Shared Managers list UI |
| `lib/screens/team_screen.dart` | Embed Managers section |
| `lib/screens/platform_admin_screen.dart` | Managers on company card/detail |

---

### Task 1: ManagerInvite model + email normalize

**Files:**
- Create: `lib/models/manager_invite.dart`
- Create: `test/models/manager_invite_test.dart`

- [ ] **Step 1: Write failing tests**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:wiggywash/models/manager_invite.dart';

void main() {
  test('normalizeEmail trims and lowercases', () {
    expect(ManagerInvite.normalizeEmail('  Pat@Gmail.COM '), 'pat@gmail.com');
  });

  test('normalizeEmail returns empty for blank', () {
    expect(ManagerInvite.normalizeEmail('   '), '');
  });

  test('fromMap parses fields', () {
    final m = ManagerInvite.fromMap('inv1', {
      'email': 'a@b.com',
      'displayName': 'Alex',
      'invitedByUid': 'u1',
      'invitedByEmail': 'boss@b.com',
      'claimedUid': 'u2',
    }, companyId: 'c1');
    expect(m.id, 'inv1');
    expect(m.companyId, 'c1');
    expect(m.email, 'a@b.com');
    expect(m.displayName, 'Alex');
    expect(m.claimedUid, 'u2');
    expect(m.isClaimed, isTrue);
  });
}
```

- [ ] **Step 2: Run — expect FAIL**

Run: `flutter test test/models/manager_invite_test.dart`

- [ ] **Step 3: Implement model**

```dart
class ManagerInvite {
  const ManagerInvite({
    required this.id,
    required this.companyId,
    required this.email,
    this.displayName,
    required this.invitedByUid,
    required this.invitedByEmail,
    this.createdAt,
    this.claimedUid,
  });

  final String id;
  final String companyId;
  final String email;
  final String? displayName;
  final String invitedByUid;
  final String invitedByEmail;
  final DateTime? createdAt;
  final String? claimedUid;

  bool get isClaimed => claimedUid != null && claimedUid!.isNotEmpty;

  static String normalizeEmail(String raw) => raw.trim().toLowerCase();

  Map<String, dynamic> toMap() => {
        'email': email,
        if (displayName != null && displayName!.trim().isNotEmpty)
          'displayName': displayName!.trim(),
        'invitedByUid': invitedByUid,
        'invitedByEmail': invitedByEmail,
        if (claimedUid != null) 'claimedUid': claimedUid,
      };

  factory ManagerInvite.fromMap(
    String id,
    Map<String, dynamic> data, {
    required String companyId,
  }) {
    return ManagerInvite(
      id: id,
      companyId: companyId,
      email: normalizeEmail(data['email'] as String? ?? ''),
      displayName: data['displayName'] as String?,
      invitedByUid: data['invitedByUid'] as String? ?? '',
      invitedByEmail: normalizeEmail(data['invitedByEmail'] as String? ?? ''),
      claimedUid: data['claimedUid'] as String?,
    );
  }
}
```

(Wire `createdAt` from Timestamp in Store when reading docs if needed; tests can omit.)

- [ ] **Step 4: Run — PASS**

- [ ] **Step 5: Commit**

```bash
printf '%s\n' 'feat: ManagerInvite model and email normalize' > /tmp/ww-commit-msg.txt
/usr/local/bin/git add lib/models/manager_invite.dart test/models/manager_invite_test.dart
/usr/local/bin/git commit -F /tmp/ww-commit-msg.txt
```

---

### Task 2: Pure claim / last-manager logic

**Files:**
- Create: `lib/utils/manager_invite_logic.dart`
- Create: `test/utils/manager_invite_logic_test.dart`

- [ ] **Step 1: Failing tests**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:wiggywash/models/company.dart';
import 'package:wiggywash/utils/manager_invite_logic.dart';

void main() {
  test('active company invite is eligible', () {
    expect(
      isInviteEligible(
        companyStatus: CompanyStatus.active,
        companyCreatedByUid: 'owner',
        signedInUid: 'other',
      ),
      isTrue,
    );
  });

  test('pending only eligible for creator', () {
    expect(
      isInviteEligible(
        companyStatus: CompanyStatus.pending,
        companyCreatedByUid: 'owner',
        signedInUid: 'owner',
      ),
      isTrue,
    );
    expect(
      isInviteEligible(
        companyStatus: CompanyStatus.pending,
        companyCreatedByUid: 'owner',
        signedInUid: 'other',
      ),
      isFalse,
    );
  });

  test('suspended never eligible', () {
    expect(
      isInviteEligible(
        companyStatus: CompanyStatus.suspended,
        companyCreatedByUid: 'owner',
        signedInUid: 'owner',
      ),
      isFalse,
    );
  });

  test('cannot remove last manager', () {
    expect(canRemoveManager(inviteCount: 1), isFalse);
    expect(canRemoveManager(inviteCount: 2), isTrue);
  });

  test('pickClaimTarget: zero / one / many', () {
    expect(pickClaimTarget([]), ClaimPick.none);
    expect(pickClaimTarget(['c1']), ClaimPick.one);
    expect(pickClaimTarget(['c1', 'c2']), ClaimPick.many);
  });
}
```

- [ ] **Step 2: Implement**

```dart
import '../models/company.dart';

enum ClaimPick { none, one, many }

bool isInviteEligible({
  required CompanyStatus companyStatus,
  required String? companyCreatedByUid,
  required String signedInUid,
}) {
  switch (companyStatus) {
    case CompanyStatus.active:
      return true;
    case CompanyStatus.pending:
      return companyCreatedByUid != null &&
          companyCreatedByUid == signedInUid;
    case CompanyStatus.suspended:
      return false;
  }
}

bool canRemoveManager({required int inviteCount}) => inviteCount > 1;

ClaimPick pickClaimTarget(List<String> eligibleCompanyIds) {
  if (eligibleCompanyIds.isEmpty) return ClaimPick.none;
  if (eligibleCompanyIds.length == 1) return ClaimPick.one;
  return ClaimPick.many;
}
```

- [ ] **Step 3: Tests PASS + commit**

```bash
printf '%s\n' 'feat: manager invite claim and last-manager helpers' > /tmp/ww-commit-msg.txt
/usr/local/bin/git add lib/utils/manager_invite_logic.dart test/utils/manager_invite_logic_test.dart
/usr/local/bin/git commit -F /tmp/ww-commit-msg.txt
```

---

### Task 3: Firestore index + rules

**Files:**
- Modify: `firestore.indexes.json`
- Modify: `firestore.rules`

- [ ] **Step 1: Add collection group index**

In `firestore.indexes.json` `indexes` array, add:

```json
{
  "collectionGroup": "managerInvites",
  "queryScope": "COLLECTION_GROUP",
  "fields": [
    { "fieldPath": "email", "order": "ASCENDING" }
  ]
}
```

- [ ] **Step 2: Rules for invites under company**

Inside `match /companies/{companyId} { ... }` after locations block, add:

```
match /managerInvites/{inviteId} {
  allow read: if canManageCompany(companyId);
  allow create, update, delete: if canManageCompany(companyId);
}
```

Also allow the signed-in user to **update only `claimedUid`** on an invite that matches their email (for claim). Prefer:

```
allow update: if canManageCompany(companyId)
  || (isRealUser()
      && request.auth.token.email.lower() == resource.data.email
      && request.resource.data.diff(resource.data).affectedKeys()
          .hasOnly(['claimedUid'])
      && request.resource.data.claimedUid == request.auth.uid);
```

(Adjust if `request.auth.token.email` unavailable on web — then allow claim update when `isRealUser()` and only `claimedUid` changes, relying on Store to set correctly; tighten later with Cloud Function if needed.)

- [ ] **Step 3: Constrain `users/{uid}` role self-write**

Replace overly open write if present with:

```
match /users/{uid} {
  allow read: if request.auth != null;
  allow create: if request.auth != null && request.auth.uid == uid;
  allow update: if request.auth != null && request.auth.uid == uid
    && (
      // Cannot newly assign companyManager unless platform admin
      // OR role unchanged OR role cleared
      !('role' in request.resource.data)
      || request.resource.data.role == resource.data.role
      || request.resource.data.role == null
      || isPlatformAdmin()
      || (
        request.resource.data.role == 'companyManager'
        && request.resource.data.companyId is string
        // Client must have matching invite; rules collection-group exists() is limited —
        // use: exists(/databases/.../companies/$(companyId)/managerInvites/$(inviteDocId))
        // Practical v1: allow companyManager self-set only when companyId is string
        // AND email on user matches token email; invite existence checked in app +
        // invite claimedUid update. Document residual risk in commit message.
        && request.resource.data.email == request.auth.token.email.lower()
      )
    );
  allow delete: if isPlatformAdmin();
}
```

**Important:** Shared golf `users` collection — keep create for own uid; do not break golf profile merges. Prefer minimal change: allow update of non-role fields always for own uid; when `role` changes to `companyManager`, require `isRealUser()` + email match. Platform admin can write any user via admin SDK or separate admin update path in Store using admin privileges if rules allow `isPlatformAdmin()` updates on any uid — add:

```
allow update: if isPlatformAdmin();
```

as an additional OR branch.

- [ ] **Step 4: Deploy note** — implementer runs `firebase deploy --only firestore:rules,firestore:indexes` when credentials available; otherwise commit files and note in PR.

- [ ] **Step 5: Commit**

```bash
printf '%s\n' 'feat: firestore rules and index for managerInvites' > /tmp/ww-commit-msg.txt
/usr/local/bin/git add firestore.rules firestore.indexes.json
/usr/local/bin/git commit -F /tmp/ww-commit-msg.txt
```

---

### Task 4: Store invite CRUD + claim + create-company invite

**Files:**
- Modify: `lib/services/store.dart`

- [ ] **Step 1: Helpers**

```dart
CollectionReference<Map<String, dynamic>> _managerInvitesCol(String companyId) =>
    _companiesCol.doc(companyId).collection('managerInvites');
```

- [ ] **Step 2: `listManagerInvites(String companyId)`**

```dart
Future<List<ManagerInvite>> listManagerInvites(String companyId) async {
  final snap = await _managerInvitesCol(companyId).orderBy('email').get();
  return snap.docs
      .map((d) => ManagerInvite.fromMap(d.id, d.data(), companyId: companyId))
      .toList();
}
```

- [ ] **Step 3: `addManagerInvite`**

```dart
Future<String?> addManagerInvite({
  required String companyId,
  required String email,
  String? displayName,
}) async {
  final normalized = ManagerInvite.normalizeEmail(email);
  if (normalized.isEmpty || !normalized.contains('@')) {
    return 'Enter a valid email address.';
  }
  final existing = await _managerInvitesCol(companyId)
      .where('email', isEqualTo: normalized)
      .limit(1)
      .get();
  if (existing.docs.isNotEmpty) return 'That email is already invited.';
  final me = _appUser;
  if (me == null) return 'Not signed in.';
  try {
    await _managerInvitesCol(companyId).add({
      'email': normalized,
      if (displayName != null && displayName.trim().isNotEmpty)
        'displayName': displayName.trim(),
      'invitedByUid': me.uid,
      'invitedByEmail': me.email,
      'createdAt': FieldValue.serverTimestamp(),
    });
    return null;
  } catch (e) {
    debugPrint('addManagerInvite error: $e');
    return 'Could not add manager.';
  }
}
```

- [ ] **Step 4: `updateManagerInviteDisplayName` / `removeManagerInvite`**

Remove:

1. Count invites; if `!canRemoveManager(inviteCount: n)` return `'Keep at least one manager.'`
2. Delete invite doc
3. Query `users` where `email == invite.email` and `companyId == companyId` (may need composite index, or scan company managers if few); clear role with:

```dart
await _usersCol.doc(uid).set({
  'role': FieldValue.delete(),
  'companyId': FieldValue.delete(),
}, SetOptions(merge: true));
```

- [ ] **Step 5: `tryClaimManagerInvite` after user doc ensure**

Call from `_onAuthChanged` after ensuring user doc for non-anonymous users, **before or inside** first `_onUserDoc` when role is null:

```dart
Future<String?> tryClaimManagerInvite() async {
  final user = _authUser;
  if (user == null || user.isAnonymous) return null;
  final email = ManagerInvite.normalizeEmail(user.email ?? '');
  if (email.isEmpty) return null;
  final snap = await _db
      .collectionGroup('managerInvites')
      .where('email', isEqualTo: email)
      .get();
  final eligible = <({ManagerInvite invite, Company company})>[];
  for (final doc in snap.docs) {
    final companyId = doc.reference.parent.parent?.id;
    if (companyId == null) continue;
    final companySnap = await _companiesCol.doc(companyId).get();
    if (!companySnap.exists) continue;
    final company = Company.fromDoc(companySnap);
    final invite = ManagerInvite.fromMap(
      doc.id,
      doc.data(),
      companyId: companyId,
    );
    if (isInviteEligible(
      companyStatus: company.status,
      companyCreatedByUid: company.createdByUid,
      signedInUid: user.uid,
    )) {
      eligible.add((invite: invite, company: company));
    }
  }
  switch (pickClaimTarget(eligible.map((e) => e.company.id).toList())) {
    case ClaimPick.none:
      return null; // UI shows not invited
    case ClaimPick.many:
      return 'Contact support — this email is invited to multiple companies.';
    case ClaimPick.one:
      final hit = eligible.first;
      // pick first location id for company
      final locSnap = await _companiesCol
          .doc(hit.company.id)
          .collection('locations')
          .limit(1)
          .get();
      final locationId = locSnap.docs.isEmpty ? null : locSnap.docs.first.id;
      await _usersCol.doc(user.uid).set({
        'role': UserRole.companyManager.firestoreValue,
        'companyId': hit.company.id,
        if (locationId != null) 'locationId': locationId,
        'email': email,
        'displayName': user.displayName ?? '',
      }, SetOptions(merge: true));
      await doc.reference.set({
        'claimedUid': user.uid,
      }, SetOptions(merge: true)); // use hit.invite ref
      return null;
  }
}
```

Fix the claim write to use `hit.invite` document reference from the loop. Call `tryClaimManagerInvite()` once after ensure-user in `_onAuthChanged` when not anonymous; store any multi-company error on a `String? managerClaimError` getter for the auth screen.

- [ ] **Step 6: `createPendingCompany` also writes creator invite**

In the same batch as today:

```dart
batch.set(
  companyRef.collection('managerInvites').doc(), // or email-slug id
  {
    'email': user.email,
    'displayName': user.displayName,
    'invitedByUid': user.uid,
    'invitedByEmail': user.email,
    'claimedUid': user.uid,
    'createdAt': FieldValue.serverTimestamp(),
  },
);
```

- [ ] **Step 7: Commit**

```bash
printf '%s\n' 'feat: store manager invite CRUD and Google claim' > /tmp/ww-commit-msg.txt
/usr/local/bin/git add lib/services/store.dart
/usr/local/bin/git commit -F /tmp/ww-commit-msg.txt
```

---

### Task 5: Manager auth copy + not-invited state

**Files:**
- Modify: `lib/screens/manager_auth_screen.dart`

- [ ] **Step 1: Update `_signInStep` caption**

```dart
const Text(
  'Sign in with the Google account your company invited. '
  'After your company is approved, you\'ll land on the Team Dashboard.',
  style: TextStyles.caption,
),
```

- [ ] **Step 2: Update `_createStep` caption**

```dart
const Text(
  'New car wash? Continue with Google, submit your company for approval, '
  'then wait for platform approval. You\'ll be the first manager.',
  style: TextStyles.caption,
),
```

- [ ] **Step 3: Not-invited card**

When `signedIn && appUser.role == null && !_creating`:

```dart
AppCard(
  padding: const EdgeInsets.all(32),
  child: Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      const Text('Not a manager yet', style: TextStyles.subheading),
      const SizedBox(height: 8),
      Text(
        'This Google account isn’t a manager yet. Ask a company manager to add '
        '${appUser.email} under Managers, then sign in again.\n\n'
        'Or choose Create a new company if you’re starting a new business.',
        style: TextStyles.caption,
      ),
      if (Store.instance.managerClaimError != null) ...[
        const SizedBox(height: 8),
        Text(Store.instance.managerClaimError!,
            style: TextStyles.caption.copyWith(color: AppColors.danger)),
      ],
      const SizedBox(height: 16),
      ElevatedButton(
        onPressed: () => setState(() => _creating = true),
        child: const Text('Create a new company'),
      ),
      TextButton(
        onPressed: () => Store.instance.signOutManager(),
        child: const Text('Use a different Google account'),
      ),
    ],
  ),
)
```

Adjust build() branch order: signup form → not invited → creating → sign in.

- [ ] **Step 4: Commit**

```bash
printf '%s\n' 'feat: clearer manager sign-in and not-invited copy' > /tmp/ww-commit-msg.txt
/usr/local/bin/git add lib/screens/manager_auth_screen.dart
/usr/local/bin/git commit -F /tmp/ww-commit-msg.txt
```

---

### Task 6: Shared Managers section + Team screen

**Files:**
- Create: `lib/widgets/managers_section.dart`
- Modify: `lib/screens/team_screen.dart`

- [ ] **Step 1: Widget API**

```dart
class ManagersSection extends StatefulWidget {
  const ManagersSection({super.key, required this.companyId});
  final String companyId;
  ...
}
```

Load invites in `initState` / refresh after mutations via `Store.instance.listManagerInvites`.

UI:
- Title **Managers**
- Caption: They must Continue with Google using this exact address.
- ListTile per invite: title email, subtitle displayName + Invited/Signed in
- trailing: edit (dialog for display name), delete (confirm)
- TextField + button **Add manager**

- [ ] **Step 2: Embed on Team** after company code card (or after locations):

```dart
if (company != null) ...[
  const SizedBox(height: 16),
  ManagersSection(companyId: company.id),
],
```

- [ ] **Step 3: Commit**

```bash
printf '%s\n' 'feat: Managers section on Team screen' > /tmp/ww-commit-msg.txt
/usr/local/bin/git add lib/widgets/managers_section.dart lib/screens/team_screen.dart
/usr/local/bin/git commit -F /tmp/ww-commit-msg.txt
```

---

### Task 7: Platform Admin managers list

**Files:**
- Modify: `lib/screens/platform_admin_screen.dart`

- [ ] **Step 1:** On `_CompanyCard`, below actions, if company is active or pending:

```dart
ManagersSection(companyId: c.id),
```

Or ExpansionTile “Managers” wrapping the same widget to avoid huge cards.

- [ ] **Step 2: Manual — platform admin add/remove on a company**

- [ ] **Step 3: Commit**

```bash
printf '%s\n' 'feat: manage company managers from Platform Admin' > /tmp/ww-commit-msg.txt
/usr/local/bin/git add lib/screens/platform_admin_screen.dart
/usr/local/bin/git commit -F /tmp/ww-commit-msg.txt
```

---

### Task 8: Verification

- [ ] **Step 1:** `flutter test test/models/manager_invite_test.dart test/utils/manager_invite_logic_test.dart`
- [ ] **Step 2:** `flutter analyze` on touched files
- [ ] **Step 3: Manual checklist**

| Check | Pass? |
|-------|-------|
| Sign-in copy readable | |
| Create company → pending wait; invite exists for creator | |
| Add invite → Google sign-in → dashboard | |
| Remove → not invited copy | |
| Cannot remove last manager | |
| Platform admin can add/remove | |
| Uninvited Google cannot open dashboard | |

---

## Spec coverage

| Spec item | Task |
|-----------|------|
| Sign-in / create / not-invited copy | 5 |
| Invite data model | 1 |
| Claim eligibility + last manager | 2, 4 |
| Rules + index | 3 |
| Store CRUD + create-company invite + claim | 4 |
| Team Managers UI | 6 |
| Platform Admin Managers | 7 |
| No self-serve join | 5 (instructions only) |
