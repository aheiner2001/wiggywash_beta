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
}
