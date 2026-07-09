# Master Sheet Spreadsheet Feel Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make the Master Sheet feel like a spreadsheet — freeze panes, show/hide columns, sort & filter, density, and a lighter header — via toolbar tools and device prefs, without inline editing.

**Architecture:** Pure helpers own column ids, sort/filter, and prefs serialization. `MasterSheetScreen` owns toolbar state and applies tools to built rows before rendering. `_SpreadsheetTable` gains visible-column + density params and a light visual treatment; freeze panes use a fixed first-column strip + linked horizontal/vertical scroll for the metric grid.

**Tech Stack:** Flutter web, `shared_preferences` (existing), existing `Submission` / `kLineItems` / `AppColors` / `_SpreadsheetTable`.

**Spec:** `docs/superpowers/specs/2026-07-09-master-sheet-spreadsheet-feel-design.md`

---

## File map

| File | Responsibility |
|------|----------------|
| `lib/utils/sheet_column.dart` | Column id constants + default visibility list from `kLineItems` |
| `lib/utils/sheet_tools_prefs.dart` | Load/save density, columns, sort, min BA/revenue prefs |
| `lib/utils/sheet_row_tools.dart` | Pure filter + sort of `List<MasterSheetRow>`; re-aggregate totals from visible |
| `lib/widgets/sheet_tools_bar.dart` | Columns / Sort / Filter / Density toolbar controls |
| `lib/screens/master_sheet_screen.dart` | Wire prefs, apply tools to rows, pass density/columns into table, freeze + polish |
| `test/utils/sheet_row_tools_test.dart` | Unit tests for filter/sort/totals |
| `test/utils/sheet_tools_prefs_test.dart` | Prefs round-trip |

**Export unchanged:** `_buildMasterSheetRows` + existing CSV/XLSX paths keep using unfiltered full scope (do not pass sheet-tool filters into export).

---

### Task 1: Column ids + prefs model

**Files:**
- Create: `lib/utils/sheet_column.dart`
- Create: `lib/utils/sheet_tools_prefs.dart`
- Create: `test/utils/sheet_tools_prefs_test.dart`

- [ ] **Step 1: Write failing prefs test**

Create `test/utils/sheet_tools_prefs_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wiggywash/utils/sheet_column.dart';
import 'package:wiggywash/utils/sheet_tools_prefs.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('defaults: all columns visible, comfortable, nameAsc sort', () {
    final p = SheetToolsPrefs.defaults();
    expect(p.density, SheetDensity.comfortable);
    expect(p.sortKey, SheetSortKey.nameOrDate);
    expect(p.sortAsc, isTrue);
    expect(p.minBa, isNull);
    expect(p.minRevenue, isNull);
    expect(p.hiddenColumnIds, isEmpty);
  });

  test('round-trip save/load', () async {
    final original = SheetToolsPrefs(
      density: SheetDensity.dense,
      sortKey: SheetSortKey.revenue,
      sortAsc: false,
      minBa: 40,
      minRevenue: 100,
      hiddenColumnIds: {SheetColumnId.talked, SheetColumnId.vip},
    );
    await SheetToolsPrefs.save(original);
    final loaded = await SheetToolsPrefs.load();
    expect(loaded.density, SheetDensity.dense);
    expect(loaded.sortKey, SheetSortKey.revenue);
    expect(loaded.sortAsc, isFalse);
    expect(loaded.minBa, 40);
    expect(loaded.minRevenue, 100);
    expect(loaded.hiddenColumnIds, {SheetColumnId.talked, SheetColumnId.vip});
  });

  test('isColumnVisible treats unknown as visible and first col always on', () {
    final p = SheetToolsPrefs(
      density: SheetDensity.compact,
      sortKey: SheetSortKey.ba,
      sortAsc: true,
      minBa: null,
      minRevenue: null,
      hiddenColumnIds: {SheetColumnId.score},
    );
    expect(p.isColumnVisible(SheetColumnId.first), isTrue);
    expect(p.isColumnVisible(SheetColumnId.score), isFalse);
    expect(p.isColumnVisible(SheetColumnId.revenue), isTrue);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/utils/sheet_tools_prefs_test.dart`

Expected: FAIL — library not found / undefined classes.

- [ ] **Step 3: Implement column ids + prefs**

Create `lib/utils/sheet_column.dart`:

```dart
import '../models/scorecard_config.dart';

/// Stable ids for Master Sheet metric columns (first/name-date is never hidden).
abstract final class SheetColumnId {
  static const first = 'first';
  static const talked = 'talked';
  static const vip = 'vip';
  static const aboveEco = 'aboveEco';
  static const ba = 'ba';
  static const score = 'score';
  static const revenue = 'revenue';

  /// Line-item columns use the item's `id` from [kLineItems].
  static String lineItem(String itemId) => 'li:$itemId';

  static List<String> allToggleableIds() => [
        talked,
        for (final i in kLineItems) lineItem(i.id),
        vip,
        aboveEco,
        ba,
        score,
        revenue,
      ];
}

enum SheetDensity { comfortable, compact, dense }

enum SheetSortKey { nameOrDate, revenue, ba, score, talked }
```

Create `lib/utils/sheet_tools_prefs.dart`:

```dart
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'sheet_column.dart';

const _kPrefsKey = 'ww_master_sheet_tools';

class SheetToolsPrefs {
  const SheetToolsPrefs({
    required this.density,
    required this.sortKey,
    required this.sortAsc,
    required this.minBa,
    required this.minRevenue,
    required this.hiddenColumnIds,
  });

  final SheetDensity density;
  final SheetSortKey sortKey;
  final bool sortAsc;
  final double? minBa;
  final double? minRevenue;
  final Set<String> hiddenColumnIds;

  factory SheetToolsPrefs.defaults() => const SheetToolsPrefs(
        density: SheetDensity.comfortable,
        sortKey: SheetSortKey.nameOrDate,
        sortAsc: true,
        minBa: null,
        minRevenue: null,
        hiddenColumnIds: {},
      );

  bool isColumnVisible(String id) {
    if (id == SheetColumnId.first) return true;
    return !hiddenColumnIds.contains(id);
  }

  SheetToolsPrefs copyWith({
    SheetDensity? density,
    SheetSortKey? sortKey,
    bool? sortAsc,
    double? minBa,
    bool clearMinBa = false,
    double? minRevenue,
    bool clearMinRevenue = false,
    Set<String>? hiddenColumnIds,
  }) {
    return SheetToolsPrefs(
      density: density ?? this.density,
      sortKey: sortKey ?? this.sortKey,
      sortAsc: sortAsc ?? this.sortAsc,
      minBa: clearMinBa ? null : (minBa ?? this.minBa),
      minRevenue: clearMinRevenue ? null : (minRevenue ?? this.minRevenue),
      hiddenColumnIds: hiddenColumnIds ?? this.hiddenColumnIds,
    );
  }

  Map<String, dynamic> toJson() => {
        'density': density.name,
        'sortKey': sortKey.name,
        'sortAsc': sortAsc,
        'minBa': minBa,
        'minRevenue': minRevenue,
        'hidden': hiddenColumnIds.toList(),
      };

  factory SheetToolsPrefs.fromJson(Map<String, dynamic> json) {
    SheetDensity density = SheetDensity.comfortable;
    for (final d in SheetDensity.values) {
      if (d.name == json['density']) density = d;
    }
    SheetSortKey sortKey = SheetSortKey.nameOrDate;
    for (final k in SheetSortKey.values) {
      if (k.name == json['sortKey']) sortKey = k;
    }
    final hidden = <String>{};
    final rawHidden = json['hidden'];
    if (rawHidden is List) {
      for (final e in rawHidden) {
        if (e is String) hidden.add(e);
      }
    }
    return SheetToolsPrefs(
      density: density,
      sortKey: sortKey,
      sortAsc: json['sortAsc'] as bool? ?? true,
      minBa: (json['minBa'] as num?)?.toDouble(),
      minRevenue: (json['minRevenue'] as num?)?.toDouble(),
      hiddenColumnIds: hidden,
    );
  }

  static Future<SheetToolsPrefs> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_kPrefsKey);
    if (raw == null || raw.isEmpty) return SheetToolsPrefs.defaults();
    try {
      final map = jsonDecode(raw) as Map<String, dynamic>;
      return SheetToolsPrefs.fromJson(map);
    } catch (_) {
      return SheetToolsPrefs.defaults();
    }
  }

  static Future<void> save(SheetToolsPrefs value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kPrefsKey, jsonEncode(value.toJson()));
  }

  double rowHeight() => switch (density) {
        SheetDensity.comfortable => 40,
        SheetDensity.compact => 32,
        SheetDensity.dense => 26,
      };

  double headerHeight() => switch (density) {
        SheetDensity.comfortable => 104,
        SheetDensity.compact => 92,
        SheetDensity.dense => 80,
      };

  double bodyFontSize() => switch (density) {
        SheetDensity.comfortable => 12.5,
        SheetDensity.compact => 12,
        SheetDensity.dense => 11,
      };
}
```

- [ ] **Step 4: Run prefs tests**

Run: `flutter test test/utils/sheet_tools_prefs_test.dart`

Expected: All PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/utils/sheet_column.dart lib/utils/sheet_tools_prefs.dart test/utils/sheet_tools_prefs_test.dart
git commit -m "$(cat <<'EOF'
feat: add Master Sheet tools prefs and column ids

EOF
)"
```

---

### Task 2: Sort / filter pure helper

**Files:**
- Create: `lib/utils/sheet_row_tools.dart`
- Create: `test/utils/sheet_row_tools_test.dart`

- [ ] **Step 1: Write failing tests**

Create `test/utils/sheet_row_tools_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:wiggywash/models/submission.dart';
import 'package:wiggywash/utils/sheet_column.dart';
import 'package:wiggywash/utils/sheet_row_tools.dart';
import 'package:wiggywash/utils/sheet_tools_prefs.dart';
import 'package:wiggywash/utils/xlsx.dart';

Submission _sub({
  required String name,
  required DateTime at,
  int talkedTo = 10,
  Map<String, int> counts = const {},
}) {
  return Submission(
    id: '${name}_${at.millisecondsSinceEpoch}',
    employeeName: name,
    baGoal: 40,
    counts: counts,
    submittedAt: at,
    approved: true,
    talkedTo: talkedTo,
  );
}

void main() {
  final alex = MasterSheetRow(
    label: 'Alex',
    submission: _sub(
      name: 'Alex',
      at: DateTime(2026, 7, 1),
      talkedTo: 10,
      counts: const {'basic': 4}, // membership-ish depends on catalog; BA uses talkedTo
    ),
  );
  final blake = MasterSheetRow(
    label: 'Blake',
    submission: _sub(
      name: 'Blake',
      at: DateTime(2026, 7, 1),
      talkedTo: 20,
      counts: const {},
    ),
  );

  test('filter by employee names (session filter)', () {
    final out = applySheetRowTools(
      rows: [alex, blake],
      prefs: SheetToolsPrefs.defaults(),
      selectedEmployees: {'Alex'},
      firstColIsDate: false,
    );
    expect(out.map((r) => r.label).toList(), ['Alex']);
  });

  test('filter min BA and min revenue', () {
    final high = MasterSheetRow(
      label: 'Casey',
      submission: _sub(
        name: 'Casey',
        at: DateTime(2026, 7, 1),
        talkedTo: 10,
        counts: const {'basic': 5},
      ),
    );
    final prefs = SheetToolsPrefs.defaults().copyWith(minBa: 1, minRevenue: 0);
    final out = applySheetRowTools(
      rows: [blake, high],
      prefs: prefs,
      selectedEmployees: null,
      firstColIsDate: false,
    );
    // blake BA 0 with no memberships; high has memberships → BA > 0
    expect(out.every((r) => r.submission.businessAverage >= 1), isTrue);
  });

  test('sort by revenue desc keeps order of values', () {
    final a = MasterSheetRow(
      label: 'A',
      submission: _sub(name: 'A', at: DateTime(2026, 7, 1), counts: const {'basic': 1}),
    );
    final b = MasterSheetRow(
      label: 'B',
      submission: _sub(name: 'B', at: DateTime(2026, 7, 1), counts: const {'basic': 3}),
    );
    final prefs = SheetToolsPrefs.defaults().copyWith(
      sortKey: SheetSortKey.revenue,
      sortAsc: false,
    );
    final out = applySheetRowTools(
      rows: [a, b],
      prefs: prefs,
      selectedEmployees: null,
      firstColIsDate: false,
    );
    expect(
      out.first.submission.grandTotalRevenue >=
          out.last.submission.grandTotalRevenue,
      isTrue,
    );
  });

  test('sort by name ascending', () {
    final prefs = SheetToolsPrefs.defaults();
    final out = applySheetRowTools(
      rows: [blake, alex],
      prefs: prefs,
      selectedEmployees: null,
      firstColIsDate: false,
    );
    expect(out.map((r) => r.label).toList(), ['Alex', 'Blake']);
  });

  test('employee filter ignored when firstColIsDate (month/member day rows)', () {
    final day = MasterSheetRow(
      label: '7/1',
      submission: _sub(name: 'Alex', at: DateTime(2026, 7, 1)),
    );
    final out = applySheetRowTools(
      rows: [day],
      prefs: SheetToolsPrefs.defaults(),
      selectedEmployees: {'Nobody'},
      firstColIsDate: true,
    );
    expect(out.length, 1);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/utils/sheet_row_tools_test.dart`

Expected: FAIL — missing `sheet_row_tools.dart`.

- [ ] **Step 3: Implement helper**

Create `lib/utils/sheet_row_tools.dart`:

```dart
import '../models/submission.dart';
import 'sheet_column.dart';
import 'sheet_tools_prefs.dart';
import 'xlsx.dart' show MasterSheetRow;

/// Filters then sorts display rows. Does not include a totals row.
List<MasterSheetRow> applySheetRowTools({
  required List<MasterSheetRow> rows,
  required SheetToolsPrefs prefs,
  required Set<String>? selectedEmployees,
  required bool firstColIsDate,
}) {
  var list = List<MasterSheetRow>.from(rows);

  if (!firstColIsDate &&
      selectedEmployees != null &&
      selectedEmployees.isNotEmpty) {
    list = list
        .where((r) => selectedEmployees.contains(r.submission.employeeName))
        .toList();
  }

  if (prefs.minBa != null) {
    final min = prefs.minBa!;
    list = list.where((r) => r.submission.businessAverage >= min).toList();
  }
  if (prefs.minRevenue != null) {
    final min = prefs.minRevenue!;
    list = list.where((r) => r.submission.grandTotalRevenue >= min).toList();
  }

  int cmp(MasterSheetRow a, MasterSheetRow b) {
    final sa = a.submission;
    final sb = b.submission;
    int primary;
    switch (prefs.sortKey) {
      case SheetSortKey.nameOrDate:
        primary = firstColIsDate
            ? sa.submittedAt.compareTo(sb.submittedAt)
            : a.label.toLowerCase().compareTo(b.label.toLowerCase());
      case SheetSortKey.revenue:
        primary = sa.grandTotalRevenue.compareTo(sb.grandTotalRevenue);
      case SheetSortKey.ba:
        primary = sa.businessAverage.compareTo(sb.businessAverage);
      case SheetSortKey.score:
        primary = sa.overallScore.compareTo(sb.overallScore);
      case SheetSortKey.talked:
        primary = sa.talkedTo.compareTo(sb.talkedTo);
    }
    if (!prefs.sortAsc) primary = -primary;
    if (primary != 0) return primary;
    return a.label.compareTo(b.label);
  }

  list.sort(cmp);
  return list;
}

/// Re-aggregate totals from visible rows using the same aggregator as the screen.
Submission totalsFromVisibleRows({
  required List<MasterSheetRow> visible,
  required DateTime anchor,
  required Submission Function(String, List<Submission>, DateTime) aggregate,
}) {
  final subs = visible.map((r) => r.submission).toList();
  return aggregate('TOTALS', subs, anchor);
}

int activeFilterCount({
  required SheetToolsPrefs prefs,
  required Set<String>? selectedEmployees,
  required bool firstColIsDate,
}) {
  var n = 0;
  if (!firstColIsDate &&
      selectedEmployees != null &&
      selectedEmployees.isNotEmpty) {
    n++;
  }
  if (prefs.minBa != null) n++;
  if (prefs.minRevenue != null) n++;
  return n;
}
```

- [ ] **Step 4: Run tests**

Run: `flutter test test/utils/sheet_row_tools_test.dart test/utils/sheet_tools_prefs_test.dart`

Expected: All PASS. If membership id `basic` is wrong for BA assertions, adjust fixture counts to a real membership id from `kLineItems` (e.g. first membership item id) — do not change production BA math.

- [ ] **Step 5: Commit**

```bash
git add lib/utils/sheet_row_tools.dart test/utils/sheet_row_tools_test.dart
git commit -m "$(cat <<'EOF'
feat: add Master Sheet row sort and filter helpers

EOF
)"
```

---

### Task 3: Visual polish + density on `_SpreadsheetTable`

**Files:**
- Modify: `lib/screens/master_sheet_screen.dart` (`_SpreadsheetTable` and related)

- [ ] **Step 1: Extend `_SpreadsheetTable` constructor**

Add fields (keep existing ones):

```dart
final Set<String> hiddenColumnIds; // empty = all visible
final SheetDensity density;
```

Import `sheet_column.dart` and `sheet_tools_prefs.dart`. Default `hiddenColumnIds` to `const {}` and `density` to `SheetDensity.comfortable` so existing call sites compile until Task 5 wires prefs.

- [ ] **Step 2: Light header (kill navy bar)**

Replace header decoration and text styles:

```dart
static const _headerBg = Color(0xFFF4F6FA);
static const _headerFg = Color(0xFF74808F);
static const _gridColor = Color(0xFFE2E7EF);
static const _zebra = Color(0xFFFAFBFC);

TableRow _headerRow(List<LineItem> items) {
  return TableRow(
    decoration: const BoxDecoration(color: _headerBg),
    children: [
      _firstHeader(widget.firstColIsDate ? 'Date' : 'Name'),
      if (_vis(SheetColumnId.talked)) _vHeader('Total Talked'),
      for (final i in items)
        if (_vis(SheetColumnId.lineItem(i.id))) _vHeader(i.label),
      if (_vis(SheetColumnId.vip)) _vHeader('Total VIP'),
      if (_vis(SheetColumnId.aboveEco)) _vHeader('Above Eco'),
      if (_vis(SheetColumnId.ba)) _vHeader('BA %'),
      if (_vis(SheetColumnId.score)) _vHeader('Score'),
      if (_vis(SheetColumnId.revenue)) _vHeader('Revenue'),
    ],
  );
}

bool _vis(String id) => !widget.hiddenColumnIds.contains(id);
```

Update `_firstHeader` / `_vHeader` to use `_headerFg` (not white) and `widget`-driven heights from density (`SheetToolsPrefs`-style heights: comfortable 104 / compact 92 / dense 80 for header; body from density).

- [ ] **Step 3: Filter point + data row children the same way**

In `_pointRow` and `_dataRow`, only emit cells for visible columns (same `if (_vis(...))` gates). Keep BA color logic unchanged. Apply zebra: for non-total, non-top, non-hover rows, alternate `_zebra` / white by row index (pass index into `_dataRow` or compute from `widget.rows` index in the build loop).

Use `widget.density` for cell heights / font sizes (mirror `SheetToolsPrefs.rowHeight` / `bodyFontSize` — either call those via a tiny local switch or construct a throwaway prefs; prefer a private method on the State).

- [ ] **Step 4: Stronger totals**

Totals row already uses `AppColors.blueSoft`; keep it, bump border emphasis if needed (e.g. top border via cell decoration). Do not use solid navy.

- [ ] **Step 5: Analyze**

Run: `flutter analyze lib/screens/master_sheet_screen.dart`

Expected: No issues.

- [ ] **Step 6: Commit**

```bash
git add lib/screens/master_sheet_screen.dart
git commit -m "$(cat <<'EOF'
feat: light Master Sheet header, zebra, density, column gates

EOF
)"
```

---

### Task 4: Freeze first column (linked scroll)

**Files:**
- Modify: `lib/screens/master_sheet_screen.dart` — `_MainPanel` table layout (~673–703) and optionally `_SpreadsheetTable`

**Approach:** Replace the single wide `Table` body with a `Row`:

1. **Frozen strip** — first column only (header label + point label + body labels + TOTALS), fixed width ~116.
2. **Scrollable metrics** — remaining columns in a horizontal `SingleChildScrollView`.
3. **Vertical sync** — one `ScrollController` shared by frozen body and metrics body (or `NotificationListener` linking two controllers).
4. **Horizontal sync** — one controller shared by metrics header and metrics body (fix the current bug where header/body horizontal scrolls are independent).

- [ ] **Step 1: Add scroll controllers to `_MainPanel` state**

Convert `_MainPanel` from `StatelessWidget` to `StatefulWidget` (or lift controllers into `MasterSheetScreen`). Create:

```dart
final _hHeader = ScrollController();
final _hBody = ScrollController();
final _vFrozen = ScrollController();
final _vBody = ScrollController();
```

In `initState`, listen `_hBody` → jump `_hHeader` (guard recursion with a bool). Same for `_vBody` ↔ `_vFrozen`. Dispose all four in `dispose`.

- [ ] **Step 2: Split table rendering**

Extend `_TablePart` or add a `SheetPane { frozen, metrics }` / `includeFirstColumn` flag so `_SpreadsheetTable` can render:

- `frozen` pane: only column 0 cells for header/point/body/totals
- `metrics` pane: columns 1..n for the same parts

Simplest path that matches current split header/body:

```dart
enum _TablePart { all, header, body }
enum _TablePane { full, frozen, metrics }
```

Pass `pane` into `_SpreadsheetTable`. When building children lists, if `pane == frozen` emit only first cell widgets; if `metrics`, emit only the rest. Column widths map must match.

- [ ] **Step 3: Wire layout**

```dart
Expanded(
  child: Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      // frozen column
      Column(
        children: [
          table(part: _TablePart.header, pane: _TablePane.frozen),
          Expanded(
            child: SingleChildScrollView(
              controller: _vFrozen,
              child: table(part: _TablePart.body, pane: _TablePane.frozen, onTap: ...),
            ),
          ),
        ],
      ),
      Expanded(
        child: Column(
          children: [
            SingleChildScrollView(
              controller: _hHeader,
              scrollDirection: Axis.horizontal,
              child: table(part: _TablePart.header, pane: _TablePane.metrics),
            ),
            Expanded(
              child: SingleChildScrollView(
                controller: _vBody,
                child: SingleChildScrollView(
                  controller: _hBody,
                  scrollDirection: Axis.horizontal,
                  child: table(part: _TablePart.body, pane: _TablePane.metrics, onTap: ...),
                ),
              ),
            ),
          ],
        ),
      ),
    ],
  ),
)
```

Keep padding consistent with existing `14` horizontal insets.

- [ ] **Step 4: Manual check notes (document in commit body if useful)**

On web: scroll body horizontally — header metrics move with it; first column stays. Scroll vertically — frozen names and metrics rows stay aligned.

- [ ] **Step 5: Analyze + commit**

```bash
flutter analyze lib/screens/master_sheet_screen.dart
git add lib/screens/master_sheet_screen.dart
git commit -m "$(cat <<'EOF'
feat: freeze Master Sheet first column with linked scroll

EOF
)"
```

---

### Task 5: Sheet tools toolbar + wire prefs into screen

**Files:**
- Create: `lib/widgets/sheet_tools_bar.dart`
- Modify: `lib/screens/master_sheet_screen.dart`

- [ ] **Step 1: Build `SheetToolsBar`**

Create `lib/widgets/sheet_tools_bar.dart` with a compact row of outline buttons:

- **Columns** → `PopupMenuButton` / `showModalBottomSheet` with checkboxes for each `SheetColumnId.allToggleableIds()` (resolve line-item labels via `kLineItems`). Actions: Show all, Reset. Name/Date shown disabled-checked.
- **Sort** → menu of `SheetSortKey` values + Asc/Desc toggle.
- **Filter** → dialog/sheet: employee multi-select (only if `showEmployeeFilter`), min BA text field, min revenue text field, Clear.
- **Density** → three-option menu (Comfortable / Compact / Dense).

Props:

```dart
class SheetToolsBar extends StatelessWidget {
  const SheetToolsBar({
    super.key,
    required this.prefs,
    required this.onPrefsChanged,
    required this.employeeNames,
    required this.selectedEmployees,
    required this.onSelectedEmployeesChanged,
    required this.showEmployeeFilter,
    required this.activeFilterCount,
  });
  // ...
}
```

Style: white/outline; use `Theme.of(context).colorScheme.primary` only for selected/active chips (e.g. when `activeFilterCount > 0`).

On narrow width (`MediaQuery.sizeOf(context).width < 720`), collapse the four tools into one `PopupMenuButton` labeled **Sheet tools**.

- [ ] **Step 2: State on `MasterSheetScreen`**

```dart
SheetToolsPrefs _sheetPrefs = SheetToolsPrefs.defaults();
Set<String>? _selectedEmployees; // session-only; null = all
```

In `initState`, after layout pref: `SheetToolsPrefs.load().then((p) { if (mounted) setState(() => _sheetPrefs = p); });`

On every prefs change: `setState` + `SheetToolsPrefs.save`.

Clear `_selectedEmployees` in `dispose` (session-only — already gone with State).

- [ ] **Step 3: Apply tools in `_MainPanel` / build path**

After `_buildMasterSheetRows(...)`:

```dart
final visibleRows = applySheetRowTools(
  rows: built.rows,
  prefs: sheetPrefs,
  selectedEmployees: selectedEmployees,
  firstColIsDate: built.firstColIsDate,
);
final visibleTotals = totalsFromVisibleRows(
  visible: visibleRows,
  anchor: anchor,
  aggregate: aggregate,
);
```

Pass `visibleRows` / `visibleTotals` into `_SpreadsheetTable` (not the unfiltered built rows). Recompute `topScore` from `visibleRows`.

**Export path:** keep calling `_buildMasterSheetRows` on full `scope` without `applySheetRowTools`.

- [ ] **Step 4: Place toolbar**

In `_MainPanel` (or parent), above the sheet, after view/period controls area — insert `SheetToolsBar` before the “Exporting N rows” caption. Update caption to use visible row count for display only; export still uses full build.

Hide employee filter when `view == _View.member` or `firstColIsDate` (pass `showEmployeeFilter: view == _View.team`).

- [ ] **Step 5: Empty filter state**

If `visibleRows.isEmpty`, show a short centered message under the toolbar: “No rows match filters” + TextButton Clear that clears session employees + `minBa`/`minRevenue` via `copyWith(clearMinBa: true, clearMinRevenue: true)`.

- [ ] **Step 6: Analyze + test + commit**

```bash
flutter analyze
flutter test test/utils/
git add lib/widgets/sheet_tools_bar.dart lib/screens/master_sheet_screen.dart
git commit -m "$(cat <<'EOF'
feat: Master Sheet Columns Sort Filter Density toolbar

EOF
)"
```

---

### Task 6: Verification pass

**Files:** none new (fixups only if analyze/tests fail)

- [ ] **Step 1: Full analyze + tests**

```bash
flutter analyze
flutter test
```

Expected: clean analyze; all tests pass.

- [ ] **Step 2: Manual checklist (web)**

1. Header is light gray, not navy slab; BA cells still colored.
2. Horizontal scroll keeps Name/Date fixed; header metrics stay aligned with body.
3. Hide Revenue → column gone from header, point row, body, totals; export XLSX still has Revenue.
4. Sort Revenue desc; TOTALS stays last.
5. Filter min BA 40; totals match visible people only.
6. Density Dense shrinks rows; survives hot restart (prefs).
7. Employee multi-select clears when leaving Master Sheet (new visit = all employees).
8. Member view: no employee filter control.

- [ ] **Step 3: Commit any fixes**

```bash
git add -u
git commit -m "$(cat <<'EOF'
fix: spreadsheet-feel polish from verification pass

EOF
)"
```

(Skip empty commit if nothing to fix.)

---

## Spec coverage check

| Spec item | Task |
|-----------|------|
| Freeze header + first column | Task 4 (header already split; first col + linked H scroll) |
| Light header / zebra / totals / less navy | Task 3 |
| Show/hide columns + Show all/Reset | Task 5 (+ gates in Task 3) |
| Sort keys + Asc/Desc; totals pinned | Task 2 + 5 |
| Filter employee / min BA / min revenue; session employee | Task 2 + 5 |
| Totals from visible rows | Task 2 + 5 |
| Density 3 modes | Task 1 + 3 + 5 |
| Toolbar only; overflow on narrow | Task 5 |
| Prefs device-local; export full | Task 1 + 5 |
| Unit tests sort/filter | Task 2 |
| No inline edit / React / Settings tab | Honored (not in plan) |

---

## Execution handoff

Plan complete. After user picks an execution mode, use the matching skill only (no implementation in the planning turn beyond writing this file).
