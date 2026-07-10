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
