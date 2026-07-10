# Polish Fixes + Company Themes (Spec A) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Fix stale employee tips, make app density visibly different, clarify manager-invite errors, and replace brand-color hex with company `themeId` palettes plus personal dark mode.

**Architecture:** Keep Master Sheet density independent. Widen `UiDensity` token deltas (today `stepButtonSize` is identical for both modes). Map Firestore invite failures to clear strings. Add `Company.themeId` + `ThemeExtension` token sets (`classic` / `forest` / `sky`) with light+dark variants; `main.dart` builds `ThemeData` from company theme + local `darkMode` prefs. Remove Settings brand-hex UI. Spec B (preset requests board) is out of scope.

**Tech Stack:** Flutter web, `shared_preferences`, existing `Company` / `Store` / `SettingsScreen` / `ManagersSection`, Firestore `companies/{id}`.

**Spec:** `docs/superpowers/specs/2026-07-09-polish-themes-design.md`

**Out of scope:** Spec B preset requests, push/email, custom hex, company-wide forced dark mode, employee Settings (dark mode lives on manager Settings tab for Spec A; employees keep current chrome until a later profile toggle if needed).

---

## File map

| File | Responsibility |
|------|----------------|
| `lib/screens/tips_screen.dart` | Honest employee tip copy |
| `test/screens/tips_copy_test.dart` | Guard against stale “tap Your total today” tip |
| `lib/utils/ui_density.dart` | Larger Comfortable↔Compact deltas |
| `test/utils/ui_density_test.dart` | Assert step size + padding differ |
| `lib/utils/firestore_user_error.dart` | Map Firebase/permission errors to user strings |
| `test/utils/firestore_user_error_test.dart` | Error mapping unit tests |
| `lib/services/store.dart` | Invite error mapping; `updateCompanyThemeId` |
| `lib/widgets/managers_section.dart` | Success copy for invites |
| `lib/models/company.dart` | `themeId` field + parse/default |
| `test/models/company_test.dart` | `themeId` parse / unknown → classic |
| `lib/theme/app_theme_id.dart` | Enum + parse helpers |
| `lib/theme/wiggy_tokens.dart` | `ThemeExtension` light/dark token sets |
| `lib/theme.dart` | `buildTheme({themeId, dark})` using tokens |
| `lib/utils/dark_mode_prefs.dart` | Local dark mode load/save |
| `test/utils/dark_mode_prefs_test.dart` | Prefs round-trip |
| `lib/main.dart` | Theme from company + dark prefs |
| `lib/screens/settings_screen.dart` | Theme picker + dark mode; remove hex brand UI |

---

### Task 1: Fix employee tip #3

**Files:**
- Modify: `lib/screens/tips_screen.dart`
- Create: `test/screens/tips_copy_test.dart`

- [ ] **Step 1: Write the failing test**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:wiggywash/screens/tips_screen.dart';

void main() {
  test('employee tips do not mention tapping Your total today', () {
    // Export tips for test via a top-level getter added in Step 3, or
    // pump TipsScreen and assert text.
    // Prefer pumping the screen:
  });
}
```

Use a widget test:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wiggywash/screens/tips_screen.dart';

void main() {
  testWidgets('employee tips omit nonexistent total-today tap', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: TipsScreen(audience: TipsAudience.employee)),
    );
    expect(find.textContaining('Tap Your total today'), findsNothing);
    expect(find.textContaining('line-by-line breakdown'), findsNothing);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/screens/tips_copy_test.dart`  
Expected: FAIL — finds the stale tip text.

- [ ] **Step 3: Replace tip #3 with real scorecard behavior**

In `lib/screens/tips_screen.dart`, replace the third `_employeeTips` entry with:

```dart
  _Tip(
    'Save as you go',
    'Tap Save during your shift so totals stay on the sticky bar and in the database. Submit Shift when you are finished.',
    Icons.save_outlined,
  ),
```

Keep tips 1, 2, and 4 unchanged unless another tip is clearly wrong.

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/screens/tips_copy_test.dart`  
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add lib/screens/tips_screen.dart test/screens/tips_copy_test.dart
git commit -m "fix: replace stale employee tip about total-today tap"
```

---

### Task 2: Make UiDensity deltas obvious

**Files:**
- Modify: `lib/utils/ui_density.dart`
- Modify: `test/utils/ui_density_test.dart` (create if missing; update if present)

- [ ] **Step 1: Update / write failing assertions**

Ensure tests include:

```dart
  test('compact is tighter and uses smaller steppers than comfortable', () {
    final c = UiDensity.comfortable;
    final k = UiDensity.compact;
    expect(k.pagePadding, lessThan(c.pagePadding));
    expect(k.sectionGap, lessThan(c.sectionGap));
    expect(k.tallyVerticalMargin, lessThan(c.tallyVerticalMargin));
    expect(k.peopleCardPadding, lessThan(c.peopleCardPadding));
    expect(k.loginCardPadding, lessThan(c.loginCardPadding));
    expect(k.stepButtonSize, lessThan(c.stepButtonSize));
    expect(c.stepButtonSize - k.stepButtonSize, greaterThanOrEqualTo(8));
    expect(c.pagePadding - k.pagePadding, greaterThanOrEqualTo(6));
  });
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/utils/ui_density_test.dart`  
Expected: FAIL — current `stepButtonSize` is `44` for both.

- [ ] **Step 3: Widen tokens in `ui_density.dart`**

Replace the extension values with (exact numbers):

```dart
extension UiDensityTokens on UiDensity {
  double get pagePadding => switch (this) {
        UiDensity.comfortable => 16,
        UiDensity.compact => 8,
      };

  double get sectionGap => switch (this) {
        UiDensity.comfortable => 14,
        UiDensity.compact => 6,
      };

  double get loginCardPadding => switch (this) {
        UiDensity.comfortable => 32,
        UiDensity.compact => 16,
      };

  double get tallyVerticalMargin => switch (this) {
        UiDensity.comfortable => 8,
        UiDensity.compact => 2,
      };

  double get stepButtonSize => switch (this) {
        UiDensity.comfortable => 52,
        UiDensity.compact => 40,
      };

  double get peopleCardPadding => switch (this) {
        UiDensity.comfortable => 16,
        UiDensity.compact => 8,
      };
}
```

Note: scorecard phone path may still `max(stepButtonSize, 48)` — that is fine; desktop/tablet and non-phone paths should show the delta. Do not change Master Sheet density.

- [ ] **Step 4: Run tests**

Run: `flutter test test/utils/ui_density_test.dart`  
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add lib/utils/ui_density.dart test/utils/ui_density_test.dart
git commit -m "fix: widen Comfortable vs Compact UI density deltas"
```

---

### Task 3: Clearer manager invite errors + success copy

**Files:**
- Create: `lib/utils/firestore_user_error.dart`
- Create: `test/utils/firestore_user_error_test.dart`
- Modify: `lib/services/store.dart` (`addManagerInvite` catch)
- Modify: `lib/widgets/managers_section.dart` (success message)

- [ ] **Step 1: Write failing tests for error mapper**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:wiggywash/utils/firestore_user_error.dart';

void main() {
  test('permission-denied maps clearly', () {
    expect(
      mapFirestoreUserError(
        'ignored',
        code: 'permission-denied',
        fallback: 'Could not add manager.',
      ),
      'You do not have permission to invite managers.',
    );
  });

  test('unavailable maps to network message', () {
    expect(
      mapFirestoreUserError(
        'x',
        code: 'unavailable',
        fallback: 'Could not add manager.',
      ),
      'Network error — try again.',
    );
  });

  test('unknown uses fallback', () {
    expect(
      mapFirestoreUserError(
        'weird',
        code: null,
        fallback: 'Could not add manager.',
      ),
      'Could not add manager.',
    );
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/utils/firestore_user_error_test.dart`  
Expected: FAIL — library missing.

- [ ] **Step 3: Implement mapper**

```dart
/// Maps Firebase/Firestore failures to short UI strings.
String mapFirestoreUserError(
  Object error, {
  String? code,
  required String fallback,
}) {
  final c = (code ?? _codeFrom(error))?.toLowerCase();
  switch (c) {
    case 'permission-denied':
      return 'You do not have permission to invite managers.';
    case 'unavailable':
    case 'deadline-exceeded':
      return 'Network error — try again.';
    case 'already-exists':
      return 'That email is already invited.';
    default:
      return fallback;
  }
}

String? _codeFrom(Object error) {
  try {
    // firebase_core FirebaseException has .code
    final dynamic e = error;
    final code = e.code;
    if (code is String) return code;
  } catch (_) {}
  final s = error.toString().toLowerCase();
  if (s.contains('permission-denied')) return 'permission-denied';
  if (s.contains('unavailable')) return 'unavailable';
  return null;
}
```

- [ ] **Step 4: Wire `addManagerInvite` catch**

In `lib/services/store.dart`, replace the catch return:

```dart
    } catch (e) {
      debugPrint('addManagerInvite error: $e');
      String? code;
      try {
        code = (e as dynamic).code as String?;
      } catch (_) {}
      return mapFirestoreUserError(
        e,
        code: code,
        fallback: 'Could not add manager.',
      );
    }
```

Add import for `firestore_user_error.dart`.

- [ ] **Step 5: Success copy in `ManagersSection`**

Change success message to:

```dart
showStoreMessage(
  context,
  'Invite saved — they must sign in with that Google email.',
);
```

- [ ] **Step 6: Run tests**

Run: `flutter test test/utils/firestore_user_error_test.dart test/utils/manager_invite_logic_test.dart test/models/manager_invite_test.dart`  
Expected: PASS

- [ ] **Step 7: Commit**

```bash
git add lib/utils/firestore_user_error.dart test/utils/firestore_user_error_test.dart lib/services/store.dart lib/widgets/managers_section.dart
git commit -m "fix: clearer manager invite errors and success copy"
```

**Manual check after deploy:** Team → Managers → invite a new email while signed in as a company manager. If still permission-denied, verify `users/{uid}` has `role: manager` (or equivalent) and `companyId` matching — rules require `canManageCompany`.

---

### Task 4: `AppThemeId` + `Company.themeId`

**Files:**
- Create: `lib/theme/app_theme_id.dart`
- Modify: `lib/models/company.dart`
- Modify: `test/models/company_test.dart`

- [ ] **Step 1: Write failing company tests**

```dart
  test('themeId defaults to classic when missing', () {
    final c = Company.fromMap('abc', {
      'name': 'Wiggy Wash',
      'companyCode': 'WIGGY',
      'status': 'active',
    });
    expect(c.themeId, 'classic');
  });

  test('unknown themeId falls back to classic', () {
    final c = Company.fromMap('abc', {
      'name': 'Wiggy Wash',
      'companyCode': 'WIGGY',
      'status': 'active',
      'themeId': 'neon-purple',
    });
    expect(c.themeId, 'classic');
  });

  test('parses forest themeId', () {
    final c = Company.fromMap('abc', {
      'name': 'Wiggy Wash',
      'companyCode': 'WIGGY',
      'status': 'active',
      'themeId': 'forest',
    });
    expect(c.themeId, 'forest');
  });
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/models/company_test.dart`  
Expected: FAIL — no `themeId`.

- [ ] **Step 3: Add `AppThemeId`**

Create `lib/theme/app_theme_id.dart`:

```dart
enum AppThemeId { classic, forest, sky }

extension AppThemeIdX on AppThemeId {
  String get firestoreValue => name;

  static AppThemeId parse(String? raw) {
    if (raw == null || raw.isEmpty) return AppThemeId.classic;
    for (final id in AppThemeId.values) {
      if (id.name == raw) return id;
    }
    return AppThemeId.classic;
  }
}
```

- [ ] **Step 4: Add `themeId` on `Company`**

- Constructor field: `this.themeId = 'classic'` as `final String themeId`.
- `copyWith({String? themeId})`.
- `toMap`: always write `'themeId': themeId`.
- `fromMap`: `themeId: AppThemeIdX.parse(data['themeId'] as String?).firestoreValue` (store canonical string).
- Keep `primaryColor` field for backward compat; do not use it for theming after Task 6.

- [ ] **Step 5: Run tests**

Run: `flutter test test/models/company_test.dart`  
Expected: PASS

- [ ] **Step 6: Commit**

```bash
git add lib/theme/app_theme_id.dart lib/models/company.dart test/models/company_test.dart
git commit -m "feat: Company.themeId with classic default"
```

---

### Task 5: Theme tokens + `buildTheme(themeId, dark)`

**Files:**
- Create: `lib/theme/wiggy_tokens.dart`
- Modify: `lib/theme.dart`
- Create: `test/theme/build_theme_test.dart`

- [ ] **Step 1: Write failing theme tests**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wiggywash/theme.dart';
import 'package:wiggywash/theme/app_theme_id.dart';
import 'package:wiggywash/theme/wiggy_tokens.dart';

void main() {
  test('classic light uses light brightness', () {
    final t = buildTheme(themeId: AppThemeId.classic, dark: false);
    expect(t.brightness, Brightness.light);
    expect(t.extension<WiggyTokens>(), isNotNull);
  });

  test('classic dark uses dark brightness', () {
    final t = buildTheme(themeId: AppThemeId.classic, dark: true);
    expect(t.brightness, Brightness.dark);
  });

  test('forest primary differs from classic', () {
    final c = buildTheme(themeId: AppThemeId.classic, dark: false);
    final f = buildTheme(themeId: AppThemeId.forest, dark: false);
    expect(c.colorScheme.primary, isNot(equals(f.colorScheme.primary)));
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/theme/build_theme_test.dart`  
Expected: FAIL — signature / types missing.

- [ ] **Step 3: Implement `WiggyTokens` ThemeExtension**

In `lib/theme/wiggy_tokens.dart`, define:

```dart
@immutable
class WiggyTokens extends ThemeExtension<WiggyTokens> {
  const WiggyTokens({
    required this.sectionHeader,
    required this.sectionHeaderText,
    required this.tallyBox,
    required this.tallyField,
    required this.hairline,
    required this.accent,
  });

  final Color sectionHeader;
  final Color sectionHeaderText;
  final Color tallyBox;
  final Color tallyField;
  final Color hairline;
  final Color accent;

  static WiggyTokens forId(AppThemeId id, {required bool dark}) { /* ... */ }

  @override
  WiggyTokens copyWith({...}) => ...;

  @override
  WiggyTokens lerp(ThemeExtension<WiggyTokens>? other, double t) { ... }
}
```

Token values (lock these in):

**classic light:** match today’s `AppColors` (navy primary `#1B2A4A`, rose header `#E9C4C7`, etc.).  
**classic dark:** scaffold `#121820`, surface `#1B2433`, primary `#8FC4E8`, onPrimary `#121820`, sectionHeader `#2A3548`, sectionHeaderText `#E9C4C7`, tallyBox `#3A5A78`, tallyField `#243044`, text light, hairline `#2E3A4D`.  
**forest light:** primary `#0B3D2E`, scaffold `#F3F7F4`, sectionHeader `#A8D5BA`, sectionHeaderText `#1B4332`, tallyBox `#6BBF8A`, tallyField `#E5F4EA`.  
**forest dark:** primary `#66BB6A`, scaffold `#0D1F17`, surface `#14261E`, onPrimary `#0D1F17`, sectionHeader `#1B4332`, sectionHeaderText `#C8E6C9`.  
**sky light:** primary `#1A365D`, scaffold `#F0F6FB`, sectionHeader `#90CDF4`, sectionHeaderText `#1A365D`.  
**sky dark:** primary `#63B3ED`, scaffold `#0B1524`, surface `#122033`.

- [ ] **Step 4: Change `buildTheme` signature**

Replace `buildTheme({Color? primary})` with:

```dart
ThemeData buildTheme({
  AppThemeId themeId = AppThemeId.classic,
  bool dark = false,
}) {
  final tokens = WiggyTokens.forId(themeId, dark: dark);
  final brand = _primaryFor(themeId, dark: dark);
  final scheme = ColorScheme.fromSeed(
    seedColor: brand,
    brightness: dark ? Brightness.dark : Brightness.light,
  ).copyWith(
    primary: brand,
    secondary: tokens.accent,
    surface: dark ? _surfaceFor(themeId, dark: true) : AppColors.surface,
    onPrimary: dark ? _onPrimaryFor(themeId) : Colors.white,
    onSurface: dark ? const Color(0xFFE8EEF6) : AppColors.textPrimary,
  );
  // Keep existing AppBar / button / input wiring from current theme.dart,
  // but scaffoldBackgroundColor from scheme / tokens.
  return base.copyWith(
    extensions: [tokens],
    // ... existing theme copies using brand/scheme
  );
}
```

Keep `AppColors` static constants as the classic-light reference used by widgets not yet reading `ThemeExtension`. Material chrome (AppBar, buttons, scaffold) must follow `buildTheme`.

Deprecate unused `primary:` parameter — update all call sites in Task 6.

- [ ] **Step 5: Run tests**

Run: `flutter test test/theme/build_theme_test.dart`  
Expected: PASS

- [ ] **Step 6: Commit**

```bash
git add lib/theme/wiggy_tokens.dart lib/theme.dart test/theme/build_theme_test.dart
git commit -m "feat: curated theme tokens with light and dark variants"
```

---

### Task 6: Dark mode prefs + wire `main.dart` + Store theme save

**Files:**
- Create: `lib/utils/dark_mode_prefs.dart`
- Create: `test/utils/dark_mode_prefs_test.dart`
- Modify: `lib/main.dart`
- Modify: `lib/services/store.dart` (add `updateCompanyThemeId`; stop using primary for theme)

- [ ] **Step 1: Write failing dark prefs tests**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wiggywash/utils/dark_mode_prefs.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('defaults false', () async {
    expect(await DarkModePrefs.load(), isFalse);
  });

  test('round-trip true', () async {
    await DarkModePrefs.save(true);
    expect(await DarkModePrefs.load(), isTrue);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/utils/dark_mode_prefs_test.dart`  
Expected: FAIL

- [ ] **Step 3: Implement prefs**

```dart
const kDarkModePrefsKey = 'ww_dark_mode';

class DarkModePrefs {
  static Future<bool> load() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(kDarkModePrefsKey) ?? false;
  }

  static Future<void> save(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(kDarkModePrefsKey, value);
  }
}
```

- [ ] **Step 4: Add `Store.updateCompanyThemeId`**

Mirror `updateCompanyPrimaryColor`, but write `themeId` and update `_activeCompany.copyWith(themeId: ...)`. Validate with `AppThemeIdX.parse` — only allow known ids (re-parse so unknown cannot be saved). Leave `primaryColor` untouched in Firestore (ignore going forward).

```dart
  Future<String?> updateCompanyThemeId(String themeId) async {
    final id = _activeCompanyId;
    if (id == null) return 'No active company.';
    final parsed = AppThemeIdX.parse(themeId);
    // Reject if input was garbage that collapsed to classic incorrectly:
    if (themeId.trim().isNotEmpty &&
        parsed == AppThemeId.classic &&
        themeId.trim() != 'classic') {
      return 'Unknown theme.';
    }
    try {
      await _companiesCol.doc(id).set(
        {'themeId': parsed.firestoreValue},
        SetOptions(merge: true),
      );
      if (_activeCompany != null) {
        _activeCompany =
            _activeCompany!.copyWith(themeId: parsed.firestoreValue);
      }
      notifyListeners();
      return null;
    } catch (e) {
      debugPrint('updateCompanyThemeId error: $e');
      return 'Could not save theme.';
    }
  }
```

Fix unknown rejection: only accept `AppThemeId.values.map((e) => e.name)`:

```dart
    final allowed = AppThemeId.values.map((e) => e.name).toSet();
    if (!allowed.contains(themeId)) return 'Unknown theme.';
    final parsed = AppThemeIdX.parse(themeId);
```

- [ ] **Step 5: Wire `WiggyWashApp`**

Hold dark mode in a small `ValueNotifier` or load once into `Store`/dedicated `ChangeNotifier`. Simplest Spec A approach: extend `Store` with `bool darkMode` + `Future<void> setDarkMode(bool)` that saves prefs and `notifyListeners()`, loaded in `Store.init()`.

In `main.dart`:

```dart
final themeId = AppThemeIdX.parse(Store.instance.activeCompany?.themeId);
return MaterialApp(
  theme: buildTheme(
    themeId: themeId,
    dark: Store.instance.darkMode,
  ),
  // ...
);
```

Remove `parseBrandColor` / `primaryColor` from `main.dart` theme construction.

- [ ] **Step 6: Run tests**

Run: `flutter test test/utils/dark_mode_prefs_test.dart test/models/company_test.dart test/theme/build_theme_test.dart`  
Expected: PASS

- [ ] **Step 7: Commit**

```bash
git add lib/utils/dark_mode_prefs.dart test/utils/dark_mode_prefs_test.dart lib/main.dart lib/services/store.dart
git commit -m "feat: dark mode prefs and company themeId wiring"
```

---

### Task 7: Settings UI — themes + dark mode; remove brand hex

**Files:**
- Modify: `lib/screens/settings_screen.dart`

- [ ] **Step 1: Replace Brand color card with Theme card**

Remove hex controllers, presets, `_save` brand color, and brand preview button.

Add company theme section (managers only — this screen is already manager-shell only):

```dart
// Segmented or radio list:
// Classic | Forest | Sky
// onSelectionChanged -> Store.instance.updateCompanyThemeId(...)
```

Show a small preview strip (three colored boxes using `WiggyTokens.forId` / `buildTheme` primary) under the control.

- [ ] **Step 2: Add Dark mode card (separate section)**

```dart
AppCard(
  child: Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Text('Dark mode', style: TextStyles.subheading),
      Text('This device only. Uses the dark variant of the company theme.',
          style: TextStyles.caption),
      SwitchListTile(
        contentPadding: EdgeInsets.zero,
        title: const Text('Use dark mode'),
        value: Store.instance.darkMode,
        onChanged: (v) => Store.instance.setDarkMode(v),
      ),
    ],
  ),
);
```

Keep Display density card; update its caption if needed (still notes Master Sheet density is separate).

- [ ] **Step 3: Manual / analyzer check**

Run: `dart analyze lib/screens/settings_screen.dart lib/main.dart lib/theme.dart`  
Expected: No issues.

- [ ] **Step 4: Commit**

```bash
git add lib/screens/settings_screen.dart
git commit -m "feat: Settings theme picker and personal dark mode"
```

---

### Task 8: Apply tokens on scorecard section chrome (minimum visual pass)

**Files:**
- Modify: `lib/widgets/tally_row.dart` and/or scorecard section headers that hardcode `AppColors.rose` / `AppColors.blue`
- Grep: `AppColors.rose`, `AppColors.blueSoft`, `AppColors.navy` in scorecard + team list headers

- [ ] **Step 1: Grep hardcoded section colors**

Run: `rg "AppColors\\.(rose|blueSoft|blue|navy)" lib/widgets/tally_row.dart lib/screens/scorecard_screen.dart lib/screens/team_screen.dart lib/screens/master_sheet_screen.dart -n`

- [ ] **Step 2: Prefer ThemeExtension where section headers / tally fills are painted**

Pattern:

```dart
final tokens = Theme.of(context).extension<WiggyTokens>() ??
    WiggyTokens.forId(AppThemeId.classic, dark: false);
// use tokens.sectionHeader, tokens.tallyField, etc.
```

Do not rewrite the entire app — focus on scorecard tally chrome + any obvious Team header chips so Forest/Sky are visible beyond AppBar color.

- [ ] **Step 3: Analyzer + smoke tests**

Run: `flutter test test/theme/build_theme_test.dart test/screens/tips_copy_test.dart test/utils/ui_density_test.dart`  
Expected: PASS

- [ ] **Step 4: Commit**

```bash
git add lib/widgets/tally_row.dart lib/screens/scorecard_screen.dart # + any other files touched
git commit -m "feat: apply theme tokens on scorecard section chrome"
```

---

### Task 9: Verification checklist

- [ ] **Step 1: Automated suite**

Run:

```bash
flutter test test/screens/tips_copy_test.dart \
  test/utils/ui_density_test.dart \
  test/utils/firestore_user_error_test.dart \
  test/utils/dark_mode_prefs_test.dart \
  test/models/company_test.dart \
  test/theme/build_theme_test.dart \
  test/utils/manager_invite_logic_test.dart
```

Expected: all PASS

- [ ] **Step 2: Manual QA**

1. Tips → employee tip #3 mentions Save / Submit, not “tap Your total today”.
2. Settings → Compact vs Comfortable: scorecard stepper size / padding clearly changes.
3. Team → invite manager: success string mentions Google email; force a bad permission case if possible and confirm mapped error.
4. Settings → switch Classic / Forest / Sky: AppBar + scorecard section colors update for all managers/employees on reload.
5. Dark mode switch: this device only; other devices stay light.
6. Master Sheet density control still independent.

- [ ] **Step 3: Commit any leftover copy tweaks only if needed**

---

## Spec coverage self-check

| Spec requirement | Task |
|------------------|------|
| Honest tip #3 | Task 1 |
| Obvious density | Task 2 |
| Invite errors + success | Task 3 |
| Company `themeId` curated themes | Tasks 4–5, 7 |
| Personal dark mode | Tasks 5–7 |
| Ignore `primaryColor` / remove hex UI | Tasks 6–7 |
| Wire Team/Sheet/Scorecard chrome | Tasks 6–8 |
| Spec B parked | Out of scope (noted in header) |

## Placeholder / consistency self-check

- No TBD steps; theme color values locked in Task 5.
- `themeId` string on `Company` matches `AppThemeId.name`.
- `buildTheme(themeId:, dark:)` is the only theme entry point after Task 6.
- `updateCompanyThemeId` is the only Settings theme write path.
