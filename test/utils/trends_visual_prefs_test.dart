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
