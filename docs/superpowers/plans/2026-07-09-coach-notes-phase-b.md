# Coach Notes (Phase B) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Let managers leave a single ≤280-character coach note on a submission; employees see it on Reports; employee Save never wipes the note.

**Architecture:** Extend `Submission` with `coachNote` / `coachNoteBy` / `coachNoteAt`. Persist via Store `_toDoc` / `_fromDoc` and a dedicated merge update (and optional fields on `updateSubmission`). Write UI in submission editor + pending card compose; read UI on personal Reports; glance icon on manager pending/employee cards. Team Reports must not surface other people’s notes.

**Tech Stack:** Flutter web, Firestore merge writes, existing `Submission` / `Store` / `showSubmissionEditor` / `ReportsScreen` / Master Sheet pending UI.

**Spec:** `docs/superpowers/specs/2026-07-09-front-of-house-coach-notes-design.md` (Phase B only)

**Prerequisite:** Phase A may ship first; this plan does not depend on density/motion tokens.

**Out of scope:** Threads, push/email, notes on live scorecard tally, Firestore rules rewrite beyond app-level preserve.

---

## File map

| File | Responsibility |
|------|----------------|
| `lib/models/submission.dart` | Coach fields + JSON + `copyWith` + clear helper |
| `test/models/submission_coach_note_test.dart` | Round-trip + clear + preserve semantics |
| `lib/services/store.dart` | Serialize coach fields; `setCoachNote`; preserve on employee `addSubmission` |
| `lib/widgets/submission_editor.dart` | Coach note field + return value |
| `lib/screens/master_sheet_screen.dart` | Pending compose + note icon; wire updates |
| `lib/screens/reports_screen.dart` | Personal coach banner; hide notes in team view |
| `lib/screens/scorecard_screen.dart` | Employee Save merges existing coach fields |
| `lib/screens/manager_screen.dart` | Optional note icon on `_EmployeeCard` when any sub has note |

---

### Task 1: Submission model + unit tests

**Files:**
- Modify: `lib/models/submission.dart`
- Create: `test/models/submission_coach_note_test.dart`

- [ ] **Step 1: Write failing tests**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:wiggywash/models/submission.dart';

Submission base({
  String? coachNote,
  String? coachNoteBy,
  DateTime? coachNoteAt,
}) {
  return Submission(
    id: 's1',
    employeeName: 'Alex',
    baGoal: 40,
    counts: const {'vip': 1},
    submittedAt: DateTime(2026, 7, 9),
    talkedTo: 10,
    coachNote: coachNote,
    coachNoteBy: coachNoteBy,
    coachNoteAt: coachNoteAt,
  );
}

void main() {
  test('JSON round-trip with coach fields', () {
    final at = DateTime.utc(2026, 7, 9, 18);
    final s = base(
      coachNote: 'Great VIP push',
      coachNoteBy: 'Pat',
      coachNoteAt: at,
    );
    final again = Submission.fromJson(s.toJson());
    expect(again.coachNote, 'Great VIP push');
    expect(again.coachNoteBy, 'Pat');
    expect(again.coachNoteAt, at);
  });

  test('JSON omits null coach fields', () {
    final json = base().toJson();
    expect(json.containsKey('coachNote'), isFalse);
    expect(json.containsKey('coachNoteBy'), isFalse);
    expect(json.containsKey('coachNoteAt'), isFalse);
  });

  test('normalizeCoachNote clears whitespace', () {
    expect(Submission.normalizeCoachNote('  '), isNull);
    expect(Submission.normalizeCoachNote(' hi '), 'hi');
  });

  test('copyWith can clear coach note', () {
    final s = base(
      coachNote: 'x',
      coachNoteBy: 'Pat',
      coachNoteAt: DateTime.utc(2026, 7, 9),
    );
    final cleared = s.copyWith(clearCoachNote: true);
    expect(cleared.coachNote, isNull);
    expect(cleared.coachNoteBy, isNull);
    expect(cleared.coachNoteAt, isNull);
  });

  test('hasCoachNote', () {
    expect(base(coachNote: 'x').hasCoachNote, isTrue);
    expect(base(coachNote: '  ').hasCoachNote, isFalse);
    expect(base().hasCoachNote, isFalse);
  });
}
```

- [ ] **Step 2: Run — expect FAIL**

Run: `flutter test test/models/submission_coach_note_test.dart`

- [ ] **Step 3: Extend `Submission`**

Add fields to constructor and class:

```dart
this.coachNote,
this.coachNoteBy,
this.coachNoteAt,

static const maxCoachNoteLength = 280;

final String? coachNote;
final String? coachNoteBy;
final DateTime? coachNoteAt;

bool get hasCoachNote {
  final n = coachNote?.trim();
  return n != null && n.isNotEmpty;
}

static String? normalizeCoachNote(String? raw) {
  if (raw == null) return null;
  final t = raw.trim();
  if (t.isEmpty) return null;
  return t;
}
```

Update `copyWith` to accept the new fields and `bool clearCoachNote = false`. When `clearCoachNote`, force all three coach fields to null; else use `?? this.*` pattern.

Update `toJson` / `fromJson` mirroring `editedBy` / `editedAt` (ISO8601 for `coachNoteAt`).

- [ ] **Step 4: Run tests — PASS**

- [ ] **Step 5: Commit**

```bash
git add lib/models/submission.dart test/models/submission_coach_note_test.dart
git commit -m "feat: Submission coach note fields and JSON"
```

---

### Task 2: Store serialize + setCoachNote + preserve on full write

**Files:**
- Modify: `lib/services/store.dart`

- [ ] **Step 1: `_fromDoc` / `_toDoc`**

In `_fromDoc`, after `editedAt`:

```dart
final coachNoteAtTs = data['coachNoteAt'];
...
coachNote: data['coachNote'] as String?,
coachNoteBy: data['coachNoteBy'] as String?,
coachNoteAt: coachNoteAtTs is Timestamp
    ? coachNoteAtTs.toDate()
    : null,
```

In `_toDoc`:

```dart
if (s.coachNote != null) 'coachNote': s.coachNote,
if (s.coachNoteBy != null) 'coachNoteBy': s.coachNoteBy,
if (s.coachNoteAt != null)
  'coachNoteAt': Timestamp.fromDate(s.coachNoteAt!),
```

**Critical for clears:** when writing a full document via `addSubmission` / `.set(_toDoc)`, include explicit deletes if you need to clear — prefer Task’s `setCoachNote` for clears using `FieldValue.delete()`.

- [ ] **Step 2: `setCoachNote` API**

```dart
Future<String?> setCoachNote(String id, {required String? note}) async {
  final ref = _locationRef;
  if (ref == null) return 'No active location.';
  final normalized = Submission.normalizeCoachNote(note);
  if (normalized != null &&
      normalized.length > Submission.maxCoachNoteLength) {
    return 'Coach note must be ${Submission.maxCoachNoteLength} characters or fewer.';
  }
  try {
    final doc = ref.collection(_kSubmissionsCol).doc(id);
    if (normalized == null) {
      await doc.set({
        'coachNote': FieldValue.delete(),
        'coachNoteBy': FieldValue.delete(),
        'coachNoteAt': FieldValue.delete(),
      }, SetOptions(merge: true));
    } else {
      await doc.set({
        'coachNote': normalized,
        'coachNoteBy': _appUser?.name ?? 'manager',
        'coachNoteAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    }
    return null;
  } catch (e) {
    debugPrint('setCoachNote error: $e');
    return 'Could not save coach note.';
  }
}
```

Keep `updateSubmission` as merge of counts/ba/talkedTo only (does not touch coach fields) — already safe.

- [ ] **Step 3: Employee `addSubmission` must not wipe notes**

`ScorecardScreen._save` calls `addSubmission` with a fresh `Submission(...)` that omits coach fields. Change `addSubmission` to **merge** and omit null coach keys OR, preferably, change scorecard save (Task 5) to re-read today’s record and `copyWith` coach fields before `addSubmission`.

**Do both belt-and-suspenders:**

In `addSubmission`, use `SetOptions(merge: true)`:

```dart
await ref
    .collection(_kSubmissionsCol)
    .doc(submission.id)
    .set(_toDoc(submission), SetOptions(merge: true));
```

And ensure `_toDoc` **does not write** `coachNote: null` keys (only `if (s.coachNote != null)`), so merge leaves existing Firestore coach fields alone when the in-memory submission has null coach fields.

- [ ] **Step 4: Smoke — no unit harness for Store; commit**

```bash
git add lib/services/store.dart
git commit -m "feat: persist coach notes with merge-safe writes"
```

---

### Task 3: Submission editor coach field

**Files:**
- Modify: `lib/widgets/submission_editor.dart`

- [ ] **Step 1: State + field UI**

```dart
late final TextEditingController _coachNote;
String? _coachError;

// initState:
_coachNote = TextEditingController(text: e?.coachNote ?? '');

// dispose: _coachNote.dispose();
```

Below tallies, before dialog actions area content end:

```dart
const SizedBox(height: 12),
TextField(
  controller: _coachNote,
  maxLength: Submission.maxCoachNoteLength,
  maxLines: 3,
  decoration: InputDecoration(
    labelText: 'Coach note',
    hintText: 'Optional coaching comment',
    errorText: _coachError,
  ),
),
```

- [ ] **Step 2: `_save` builds coach onto `Submission`**

```dart
final normalized = Submission.normalizeCoachNote(_coachNote.text);
if (normalized != null &&
    normalized.length > Submission.maxCoachNoteLength) {
  setState(() => _coachError =
      'Max ${Submission.maxCoachNoteLength} characters');
  return;
}
final existing = widget.existing;
final result = Submission(
  ...
  approved: existing?.approved ?? false,
  approvedBy: existing?.approvedBy,
  approvedAt: existing?.approvedAt,
  editedBy: existing?.editedBy,
  editedAt: existing?.editedAt,
  coachNote: normalized,
  coachNoteBy: normalized == null
      ? null
      : (existing?.coachNote == normalized
          ? existing?.coachNoteBy
          : null), // store setCoachNote will set by/at; or set here:
  coachNoteAt: normalized == null ? null : existing?.coachNoteAt,
);
```

Simpler approach for editor return value: include `coachNote` text only; callers call `setCoachNote` after `updateSubmission`. Prefer that:

After successful `updateSubmission` in callers, also:

```dart
await Store.instance.setCoachNote(id, note: result.coachNote);
```

And put normalized note (or null to clear) on the returned `Submission.coachNote`.

When user clears the field, `normalizeCoachNote` → null → `setCoachNote` deletes.

- [ ] **Step 3: Commit**

```bash
git add lib/widgets/submission_editor.dart
git commit -m "feat: coach note field in submission editor"
```

---

### Task 4: Wire Master Sheet pending + editor callers

**Files:**
- Modify: `lib/screens/master_sheet_screen.dart`

- [ ] **Step 1: After every `showSubmissionEditor` + `updateSubmission` path**

```dart
await Store.instance.setCoachNote(result.id, note: result.coachNote);
```

Apply in `_PendingCard._edit` and any Master Sheet day-edit / add-new paths that already call `updateSubmission` / `addSubmission` after the editor (search `showSubmissionEditor`).

For **new** submissions from editor, after add, also `setCoachNote` if note non-null.

- [ ] **Step 2: Pending card — optional one-line compose + note icon**

In `_PendingCard`:

- If `submission.hasCoachNote`, show `Icons.sticky_note_2_outlined` in the header row (tooltip: note preview truncated).
- Add a dense `TextField` (optional) “Add coach note…” local controller; on Approve:

```dart
final noteText = _noteController.text; // if StatefulWidget
final errNote = await Store.instance.setCoachNote(
  submission.id,
  note: noteText,
);
if (errNote != null) { showStoreMessage(...); return; }
final err = await Store.instance.approveSubmission(submission.id);
```

Empty field on approve = leave existing note unchanged: call `setCoachNote` only if user typed something **or** you track dirty; simplest: if `trim().isEmpty` skip `setCoachNote` (preserve existing).

- [ ] **Step 3: Manual approve with note; open editor; clear note**

- [ ] **Step 4: Commit**

```bash
git add lib/screens/master_sheet_screen.dart
git commit -m "feat: coach notes on pending approvals and sheet edits"
```

---

### Task 5: Employee Save preserve + Reports read UI

**Files:**
- Modify: `lib/screens/scorecard_screen.dart`
- Modify: `lib/screens/reports_screen.dart`
- Modify: `lib/screens/manager_screen.dart` (glance icon)

- [ ] **Step 1: Scorecard `_save` merge**

Before `addSubmission`:

```dart
final existing = _todayRecord();
final submission = Submission(
  id: _todayId,
  employeeName: widget.profile.name,
  baGoal: goal,
  counts: Map.of(_counts),
  submittedAt: DateTime.now(),
  talkedTo: _talkedTo,
  approved: existing?.approved ?? false,
  approvedBy: existing?.approvedBy,
  approvedAt: existing?.approvedAt,
  coachNote: existing?.coachNote,
  coachNoteBy: existing?.coachNoteBy,
  coachNoteAt: existing?.coachNoteAt,
  editedBy: existing?.editedBy,
  editedAt: existing?.editedAt,
);
```

(With Task 2 merge-safe `_toDoc`, even null coach omits keys — still copy for local correctness.)

- [ ] **Step 2: Reports — personal coach banner**

When `filterName != null`, before `_FullBreakdown` (or above each shift in the list), for each submission with `hasCoachNote`:

```dart
AppCard(
  padding: const EdgeInsets.all(14),
  child: Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        'Coach note',
        style: TextStyles.caption.copyWith(fontWeight: FontWeight.w800),
      ),
      const SizedBox(height: 4),
      Text(s.coachNote!, style: TextStyles.body),
      if (s.coachNoteBy != null) ...[
        const SizedBox(height: 4),
        Text(
          [
            s.coachNoteBy,
            if (s.coachNoteAt != null) _time.format(s.coachNoteAt!),
          ].whereType<String>().join(' · '),
          style: TextStyles.caption,
        ),
      ],
    ],
  ),
),
```

When `filterName == null` (team view): **do not** render coach notes on `_EmployeeReport` / team cards.

- [ ] **Step 3: Manager glance icon on `_EmployeeCard`**

If any submission in the card `hasCoachNote`, show a small `Icons.sticky_note_2_outlined` next to the name (non-interactive or opens Master Sheet — keep icon-only for v1).

- [ ] **Step 4: Manual matrix**

| Case | Expected |
|------|----------|
| Manager note via editor | Employee personal Reports shows banner |
| Team Reports / see-all | No coach text for other workers |
| Employee Save after note | Note still on doc |
| Clear note in editor | Banner gone |
| >280 chars | Validation error |

- [ ] **Step 5: Commit**

```bash
git add lib/screens/scorecard_screen.dart lib/screens/reports_screen.dart lib/screens/manager_screen.dart
git commit -m "feat: show coach notes on Reports; preserve on employee Save"
```

---

### Task 6: Phase B verification

- [ ] **Step 1:** `flutter test test/models/submission_coach_note_test.dart` — PASS
- [ ] **Step 2:** Manual checklist against Phase B success criteria in the spec
- [ ] **Step 3:** Done — no Phase A regressions required beyond smoke

---

## Spec coverage (Phase B)

| Spec item | Task |
|-----------|------|
| Model fields + 280 limit + overwrite | 1, 2 |
| Merge-safe employee Save | 2, 5 |
| Editor write | 3, 4 |
| Pending compose | 4 |
| Reports read (personal only) | 5 |
| Manager glance icon | 4, 5 |
| No push/threads/live scorecard note | Explicitly omitted |
