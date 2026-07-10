# Employee Requests UI Polish Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a scorecard AppBar shortcut to Requests, restyle the employee Requests page to match the manager board look, and show `Status · h:mm a` timestamps on employee tiles (manager already shows time).

**Architecture:** Keep behavior in `EmployeeRequestsScreen` and `ScorecardScreen`. Add a tiny pure caption helper in `staff_request_logic.dart` for status + optional time so formatting is unit-tested. Restyle employee UI with the same visual tokens as `ManagerRequestsScreen` (gray page, section titles, count badge, board panel, white tiles, empty icon) without extracting shared widgets.

**Tech Stack:** Flutter, `intl` `DateFormat`, existing `Store` / `StaffRequest` / clear-prefs.

**Spec:** `docs/superpowers/specs/2026-07-09-employee-requests-ui-polish-design.md`

**Out of scope:** Employee bottom nav/shell, two-column board, shared widget kit, Firestore/rules, clear-finished changes, manager timestamp format changes.

---

## File map

| File | Responsibility |
|------|----------------|
| `lib/utils/staff_request_logic.dart` | Add `formatStaffRequestTime` + `employeeRequestCaption` |
| `test/utils/staff_request_logic_test.dart` | Tests for caption/time helpers |
| `lib/screens/scorecard_screen.dart` | AppBar Requests icon → push `EmployeeRequestsScreen` |
| `lib/screens/employee_requests_screen.dart` | Manager-like layout + caption with time |
| `lib/widgets/profile_menu.dart` | Unchanged (keep Account → Requests) |
| `lib/screens/manager_requests_screen.dart` | Unchanged (already shows `h:mm a`) |

---

### Task 1: Caption / time helpers (TDD)

**Files:**
- Modify: `lib/utils/staff_request_logic.dart`
- Modify: `test/utils/staff_request_logic_test.dart`

- [ ] **Step 1: Write failing tests**

Append to `test/utils/staff_request_logic_test.dart`:

```dart
test('formatStaffRequestTime empty when null', () {
  expect(formatStaffRequestTime(null), '');
});

test('formatStaffRequestTime uses h:mm a', () {
  final t = DateTime(2026, 7, 9, 15, 42);
  expect(formatStaffRequestTime(t), '3:42 PM');
});

test('employeeRequestCaption status only when no time', () {
  expect(
    employeeRequestCaption(StaffRequestStatus.pending, null),
    'Sent',
  );
});

test('employeeRequestCaption status · time', () {
  final t = DateTime(2026, 7, 9, 15, 42);
  expect(
    employeeRequestCaption(StaffRequestStatus.completed, t),
    'Done · 3:42 PM',
  );
});
```

Confirm `employeeLabel` values in `lib/models/staff_request.dart` (`Sent` / `Accepted` / `Done` / etc.) match the expected strings above; if labels differ, use the actual `employeeLabel` strings in the tests.

- [ ] **Step 2: Run tests — expect FAIL**

Run: `flutter test test/utils/staff_request_logic_test.dart`  
Expected: FAIL — `formatStaffRequestTime` / `employeeRequestCaption` not defined.

- [ ] **Step 3: Implement helpers**

In `lib/utils/staff_request_logic.dart`, add:

```dart
import 'package:intl/intl.dart';
import '../models/staff_request.dart';

final _staffRequestTime = DateFormat('h:mm a');

String formatStaffRequestTime(DateTime? createdAt) {
  if (createdAt == null) return '';
  return _staffRequestTime.format(createdAt);
}

String employeeRequestCaption(StaffRequestStatus status, DateTime? createdAt) {
  final time = formatStaffRequestTime(createdAt);
  if (time.isEmpty) return status.employeeLabel;
  return '${status.employeeLabel} · $time';
}
```

Keep existing exports (`staffRequestProfileKey`, `validateRequestText`, etc.). Only add `intl` if not already imported.

- [ ] **Step 4: Run tests — expect PASS**

Run: `flutter test test/utils/staff_request_logic_test.dart`  
Expected: All tests passed.

- [ ] **Step 5: Commit**

```bash
git add lib/utils/staff_request_logic.dart test/utils/staff_request_logic_test.dart
git commit -m "$(cat <<'EOF'
feat: add employee request status+time caption helper

EOF
)"
```

---

### Task 2: Scorecard AppBar Requests icon

**Files:**
- Modify: `lib/screens/scorecard_screen.dart`

- [ ] **Step 1: Add import**

At top of `scorecard_screen.dart`, add:

```dart
import 'employee_requests_screen.dart';
```

- [ ] **Step 2: Insert AppBar action before ProfileAction**

In the main `AppBar` `actions:` list (the one with Tips / Google review / Clear / Profile), insert **before** `const ProfileAction()`:

```dart
IconButton(
  tooltip: 'Requests',
  onPressed: () => Navigator.of(context).push(
    MaterialPageRoute(
      builder: (_) => const EmployeeRequestsScreen(),
    ),
  ),
  icon: const Icon(Icons.campaign_outlined),
),
```

Do not remove Tips, Google review, Clear, or Profile. Do not change `profile_menu.dart`.

- [ ] **Step 3: Analyze**

Run: `dart analyze lib/screens/scorecard_screen.dart`  
Expected: No issues found.

- [ ] **Step 4: Commit**

```bash
git add lib/screens/scorecard_screen.dart
git commit -m "$(cat <<'EOF'
feat: open Requests from employee scorecard app bar

EOF
)"
```

---

### Task 3: Restyle employee Requests screen

**Files:**
- Modify: `lib/screens/employee_requests_screen.dart`

- [ ] **Step 1: Replace UI build (keep state/logic)**

Keep existing state fields and methods (`_custom`, debounce, `_clearedIds`, `_loadCleared`, `_clearFinished`, `_send`) unchanged.

Rewrite `build` so the scaffold matches manager visual language:

```dart
@override
Widget build(BuildContext context) {
  return Scaffold(
    backgroundColor: const Color(0xFFF7F8FA),
    appBar: AppBar(title: const Text('Requests')),
    body: AnimatedBuilder(
      animation: Store.instance,
      builder: (context, _) {
        final name = Store.instance.profile?.name ?? '';
        final key = staffRequestProfileKey(name);
        final presets = Store.instance.requestPresets;
        final mine = Store.instance.staffRequests.where((r) {
          if (r.status == StaffRequestStatus.dismissed) return false;
          if (_clearedIds.contains(r.id)) return false;
          if (r.employeeProfileKey != null &&
              r.employeeProfileKey!.isNotEmpty) {
            return r.employeeProfileKey == key;
          }
          return r.employeeName.trim().toLowerCase() == key;
        }).toList();
        final finishedCount = mine
            .where((r) => r.status == StaffRequestStatus.completed)
            .length;

        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 40),
          children: [
            const Text(
              'Quick requests',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Tap a preset to notify your manager',
              style: TextStyles.caption,
            ),
            const SizedBox(height: 12),
            if (presets.isEmpty)
              const Text(
                'No presets yet — ask a manager to add some, or type below.',
                style: TextStyles.caption,
              )
            else
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  for (final p in presets)
                    ActionChip(
                      label: Text(p.label),
                      onPressed: _busy
                          ? null
                          : () => _send(text: p.label, presetId: p.id),
                    ),
                ],
              ),
            const SizedBox(height: 24),
            Material(
              color: Colors.white,
              elevation: 1,
              shadowColor: const Color(0x14000000),
              borderRadius: BorderRadius.circular(14),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      'Custom request',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _custom,
                      maxLength: kStaffRequestMaxLen,
                      maxLengthEnforcement: MaxLengthEnforcement.enforced,
                      decoration: const InputDecoration(
                        labelText: 'Message',
                        hintText: 'Need more towels at bay 2',
                        isDense: true,
                      ),
                      onSubmitted: (_) {
                        if (!_busy) _send(text: _custom.text);
                      },
                    ),
                    const SizedBox(height: 8),
                    FilledButton(
                      onPressed: _busy ? null : () => _send(text: _custom.text),
                      child: const Text('Send'),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 28),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Text(
                            'Your requests',
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(width: 8),
                          _CountBadge(mine.length),
                        ],
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Status updates from your manager',
                        style: TextStyles.caption,
                      ),
                    ],
                  ),
                ),
                if (_clearedLoaded && finishedCount > 0)
                  TextButton(
                    onPressed: _busy ? null : () => _clearFinished(mine),
                    child: const Text('Clear finished'),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              constraints: const BoxConstraints(minHeight: 180),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFF3F5F8),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFE2E7EF)),
              ),
              child: mine.isEmpty
                  ? const _EmptyPanel(
                      icon: Icons.inbox_outlined,
                      message: 'Nothing sent yet',
                    )
                  : Column(
                      children: [
                        for (final r in mine) ...[
                          Material(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            child: Padding(
                              padding: const EdgeInsets.all(14),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  Text(
                                    r.text,
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.textPrimary,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    employeeRequestCaption(
                                      r.status,
                                      r.createdAt,
                                    ),
                                    style: TextStyles.caption,
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 10),
                        ],
                      ],
                    ),
            ),
          ],
        );
      },
    ),
  );
}
```

Add private helpers at bottom of the same file (employee-local copies; do not extract shared widgets):

```dart
class _CountBadge extends StatelessWidget {
  const _CountBadge(this.count);
  final int count;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minWidth: 28),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: const Color(0xFFE8ECF2),
        borderRadius: BorderRadius.circular(999),
      ),
      alignment: Alignment.center,
      child: Text(
        '$count',
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w800,
          color: AppColors.textMuted,
        ),
      ),
    );
  }
}

class _EmptyPanel extends StatelessWidget {
  const _EmptyPanel({required this.icon, required this.message});

  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 56, color: const Color(0xFFC5CDD8)),
            const SizedBox(height: 12),
            Text(
              message,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppColors.textMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
```

Remove unused `AppCard` usage on this screen if nothing else needs it in the file imports (keep `theme.dart` for `AppColors` / `TextStyles`).

- [ ] **Step 2: Analyze**

Run: `dart analyze lib/screens/employee_requests_screen.dart lib/utils/staff_request_logic.dart`  
Expected: No issues found.

- [ ] **Step 3: Re-run helper tests**

Run: `flutter test test/utils/staff_request_logic_test.dart`  
Expected: All tests passed.

- [ ] **Step 4: Commit**

```bash
git add lib/screens/employee_requests_screen.dart
git commit -m "$(cat <<'EOF'
feat: restyle employee Requests to match manager board look

EOF
)"
```

---

### Task 4: Verify + push

**Files:** none new

- [ ] **Step 1: Full analyze on touched files**

Run:

```bash
dart analyze \
  lib/utils/staff_request_logic.dart \
  lib/screens/scorecard_screen.dart \
  lib/screens/employee_requests_screen.dart
```

Expected: No issues found.

- [ ] **Step 2: Manual acceptance checklist**

- [ ] Scorecard AppBar shows campaign Requests icon left of Account; tap opens Requests.
- [ ] Account sheet still has Requests.
- [ ] Employee page: gray background, Quick requests, Custom card, Your requests board with badge/empty icon/white tiles.
- [ ] Tile caption shows `Sent · 3:42 PM` (or Accepted/Done) when `createdAt` present.
- [ ] Clear finished still hides completed on device.
- [ ] Manager tiles still show `name · time` (no code change required).

- [ ] **Step 3: Push**

```bash
git push origin HEAD
```

Only push if already on the intended branch (`mybranch` or a feature branch the user named). Do not force-push.

---

## Spec coverage (self-review)

| Spec requirement | Task |
|------------------|------|
| AppBar Requests icon next to Account | Task 2 |
| Keep Account → Requests | Task 2 (explicit non-change) |
| Soft gray + section titles + board panel + white tiles + empty icon | Task 3 |
| Quick / Custom / Your requests structure | Task 3 |
| Caption `Status · h:mm a` | Task 1 + 3 |
| Manager time unchanged | File map + Task 4 checklist |
| Clear finished / send unchanged | Task 3 keeps logic |
| No bottom nav / shared widgets / rules | Out of scope |

No placeholders. Helper names consistent across Task 1 and Task 3 (`employeeRequestCaption`, `formatStaffRequestTime`).
