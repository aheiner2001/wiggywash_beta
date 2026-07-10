import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

const kUiDensityPrefsKey = 'ww_ui_density';

enum UiDensity { comfortable, compact }

extension UiDensityTokens on UiDensity {
  /// Compact zooms UI slightly so more fits on screen.
  double get textScale => switch (this) {
        UiDensity.comfortable => 1.0,
        UiDensity.compact => 0.88,
      };

  double get pagePadding => switch (this) {
        UiDensity.comfortable => 18,
        UiDensity.compact => 8,
      };

  double get sectionGap => switch (this) {
        UiDensity.comfortable => 16,
        UiDensity.compact => 6,
      };

  double get loginCardPadding => switch (this) {
        UiDensity.comfortable => 32,
        UiDensity.compact => 14,
      };

  double get tallyVerticalMargin => switch (this) {
        UiDensity.comfortable => 10,
        UiDensity.compact => 2,
      };

  /// Minimum circular +/- diameter. Phone one-thumb pass may raise further.
  double get stepButtonSize => switch (this) {
        UiDensity.comfortable => 56,
        UiDensity.compact => 40,
      };

  double get peopleCardPadding => switch (this) {
        UiDensity.comfortable => 16,
        UiDensity.compact => 8,
      };
}

/// Device-local density; notifies so MaterialApp / screens update live.
class UiDensityController extends ChangeNotifier {
  UiDensityController._();
  static final UiDensityController instance = UiDensityController._();

  UiDensity _density = UiDensity.comfortable;
  UiDensity get density => _density;
  bool _loaded = false;
  bool get loaded => _loaded;

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(kUiDensityPrefsKey);
    var next = UiDensity.comfortable;
    if (raw != null && raw.isNotEmpty) {
      for (final d in UiDensity.values) {
        if (d.name == raw) {
          next = d;
          break;
        }
      }
    }
    _density = next;
    _loaded = true;
    notifyListeners();
  }

  Future<void> setDensity(UiDensity value) async {
    if (_density == value) return;
    _density = value;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(kUiDensityPrefsKey, value.name);
  }
}

/// @Deprecated — prefer [UiDensityController]. Kept for call-site compatibility.
class UiDensityPrefs {
  const UiDensityPrefs({required this.density});
  final UiDensity density;

  factory UiDensityPrefs.defaults() =>
      const UiDensityPrefs(density: UiDensity.comfortable);

  static Future<UiDensityPrefs> load() async {
    await UiDensityController.instance.load();
    return UiDensityPrefs(density: UiDensityController.instance.density);
  }

  static Future<void> save(UiDensityPrefs value) async {
    await UiDensityController.instance.setDensity(value.density);
  }
}
