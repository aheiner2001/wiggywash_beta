# Staff Task Assign + Review Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Let managers delete or assign To-do items to workers (optional due), give employees a My to-do list (manager-assigned in red on top + personal), and require a completion note/preset so managers can Review → Close or Reopen.

**Architecture:** Extend `staffRequests` with `source`, assignee, due, completion, and review fields plus statuses `assigned` / `awaitingReview` / `closed`. Add `completionPresets` (same shape as request presets). Update Store transitions, Firestore rules, manager To-do actions, employee My to-do UI, and badge counts. Client-filter `employee_personal` off manager boards.

**Tech Stack:** Flutter, Cloud Firestore, existing `Store` / `ManagerRequestsScreen` / `EmployeeRequestsScreen` / `Worker` team list.

**Spec:** `docs/superpowers/specs/2026-07-09-staff-task-assign-review-design.md`

**Out of scope:** Push/email, photos, multi-assignee, chat, employee badge, cross-location.

---

## File map

| File | Responsibility |
|------|----------------|
| `lib/models/staff_request.dart` | Statuses, source enum, new fields, legacy `completed`→`closed` |
| `lib/utils/staff_request_logic.dart` | Transitions, sort, due format, completion validation |
| `test/models/staff_request_test.dart` | Parse/source/legacy status |
| `test/utils/staff_request_logic_test.dart` | Transitions, sort, due, completion |
| `firestore.rules` | Employee create personal/ask; employee complete own assigned; completionPresets |
| `lib/services/store.dart` | Listeners + CRUD for assign/review/personal/completion presets |
| `lib/screens/manager_requests_screen.dart` | Delete, Assign, Review, Assign task, completion presets |
| `lib/screens/employee_requests_screen.dart` | My to-do + complete sheet + personal add/remove |
| `lib/widgets/manager_shell.dart` | Badge = pending + awaitingReview |

---

### Task 1: Model + pure logic (TDD)

**Files:**
- Modify: `lib/models/staff_request.dart`
- Modify: `lib/utils/staff_request_logic.dart`
- Modify: `test/models/staff_request_test.dart` (create if missing)
- Modify: `test/utils/staff_request_logic_test.dart`

- [ ] **Step 1: Write failing tests**

Append / replace coverage in `test/utils/staff_request_logic_test.dart`:

```dart
test('canTransition assign and review paths', () {
  expect(
    canTransition(StaffRequestStatus.accepted, StaffRequestStatus.assigned),
    isTrue,
  );
  expect(
    canTransition(StaffRequestStatus.accepted, StaffRequestStatus.closed),
    isTrue,
  );
  expect(
    canTransition(StaffRequestStatus.accepted, StaffRequestStatus.dismissed),
    isTrue,
  );
  expect(
    canTransition(StaffRequestStatus.assigned, StaffRequestStatus.awaitingReview),
    isTrue,
  );
  expect(
    canTransition(
      StaffRequestStatus.awaitingReview,
      StaffRequestStatus.closed,
    ),
    isTrue,
  );
  expect(
    canTransition(
      StaffRequestStatus.awaitingReview,
      StaffRequestStatus.assigned,
    ),
    isTrue,
  );
  expect(
    canTransition(StaffRequestStatus.closed, StaffRequestStatus.assigned),
    isFalse,
  );
});

test('legacy completed transition treated as closed target from accepted', () {
  // Manager self-complete uses closed; old completed enum removed from canTransition
  expect(
    canTransition(StaffRequestStatus.accepted, StaffRequestStatus.completed),
    isFalse,
  );
});

test('validateCompletionPayload requires note or preset', () {
  expect(validateCompletionPayload(note: '', presetLabel: null), isNotNull);
  expect(validateCompletionPayload(note: '  ', presetLabel: ''), isNotNull);
  expect(validateCompletionPayload(note: 'Done', presetLabel: null), isNull);
  expect(validateCompletionPayload(note: '', presetLabel: 'All good'), isNull);
});

test('sortEmployeeTodos manager-assigned first then due', () {
  final personal = StaffRequest(
    id: 'p',
    text: 'Buy milk',
    employeeName: 'Alex',
    source: StaffRequestSource.employeePersonal,
    status: StaffRequestStatus.assigned,
    assigneeProfileKey: 'alex',
  );
  final mgrLate = StaffRequest(
    id: 'm2',
    text: 'Late',
    employeeName: 'Alex',
    source: StaffRequestSource.managerAssign,
    status: StaffRequestStatus.assigned,
    assigneeProfileKey: 'alex',
    dueAt: DateTime(2026, 7, 10, 18),
  );
  final mgrSoon = StaffRequest(
    id: 'm1',
    text: 'Soon',
    employeeName: 'Alex',
    source: StaffRequestSource.managerAssign,
    status: StaffRequestStatus.assigned,
    assigneeProfileKey: 'alex',
    dueAt: DateTime(2026, 7, 10, 9),
  );
  final sorted = sortEmployeeTodos([personal, mgrLate, mgrSoon]);
  expect(sorted.map((r) => r.id).toList(), ['m1', 'm2', 'p']);
});

test('formatDueCaption empty when null', () {
  expect(formatDueCaption(null, now: DateTime(2026, 7, 9, 12)), '');
});

test('formatDueCaption today uses time only', () {
  final due = DateTime(2026, 7, 9, 15, 42);
  expect(
    formatDueCaption(due, now: DateTime(2026, 7, 9, 10)),
    'Due · 3:42 PM',
  );
});
```

In `test/models/staff_request_test.dart` (create if needed):

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:wiggywash/models/staff_request.dart';

void main() {
  test('parse maps completed to closed', () {
    expect(
      StaffRequestStatusX.parse('completed'),
      StaffRequestStatus.closed,
    );
  });

  test('fromMap reads source and dueAt', () {
    final r = StaffRequest.fromMap('1', {
      'text': 'Soap',
      'employeeName': 'Alex',
      'status': 'assigned',
      'source': 'manager_assign',
      'assigneeName': 'Alex',
      'assigneeProfileKey': 'alex',
    });
    expect(r.source, StaffRequestSource.managerAssign);
    expect(r.status, StaffRequestStatus.assigned);
    expect(r.assigneeProfileKey, 'alex');
  });
}
```

- [ ] **Step 2: Run tests — expect FAIL**

Run: `flutter test test/utils/staff_request_logic_test.dart test/models/staff_request_test.dart`  
Expected: FAIL (missing types / functions).

- [ ] **Step 3: Implement model**

Replace `lib/models/staff_request.dart` with:

```dart
import 'package:cloud_firestore/cloud_firestore.dart';

enum StaffRequestStatus {
  pending,
  accepted,
  assigned,
  awaitingReview,
  closed,
  dismissed,
  /// Legacy wire value only — parse maps to [closed]. Prefer [closed] in code.
  completed,
}

enum StaffRequestSource { employeeAsk, managerAssign, employeePersonal }

extension StaffRequestStatusX on StaffRequestStatus {
  String get firestoreValue => switch (this) {
        StaffRequestStatus.completed => 'closed',
        _ => name,
      };

  String get employeeLabel => switch (this) {
        StaffRequestStatus.pending => 'Sent',
        StaffRequestStatus.accepted => 'Accepted',
        StaffRequestStatus.assigned => 'To-do',
        StaffRequestStatus.awaitingReview => 'Waiting review',
        StaffRequestStatus.closed => 'Done',
        StaffRequestStatus.completed => 'Done',
        StaffRequestStatus.dismissed => 'Dismissed',
      };

  static StaffRequestStatus parse(String? raw) {
    if (raw == null || raw.isEmpty) return StaffRequestStatus.pending;
    if (raw == 'completed') return StaffRequestStatus.closed;
    for (final s in StaffRequestStatus.values) {
      if (s == StaffRequestStatus.completed) continue;
      if (s.name == raw) return s;
    }
    return StaffRequestStatus.pending;
  }
}

extension StaffRequestSourceX on StaffRequestSource {
  String get firestoreValue => switch (this) {
        StaffRequestSource.employeeAsk => 'employee_ask',
        StaffRequestSource.managerAssign => 'manager_assign',
        StaffRequestSource.employeePersonal => 'employee_personal',
      };

  bool get isManagerAssigned =>
      this == StaffRequestSource.managerAssign ||
      this == StaffRequestSource.employeeAsk;

  static StaffRequestSource parse(String? raw) {
    return switch (raw) {
      'manager_assign' => StaffRequestSource.managerAssign,
      'employee_personal' => StaffRequestSource.employeePersonal,
      _ => StaffRequestSource.employeeAsk,
    };
  }
}

class StaffRequest {
  const StaffRequest({
    required this.id,
    required this.text,
    required this.employeeName,
    this.employeeProfileKey,
    this.presetId,
    this.source = StaffRequestSource.employeeAsk,
    this.status = StaffRequestStatus.pending,
    this.assigneeName,
    this.assigneeProfileKey,
    this.assignedAt,
    this.assignedByUid,
    this.dueAt,
    this.completionNote,
    this.completionPresetId,
    this.completionPresetLabel,
    this.reviewedAt,
    this.reviewedByUid,
    this.createdAt,
    this.acceptedAt,
    this.acceptedByUid,
    this.completedAt,
    this.completedByUid,
    this.dismissedAt,
  });

  final String id;
  final String text;
  final String employeeName;
  final String? employeeProfileKey;
  final String? presetId;
  final StaffRequestSource source;
  final StaffRequestStatus status;
  final String? assigneeName;
  final String? assigneeProfileKey;
  final DateTime? assignedAt;
  final String? assignedByUid;
  final DateTime? dueAt;
  final String? completionNote;
  final String? completionPresetId;
  final String? completionPresetLabel;
  final DateTime? reviewedAt;
  final String? reviewedByUid;
  final DateTime? createdAt;
  final DateTime? acceptedAt;
  final String? acceptedByUid;
  final DateTime? completedAt;
  final String? completedByUid;
  final DateTime? dismissedAt;

  bool get isPersonal => source == StaffRequestSource.employeePersonal;

  Map<String, dynamic> toMap() => {
        'text': text.trim(),
        'employeeName': employeeName.trim(),
        if (employeeProfileKey != null)
          'employeeProfileKey': employeeProfileKey,
        if (presetId != null) 'presetId': presetId,
        'source': source.firestoreValue,
        'status': status.firestoreValue,
        if (assigneeName != null) 'assigneeName': assigneeName,
        if (assigneeProfileKey != null)
          'assigneeProfileKey': assigneeProfileKey,
        if (assignedAt != null) 'assignedAt': Timestamp.fromDate(assignedAt!),
        if (assignedByUid != null) 'assignedByUid': assignedByUid,
        if (dueAt != null) 'dueAt': Timestamp.fromDate(dueAt!),
        if (completionNote != null) 'completionNote': completionNote,
        if (completionPresetId != null)
          'completionPresetId': completionPresetId,
        if (completionPresetLabel != null)
          'completionPresetLabel': completionPresetLabel,
        if (reviewedAt != null) 'reviewedAt': Timestamp.fromDate(reviewedAt!),
        if (reviewedByUid != null) 'reviewedByUid': reviewedByUid,
        'createdAt': createdAt != null
            ? Timestamp.fromDate(createdAt!)
            : FieldValue.serverTimestamp(),
        if (acceptedAt != null) 'acceptedAt': Timestamp.fromDate(acceptedAt!),
        if (acceptedByUid != null) 'acceptedByUid': acceptedByUid,
        if (completedAt != null)
          'completedAt': Timestamp.fromDate(completedAt!),
        if (completedByUid != null) 'completedByUid': completedByUid,
        if (dismissedAt != null)
          'dismissedAt': Timestamp.fromDate(dismissedAt!),
      };

  factory StaffRequest.fromMap(String id, Map<String, dynamic> data) {
    DateTime? asDate(dynamic v) => v is Timestamp ? v.toDate() : null;
    return StaffRequest(
      id: id,
      text: (data['text'] as String? ?? '').trim(),
      employeeName: (data['employeeName'] as String? ?? '').trim(),
      employeeProfileKey: data['employeeProfileKey'] as String?,
      presetId: data['presetId'] as String?,
      source: StaffRequestSourceX.parse(data['source'] as String?),
      status: StaffRequestStatusX.parse(data['status'] as String?),
      assigneeName: data['assigneeName'] as String?,
      assigneeProfileKey: data['assigneeProfileKey'] as String?,
      assignedAt: asDate(data['assignedAt']),
      assignedByUid: data['assignedByUid'] as String?,
      dueAt: asDate(data['dueAt']),
      completionNote: data['completionNote'] as String?,
      completionPresetId: data['completionPresetId'] as String?,
      completionPresetLabel: data['completionPresetLabel'] as String?,
      reviewedAt: asDate(data['reviewedAt']),
      reviewedByUid: data['reviewedByUid'] as String?,
      createdAt: asDate(data['createdAt']),
      acceptedAt: asDate(data['acceptedAt']),
      acceptedByUid: data['acceptedByUid'] as String?,
      completedAt: asDate(data['completedAt']),
      completedByUid: data['completedByUid'] as String?,
      dismissedAt: asDate(data['dismissedAt']),
    );
  }

  factory StaffRequest.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) =>
      StaffRequest.fromMap(doc.id, doc.data() ?? {});
}
```

- [ ] **Step 4: Implement logic helpers**

Update `lib/utils/staff_request_logic.dart` — keep existing helpers; replace `canTransition` and add:

```dart
const kCompletionPresetCap = 10;

final _dueDate = DateFormat('MMM d · h:mm a');

bool canTransition(StaffRequestStatus from, StaffRequestStatus to) {
  return switch ((from, to)) {
    (StaffRequestStatus.pending, StaffRequestStatus.accepted) => true,
    (StaffRequestStatus.pending, StaffRequestStatus.dismissed) => true,
    (StaffRequestStatus.accepted, StaffRequestStatus.assigned) => true,
    (StaffRequestStatus.accepted, StaffRequestStatus.closed) => true,
    (StaffRequestStatus.accepted, StaffRequestStatus.dismissed) => true,
    (StaffRequestStatus.assigned, StaffRequestStatus.awaitingReview) => true,
    (StaffRequestStatus.assigned, StaffRequestStatus.dismissed) => true,
    (StaffRequestStatus.awaitingReview, StaffRequestStatus.closed) => true,
    (StaffRequestStatus.awaitingReview, StaffRequestStatus.assigned) => true,
    _ => false,
  };
}

String? validateCompletionPayload({
  required String note,
  String? presetLabel,
}) {
  final n = note.trim();
  final p = presetLabel?.trim() ?? '';
  if (n.isEmpty && p.isEmpty) {
    return 'Add a short note or pick a completion preset.';
  }
  if (n.length > kStaffRequestMaxLen) {
    return 'Keep it under $kStaffRequestMaxLen characters.';
  }
  return null;
}

/// Manager-assigned (non-personal) first, then by dueAt ascending (nulls last),
/// then createdAt descending.
List<StaffRequest> sortEmployeeTodos(List<StaffRequest> items) {
  final copy = [...items];
  copy.sort((a, b) {
    final aMgr = !a.isPersonal;
    final bMgr = !b.isPersonal;
    if (aMgr != bMgr) return aMgr ? -1 : 1;
    final ad = a.dueAt;
    final bd = b.dueAt;
    if (ad != null && bd != null) {
      final c = ad.compareTo(bd);
      if (c != 0) return c;
    } else if (ad != null) {
      return -1;
    } else if (bd != null) {
      return 1;
    }
    final at = a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
    final bt = b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
    return bt.compareTo(at);
  });
  return copy;
}

String formatDueCaption(DateTime? dueAt, {DateTime? now}) {
  if (dueAt == null) return '';
  final n = now ?? DateTime.now();
  final sameDay =
      dueAt.year == n.year && dueAt.month == n.month && dueAt.day == n.day;
  if (sameDay) {
    return 'Due · ${formatStaffRequestTime(dueAt)}';
  }
  return 'Due · ${_dueDate.format(dueAt)}';
}

bool isManagerBoardVisible(StaffRequest r) {
  if (r.source == StaffRequestSource.employeePersonal) return false;
  return true;
}
```

Fix any existing tests that still expect `canTransition(..., completed)` — change to `closed`.

Update `employeeRequestCaption` labels via status `employeeLabel` (already).

- [ ] **Step 5: Run tests — expect PASS**

Run: `flutter test test/utils/staff_request_logic_test.dart test/models/staff_request_test.dart`  
Expected: All tests passed.

- [ ] **Step 6: Commit**

```bash
git add lib/models/staff_request.dart lib/utils/staff_request_logic.dart \
  test/models/staff_request_test.dart test/utils/staff_request_logic_test.dart
git commit -m "$(cat <<'EOF'
feat: extend staff request model for assign and review

EOF
)"
```

---

### Task 2: Firestore rules

**Files:**
- Modify: `firestore.rules`

- [ ] **Step 1: Replace staffRequests + add completionPresets**

Inside `match /locations/{locationId}` under companies (same block as today):

```
match /requestPresets/{presetId} {
  allow read: if signedIn();
  allow create, update, delete: if canManageCompany(companyId);
}
match /completionPresets/{presetId} {
  allow read: if signedIn();
  allow create, update, delete: if canManageCompany(companyId);
}
match /staffRequests/{requestId} {
  allow read: if signedIn();

  allow create: if canManageCompany(companyId)
    || (signedIn()
        && request.resource.data.text is string
        && request.resource.data.text.size() > 0
        && request.resource.data.text.size() <= 120
        && request.resource.data.employeeName is string
        && request.resource.data.employeeName.size() > 0
        && (
          (request.resource.data.status == 'pending'
            && request.resource.data.source == 'employee_ask')
          || (request.resource.data.status == 'assigned'
            && request.resource.data.source == 'employee_personal')
        ));

  allow update: if canManageCompany(companyId)
    || (signedIn()
        && resource.data.status == 'assigned'
        && request.resource.data.status == 'awaitingReview'
        && resource.data.assigneeProfileKey is string
        && request.resource.data.assigneeProfileKey
            == resource.data.assigneeProfileKey
        && request.resource.data.diff(resource.data).affectedKeys()
            .hasOnly([
              'status',
              'completionNote',
              'completionPresetId',
              'completionPresetLabel',
              'completedAt',
              'completedByUid'
            ]));

  allow delete: if canManageCompany(companyId)
    || (signedIn()
        && resource.data.source == 'employee_personal'
        && resource.data.status == 'assigned'
        && resource.data.assigneeProfileKey is string);
}
```

Note: employee personal delete is allowed for signed-in users; Store will only call delete for the signed-in employee’s own key (client trust + anonymous auth limitation same as existing asks). If `diff().hasOnly` is too strict for FieldValue timestamps, widen affectedKeys to include only the listed fields (Firestore still requires those keys to be the only ones changed).

- [ ] **Step 2: Commit**

```bash
git add firestore.rules
git commit -m "$(cat <<'EOF'
feat: firestore rules for assign, review, and personal todos

EOF
)"
```

Remind in commit body / later Task 7: deploy with `firebase deploy --only firestore:rules`.

---

### Task 3: Store methods + listeners

**Files:**
- Modify: `lib/services/store.dart`

- [ ] **Step 1: Add completion preset state**

Near request preset fields:

```dart
StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _completionPresetsSub;
List<RequestPreset> _completionPresets = [];

List<RequestPreset> get completionPresets =>
    List.unmodifiable(_completionPresets);

int get pendingStaffRequestCount => _staffRequests.where((r) {
      if (!isManagerBoardVisible(r)) return false;
      return r.status == StaffRequestStatus.pending ||
          r.status == StaffRequestStatus.awaitingReview;
    }).length;
```

Import `isManagerBoardVisible` from staff_request_logic.

- [ ] **Step 2: Listen + clear**

In the location listen setup (next to requestPresets):

```dart
_completionPresetsSub?.cancel();
_completionPresetsSub = base
    .collection('completionPresets')
    .orderBy('sortOrder')
    .snapshots()
    .listen((snap) {
  _completionPresets = snap.docs.map(RequestPreset.fromDoc).toList();
  notifyListeners();
}, onError: (Object e) => debugPrint('completionPresets listen error: $e'));
```

On teardown, cancel `_completionPresetsSub` and clear `_completionPresets`.

- [ ] **Step 3: CRUD completion presets**

Mirror `addRequestPreset` / `updateRequestPreset` / `deleteRequestPreset` against `completionPresets` with `kCompletionPresetCap`.

- [ ] **Step 4: Update createStaffRequest**

When creating employee asks, set `'source': StaffRequestSource.employeeAsk.firestoreValue`.

- [ ] **Step 5: Replace transitions + add APIs**

Update `_transitionStaffRequest` switch for new statuses:

```dart
case StaffRequestStatus.closed:
  data['completedAt'] = FieldValue.serverTimestamp();
  if (uid != null) data['completedByUid'] = uid;
  data['reviewedAt'] = FieldValue.serverTimestamp();
  if (uid != null) data['reviewedByUid'] = uid;
  break;
case StaffRequestStatus.assigned:
  // used by reopen — clear review stamps
  data['reviewedAt'] = FieldValue.delete();
  data['reviewedByUid'] = FieldValue.delete();
  break;
case StaffRequestStatus.awaitingReview:
  data['completedAt'] = FieldValue.serverTimestamp();
  if (uid != null) data['completedByUid'] = uid;
  break;
case StaffRequestStatus.dismissed:
  data['dismissedAt'] = FieldValue.serverTimestamp();
  break;
case StaffRequestStatus.accepted:
  data['acceptedAt'] = FieldValue.serverTimestamp();
  if (uid != null) data['acceptedByUid'] = uid;
  break;
case StaffRequestStatus.pending:
case StaffRequestStatus.completed:
  break;
```

Change:

```dart
Future<String?> completeStaffRequest(String id) =>
    _transitionStaffRequest(id, StaffRequestStatus.closed);
```

Add:

```dart
Future<String?> assignStaffRequest({
  required String id,
  required String assigneeName,
  DateTime? dueAt,
}) async {
  final loc = _locationRef;
  if (loc == null) return 'No active location.';
  final name = assigneeName.trim();
  if (name.isEmpty) return 'Pick a team member.';
  StaffRequest? current;
  for (final r in _staffRequests) {
    if (r.id == id) current = r;
  }
  if (current == null) return 'Request not found.';
  if (!canTransition(current.status, StaffRequestStatus.assigned)) {
    return 'That status change is not allowed.';
  }
  final uid = _appUser?.uid;
  try {
    final data = <String, dynamic>{
      'status': StaffRequestStatus.assigned.firestoreValue,
      'assigneeName': name,
      'assigneeProfileKey': staffRequestProfileKey(name),
      'assignedAt': FieldValue.serverTimestamp(),
      if (uid != null) 'assignedByUid': uid,
      if (current.source == StaffRequestSource.employeeAsk)
        'source': StaffRequestSource.employeeAsk.firestoreValue,
    };
    if (dueAt != null) {
      data['dueAt'] = Timestamp.fromDate(dueAt);
    } else {
      data['dueAt'] = FieldValue.delete();
    }
    await loc.collection('staffRequests').doc(id).set(data, SetOptions(merge: true));
    return null;
  } catch (e) {
    debugPrint('assignStaffRequest error: $e');
    return mapFirestoreUserError(e, fallback: 'Could not assign.');
  }
}

Future<String?> createAssignedTask({
  required String text,
  required String assigneeName,
  DateTime? dueAt,
}) async {
  final err = validateRequestText(text);
  if (err != null) return err;
  final loc = _locationRef;
  if (loc == null) return 'No active location.';
  final name = assigneeName.trim();
  if (name.isEmpty) return 'Pick a team member.';
  final uid = _appUser?.uid;
  try {
    await loc.collection('staffRequests').add({
      'text': text.trim(),
      'employeeName': name,
      'employeeProfileKey': staffRequestProfileKey(name),
      'assigneeName': name,
      'assigneeProfileKey': staffRequestProfileKey(name),
      'source': StaffRequestSource.managerAssign.firestoreValue,
      'status': StaffRequestStatus.assigned.firestoreValue,
      'assignedAt': FieldValue.serverTimestamp(),
      if (uid != null) 'assignedByUid': uid,
      if (dueAt != null) 'dueAt': Timestamp.fromDate(dueAt),
      'createdAt': FieldValue.serverTimestamp(),
    });
    return null;
  } catch (e) {
    debugPrint('createAssignedTask error: $e');
    return mapFirestoreUserError(e, fallback: 'Could not create task.');
  }
}

Future<String?> createPersonalTodo(String text) async {
  final err = validateRequestText(text);
  if (err != null) return err;
  final loc = _locationRef;
  if (loc == null) return 'No active location.';
  final name = profile?.name.trim() ?? '';
  if (name.isEmpty) return 'Sign in as an employee first.';
  final key = staffRequestProfileKey(name);
  try {
    await loc.collection('staffRequests').add({
      'text': text.trim(),
      'employeeName': name,
      'employeeProfileKey': key,
      'assigneeName': name,
      'assigneeProfileKey': key,
      'source': StaffRequestSource.employeePersonal.firestoreValue,
      'status': StaffRequestStatus.assigned.firestoreValue,
      'assignedAt': FieldValue.serverTimestamp(),
      'createdAt': FieldValue.serverTimestamp(),
    });
    return null;
  } catch (e) {
    debugPrint('createPersonalTodo error: $e');
    return mapFirestoreUserError(e, fallback: 'Could not add to-do.');
  }
}

Future<String?> deletePersonalTodo(String id) async {
  final loc = _locationRef;
  if (loc == null) return 'No active location.';
  StaffRequest? current;
  for (final r in _staffRequests) {
    if (r.id == id) current = r;
  }
  if (current == null) return 'Not found.';
  if (current.source != StaffRequestSource.employeePersonal) {
    return 'Only personal to-dos can be removed this way.';
  }
  try {
    await loc.collection('staffRequests').doc(id).delete();
    return null;
  } catch (e) {
    debugPrint('deletePersonalTodo error: $e');
    return mapFirestoreUserError(e, fallback: 'Could not remove to-do.');
  }
}

Future<String?> submitAssignedCompletion({
  required String id,
  required String note,
  String? completionPresetId,
  String? completionPresetLabel,
}) async {
  final err = validateCompletionPayload(
    note: note,
    presetLabel: completionPresetLabel,
  );
  if (err != null) return err;
  final loc = _locationRef;
  if (loc == null) return 'No active location.';
  StaffRequest? current;
  for (final r in _staffRequests) {
    if (r.id == id) current = r;
  }
  if (current == null) return 'Not found.';
  if (current.isPersonal) {
    return 'Personal to-dos are removed, not reviewed.';
  }
  if (!canTransition(current.status, StaffRequestStatus.awaitingReview)) {
    return 'That status change is not allowed.';
  }
  final uid = _appUser?.uid;
  try {
    await loc.collection('staffRequests').doc(id).set({
      'status': StaffRequestStatus.awaitingReview.firestoreValue,
      'completionNote': note.trim(),
      if (completionPresetId != null)
        'completionPresetId': completionPresetId,
      if (completionPresetLabel != null)
        'completionPresetLabel': completionPresetLabel.trim(),
      'completedAt': FieldValue.serverTimestamp(),
      if (uid != null) 'completedByUid': uid,
    }, SetOptions(merge: true));
    return null;
  } catch (e) {
    debugPrint('submitAssignedCompletion error: $e');
    return mapFirestoreUserError(e, fallback: 'Could not submit.');
  }
}

Future<String?> closeStaffRequest(String id) =>
    _transitionStaffRequest(id, StaffRequestStatus.closed);

Future<String?> reopenStaffRequest(String id) =>
    _transitionStaffRequest(id, StaffRequestStatus.assigned);
```

Keep `dismissStaffRequest` for Delete on to-do.

- [ ] **Step 6: Analyze**

Run: `dart analyze lib/services/store.dart lib/models/staff_request.dart`  
Expected: No issues. Fix any switch exhaustiveness on `StaffRequestStatus`.

- [ ] **Step 7: Commit**

```bash
git add lib/services/store.dart
git commit -m "$(cat <<'EOF'
feat: store APIs for assign, review, and personal todos

EOF
)"
```

---

### Task 4: Manager Requests UI

**Files:**
- Modify: `lib/screens/manager_requests_screen.dart`

- [ ] **Step 1: Filter lists**

In `build`, when computing incoming/todos:

```dart
final visible = all.where(isManagerBoardVisible).toList();
final incoming = _sortedIncoming(
  visible.where((r) => r.status == StaffRequestStatus.pending).toList(),
);
final todos = visible
    .where(
      (r) =>
          r.status == StaffRequestStatus.accepted ||
          r.status == StaffRequestStatus.awaitingReview,
    )
    .toList();
```

- [ ] **Step 2: Replace to-do actions**

For `accepted`:

```dart
List<Widget> _todoActions(StaffRequest r) {
  if (r.status == StaffRequestStatus.awaitingReview) {
    return [
      FilledButton(
        onPressed: _busy ? null : () => _openReview(r),
        child: const Text('Review'),
      ),
    ];
  }
  return [
    TextButton(
      onPressed: _busy
          ? null
          : () => _run(() => Store.instance.dismissStaffRequest(r.id)),
      child: const Text('Delete'),
    ),
    TextButton(
      onPressed: _busy ? null : () => _openAssign(r),
      child: const Text('Assign to…'),
    ),
    FilledButton(
      onPressed: _busy
          ? null
          : () => _run(
                () => Store.instance.completeStaffRequest(r.id),
                ok: 'Closed',
              ),
      child: const Text('Mark complete'),
    ),
  ];
}
```

On awaitingReview tiles, show a small “Needs review” caption under the name line (extend `_RequestTile` with optional `badge` string, or prepend to subtitle).

- [ ] **Step 3: Assign dialog**

```dart
Future<void> _openAssign(StaffRequest r) async {
  final workers = Store.instance.workers;
  if (workers.isEmpty) {
    showStoreMessage(context, 'Add team members first', error: true);
    return;
  }
  String? selected = workers.first.name;
  DateTime? due;
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setLocal) => AlertDialog(
        title: const Text('Assign to…'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DropdownButtonFormField<String>(
              value: selected,
              items: [
                for (final w in workers)
                  DropdownMenuItem(value: w.name, child: Text(w.name)),
              ],
              onChanged: (v) => setLocal(() => selected = v),
              decoration: const InputDecoration(labelText: 'Employee'),
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: () async {
                final now = DateTime.now();
                final d = await showDatePicker(
                  context: ctx,
                  firstDate: now,
                  lastDate: now.add(const Duration(days: 365)),
                  initialDate: due ?? now,
                );
                if (d == null || !ctx.mounted) return;
                final t = await showTimePicker(
                  context: ctx,
                  initialTime: TimeOfDay.fromDateTime(due ?? now),
                );
                if (t == null) return;
                setLocal(() {
                  due = DateTime(d.year, d.month, d.day, t.hour, t.minute);
                });
              },
              child: Text(
                due == null
                    ? 'Optional: set due time'
                    : 'Due ${DateFormat('MMM d · h:mm a').format(due!)}',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Assign'),
          ),
        ],
      ),
    ),
  );
  if (ok != true || selected == null || !mounted) return;
  await _run(
    () => Store.instance.assignStaffRequest(
      id: r.id,
      assigneeName: selected!,
      dueAt: due,
    ),
    ok: 'Assigned',
  );
}
```

- [ ] **Step 4: Review dialog**

```dart
Future<void> _openReview(StaffRequest r) async {
  final note = (r.completionNote ?? '').trim();
  final preset = (r.completionPresetLabel ?? '').trim();
  final body = [
    if (preset.isNotEmpty) 'Preset: $preset',
    if (note.isNotEmpty) note,
  ].join('\n');
  final action = await showDialog<String>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Review completion'),
      content: Text(body.isEmpty ? '(No note)' : body),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, 'reopen'),
          child: const Text('Reopen'),
        ),
        ElevatedButton(
          onPressed: () => Navigator.pop(ctx, 'close'),
          child: const Text('Close'),
        ),
      ],
    ),
  );
  if (action == null || !mounted) return;
  if (action == 'close') {
    await _run(() => Store.instance.closeStaffRequest(r.id), ok: 'Closed');
  } else if (action == 'reopen') {
    await _run(() => Store.instance.reopenStaffRequest(r.id), ok: 'Reopened');
  }
}
```

- [ ] **Step 5: Assign task entry + completion presets UI**

AppBar: add second action or change menu — keep **Add New Request** for request presets; add **Assign task** `TextButton.icon` that opens dialog (text field + worker dropdown + optional due) calling `createAssignedTask`.

In presets section bottom, add a second strip **Completion presets** reusing the same chip/add pattern but calling `addCompletionPreset` / `updateCompletionPreset` / `deleteCompletionPreset` and listing `Store.instance.completionPresets`. Cap messaging uses `kCompletionPresetCap`.

Show due on tiles when `r.dueAt != null` using `formatDueCaption(r.dueAt)`.

- [ ] **Step 6: Analyze + commit**

Run: `dart analyze lib/screens/manager_requests_screen.dart`  
Expected: No issues.

```bash
git add lib/screens/manager_requests_screen.dart
git commit -m "$(cat <<'EOF'
feat: manager assign, delete, and review on Requests to-do

EOF
)"
```

---

### Task 5: Employee Requests UI (My to-do)

**Files:**
- Modify: `lib/screens/employee_requests_screen.dart`

- [ ] **Step 1: Split lists in build**

```dart
final key = staffRequestProfileKey(name);
final mineAsks = Store.instance.staffRequests.where((r) {
  if (r.source != StaffRequestSource.employeeAsk) return false;
  if (r.status == StaffRequestStatus.dismissed) return false;
  if (r.status == StaffRequestStatus.assigned) return false;
  if (r.status == StaffRequestStatus.awaitingReview) return false;
  if (_clearedIds.contains(r.id)) return false;
  // existing name/key match…
}).toList();

final todos = sortEmployeeTodos(
  Store.instance.staffRequests.where((r) {
    if (r.status != StaffRequestStatus.assigned) return false;
    final aKey = r.assigneeProfileKey ?? r.employeeProfileKey ?? '';
    return aKey == key ||
        r.employeeName.trim().toLowerCase() == key;
  }).toList(),
);
```

- [ ] **Step 2: My to-do section (above Quick requests)**

Board panel titled **My to-do** with count badge.

- Empty: inbox empty panel “No open to-dos”.
- For each todo tile:
  - If `!r.isPersonal`: red left border (`Border(left: BorderSide(color: Color(0xFFC62828), width: 4))`), text bold, due caption if any, **Complete** button → `_openComplete(r)`.
  - If personal: normal white tile, **Remove** → `deletePersonalTodo`.
- Below list: text field + **Add** calling `createPersonalTodo`.

- [ ] **Step 3: Complete sheet**

```dart
Future<void> _openComplete(StaffRequest r) async {
  final note = TextEditingController();
  String? presetId;
  String? presetLabel;
  final presets = Store.instance.completionPresets;
  final ok = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    builder: (ctx) => Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 16,
        bottom: MediaQuery.of(ctx).viewInsets.bottom + 16,
      ),
      child: StatefulBuilder(
        builder: (ctx, setLocal) => Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('Mark complete', style: TextStyles.subheading),
            const SizedBox(height: 8),
            if (presets.isNotEmpty)
              Wrap(
                spacing: 8,
                children: [
                  for (final p in presets)
                    ChoiceChip(
                      label: Text(p.label),
                      selected: presetId == p.id,
                      onSelected: (_) => setLocal(() {
                        presetId = p.id;
                        presetLabel = p.label;
                      }),
                    ),
                ],
              ),
            TextField(
              controller: note,
              maxLength: kStaffRequestMaxLen,
              decoration: const InputDecoration(
                labelText: 'Note (optional if preset selected)',
              ),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Submit'),
            ),
          ],
        ),
      ),
    ),
  );
  final text = note.text;
  note.dispose();
  if (ok != true || !mounted) return;
  setState(() => _busy = true);
  final err = await Store.instance.submitAssignedCompletion(
    id: r.id,
    note: text,
    completionPresetId: presetId,
    completionPresetLabel: presetLabel,
  );
  if (!mounted) return;
  setState(() => _busy = false);
  if (err != null) {
    showStoreMessage(context, err, error: true);
  } else {
    showStoreMessage(context, 'Submitted for review');
  }
}
```

- [ ] **Step 4: Keep Quick requests + Your requests (asks only)**

Your requests list uses `mineAsks`; clear finished applies to `closed`/`completed` asks as today (`StaffRequestStatus.closed`).

Update finished filter:

```dart
.where((r) =>
    r.status == StaffRequestStatus.closed ||
    r.status == StaffRequestStatus.completed)
```

- [ ] **Step 5: Analyze + commit**

Run: `dart analyze lib/screens/employee_requests_screen.dart`  
Expected: No issues.

```bash
git add lib/screens/employee_requests_screen.dart
git commit -m "$(cat <<'EOF'
feat: employee My to-do with complete note and personal items

EOF
)"
```

---

### Task 6: Badge (already in Store) + shell smoke

**Files:**
- Modify: `lib/widgets/manager_shell.dart` only if it hardcodes pending-only logic (it uses `pendingStaffRequestCount` — Task 3 already updates the getter).

- [ ] **Step 1: Confirm shell uses getter**

No code change if `_requestsIcon` already uses `Store.instance.pendingStaffRequestCount`.

- [ ] **Step 2: Commit only if a comment/doc tweak needed — otherwise skip**

---

### Task 7: Verify + deploy rules + push

**Files:** none new

- [ ] **Step 1: Analyze all touched**

```bash
dart analyze \
  lib/models/staff_request.dart \
  lib/utils/staff_request_logic.dart \
  lib/services/store.dart \
  lib/screens/manager_requests_screen.dart \
  lib/screens/employee_requests_screen.dart \
  lib/widgets/manager_shell.dart
```

Expected: No issues.

- [ ] **Step 2: Tests**

```bash
flutter test test/utils/staff_request_logic_test.dart test/models/staff_request_test.dart
```

Expected: All passed.

- [ ] **Step 3: Deploy rules**

```bash
firebase deploy --only firestore:rules
```

- [ ] **Step 4: Manual checklist**

- [ ] Incoming ask → Accept → Delete removes from to-do
- [ ] Accept → Assign to worker + due → employee sees red top item with due
- [ ] Employee Complete with note → manager Review → Close
- [ ] Review → Reopen → back on employee list
- [ ] Manager Assign task from AppBar
- [ ] Employee personal add/remove; not on manager board
- [ ] Manager Mark complete on accepted closes without review
- [ ] Badge counts pending + awaitingReview

- [ ] **Step 5: Push**

```bash
git push origin HEAD
```

---

## Spec coverage (self-review)

| Spec requirement | Task |
|------------------|------|
| Delete + Assign on manager to-do | Task 4 |
| Optional due | Task 3–4 |
| Employee My to-do + red manager items | Task 5 |
| Completion note/preset → awaitingReview | Task 1, 3, 5 |
| Review Close / Reopen | Task 3–4 |
| Personal todos hidden from manager UI | Task 1 `isManagerBoardVisible`, Task 4 |
| Manager self-complete → closed | Task 3 |
| Completion presets | Task 2–4 |
| Badge pending + awaitingReview | Task 3 |
| Rules for employee complete/personal | Task 2 |
| Legacy completed → closed | Task 1 |

No placeholders. Method names consistent: `assignStaffRequest`, `submitAssignedCompletion`, `closeStaffRequest`, `reopenStaffRequest`, `createPersonalTodo`, `createAssignedTask`.
