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
