# Dashboard Cards + Brand Color Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add List/Cards toggle with mini scorecard grid on the manager Team Dashboard, plus a Settings tab that saves company `primaryColor` and applies it as an accent-only theme company-wide.

**Architecture:** Device prefs drive dashboard layout. Mini scorecard widget aggregates period submissions into per-line-item rows. Settings writes `companies/{id}.primaryColor`; `MaterialApp` rebuilds `buildTheme(primary:)` from `Store.activeCompany` so employees and managers share the accent.

**Tech Stack:** Flutter, SharedPreferences, existing Firestore `Company.primaryColor`, `ThemeData` / `ColorScheme`.

**Spec:** `docs/superpowers/specs/2026-07-09-dashboard-cards-brand-color-design.md`

**Git tip:** If `git commit -m` fails with `unknown option trailer`, use:
`printf '%s\n' 'message' > /tmp/commitmsg.txt && /usr/bin/git commit -F /tmp/commitmsg.txt`

---

## File map

| File | Responsibility |
|------|----------------|
| `lib/utils/brand_color.dart` | Parse hex → `Color?`; format `Color` → `#RRGGBB` |
| `lib/widgets/mini_scorecard_card.dart` | Glanceable per-employee card (name, BA, line items, revenue) |
| `lib/screens/manager_screen.dart` | List/Cards toggle, prefs, grid vs list |
| `lib/screens/settings_screen.dart` | Brand color presets + picker + save |
| `lib/widgets/manager_shell.dart` | Add Settings destination |
| `lib/services/store.dart` | `updateCompanyPrimaryColor` |
| `lib/theme.dart` | `buildTheme({Color? primary})` accent-only |
| `lib/main.dart` | Theme from `Store.activeCompany?.primaryColor` |
| `test/utils/brand_color_test.dart` | Hex parse/format tests |
| `test/widgets/mini_scorecard_card_test.dart` | Hides zero line items |

---

### Task 1: Brand color helpers (TDD)

**Files:**
- Create: `lib/utils/brand_color.dart`
- Test: `test/utils/brand_color_test.dart`

- [ ] **Step 1: Write failing tests**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wiggywash/utils/brand_color.dart';

void main() {
  test('parseBrandColor accepts #RRGGBB', () {
    expect(parseBrandColor('#2E7D52'), const Color(0xFF2E7D52));
  });

  test('parseBrandColor accepts RRGGBB without hash', () {
    expect(parseBrandColor('1B2A4A'), const Color(0xFF1B2A4A));
  });

  test('parseBrandColor returns null for invalid', () {
    expect(parseBrandColor(null), isNull);
    expect(parseBrandColor(''), isNull);
    expect(parseBrandColor('zzz'), isNull);
    expect(parseBrandColor('#12'), isNull);
  });

  test('formatBrandColor writes #RRGGBB', () {
    expect(formatBrandColor(const Color(0xFF2E7D52)), '#2E7D52');
  });
}
```

- [ ] **Step 2: Run — expect FAIL**

Run: `flutter test test/utils/brand_color_test.dart`  
Expected: FAIL (library not found).

- [ ] **Step 3: Implement**

```dart
import 'package:flutter/material.dart';

/// Parses `#RRGGBB` or `RRGGBB` into a Color. Returns null if invalid.
Color? parseBrandColor(String? raw) {
  if (raw == null) return null;
  var s = raw.trim();
  if (s.startsWith('#')) s = s.substring(1);
  if (s.length != 6) return null;
  final value = int.tryParse(s, radix: 16);
  if (value == null) return null;
  return Color(0xFF000000 | value);
}

String formatBrandColor(Color color) {
  final rgb = color.toARGB32() & 0xFFFFFF;
  return '#${rgb.toRadixString(16).padLeft(6, '0').toUpperCase()}';
}
```

If `toARGB32` is unavailable on the SDK, use:
`(((color.a * 255).round() << 24) | ((color.r * 255).round() << 16) | ((color.g * 255).round() << 8) | (color.b * 255).round())`  
or the older `color.value` if still present — pick what `flutter analyze` accepts.

- [ ] **Step 4: Run — expect PASS**

Run: `flutter test test/utils/brand_color_test.dart`

- [ ] **Step 5: Commit**

```bash
git add lib/utils/brand_color.dart test/utils/brand_color_test.dart
git commit -m "feat: brand color hex parse/format helpers"
```

---

### Task 2: Mini scorecard card widget (TDD)

**Files:**
- Create: `lib/widgets/mini_scorecard_card.dart`
- Test: `test/widgets/mini_scorecard_card_test.dart`

- [ ] **Step 1: Write failing widget test**

Aggregate counts across submissions; only show items with count > 0.

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wiggywash/models/submission.dart';
import 'package:wiggywash/theme.dart';
import 'package:wiggywash/widgets/mini_scorecard_card.dart';

void main() {
  testWidgets('shows only non-zero line items', (tester) async {
    final subs = [
      Submission(
        id: '1',
        employeeName: 'Alex',
        baGoal: 40,
        counts: const {'gold': 2, 'basic': 0},
        submittedAt: DateTime(2026, 7, 9),
        approved: true,
        talkedTo: 10,
      ),
    ];
    // Use real line-item ids from scorecard_config that exist in ItemBook.
    // If 'gold'/'basic' are wrong, open lib/models/scorecard_config.dart and
    // pick two real ids (one with count 2, one with 0).

    await tester.pumpWidget(
      MaterialApp(
        theme: buildTheme(),
        home: Scaffold(
          body: MiniScorecardCard(name: 'Alex', submissions: subs),
        ),
      ),
    );

    expect(find.text('Alex'), findsOneWidget);
    // Assert a zero-count label is absent and a positive count label is present
    // using the real labels from ItemBook for the ids you chose.
  });
}
```

**Before writing the test:** open `lib/models/scorecard_config.dart`, pick two real `LineItem.id` values. Use those in `counts` and assert on their `.label` strings.

- [ ] **Step 2: Run — expect FAIL**

Run: `flutter test test/widgets/mini_scorecard_card_test.dart`

- [ ] **Step 3: Implement `MiniScorecardCard`**

Create `lib/widgets/mini_scorecard_card.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/scorecard_config.dart';
import '../models/submission.dart';
import '../services/store.dart';
import '../theme.dart';

final _money = NumberFormat.currency(symbol: '\$', decimalDigits: 0);

class MiniScorecardCard extends StatelessWidget {
  const MiniScorecardCard({
    super.key,
    required this.name,
    required this.submissions,
  });

  final String name;
  final List<Submission> submissions;

  int _count(String id) =>
      submissions.fold(0, (s, e) => s + e.countOf(id));

  @override
  Widget build(BuildContext context) {
    final revenue =
        submissions.fold(0.0, (s, e) => s + e.grandTotalRevenue);
    final memberships =
        submissions.fold(0, (s, e) => s + e.totalMemberships);
    final singles =
        submissions.fold(0, (s, e) => s + e.totalSingleWashes);
    final totalWashes = memberships + singles;
    final conv =
        totalWashes == 0 ? 0.0 : memberships / totalWashes * 100;
    final latestGoal = submissions.isEmpty
        ? 0.0
        : submissions
            .reduce((a, b) =>
                a.submittedAt.isAfter(b.submittedAt) ? a : b)
            .baGoal;
    final badgeColor = baColor(conv, latestGoal);
    final sections = Store.instance.enabledSections;

    return AppCard(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(name, style: TextStyles.subheading),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: badgeColor,
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                ),
                child: Text(
                  'BA ${conv.toStringAsFixed(0)}%',
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    fontSize: 11,
                  ),
                ),
              ),
            ],
          ),
          for (final section in sections) ...[
            Builder(builder: (context) {
              final rows = <Widget>[];
              for (final item in itemsFor(section)) {
                final c = _count(item.id);
                if (c <= 0) continue;
                rows.add(
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 3),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(item.label,
                              style: TextStyles.caption
                                  .copyWith(color: AppColors.textPrimary)),
                        ),
                        Text('×$c',
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 12,
                            )),
                      ],
                    ),
                  ),
                );
              }
              if (rows.isEmpty) return const SizedBox.shrink();
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 8),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.rose,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      section.title.toUpperCase(),
                      style: const TextStyle(
                        fontSize: 10,
                        letterSpacing: 1.2,
                        fontWeight: FontWeight.w800,
                        color: AppColors.roseText,
                      ),
                    ),
                  ),
                  ...rows,
                ],
              );
            }),
          ],
          const SizedBox(height: 8),
          Text(_money.format(revenue), style: TextStyles.subheading),
        ],
      ),
    );
  }
}
```

- [ ] **Step 4: Fix test ids/labels; run PASS**

- [ ] **Step 5: Commit**

```bash
git add lib/widgets/mini_scorecard_card.dart test/widgets/mini_scorecard_card_test.dart
git commit -m "feat: mini scorecard card for dashboard grid"
```

---

### Task 3: Dashboard List / Cards toggle

**Files:**
- Modify: `lib/screens/manager_screen.dart`

- [ ] **Step 1: Add layout enum + prefs**

Near top of `manager_screen.dart` (after imports):

```dart
import 'package:shared_preferences/shared_preferences.dart';
import '../widgets/mini_scorecard_card.dart';

enum _PeopleLayout { list, cards }

const _kPeopleLayout = 'ww_dashboard_people_layout';
```

In `_ManagerScreenState`:

```dart
  _PeopleLayout _peopleLayout = _PeopleLayout.list;

  @override
  void initState() {
    super.initState();
    _loadPeopleLayout();
  }

  Future<void> _loadPeopleLayout() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_kPeopleLayout);
    if (!mounted) return;
    if (raw == _PeopleLayout.cards.name) {
      setState(() => _peopleLayout = _PeopleLayout.cards);
    }
  }

  Future<void> _setPeopleLayout(_PeopleLayout layout) async {
    setState(() => _peopleLayout = layout);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kPeopleLayout, layout.name);
  }
```

(If `initState` already exists, merge into it.)

- [ ] **Step 2: Toggle UI above people section**

In the `ListView` children, immediately before the employee list / empty / skeleton block, add:

```dart
                  if (all.isNotEmpty ||
                      (!Store.instance.submissionsLoading &&
                          Store.instance.workers.isNotEmpty)) ...[
                    SegmentedButton<_PeopleLayout>(
                      segments: const [
                        ButtonSegment(
                          value: _PeopleLayout.list,
                          label: Text('List'),
                          icon: Icon(Icons.view_agenda_outlined, size: 18),
                        ),
                        ButtonSegment(
                          value: _PeopleLayout.cards,
                          label: Text('Cards'),
                          icon: Icon(Icons.grid_view_rounded, size: 18),
                        ),
                      ],
                      selected: {_peopleLayout},
                      onSelectionChanged: (s) => _setPeopleLayout(s.first),
                    ),
                    const SizedBox(height: 12),
                  ],
```

Adjust the `if` so the toggle shows whenever there is content to display (same conditions as the people section). Prefer showing the toggle whenever `all.isNotEmpty`.

- [ ] **Step 3: Branch list vs grid**

Replace the current `...(_byEmployee(all).entries.map(... _EmployeeCard ...))` with:

```dart
                  else if (_peopleLayout == _PeopleLayout.list)
                    ...(_byEmployee(all).entries.map(
                          (e) => Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: _EmployeeCard(
                              name: e.key,
                              submissions: e.value,
                            ),
                          ),
                        ))
                  else
                    _PeopleCardsGrid(byEmployee: _byEmployee(all)),
```

Add widget at bottom of file (or private in same file):

```dart
class _PeopleCardsGrid extends StatelessWidget {
  const _PeopleCardsGrid({required this.byEmployee});
  final Map<String, List<Submission>> byEmployee;

  @override
  Widget build(BuildContext context) {
    final entries = byEmployee.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));
    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth;
        final cross = w >= 900 ? 4 : (w >= 600 ? 3 : 2);
        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: entries.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: cross,
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            childAspectRatio: cross >= 3 ? 0.72 : 0.78,
          ),
          itemBuilder: (context, i) {
            final e = entries[i];
            return MiniScorecardCard(name: e.key, submissions: e.value);
          },
        );
      },
    );
  }
}
```

Tune `childAspectRatio` if cards clip; prefer slightly taller cards over overflow.

Also widen the dashboard `ConstrainedBox` max width when in cards mode if needed (e.g. `maxWidth: _peopleLayout == _PeopleLayout.cards ? 1100 : 760`) so 3–4 columns have room.

- [ ] **Step 4: Analyze**

Run: `flutter analyze lib/screens/manager_screen.dart`  
Expected: No issues.

- [ ] **Step 5: Commit**

```bash
git add lib/screens/manager_screen.dart
git commit -m "feat: List/Cards toggle on manager dashboard"
```

---

### Task 4: Store update for primaryColor

**Files:**
- Modify: `lib/services/store.dart`

- [ ] **Step 1: Add method**

Near other company write helpers (after `previewCompany` / approve helpers):

```dart
  Future<String?> updateCompanyPrimaryColor(String hex) async {
    final id = _activeCompanyId;
    if (id == null) return 'No active company.';
    final parsed = parseBrandColor(hex);
    if (parsed == null) return 'Invalid color.';
    final normalized = formatBrandColor(parsed);
    try {
      await _companiesCol.doc(id).set(
        {'primaryColor': normalized},
        SetOptions(merge: true),
      );
      if (_activeCompany != null) {
        _activeCompany = Company(
          id: _activeCompany!.id,
          name: _activeCompany!.name,
          companyCode: _activeCompany!.companyCode,
          status: _activeCompany!.status,
          logoUrl: _activeCompany!.logoUrl,
          primaryColor: normalized,
          createdAt: _activeCompany!.createdAt,
          approvedAt: _activeCompany!.approvedAt,
          approvedBy: _activeCompany!.approvedBy,
          createdByEmail: _activeCompany!.createdByEmail,
          createdByUid: _activeCompany!.createdByUid,
          rejectionReason: _activeCompany!.rejectionReason,
        );
      }
      notifyListeners();
      return null;
    } catch (e) {
      debugPrint('updateCompanyPrimaryColor error: $e');
      return 'Could not save brand color.';
    }
  }
```

Add import: `import '../utils/brand_color.dart';`

Prefer adding `Company.copyWith({String? primaryColor, ...})` on the model if cleaner — optional small addition in `lib/models/company.dart`.

- [ ] **Step 2: Ensure company doc stays fresh**

Confirm `_loadActiveCompanyDoc` / company snapshots already refresh `_activeCompany` for managers. If managers only load company once, either call `_loadActiveCompanyDoc` after save (already updating local) or add a short listen — local update + merge write is enough for the saver; other devices need existing listen or next login. Acceptable for v1: saver sees instant update; others on next company reload. If `previewCompany` is used for employees, ensure employee path loads `primaryColor` (already on `Company.fromDoc`).

- [ ] **Step 3: Commit**

```bash
git add lib/services/store.dart lib/models/company.dart
git commit -m "feat: save company primaryColor from Store"
```

---

### Task 5: Settings screen + shell nav

**Files:**
- Create: `lib/screens/settings_screen.dart`
- Modify: `lib/widgets/manager_shell.dart`

- [ ] **Step 1: Create SettingsScreen**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart'; // ONLY if adding package
// Prefer NO new package: use showDialog with a simple HSV or preset-only + TextField for hex.

import '../services/store.dart';
import '../theme.dart';
import '../utils/brand_color.dart';
import '../widgets/store_message.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  static const _presets = <Color>[
    Color(0xFF1B2A4A), // navy default
    Color(0xFF2E7D52), // spring green
    Color(0xFF1565C0),
    Color(0xFFC62828),
    Color(0xFF6A1B9A),
  ];

  Color _draft = AppColors.navy;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    final existing =
        parseBrandColor(Store.instance.activeCompany?.primaryColor);
    if (existing != null) _draft = existing;
  }

  Future<void> _save() async {
    setState(() => _busy = true);
    final err = await Store.instance
        .updateCompanyPrimaryColor(formatBrandColor(_draft));
    if (!mounted) return;
    setState(() => _busy = false);
    showStoreMessage(
      context,
      err ?? 'Brand color saved',
      error: err != null,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              AppCard(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text('Brand color', style: TextStyles.subheading),
                    const SizedBox(height: 6),
                    const Text(
                      'Applies company-wide to buttons, nav, and accents.',
                      style: TextStyles.caption,
                    ),
                    const SizedBox(height: 14),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: [
                        for (final c in _presets)
                          GestureDetector(
                            onTap: () => setState(() => _draft = c),
                            child: Container(
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(
                                color: c,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: _draft.toARGB32() == c.toARGB32()
                                      ? AppColors.textPrimary
                                      : Colors.white,
                                  width: 3,
                                ),
                                boxShadow: const [
                                  BoxShadow(
                                    color: Color(0x22000000),
                                    blurRadius: 4,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        // Optional: IconButton that opens a dialog with
                        // Slider RGB or TextField('#RRGGBB') — no new deps.
                      ],
                    ),
                    const SizedBox(height: 16),
                    const Text('Preview', style: TextStyles.caption),
                    const SizedBox(height: 8),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _draft,
                        foregroundColor: Colors.white,
                      ),
                      onPressed: () {},
                      child: const Text('Primary button'),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: _busy ? null : _save,
                      child: _busy
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Save brand color'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
```

**Do not add `flutter_colorpicker` unless necessary.** Prefer presets + optional hex `TextField` dialog for custom colors (YAGNI).

- [ ] **Step 2: Wire ManagerShell**

```dart
import '../screens/settings_screen.dart';

  static const _destinations = [
    (icon: Icons.dashboard_rounded, label: 'Dashboard'),
    (icon: Icons.table_chart_outlined, label: 'Master Sheet'),
    (icon: Icons.group_outlined, label: 'Team'),
    (icon: Icons.sell_outlined, label: 'Prices'),
    (icon: Icons.settings_outlined, label: 'Settings'),
  ];

  Widget _page(int index) => switch (index) {
        0 => const ManagerScreen(),
        1 => const MasterSheetScreen(),
        2 => const TeamScreen(),
        3 => const PricingScreen(),
        4 => const SettingsScreen(),
        _ => const ManagerScreen(),
      };
```

For bottom `NavigationBar` with 5 items: set `labelBehavior: NavigationDestinationLabelBehavior.alwaysHide` only if overflow; prefer `NavigationDestinationLabelBehavior.alwaysShow` first and shrink icon size if needed.

- [ ] **Step 3: Analyze + commit**

```bash
flutter analyze lib/screens/settings_screen.dart lib/widgets/manager_shell.dart
git add lib/screens/settings_screen.dart lib/widgets/manager_shell.dart
git commit -m "feat: Settings tab with brand color picker"
```

---

### Task 6: Theme wiring (accent-only)

**Files:**
- Modify: `lib/theme.dart`
- Modify: `lib/main.dart`
- Optionally: `lib/widgets/manager_shell.dart` (selected rail color from `Theme.of(context).colorScheme.primary`)

- [ ] **Step 1: Parameterize buildTheme**

Change signature:

```dart
ThemeData buildTheme({Color? primary}) {
  final brand = primary ?? AppColors.navy;
  final scheme = ColorScheme.fromSeed(
    seedColor: brand,
    brightness: Brightness.light,
  ).copyWith(
    primary: brand,
    secondary: AppColors.accent,
    surface: AppColors.surface,
    onPrimary: Colors.white,
    onSurface: AppColors.textPrimary,
  );
  // ... rest: replace AppColors.navy usages for buttons/appBar/switch
  // with `brand` where they are brand accents.
  // Keep AppColors.textPrimary, rose, BA colors, background white.
```

Replace elevated button `backgroundColor: AppColors.navy` → `brand`.  
Replace `appBarTheme.backgroundColor` → `brand`.  
Keep scaffold white.

- [ ] **Step 2: MaterialApp listens to Store**

In `lib/main.dart`:

```dart
class WiggyWashApp extends StatelessWidget {
  const WiggyWashApp({super.key});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Store.instance,
      builder: (context, _) {
        final primary =
            parseBrandColor(Store.instance.activeCompany?.primaryColor);
        return MaterialApp(
          title: 'Wiggy Wash',
          debugShowCheckedModeBanner: false,
          theme: buildTheme(primary: primary),
          home: const _Root(),
        );
      },
    );
  }
}
```

Import `utils/brand_color.dart`.

- [ ] **Step 3: Shell selected indicator**

In `manager_shell.dart`, use `Theme.of(context).colorScheme.primary` for selected rail/destination indicator where hardcoded `AppColors.navy` / `blueSoft` is used for selection (keep soft background as a light tint of primary if easy: `primary.withValues(alpha: 0.12)`).

- [ ] **Step 4: Analyze + test + commit**

```bash
flutter analyze
flutter test
git add lib/theme.dart lib/main.dart lib/widgets/manager_shell.dart
git commit -m "feat: company primaryColor drives accent theme"
```

---

### Task 7: Polish + smoke checklist

- [ ] **Step 1: Polish**
  - Cards grid aspect ratio / scroll on small phones
  - Settings: clear “Reset to default navy” control
  - Ensure BA badges still use `baColor`, not brand green

- [ ] **Step 2: Manual smoke**
  - [ ] Dashboard List ↔ Cards; reload keeps choice
  - [ ] Cards show per-line items; zeros hidden
  - [ ] Settings save color; buttons/app bar update
  - [ ] Employee session (same company) sees accent after refresh
  - [ ] Null `primaryColor` → navy

- [ ] **Step 3: Final commit if polish landed**

```bash
git commit -m "polish: dashboard cards and brand settings"
```

---

## Spec coverage

| Spec item | Task |
|-----------|------|
| List/Cards toggle + prefs | Task 3 |
| Mini scorecard per-line items | Task 2–3 |
| Responsive 2–4 columns | Task 3 |
| Settings nav tab | Task 5 |
| Save `primaryColor` | Task 4–5 |
| Accent-only theme company-wide | Task 1, 6 |
| Hex parse / invalid fallback | Task 1, 6 |
| No logo / full recolor | Omitted |

## Consistency notes

- Prefs key: `ww_dashboard_people_layout`
- Helpers: `parseBrandColor` / `formatBrandColor`
- Store API: `updateCompanyPrimaryColor`
- Theme API: `buildTheme({Color? primary})`
