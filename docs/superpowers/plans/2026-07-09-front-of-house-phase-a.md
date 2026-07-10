# Front-of-House Visual System (Phase A) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ship brand-first login, clearer dashboard hierarchy, app-wide Comfortable/Compact density, three purposeful motions, and a one-thumb phone scorecard.

**Architecture:** Add device-local `UiDensity` prefs (`ww_ui_density`) and spacing helpers. Apply tokens on login, dashboard people rows, and scorecard tallies. Reorder `ManagerScreen` so team totals lead the first viewport. Animate only tab change, approve, and scorecard save. Enlarge phone steppers and promote BA/$ into the sticky Save bar.

**Tech Stack:** Flutter web, `shared_preferences`, existing `theme.dart` / `AppColors` / `baColor`, `ManagerShell`, `ManagerScreen`, `ScorecardScreen`.

**Spec:** `docs/superpowers/specs/2026-07-09-front-of-house-coach-notes-design.md` (Phase A only — do not implement coach notes here)

**Out of scope:** Phase B coach notes, Master Sheet density changes, logo upload, dark mode.

---

## File map

| File | Responsibility |
|------|----------------|
| `lib/utils/ui_density.dart` | `UiDensity` enum + load/save + spacing helpers |
| `test/utils/ui_density_test.dart` | Prefs + helper unit tests |
| `lib/screens/settings_screen.dart` | Density Comfortable / Compact control |
| `lib/widgets/company_header.dart` | Hero-scale company brand after resolve |
| `lib/widgets/brand_header.dart` | Slightly stronger pre-resolve product brand |
| `lib/screens/company_login_screen.dart` | Density-aware padding; hierarchy with headers |
| `lib/screens/manager_screen.dart` | First-viewport reorder; density on people cards |
| `lib/widgets/manager_shell.dart` | Animated tab body switch |
| `lib/screens/master_sheet_screen.dart` | Approve success flash motion (`_PendingCard`) |
| `lib/widgets/tally_row.dart` | Density + phone hit targets |
| `lib/screens/scorecard_screen.dart` | Sticky summary strip + save flash timing |

---

### Task 1: UiDensity prefs + spacing helpers

**Files:**
- Create: `lib/utils/ui_density.dart`
- Create: `test/utils/ui_density_test.dart`

- [ ] **Step 1: Write the failing test**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wiggywash/utils/ui_density.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('defaults to comfortable', () {
    expect(UiDensityPrefs.defaults().density, UiDensity.comfortable);
  });

  test('corrupt value loads as comfortable', () async {
    SharedPreferences.setMockInitialValues({'ww_ui_density': 'nope'});
    final loaded = await UiDensityPrefs.load();
    expect(loaded.density, UiDensity.comfortable);
  });

  test('round-trip save/load compact', () async {
    await UiDensityPrefs.save(
      const UiDensityPrefs(density: UiDensity.compact),
    );
    final loaded = await UiDensityPrefs.load();
    expect(loaded.density, UiDensity.compact);
  });

  test('compact padding is tighter than comfortable', () {
    final c = UiDensity.comfortable;
    final k = UiDensity.compact;
    expect(k.pagePadding, lessThan(c.pagePadding));
    expect(k.tallyVerticalMargin, lessThan(c.tallyVerticalMargin));
    expect(k.stepButtonSize, greaterThanOrEqualTo(44));
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/utils/ui_density_test.dart`  
Expected: FAIL (library not found)

- [ ] **Step 3: Implement `lib/utils/ui_density.dart`**

```dart
import 'package:shared_preferences/shared_preferences.dart';

const kUiDensityPrefsKey = 'ww_ui_density';

enum UiDensity { comfortable, compact }

extension UiDensityTokens on UiDensity {
  double get pagePadding => switch (this) {
        UiDensity.comfortable => 14,
        UiDensity.compact => 10,
      };

  double get sectionGap => switch (this) {
        UiDensity.comfortable => 12,
        UiDensity.compact => 8,
      };

  double get loginCardPadding => switch (this) {
        UiDensity.comfortable => 32,
        UiDensity.compact => 20,
      };

  double get tallyVerticalMargin => switch (this) {
        UiDensity.comfortable => 5,
        UiDensity.compact => 3,
      };

  /// Minimum circular +/- diameter. Phone one-thumb pass may raise further.
  double get stepButtonSize => switch (this) {
        UiDensity.comfortable => 44,
        UiDensity.compact => 44,
      };

  double get peopleCardPadding => switch (this) {
        UiDensity.comfortable => 14,
        UiDensity.compact => 10,
      };
}

class UiDensityPrefs {
  const UiDensityPrefs({required this.density});
  final UiDensity density;

  factory UiDensityPrefs.defaults() =>
      const UiDensityPrefs(density: UiDensity.comfortable);

  static Future<UiDensityPrefs> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(kUiDensityPrefsKey);
    if (raw == null || raw.isEmpty) return UiDensityPrefs.defaults();
    for (final d in UiDensity.values) {
      if (d.name == raw) return UiDensityPrefs(density: d);
    }
    return UiDensityPrefs.defaults();
  }

  static Future<void> save(UiDensityPrefs value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(kUiDensityPrefsKey, value.density.name);
  }
}
```

- [ ] **Step 4: Run tests — expect PASS**

Run: `flutter test test/utils/ui_density_test.dart`

- [ ] **Step 5: Commit**

```bash
git add lib/utils/ui_density.dart test/utils/ui_density_test.dart
git commit -m "feat: app-wide UiDensity prefs and spacing tokens"
```

---

### Task 2: Settings density toggle

**Files:**
- Modify: `lib/screens/settings_screen.dart`

- [ ] **Step 1: Load density in `initState` and add UI above Brand color**

Add imports:

```dart
import '../utils/ui_density.dart';
```

State fields:

```dart
UiDensity _density = UiDensity.comfortable;
bool _densityBusy = false;
```

In `initState` after brand init:

```dart
UiDensityPrefs.load().then((p) {
  if (!mounted) return;
  setState(() => _density = p.density);
});
```

Handler:

```dart
Future<void> _setDensity(UiDensity d) async {
  setState(() {
    _density = d;
    _densityBusy = true;
  });
  await UiDensityPrefs.save(UiDensityPrefs(density: d));
  if (!mounted) return;
  setState(() => _densityBusy = false);
  showStoreMessage(context, 'Density saved on this device');
}
```

In the `ListView` children, **before** the Brand color `AppCard`, insert:

```dart
AppCard(
  padding: const EdgeInsets.all(18),
  child: Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      const Text('Display density', style: TextStyles.subheading),
      const SizedBox(height: 6),
      const Text(
        'Comfortable or Compact for dashboard, scorecard, and login on this device. Master Sheet density stays separate.',
        style: TextStyles.caption,
      ),
      const SizedBox(height: 14),
      SegmentedButton<UiDensity>(
        segments: const [
          ButtonSegment(
            value: UiDensity.comfortable,
            label: Text('Comfortable'),
          ),
          ButtonSegment(
            value: UiDensity.compact,
            label: Text('Compact'),
          ),
        ],
        selected: {_density},
        onSelectionChanged: _densityBusy
            ? null
            : (s) => _setDensity(s.first),
      ),
    ],
  ),
),
const SizedBox(height: 12),
```

- [ ] **Step 2: Hot-restart Settings — toggle Compact / Comfortable; confirm no crash**

- [ ] **Step 3: Commit**

```bash
git add lib/screens/settings_screen.dart
git commit -m "feat: Settings Comfortable/Compact density control"
```

---

### Task 3: Brand-first login (#14)

**Files:**
- Modify: `lib/widgets/brand_header.dart`
- Modify: `lib/widgets/company_header.dart`
- Modify: `lib/screens/company_login_screen.dart`

- [ ] **Step 1: Strengthen `BrandHeader` product presence**

Increase default height to `112`. Raise “Sales Scorecard” to muted but visible:

```dart
const Text(
  'Sales Scorecard',
  style: TextStyle(
    fontSize: 15,
    fontWeight: FontWeight.w700,
    color: AppColors.textMuted,
    letterSpacing: 2.5,
  ),
),
```

- [ ] **Step 2: Make `CompanyHeader` the hero after resolve**

Replace the current small avatar + `TextStyles.subheading` with larger type:

- Logo / avatar: height **88** (or `radius: 44`)
- Company name: `fontSize: 28`, `fontWeight: FontWeight.w900`, `color: AppColors.navy`, centered
- Keep “Sales Scorecard” as caption **below** the name (smaller than the name)

Remove any layout that makes the step card title compete with the company name.

- [ ] **Step 3: Login padding from density**

In `CompanyLoginScreen`, load density in `initState` into `UiDensity _density = UiDensity.comfortable`.  
Use `_density.pagePadding` / `_density.loginCardPadding` on the outer scroll padding and `_buildCodeStep` card padding.

- [ ] **Step 4: Manual check**

1. Cold open: product logo dominates over the code form.  
2. Valid code: company name larger than “Enter company code” / location / name titles.  
3. Manager Google link still at bottom of code step.

- [ ] **Step 5: Commit**

```bash
git add lib/widgets/brand_header.dart lib/widgets/company_header.dart lib/screens/company_login_screen.dart
git commit -m "feat: brand-first login hierarchy"
```

---

### Task 4: Dashboard first-viewport hierarchy (#17)

**Files:**
- Modify: `lib/screens/manager_screen.dart`

- [ ] **Step 1: Reorder `ListView` children**

Current order (approx): Period → Challenge → SeeAll → TeamTotals → Trends → List/Cards → people.

**New order:**

1. `_PeriodBar` (unchanged)
2. `_TeamTotals` (**immediately after period**; optionally bump revenue style to `fontSize: 32` and BA row emphasis)
3. People layout segmented control (show whenever `all.isNotEmpty`, same as today)
4. People list/cards / empty / skeleton
5. **Below the fold / lower priority block:** `_SeeAllToggle`, then `ChallengeCard`, then `_TrendsCard` (only if `all.isNotEmpty`)

Keep all features; do not delete Challenge / Trends / See all.

Insert a light divider or `SizedBox(height: 20)` plus a caption “More” before the deferred block if it helps scanning — optional, keep subtle.

- [ ] **Step 2: Apply density to people vertical gaps**

Load `UiDensity` in `ManagerScreen.initState` (same pattern as Settings). Use `_density.sectionGap` between people cards and `_density.peopleCardPadding` where `_EmployeeCard` / card padding is hard-coded.

- [ ] **Step 3: Manual check**

On a typical laptop viewport height, the first screenful should show period + team total + start of people — not Challenge before the total.

- [ ] **Step 4: Commit**

```bash
git add lib/screens/manager_screen.dart
git commit -m "feat: lead dashboard with team totals"
```

---

### Task 5: Manager tab motion (#16 part 1)

**Files:**
- Modify: `lib/widgets/manager_shell.dart`

- [ ] **Step 1: Wrap tab body in `AnimatedSwitcher`**

Replace bare `body` / `Expanded(child: body)` with:

```dart
final body = KeyedSubtree(
  key: ValueKey<int>(_index),
  child: _page(_index),
);

Widget animatedBody = AnimatedSwitcher(
  duration: const Duration(milliseconds: 240),
  switchInCurve: Curves.easeOut,
  switchOutCurve: Curves.easeOut,
  transitionBuilder: (child, animation) {
    final offset = Tween<Offset>(
      begin: const Offset(0.03, 0),
      end: Offset.zero,
    ).animate(animation);
    return FadeTransition(
      opacity: animation,
      child: SlideTransition(position: offset, child: child),
    );
  },
  child: body,
);
```

Use `animatedBody` in both wide (`Expanded`) and narrow (`Scaffold.body`) layouts.

- [ ] **Step 2: Manual — switch Dashboard ↔ Master Sheet ↔ Settings; confirm short fade/slide, no other loops**

- [ ] **Step 3: Commit**

```bash
git add lib/widgets/manager_shell.dart
git commit -m "feat: animate manager tab transitions"
```

---

### Task 6: Approve motion (#16 part 2)

**Files:**
- Modify: `lib/screens/master_sheet_screen.dart` (`_PendingCard`)

- [ ] **Step 1: Convert `_PendingCard` to `StatefulWidget` with flash flag**

On successful approve (`err == null`):

```dart
setState(() => _justApproved = true);
await Future<void>.delayed(const Duration(milliseconds: 280));
if (!mounted) return;
// then call onChanged() as today
```

While `_justApproved`, wrap the card in:

```dart
AnimatedScale(
  scale: _justApproved ? 1.02 : 1.0,
  duration: const Duration(milliseconds: 220),
  curve: Curves.easeOut,
  child: AnimatedOpacity(
    opacity: _justApproved ? 0.55 : 1.0,
    duration: const Duration(milliseconds: 220),
    child: /* existing AppCard */,
  ),
)
```

Optionally tint Approve button briefly with a check icon swap — keep under 280ms total.

Do **not** add animations elsewhere in this task.

- [ ] **Step 2: Manual — approve a pending card; see brief flash then list refresh**

- [ ] **Step 3: Commit**

```bash
git add lib/screens/master_sheet_screen.dart
git commit -m "feat: brief approve success motion on pending cards"
```

---

### Task 7: One-thumb scorecard + density (#8, #15 scorecard)

**Files:**
- Modify: `lib/widgets/tally_row.dart`
- Modify: `lib/screens/scorecard_screen.dart`

- [ ] **Step 1: Extend `TallyRow` for size + density**

Add optional params with defaults matching today visually:

```dart
final double stepButtonSize;
final double verticalMargin;
```

Pass into `_StepButton` width/height and container margin.

Phone boost from parent: when `MediaQuery.sizeOf(context).width < 600`, use `max(density.stepButtonSize, 48)`.

- [ ] **Step 2: Scorecard loads density; wires `TallyRow`**

Load `UiDensity` in `ScorecardScreen`. In `_buildSections`:

```dart
TallyRow(
  item: item,
  count: _counts[item.id] ?? 0,
  onChanged: (v) => _set(item.id, v),
  stepButtonSize: phone
      ? math.max(_density.stepButtonSize, 48)
      : _density.stepButtonSize,
  verticalMargin: _density.tallyVerticalMargin,
),
```

(import `dart:math` as `math` if needed)

- [ ] **Step 3: Sticky bottom summary**

Expand `bottomNavigationBar` `Column` **above** `_SaveStatus`:

```dart
_StickyShiftSummary(live: _live, talkedTo: _talkedTo),
const SizedBox(height: 8),
_SaveStatus(...),
```

`_StickyShiftSummary` shows one row: Talked-to · BA% (colored with `baColor`) · `$` revenue — compact, high contrast, no card chrome heavier than a hairline top border.

Remove or slim the duplicate `_SummaryCard` in the scroll body **or** keep a shorter version — prefer keep share section, remove bulky mid-page summary if sticky covers it (avoid two competing totals). Spec: totals always visible with Save — sticky is source of truth.

- [ ] **Step 4: Save flash timing (#16 part 3)**

Change flash timer from 3s to **~1.2s**; keep `AnimatedSwitcher` in `_SaveStatus` if present; ensure ease-out ~240ms on status row.

- [ ] **Step 5: Manual on phone width (Chrome device mode ~390px)**

- +/- ≥48px  
- BA/$ visible with Save without scrolling to end  
- Compact density tightens tallies  
- Save flash feels snappier  

- [ ] **Step 6: Commit**

```bash
git add lib/widgets/tally_row.dart lib/screens/scorecard_screen.dart
git commit -m "feat: one-thumb scorecard sticky totals and density"
```

---

### Task 8: Phase A verification

- [ ] **Step 1: Run unit tests**

Run: `flutter test test/utils/ui_density_test.dart`  
Expected: PASS

- [ ] **Step 2: Manual checklist against spec success criteria**

| Check | Pass? |
|-------|-------|
| Login brand test (post-code company name dominates) | |
| Dashboard leads with team total | |
| Density changes login + dashboard + scorecard; sheet density untouched | |
| Only three motions (tabs, approve, save) | |
| Phone sticky totals + large steppers | |

- [ ] **Step 3: Commit any leftover polish only if needed; otherwise stop**

---

## Spec coverage (Phase A)

| Spec item | Task |
|-----------|------|
| #15 UiDensity + Settings | 1, 2 |
| #14 Brand login | 3 |
| #17 Dashboard hierarchy | 4 |
| #16 Tab / Approve / Save motion | 5, 6, 7 |
| #8 One-thumb scorecard | 7 |
| Independent Master Sheet density | 2 caption + no sheet edits |
