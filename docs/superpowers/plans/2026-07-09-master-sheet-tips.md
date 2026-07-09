# Master Sheet Trends + Tips Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace breakdown Help with Tips, and add Master Sheet period stats, charts, remembered vertical/horizontal layout, and light styling polish — all on Flutter.

**Architecture:** Pure aggregation helpers turn approved `Submission`s + a date range into summary stats and chart series. Master Sheet hosts stats → charts → table, with a layout preference in `SharedPreferences`. Tips is a static audience-aware screen opened from the existing help icons.

**Tech Stack:** Flutter web, `fl_chart`, `shared_preferences` (already in app), existing `Store` / `Submission` / `AppColors`.

**Spec:** `docs/superpowers/specs/2026-07-09-master-sheet-tips-design.md`

---

## File map

| File | Responsibility |
|------|----------------|
| `lib/screens/tips_screen.dart` | Tips UI (employee / manager); replaces `help_screen.dart` |
| `lib/utils/master_sheet_stats.dart` | Pure aggregates: summary, revenue-by-day, employee totals |
| `lib/widgets/master_sheet_trends.dart` | Summary chips + two charts (presentation only) |
| `lib/screens/master_sheet_screen.dart` | Wire trends, layout toggle, prefs, styling |
| `lib/screens/scorecard_screen.dart` | Help icon → Tips (employee) |
| `lib/screens/manager_screen.dart` | Help icon → Tips (manager) |
| `pubspec.yaml` | Add `fl_chart`; remove unused help image assets |
| `test/utils/master_sheet_stats_test.dart` | Unit tests for aggregates |
| Delete: `lib/screens/help_screen.dart`, `assets/help_tap_total.png`, `assets/help_full_breakdown.png` | Obsolete breakdown walkthrough |

---

### Task 1: Tips screen (replace HelpScreen)

**Files:**
- Create: `lib/screens/tips_screen.dart`
- Modify: `lib/screens/scorecard_screen.dart` (help IconButton ~264–271)
- Modify: `lib/screens/manager_screen.dart` (help IconButton ~263–270)
- Delete: `lib/screens/help_screen.dart`
- Modify: `pubspec.yaml` — remove `assets/help_tap_total.png` and `assets/help_full_breakdown.png`
- Delete: `assets/help_tap_total.png`, `assets/help_full_breakdown.png`

- [ ] **Step 1: Create Tips screen**

Create `lib/screens/tips_screen.dart`:

```dart
import 'package:flutter/material.dart';

import '../theme.dart';

enum TipsAudience { employee, manager }

class TipsScreen extends StatelessWidget {
  const TipsScreen({super.key, this.audience = TipsAudience.employee});

  final TipsAudience audience;

  bool get _isManager => audience == TipsAudience.manager;

  @override
  Widget build(BuildContext context) {
    final tips = _isManager ? _managerTips : _employeeTips;
    return Scaffold(
      appBar: AppBar(title: Text(_isManager ? 'Manager tips' : 'Tips')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
            children: [
              AppCard(
                padding: const EdgeInsets.all(18),
                child: Row(
                  children: [
                    Container(
                      width: 46,
                      height: 46,
                      decoration: BoxDecoration(
                        color: AppColors.blueSoft,
                        borderRadius: BorderRadius.circular(AppRadius.field),
                      ),
                      child: const Icon(Icons.lightbulb_outline_rounded,
                          color: AppColors.navy),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Text(
                        _isManager
                            ? 'Quick guide to the manager tabs and sharing access with your team.'
                            : 'Quick guide to signing in and submitting your scorecard.',
                        style: TextStyles.body,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              for (var i = 0; i < tips.length; i++) ...[
                if (i > 0) const SizedBox(height: 12),
                _TipCard(
                  number: i + 1,
                  title: tips[i].title,
                  body: tips[i].body,
                  icon: tips[i].icon,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _Tip {
  const _Tip(this.title, this.body, this.icon);
  final String title;
  final String body;
  final IconData icon;
}

const _employeeTips = [
  _Tip(
    'Sign in',
    'Enter your company code, pick your location, then your name. Enter your PIN if asked.',
    Icons.login_rounded,
  ),
  _Tip(
    'Tally and submit',
    'Count memberships, washes, and shop sales, then tap Submit Shift when you are done.',
    Icons.fact_check_outlined,
  ),
  _Tip(
    'Your total today',
    'Tap Your total today at the top of the scorecard to see a line-by-line breakdown.',
    Icons.touch_app_outlined,
  ),
  _Tip(
    'Sharing a device',
    'Use Switch user in the profile menu so the next person can sign in as themselves.',
    Icons.people_outline_rounded,
  ),
];

const _managerTips = [
  _Tip(
    'Dashboard',
    'Live team totals, pending approvals, and challenges for the active location.',
    Icons.dashboard_rounded,
  ),
  _Tip(
    'Master Sheet',
    'History grid, export (Excel/CSV), and trends/stats for the selected period.',
    Icons.table_chart_outlined,
  ),
  _Tip(
    'Team',
    'Roster, company code for employees, and switch or add locations.',
    Icons.group_outlined,
  ),
  _Tip(
    'Prices',
    'Set membership, wash, and shop prices used on scorecards and totals.',
    Icons.sell_outlined,
  ),
  _Tip(
    'Employee access',
    'Share your company code (shown on Team). Employees do not sign in with Google.',
    Icons.qr_code_2_rounded,
  ),
];

class _TipCard extends StatelessWidget {
  const _TipCard({
    required this.number,
    required this.title,
    required this.body,
    required this.icon,
  });

  final int number;
  final String title;
  final String body;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 32,
            height: 32,
            alignment: Alignment.center,
            decoration: const BoxDecoration(
              color: AppColors.navy,
              shape: BoxShape.circle,
            ),
            child: Text(
              '$number',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(icon, size: 18, color: AppColors.navy),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(title, style: TextStyles.subheading),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(body, style: TextStyles.caption),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
```

Confirm `AppRadius.field` exists in `theme.dart` (it does via existing `AppCard` / help screen). If the analyzer complains, use `BorderRadius.circular(12)` instead.

- [ ] **Step 2: Retarget entry points**

In `scorecard_screen.dart`:
- Change import from `help_screen.dart` to `tips_screen.dart`
- Replace `HelpScreen(audience: HelpAudience.employee)` with `TipsScreen(audience: TipsAudience.employee)`
- Tooltip: `'Tips'`

In `manager_screen.dart`: same with `TipsAudience.manager`.

- [ ] **Step 3: Remove obsolete help**

- Delete `lib/screens/help_screen.dart`
- Delete `assets/help_tap_total.png` and `assets/help_full_breakdown.png`
- Remove those two lines from `pubspec.yaml` `assets:`

- [ ] **Step 4: Verify analyze**

Run: `flutter analyze`
Expected: No issues related to Tips/Help imports.

- [ ] **Step 5: Commit**

```bash
git add lib/screens/tips_screen.dart lib/screens/scorecard_screen.dart lib/screens/manager_screen.dart pubspec.yaml
git rm lib/screens/help_screen.dart assets/help_tap_total.png assets/help_full_breakdown.png
git commit -m "feat: replace breakdown help with Tips screen"
```

---

### Task 2: Aggregation helpers (TDD)

**Files:**
- Create: `lib/utils/master_sheet_stats.dart`
- Test: `test/utils/master_sheet_stats_test.dart`

- [ ] **Step 1: Write failing tests**

Create `test/utils/master_sheet_stats_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:wiggywash/models/submission.dart';
import 'package:wiggywash/utils/master_sheet_stats.dart';

Submission _sub({
  required String name,
  required DateTime at,
  Map<String, int> counts = const {},
}) {
  return Submission(
    id: '${name}_${at.millisecondsSinceEpoch}',
    employeeName: name,
    baGoal: 40,
    counts: counts,
    submittedAt: at,
    approved: true,
    talkedTo: 10,
  );
}

void main() {
  final start = DateTime(2026, 7, 1);
  final endExclusive = DateTime(2026, 7, 4); // Jul 1–3 inclusive window

  test('empty period yields zero summary and empty series', () {
    final stats = buildMasterSheetStats(
      submissions: const [],
      rangeStart: start,
      rangeEndExclusive: endExclusive,
    );
    expect(stats.totalRevenue, 0);
    expect(stats.shiftCount, 0);
    expect(stats.avgRevenuePerShift, 0);
    expect(stats.revenueByDay, isEmpty);
    expect(stats.employeeTotals, isEmpty);
  });

  test('summary and revenue-by-day use grandTotalRevenue', () {
    // Use empty counts → revenue 0 still counts as shifts; add known prices via
    // counts only if priceOf is available in tests. Prefer asserting shiftCount
    // and day bucketing with revenue from grandTotalRevenue.
    final a = _sub(name: 'Alex', at: DateTime(2026, 7, 1, 10));
    final b = _sub(name: 'Alex', at: DateTime(2026, 7, 1, 18));
    final c = _sub(name: 'Blake', at: DateTime(2026, 7, 2, 12));
    final stats = buildMasterSheetStats(
      submissions: [a, b, c],
      rangeStart: start,
      rangeEndExclusive: endExclusive,
    );
    expect(stats.shiftCount, 3);
    expect(stats.totalRevenue, a.grandTotalRevenue + b.grandTotalRevenue + c.grandTotalRevenue);
    expect(stats.avgRevenuePerShift, stats.totalRevenue / 3);
    expect(stats.revenueByDay.length, 2);
    expect(stats.revenueByDay[0].day, DateTime(2026, 7, 1));
    expect(stats.revenueByDay[1].day, DateTime(2026, 7, 2));
  });

  test('employee totals sorted descending and topN collapses Other', () {
    final subs = [
      for (var i = 0; i < 10; i++)
        _sub(name: 'E$i', at: DateTime(2026, 7, 1, i + 1)),
    ];
    // Force distinct revenues by copying with different talkedTo only if needed;
    // with empty counts all revenues are 0 — still test name grouping + Other.
    final stats = buildMasterSheetStats(
      submissions: subs,
      rangeStart: start,
      rangeEndExclusive: endExclusive,
      employeeTopN: 3,
    );
    expect(stats.employeeTotals.length, lessThanOrEqualTo(4)); // 3 + Other
    final names = stats.employeeTotals.map((e) => e.name).toList();
    if (stats.employeeTotals.length == 4) {
      expect(names.last, 'Other');
    }
  });

  test('submissions outside range are ignored', () {
    final inside = _sub(name: 'Alex', at: DateTime(2026, 7, 2));
    final outside = _sub(name: 'Blake', at: DateTime(2026, 6, 30));
    final stats = buildMasterSheetStats(
      submissions: [inside, outside],
      rangeStart: start,
      rangeEndExclusive: endExclusive,
    );
    expect(stats.shiftCount, 1);
    expect(stats.employeeTotals.single.name, 'Alex');
  });
}
```

- [ ] **Step 2: Run tests — expect FAIL**

Run: `flutter test test/utils/master_sheet_stats_test.dart`
Expected: FAIL (library / symbols not found).

- [ ] **Step 3: Implement helpers**

Create `lib/utils/master_sheet_stats.dart`:

```dart
import '../models/submission.dart';

class DayRevenue {
  const DayRevenue({required this.day, required this.revenue});
  final DateTime day; // date-only (year, month, day)
  final double revenue;
}

class EmployeeRevenue {
  const EmployeeRevenue({required this.name, required this.revenue});
  final String name;
  final double revenue;
}

class MasterSheetStats {
  const MasterSheetStats({
    required this.totalRevenue,
    required this.shiftCount,
    required this.avgRevenuePerShift,
    required this.revenueByDay,
    required this.employeeTotals,
  });

  final double totalRevenue;
  final int shiftCount;
  final double avgRevenuePerShift;
  final List<DayRevenue> revenueByDay;
  final List<EmployeeRevenue> employeeTotals;
}

/// Aggregates [submissions] in `[rangeStart, rangeEndExclusive)`.
MasterSheetStats buildMasterSheetStats({
  required List<Submission> submissions,
  required DateTime rangeStart,
  required DateTime rangeEndExclusive,
  int employeeTopN = 8,
}) {
  final inRange = submissions.where((s) {
    final t = s.submittedAt;
    return !t.isBefore(rangeStart) && t.isBefore(rangeEndExclusive);
  }).toList();

  if (inRange.isEmpty) {
    return const MasterSheetStats(
      totalRevenue: 0,
      shiftCount: 0,
      avgRevenuePerShift: 0,
      revenueByDay: [],
      employeeTotals: [],
    );
  }

  var total = 0.0;
  final byDay = <DateTime, double>{};
  final byName = <String, double>{};

  for (final s in inRange) {
    final rev = s.grandTotalRevenue;
    total += rev;
    final day = DateTime(s.submittedAt.year, s.submittedAt.month, s.submittedAt.day);
    byDay[day] = (byDay[day] ?? 0) + rev;
    byName[s.employeeName] = (byName[s.employeeName] ?? 0) + rev;
  }

  final days = byDay.keys.toList()..sort();
  final revenueByDay = [
    for (final d in days) DayRevenue(day: d, revenue: byDay[d]!),
  ];

  final ranked = byName.entries.toList()
    ..sort((a, b) => b.value.compareTo(a.value));
  List<EmployeeRevenue> employeeTotals;
  if (ranked.length <= employeeTopN) {
    employeeTotals = [
      for (final e in ranked) EmployeeRevenue(name: e.key, revenue: e.value),
    ];
  } else {
    final top = ranked.take(employeeTopN).toList();
    final other = ranked.skip(employeeTopN).fold<double>(0, (s, e) => s + e.value);
    employeeTotals = [
      for (final e in top) EmployeeRevenue(name: e.key, revenue: e.value),
      EmployeeRevenue(name: 'Other', revenue: other),
    ];
  }

  return MasterSheetStats(
    totalRevenue: total,
    shiftCount: inRange.length,
    avgRevenuePerShift: total / inRange.length,
    revenueByDay: revenueByDay,
    employeeTotals: employeeTotals,
  );
}
```

- [ ] **Step 4: Run tests — expect PASS**

Run: `flutter test test/utils/master_sheet_stats_test.dart`
Expected: All tests PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/utils/master_sheet_stats.dart test/utils/master_sheet_stats_test.dart
git commit -m "feat: Master Sheet stats aggregation helpers"
```

---

### Task 3: Add fl_chart + trends widgets

**Files:**
- Modify: `pubspec.yaml` — add `fl_chart: ^0.70.2` (or latest compatible; run `flutter pub get` and adjust if needed)
- Create: `lib/widgets/master_sheet_trends.dart`

- [ ] **Step 1: Add dependency**

In `pubspec.yaml` under `dependencies:`:

```yaml
  fl_chart: ^0.70.2
```

Run: `flutter pub get`
Expected: Resolves successfully.

- [ ] **Step 2: Create trends widget**

Create `lib/widgets/master_sheet_trends.dart`:

```dart
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../theme.dart';
import '../utils/master_sheet_stats.dart';

final _money = NumberFormat.currency(symbol: '\$', decimalDigits: 0);
final _shortDay = DateFormat('M/d');

/// Summary chips + revenue-over-time + employee comparison charts.
class MasterSheetTrends extends StatelessWidget {
  const MasterSheetTrends({super.key, required this.stats});

  final MasterSheetStats stats;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _SummaryRow(stats: stats),
        const SizedBox(height: 12),
        _ChartCard(
          title: 'Revenue over time',
          child: SizedBox(
            height: 180,
            child: stats.revenueByDay.isEmpty
                ? const _EmptyChart(message: 'No approved shifts in this period')
                : _RevenueLineChart(points: stats.revenueByDay),
          ),
        ),
        const SizedBox(height: 12),
        _ChartCard(
          title: 'By employee',
          child: SizedBox(
            height: 200,
            child: stats.employeeTotals.isEmpty
                ? const _EmptyChart(message: 'No employee totals yet')
                : _EmployeeBarChart(rows: stats.employeeTotals),
          ),
        ),
      ],
    );
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({required this.stats});
  final MasterSheetStats stats;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _StatChip(
            label: 'Period total',
            value: _money.format(stats.totalRevenue),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _StatChip(
            label: 'Shifts',
            value: '${stats.shiftCount}',
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _StatChip(
            label: 'Avg / shift',
            value: _money.format(stats.avgRevenuePerShift),
          ),
        ),
      ],
    );
  }
}

class _StatChip extends StatelessWidget {
  const _StatChip({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyles.caption),
          const SizedBox(height: 4),
          Text(value, style: TextStyles.subheading),
        ],
      ),
    );
  }
}

class _ChartCard extends StatelessWidget {
  const _ChartCard({required this.title, required this.child});
  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(title, style: TextStyles.subheading),
          const SizedBox(height: 8),
          child,
        ],
      ),
    );
  }
}

class _EmptyChart extends StatelessWidget {
  const _EmptyChart({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(message, style: TextStyles.caption),
    );
  }
}

class _RevenueLineChart extends StatelessWidget {
  const _RevenueLineChart({required this.points});
  final List<DayRevenue> points;

  @override
  Widget build(BuildContext context) {
    final spots = [
      for (var i = 0; i < points.length; i++)
        FlSpot(i.toDouble(), points[i].revenue),
    ];
    final maxY = points.map((p) => p.revenue).fold<double>(0, (a, b) => a > b ? a : b);
    return LineChart(
      LineChartData(
        minY: 0,
        maxY: maxY <= 0 ? 1 : maxY * 1.15,
        gridData: const FlGridData(show: true, drawVerticalLine: false),
        borderData: FlBorderData(show: false),
        titlesData: FlTitlesData(
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 40,
              getTitlesWidget: (v, _) => Text(
                _money.format(v),
                style: TextStyles.caption.copyWith(fontSize: 10),
              ),
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              interval: 1,
              getTitlesWidget: (v, _) {
                final i = v.round();
                if (i < 0 || i >= points.length) return const SizedBox.shrink();
                return Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    _shortDay.format(points[i].day),
                    style: TextStyles.caption.copyWith(fontSize: 10),
                  ),
                );
              },
            ),
          ),
        ),
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            color: AppColors.navy,
            barWidth: 3,
            dotData: const FlDotData(show: true),
            belowBarData: BarAreaData(
              show: true,
              color: AppColors.blueSoft.withValues(alpha: 0.8),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmployeeBarChart extends StatelessWidget {
  const _EmployeeBarChart({required this.rows});
  final List<EmployeeRevenue> rows;

  @override
  Widget build(BuildContext context) {
    final maxY = rows.map((e) => e.revenue).fold<double>(0, (a, b) => a > b ? a : b);
    return BarChart(
      BarChartData(
        maxY: maxY <= 0 ? 1 : maxY * 1.15,
        gridData: const FlGridData(show: true, drawVerticalLine: false),
        borderData: FlBorderData(show: false),
        titlesData: FlTitlesData(
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 40,
              getTitlesWidget: (v, _) => Text(
                _money.format(v),
                style: TextStyles.caption.copyWith(fontSize: 10),
              ),
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (v, _) {
                final i = v.toInt();
                if (i < 0 || i >= rows.length) return const SizedBox.shrink();
                final label = rows[i].name;
                final short = label.length > 8 ? '${label.substring(0, 7)}…' : label;
                return Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(short, style: TextStyles.caption.copyWith(fontSize: 10)),
                );
              },
            ),
          ),
        ),
        barGroups: [
          for (var i = 0; i < rows.length; i++)
            BarChartGroupData(
              x: i,
              barRods: [
                BarChartRodData(
                  toY: rows[i].revenue,
                  color: AppColors.navy,
                  width: 14,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                ),
              ],
            ),
        ],
      ),
    );
  }
}
```

If `withValues` is unavailable on the SDK in CI, use `AppColors.blueSoft.withOpacity(0.8)`.

- [ ] **Step 3: Analyze**

Run: `flutter analyze lib/widgets/master_sheet_trends.dart`
Expected: No issues (or only fixable deprecations).

- [ ] **Step 4: Commit**

```bash
git add pubspec.yaml pubspec.lock lib/widgets/master_sheet_trends.dart
git commit -m "feat: Master Sheet trends charts widget"
```

---

### Task 4: Wire trends + layout orientation into Master Sheet

**Files:**
- Modify: `lib/screens/master_sheet_screen.dart`
- Modify: `lib/services/store.dart` (optional thin prefs helpers) **or** read/write prefs locally in Master Sheet state

Prefer **local prefs in Master Sheet** to avoid bloating `Store` (YAGNI).

- [ ] **Step 1: Add layout enum + prefs load/save in Master Sheet state**

Near top of `master_sheet_screen.dart` (after imports):

```dart
import 'package:shared_preferences/shared_preferences.dart';

import '../utils/master_sheet_stats.dart';
import '../widgets/master_sheet_trends.dart';

enum MasterSheetLayout { vertical, horizontal }

const _kMasterSheetLayout = 'ww_master_sheet_layout';
```

In `_MasterSheetScreenState`:

```dart
  MasterSheetLayout _layout = MasterSheetLayout.vertical;

  @override
  void initState() {
    super.initState();
    _loadLayoutPref();
  }

  Future<void> _loadLayoutPref() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_kMasterSheetLayout);
    if (!mounted) return;
    if (raw == MasterSheetLayout.horizontal.name) {
      setState(() => _layout = MasterSheetLayout.horizontal);
    }
  }

  Future<void> _setLayout(MasterSheetLayout layout) async {
    setState(() => _layout = layout);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kMasterSheetLayout, layout.name);
  }
```

- [ ] **Step 2: Derive stats from current `_scope` / custom range**

Add a getter on `_MasterSheetScreenState` that matches how `_scope` filters dates:

```dart
  (DateTime, DateTime) _statsRange() {
    if (_customRange != null) {
      return (
        DateTime(_customRange!.start.year, _customRange!.start.month, _customRange!.start.day),
        DateTime(_customRange!.end.year, _customRange!.end.month, _customRange!.end.day)
            .add(const Duration(days: 1)),
      );
    }
    if (_view == _View.team) {
      final d = DateTime(_anchor.year, _anchor.month, _anchor.day);
      return (d, d.add(const Duration(days: 1)));
    }
    // month / member views: whole month of _anchor
    final start = DateTime(_anchor.year, _anchor.month, 1);
    final end = DateTime(_anchor.year, _anchor.month + 1, 1);
    return (start, end);
  }

  MasterSheetStats get _stats {
    final range = _statsRange();
    // Use approved submissions for the period (same pool as Master Sheet).
    // For member view, optionally filter to _member — keep period-wide for trends
    // unless member drill-down should narrow charts; Spec: sync with period controls.
    var list = Store.instance.approvedSubmissions;
    if (_view == _View.member && _member != null) {
      list = list.where((s) => s.employeeName == _member).toList();
    }
    return buildMasterSheetStats(
      submissions: list,
      rangeStart: range.$1,
      rangeEndExclusive: range.$2,
    );
  }
```

- [ ] **Step 3: App bar layout toggle**

In Master Sheet `AppBar.actions`, before `ProfileAction`, add:

```dart
          IconButton(
            tooltip: _layout == MasterSheetLayout.vertical
                ? 'Switch to side-by-side layout'
                : 'Switch to stacked layout',
            onPressed: () => _setLayout(
              _layout == MasterSheetLayout.vertical
                  ? MasterSheetLayout.horizontal
                  : MasterSheetLayout.vertical,
            ),
            icon: Icon(
              _layout == MasterSheetLayout.vertical
                  ? Icons.view_agenda_outlined
                  : Icons.view_column_outlined,
            ),
          ),
```

- [ ] **Step 4: Body layout — stats → chart → table**

Locate the main body `ListView` / column that builds the grid. Insert trends **above** the table.

Use `LayoutBuilder` so horizontal only applies when `maxWidth >= 900`:

```dart
Widget _buildTrendsAndTable({required Widget table}) {
  final trends = MasterSheetTrends(stats: _stats);
  return LayoutBuilder(
    builder: (context, constraints) {
      final wide = constraints.maxWidth >= 900;
      final sideBySide =
          _layout == MasterSheetLayout.horizontal && wide;
      if (!sideBySide) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            trends,
            const SizedBox(height: 16),
            table,
          ],
        );
      }
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(flex: 2, child: trends),
          const SizedBox(width: 16),
          Expanded(flex: 3, child: table),
        ],
      );
    },
  );
}
```

Wrap the existing table widget with `_buildTrendsAndTable(table: ...)`. Keep period controls / view chips above this block (unchanged).

- [ ] **Step 5: Manual check + analyze**

Run: `flutter analyze`
Expected: No issues.

Manual: open Master Sheet → see three summary chips + two charts; toggle layout on a wide window; reload and confirm layout preference sticks.

- [ ] **Step 6: Commit**

```bash
git add lib/screens/master_sheet_screen.dart
git commit -m "feat: wire Master Sheet trends and layout preference"
```

---

### Task 5: Styling polish pass

**Files:**
- Modify: `lib/screens/master_sheet_screen.dart` (spacing, section padding)
- Modify: `lib/widgets/master_sheet_trends.dart` if needed

- [ ] **Step 1: Hierarchy pass**

Ensure Master Sheet body padding is consistent (`fromLTRB(14, 14, 14, 24)` or match existing). Add a small section label above trends if missing, e.g. `Text('Trends', style: TextStyles.subheading)` — only if it improves scanability without clutter.

Tighten hairline borders / `AppCard` usage so stats → charts → table read as one composition (no extra nested cards around the whole page).

Do **not** restyle login, scorecard, or unrelated manager screens.

- [ ] **Step 2: Analyze + test**

Run:

```bash
flutter analyze
flutter test test/utils/master_sheet_stats_test.dart
```

Expected: clean analyze; stats tests pass.

- [ ] **Step 3: Commit**

```bash
git add lib/screens/master_sheet_screen.dart lib/widgets/master_sheet_trends.dart
git commit -m "style: polish Master Sheet trends hierarchy"
```

---

### Task 6: Spec status + smoke checklist

- [ ] **Step 1: Update spec status if not already Approved**

In `docs/superpowers/specs/2026-07-09-master-sheet-tips-design.md`, ensure `**Status:** Approved`.

- [ ] **Step 2: Smoke checklist (manual)**

- [ ] Employee help icon → Tips (employee copy, no breakdown screenshots)
- [ ] Manager help icon → Tips (nav tips)
- [ ] Master Sheet shows period total / shifts / avg
- [ ] Charts update when day/week/month/custom range changes
- [ ] Empty period shows placeholder, not crash
- [ ] Layout toggle persists after refresh
- [ ] Narrow width always stacks even if horizontal selected
- [ ] Export still works (xlsx/csv/clipboard)

- [ ] **Step 3: Final commit if any doc tweaks**

```bash
git add docs/superpowers/specs/2026-07-09-master-sheet-tips-design.md
git commit -m "docs: mark Master Sheet tips spec approved"
```

(Skip if already committed with Approved status.)

---

## Spec coverage check

| Spec requirement | Task |
|------------------|------|
| Tips replace HelpScreen | Task 1 |
| Employee / manager tip content | Task 1 |
| Remove annotated help assets | Task 1 |
| Summary chips | Tasks 2–4 |
| Revenue over time chart | Tasks 3–4 |
| Employee comparison (top N + Other) | Tasks 2–4 |
| Reuse period controls | Task 4 |
| Vertical / horizontal + prefs | Task 4 |
| Narrow fallback to stacked | Task 4 |
| Styling polish | Task 5 |
| Empty period handling | Tasks 2–3 |
| Unit tests for aggregates | Task 2 |
| Stay on Flutter / no React | All tasks |
| No inline Excel editing | Explicitly omitted |

## Placeholder / consistency check

- Types: `MasterSheetStats`, `DayRevenue`, `EmployeeRevenue`, `MasterSheetLayout`, `TipsAudience` — used consistently across tasks.
- Prefs key: `ww_master_sheet_layout`.
- Chart package: `fl_chart`.
- No TBD / “implement later” steps remain.
