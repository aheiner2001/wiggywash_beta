# Master Sheet Trends Visuals Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Clean Master Sheet chart axes, fix stacked layout sheet height, and add a Trends Visuals gear with show/hide toggles plus BA% and membership-mix charts.

**Architecture:** Extend `master_sheet_stats` with BA and membership aggregates. Add `TrendsVisualPrefs` (SharedPreferences). `MasterSheetTrends` renders only enabled visuals and accepts panel mode. `MasterSheetScreen` hosts the Visuals gear, slim hidden chip, and stacked min-height sheet.

**Tech Stack:** Flutter web, `fl_chart`, `shared_preferences`, existing `Submission` / `MasterSheetStats` / `AppColors`.

**Spec:** `docs/superpowers/specs/2026-07-09-master-sheet-trends-visuals-design.md`

---

## File map

| File | Responsibility |
|------|----------------|
| `lib/utils/master_sheet_stats.dart` | Extend stats with BA-by-employee + membership mix series |
| `lib/utils/trends_visual_prefs.dart` | Load/save visibility + panel mode |
| `lib/widgets/master_sheet_trends.dart` | Compact axes, single-point revenue, conditional charts, new charts |
| `lib/screens/master_sheet_screen.dart` | Visuals gear, panel modes, stacked min-height ~420 |
| `test/utils/master_sheet_stats_test.dart` | Extend for new aggregates |
| `test/utils/trends_visual_prefs_test.dart` | Prefs round-trip |

---

### Task 1: Compact money axis helper + chart polish

**Files:**
- Modify: `lib/widgets/master_sheet_trends.dart`
- Create (optional helper in same file or): keep helpers private in the widget file

- [ ] **Step 1: Add compact money formatter used by both charts**

In `lib/widgets/master_sheet_trends.dart`, add:

```dart
String _compactMoney(double v) {
  final abs = v.abs();
  if (abs >= 1000) {
    final k = v / 1000;
    final s = k == k.roundToDouble()
        ? k.toStringAsFixed(0)
        : k.toStringAsFixed(1);
    return '\$${s}k';
  }
  return _money.format(v);
}
```

- [ ] **Step 2: Fix `_RevenueLineChart` left titles**

Replace left `getTitlesWidget` and `SideTitles` config:

```dart
leftTitles: AxisTitles(
  sideTitles: SideTitles(
    showTitles: true,
    reservedSize: 44,
    interval: maxY <= 0 ? 1 : (maxY * 1.15) / 3,
    getTitlesWidget: (v, meta) {
      if (v == meta.max) return const SizedBox.shrink();
      return Padding(
        padding: const EdgeInsets.only(right: 4),
        child: Text(
          _compactMoney(v),
          style: TextStyles.caption.copyWith(fontSize: 10),
          textAlign: TextAlign.right,
        ),
      );
    },
  ),
),
```

For single-point series (`points.length == 1`):

```dart
isCurved: points.length > 1,
dotData: const FlDotData(show: true),
```

Optionally wrap the chart in a `Column` with a caption when `points.length == 1`:

```dart
Text(
  '${_shortDay.format(points.first.day)} · ${_money.format(points.first.revenue)}',
  style: TextStyles.caption,
  textAlign: TextAlign.center,
)
```

(Pass this from parent or build inside `_RevenueLineChart` below the chart.)

- [ ] **Step 3: Apply same left-axis treatment to `_EmployeeBarChart`**

Same `_compactMoney`, `reservedSize: 44`, limited interval, skip label at `meta.max` if it collides.

- [ ] **Step 4: Analyze**

Run: `flutter analyze lib/widgets/master_sheet_trends.dart`

Expected: No issues.

- [ ] **Step 5: Commit**

```bash
git add lib/widgets/master_sheet_trends.dart
git commit -m "$(cat <<'EOF'
fix: compact Master Sheet chart axis labels

EOF
)"
```

---

### Task 2: Extend stats for BA% and membership mix

**Files:**
- Modify: `lib/utils/master_sheet_stats.dart`
- Modify: `test/utils/master_sheet_stats_test.dart`

- [ ] **Step 1: Write failing tests**

Append to `test/utils/master_sheet_stats_test.dart`:

```dart
  test('employeeBa and membershipMix aggregate per employee', () {
    final a = _sub(
      name: 'Alex',
      at: DateTime(2026, 7, 1, 10),
      counts: const {'basic': 4}, // membership
    );
    // Override talkedTo via a dedicated helper if needed — Submission uses talkedTo: 10 in _sub
    final b = _sub(
      name: 'Blake',
      at: DateTime(2026, 7, 1, 12),
      counts: const {'economy': 3}, // single
    );
    final stats = buildMasterSheetStats(
      submissions: [a, b],
      rangeStart: start,
      rangeEndExclusive: endExclusive,
    );
    expect(stats.employeeBa, isNotEmpty);
    expect(stats.membershipMix, isNotEmpty);
    final alexMix = stats.membershipMix.firstWhere((e) => e.name == 'Alex');
    expect(alexMix.memberships, greaterThan(0));
    final blakeMix = stats.membershipMix.firstWhere((e) => e.name == 'Blake');
    expect(blakeMix.singles, greaterThan(0));
  });
```

Update existing `_sub` in that file if it does not accept `counts` already — it does. Ensure membership id `basic` and single id `economy` match `scorecard_config.dart`.

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/utils/master_sheet_stats_test.dart`

Expected: FAIL — missing fields / getters.

- [ ] **Step 3: Extend models + builder**

In `lib/utils/master_sheet_stats.dart`:

```dart
class EmployeeBa {
  const EmployeeBa({required this.name, required this.ba});
  final String name;
  final double ba;
}

class EmployeeWashMix {
  const EmployeeWashMix({
    required this.name,
    required this.memberships,
    required this.singles,
  });
  final String name;
  final int memberships;
  final int singles;
}
```

Add to `MasterSheetStats`:

```dart
  final List<EmployeeBa> employeeBa;
  final List<EmployeeWashMix> membershipMix;
```

Update empty constructor and return sites to include `employeeBa: []`, `membershipMix: []`.

In the aggregation loop, also track:

```dart
  final byNameSubs = <String, List<Submission>>{};
  // ...
  byNameSubs.putIfAbsent(s.employeeName, () => []).add(s);
```

After ranking by revenue (reuse same topN / Other pattern for consistency), build:

```dart
List<EmployeeBa> buildBa(List<MapEntry<String, double>> ranked) {
  // For each name in ranked (except Other), aggregate BA from byNameSubs:
  // average of submission.businessAverage weighted by talkedTo, or
  // recompute from combined memberships / talkedTo across subs.
}
```

**Explicit BA rule:** For each employee, combine their in-range submissions into one virtual total: `sum(memberships) / sum(talkedTo) * 100` when `sum(talkedTo) > 0`, else average of `conversionRate` / existing `businessAverage` fallback — simplest: create a temporary combined count map + talked sum and use the same math as `Submission.businessAverage` by constructing one aggregate `Submission` via existing screen aggregate pattern OR:

```dart
double baFor(List<Submission> subs) {
  var memb = 0;
  var talked = 0;
  for (final s in subs) {
    memb += s.totalMemberships;
    talked += s.talkedTo;
  }
  if (talked > 0) return memb / talked * 100;
  var washes = 0;
  for (final s in subs) {
    washes += s.totalWashes;
  }
  if (washes == 0) return 0;
  return memb / washes * 100;
}
```

Membership mix:

```dart
EmployeeWashMix(
  name: name,
  memberships: subs.fold(0, (n, s) => n + s.totalMemberships),
  singles: subs.fold(0, (n, s) => n + s.totalSingleWashes),
)
```

Apply same topN + Other collapse: for Other, sum memberships/singles; BA for Other can be weighted by talked across remaining employees.

- [ ] **Step 4: Run tests**

Run: `flutter test test/utils/master_sheet_stats_test.dart`

Expected: All PASS. Fix any call sites that construct `MasterSheetStats` manually (only this file + tests).

- [ ] **Step 5: Commit**

```bash
git add lib/utils/master_sheet_stats.dart test/utils/master_sheet_stats_test.dart
git commit -m "$(cat <<'EOF'
feat: add BA and membership mix Master Sheet stats

EOF
)"
```

---

### Task 3: TrendsVisualPrefs

**Files:**
- Create: `lib/utils/trends_visual_prefs.dart`
- Create: `test/utils/trends_visual_prefs_test.dart`

- [ ] **Step 1: Write failing prefs test**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wiggywash/utils/trends_visual_prefs.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('defaults all visuals on, expanded', () {
    final p = TrendsVisualPrefs.defaults();
    expect(p.panelMode, TrendsPanelMode.expanded);
    expect(p.showSummary, isTrue);
    expect(p.showRevenueOverTime, isTrue);
    expect(p.showByEmployee, isTrue);
    expect(p.showBaByEmployee, isTrue);
    expect(p.showMembershipMix, isTrue);
  });

  test('round-trip save/load', () async {
    final original = TrendsVisualPrefs.defaults().copyWith(
      panelMode: TrendsPanelMode.chipsOnly,
      showRevenueOverTime: false,
      showMembershipMix: false,
    );
    await TrendsVisualPrefs.save(original);
    final loaded = await TrendsVisualPrefs.load();
    expect(loaded.panelMode, TrendsPanelMode.chipsOnly);
    expect(loaded.showRevenueOverTime, isFalse);
    expect(loaded.showMembershipMix, isFalse);
    expect(loaded.showSummary, isTrue);
  });
}
```

- [ ] **Step 2: Run — expect FAIL**

Run: `flutter test test/utils/trends_visual_prefs_test.dart`

- [ ] **Step 3: Implement**

Create `lib/utils/trends_visual_prefs.dart`:

```dart
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

const _kKey = 'ww_master_sheet_trends_visuals';

enum TrendsPanelMode { expanded, chipsOnly, hidden }

class TrendsVisualPrefs {
  const TrendsVisualPrefs({
    required this.panelMode,
    required this.showSummary,
    required this.showRevenueOverTime,
    required this.showByEmployee,
    required this.showBaByEmployee,
    required this.showMembershipMix,
  });

  final TrendsPanelMode panelMode;
  final bool showSummary;
  final bool showRevenueOverTime;
  final bool showByEmployee;
  final bool showBaByEmployee;
  final bool showMembershipMix;

  factory TrendsVisualPrefs.defaults() => const TrendsVisualPrefs(
        panelMode: TrendsPanelMode.expanded,
        showSummary: true,
        showRevenueOverTime: true,
        showByEmployee: true,
        showBaByEmployee: true,
        showMembershipMix: true,
      );

  TrendsVisualPrefs copyWith({
    TrendsPanelMode? panelMode,
    bool? showSummary,
    bool? showRevenueOverTime,
    bool? showByEmployee,
    bool? showBaByEmployee,
    bool? showMembershipMix,
  }) {
    return TrendsVisualPrefs(
      panelMode: panelMode ?? this.panelMode,
      showSummary: showSummary ?? this.showSummary,
      showRevenueOverTime: showRevenueOverTime ?? this.showRevenueOverTime,
      showByEmployee: showByEmployee ?? this.showByEmployee,
      showBaByEmployee: showBaByEmployee ?? this.showBaByEmployee,
      showMembershipMix: showMembershipMix ?? this.showMembershipMix,
    );
  }

  Map<String, dynamic> toJson() => {
        'panelMode': panelMode.name,
        'summary': showSummary,
        'revenueOverTime': showRevenueOverTime,
        'byEmployee': showByEmployee,
        'baByEmployee': showBaByEmployee,
        'membershipMix': showMembershipMix,
      };

  factory TrendsVisualPrefs.fromJson(Map<String, dynamic> json) {
    var mode = TrendsPanelMode.expanded;
    for (final m in TrendsPanelMode.values) {
      if (m.name == json['panelMode']) mode = m;
    }
    return TrendsVisualPrefs(
      panelMode: mode,
      showSummary: json['summary'] as bool? ?? true,
      showRevenueOverTime: json['revenueOverTime'] as bool? ?? true,
      showByEmployee: json['byEmployee'] as bool? ?? true,
      showBaByEmployee: json['baByEmployee'] as bool? ?? true,
      showMembershipMix: json['membershipMix'] as bool? ?? true,
    );
  }

  static Future<TrendsVisualPrefs> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_kKey);
    if (raw == null || raw.isEmpty) return TrendsVisualPrefs.defaults();
    try {
      return TrendsVisualPrefs.fromJson(
          jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return TrendsVisualPrefs.defaults();
    }
  }

  static Future<void> save(TrendsVisualPrefs value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kKey, jsonEncode(value.toJson()));
  }

  bool get anyChartVisible =>
      showRevenueOverTime ||
      showByEmployee ||
      showBaByEmployee ||
      showMembershipMix;

  bool get anyVisible => showSummary || anyChartVisible;
}
```

- [ ] **Step 4: Run tests — PASS**

- [ ] **Step 5: Commit**

```bash
git add lib/utils/trends_visual_prefs.dart test/utils/trends_visual_prefs_test.dart
git commit -m "$(cat <<'EOF'
feat: add Trends visual prefs

EOF
)"
```

---

### Task 4: MasterSheetTrends respects prefs + new charts

**Files:**
- Modify: `lib/widgets/master_sheet_trends.dart`

- [ ] **Step 1: Change constructor**

```dart
class MasterSheetTrends extends StatelessWidget {
  const MasterSheetTrends({
    super.key,
    required this.stats,
    required this.prefs,
  });

  final MasterSheetStats stats;
  final TrendsVisualPrefs prefs;
```

- [ ] **Step 2: Conditional build**

```dart
  @override
  Widget build(BuildContext context) {
    if (prefs.panelMode == TrendsPanelMode.hidden) {
      return const SizedBox.shrink();
    }

    final showCharts = prefs.panelMode == TrendsPanelMode.expanded;
    final children = <Widget>[];

    if (prefs.showSummary) {
      children.add(_SummaryRow(stats: stats));
    }

    if (showCharts) {
      if (prefs.showRevenueOverTime) {
        if (children.isNotEmpty) children.add(const SizedBox(height: 12));
        children.add(_ChartCard(
          title: 'Revenue over time',
          child: SizedBox(
            height: 180,
            child: stats.revenueByDay.isEmpty
                ? const _EmptyChart(message: 'No approved shifts in this period')
                : _RevenueLineChart(points: stats.revenueByDay),
          ),
        ));
      }
      if (prefs.showByEmployee) {
        if (children.isNotEmpty) children.add(const SizedBox(height: 12));
        children.add(_ChartCard(
          title: 'By employee',
          child: SizedBox(
            height: 200,
            child: stats.employeeTotals.isEmpty
                ? const _EmptyChart(message: 'No employee totals yet')
                : _EmployeeBarChart(rows: stats.employeeTotals),
          ),
        ));
      }
      if (prefs.showBaByEmployee) {
        if (children.isNotEmpty) children.add(const SizedBox(height: 12));
        children.add(_ChartCard(
          title: 'BA % by employee',
          child: SizedBox(
            height: 200,
            child: stats.employeeBa.isEmpty
                ? const _EmptyChart(message: 'No BA data yet')
                : _EmployeeBaChart(rows: stats.employeeBa),
          ),
        ));
      }
      if (prefs.showMembershipMix) {
        if (children.isNotEmpty) children.add(const SizedBox(height: 12));
        children.add(_ChartCard(
          title: 'Memberships vs singles',
          child: SizedBox(
            height: 200,
            child: stats.membershipMix.isEmpty
                ? const _EmptyChart(message: 'No wash mix yet')
                : _MembershipMixChart(rows: stats.membershipMix),
          ),
        ));
      }
    }

    if (children.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 12),
        child: Text(
          'No visuals enabled — open Visuals to show charts.',
          style: TextStyles.caption,
          textAlign: TextAlign.center,
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: children,
    );
  }
}
```

- [ ] **Step 3: Add `_EmployeeBaChart`**

Bar chart of `EmployeeBa.ba`, Y 0–max(100, maxBa*1.1), left titles as `42%` style (no money formatter). Navy bars. Name truncation like employee revenue chart.

- [ ] **Step 4: Add `_MembershipMixChart`**

Grouped bars: for each employee, two rods (memberships navy, singles a muted blue e.g. `AppColors.blueSoft` darker or `Color(0xFF5B7C99)`). Use `BarChartGroupData` with two `BarChartRodData`. Legend row under title optional (small caption “Memberships · Singles”).

- [ ] **Step 5: Analyze + fix call sites**

`MasterSheetTrends(stats: stats)` → must pass `prefs` (Task 5 wires it). Temporarily pass `TrendsVisualPrefs.defaults()` if needed so analyze passes mid-task.

- [ ] **Step 6: Commit**

```bash
git add lib/widgets/master_sheet_trends.dart
git commit -m "$(cat <<'EOF'
feat: Trends charts respect visual prefs and add BA/mix charts

EOF
)"
```

---

### Task 5: Visuals gear + stacked min-height on Master Sheet

**Files:**
- Modify: `lib/screens/master_sheet_screen.dart`

- [ ] **Step 1: State on `_MasterSheetScreenState`**

```dart
TrendsVisualPrefs _trendsPrefs = TrendsVisualPrefs.defaults();
```

In `initState`, load:

```dart
TrendsVisualPrefs.load().then((p) {
  if (mounted) setState(() => _trendsPrefs = p);
});
```

```dart
Future<void> _setTrendsPrefs(TrendsVisualPrefs p) async {
  setState(() => _trendsPrefs = p);
  await TrendsVisualPrefs.save(p);
}
```

Pass `trendsPrefs` + `onTrendsPrefs` into `_MainPanel`.

- [ ] **Step 2: Visuals menu UI**

In `_buildTrendsAndTable`, replace static Trends header with:

```dart
Row(
  children: [
    const Expanded(child: Text('Trends', style: TextStyles.subheading)),
    IconButton(
      tooltip: 'Visuals',
      icon: const Icon(Icons.tune_rounded),
      onPressed: () => _openTrendsVisuals(context),
    ),
  ],
)
```

Implement `_openTrendsVisuals` as a modal bottom sheet / dialog with:

- Checkboxes bound to each `show*` flag → `onTrendsPrefs(prefs.copyWith(...))`
- Radio / segmented for `TrendsPanelMode`
- Show all / Reset buttons → `TrendsVisualPrefs.defaults()`

(Can be a private method on `_MainPanel` or a small private widget in the same file.)

- [ ] **Step 3: Hidden panel restore chip**

When `trendsPrefs.panelMode == TrendsPanelMode.hidden`:

```dart
Padding(
  padding: const EdgeInsets.fromLTRB(14, 8, 14, 0),
  child: Align(
    alignment: Alignment.centerLeft,
    child: TextButton.icon(
      onPressed: () => onTrendsPrefs(
        trendsPrefs.copyWith(panelMode: TrendsPanelMode.expanded),
      ),
      icon: const Icon(Icons.visibility_outlined, size: 18),
      label: const Text('Trends (hidden) · Show'),
    ),
  ),
)
```

Do not render full Trends body when hidden (prefs already make `MasterSheetTrends` empty — still show the chip above the sheet).

- [ ] **Step 4: Stacked layout min-height**

Replace the stacked `SizedBox` height logic:

```dart
SizedBox(
  height: math.max(420, constraints.maxHeight * 0.45),
  child: table,
)
```

Or simply:

```dart
SizedBox(
  height: 420,
  child: table,
)
```

Spec says **minimum ~420px** — use:

```dart
final sheetH = constraints.maxHeight.isFinite
    ? math.max(420.0, constraints.maxHeight * 0.5)
    : 420.0;
```

Prefer **fixed min without crushing**: `height: max(420, min(constraints.maxHeight - 24, constraints.maxHeight))` is wrong for ListView. Spec: natural trends height + sheet min 420. So:

```dart
SizedBox(height: 420, child: table)
```

is enough for v1 (ListView scrolls). Import `dart:math` as `math` if using `max`.

- [ ] **Step 5: Wire `MasterSheetTrends(stats: stats, prefs: trendsPrefs)`**

- [ ] **Step 6: Analyze + test + commit**

```bash
flutter analyze
flutter test
git add lib/screens/master_sheet_screen.dart lib/widgets/master_sheet_trends.dart
git commit -m "$(cat <<'EOF'
feat: Trends Visuals gear and stacked sheet min-height

EOF
)"
```

---

### Task 6: Verification pass

- [ ] **Step 1: Full suite**

```bash
flutter analyze
flutter test
```

Expected: clean; all tests pass.

- [ ] **Step 2: Manual checklist**

1. Revenue Y-axis shows `$1k` style — no overlapping `$1,000b`.
2. Single-day period: one clear point + readable value.
3. Stacked layout: sheet ~420px+; page scrolls; grid usable.
4. Visuals gear toggles hide/show each chart; persists after hot restart.
5. Chips only / Hidden free space; Show chip restores Trends.
6. BA % and Memberships vs singles render for multi-employee data.
7. Sheet tools / export unchanged.

- [ ] **Step 3: Commit fixes if any**

```bash
git add -u
git commit -m "$(cat <<'EOF'
fix: Trends visuals polish from verification

EOF
)"
```

(Skip empty commit.)

---

## Spec coverage

| Spec item | Task |
|-----------|------|
| Compact Y-axis / no overlap | Task 1 |
| Single-day revenue readable | Task 1 |
| Stacked min-height ~420 + scroll | Task 5 |
| Trends Visuals gear | Task 5 |
| Toggle chips + 4 charts | Task 3–5 |
| BA % + membership mix charts | Task 2 + 4 |
| Panel expanded/chips/hidden + restore | Task 3 + 5 |
| Device prefs | Task 3 |
| Empty / all-off hint | Task 4 |
| Unit tests aggregates + prefs | Task 2–3 |
| No score leaderboard / freeform | Honored |

---

## Execution handoff

Plan complete. After user picks an execution mode, use the matching skill only.
