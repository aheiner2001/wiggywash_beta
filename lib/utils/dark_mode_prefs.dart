import 'package:shared_preferences/shared_preferences.dart';

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
