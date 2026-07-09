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
