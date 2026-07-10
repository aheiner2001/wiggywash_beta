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
