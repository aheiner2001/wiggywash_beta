import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wiggywash/utils/staff_request_clear_prefs.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('load empty by default', () async {
    final ids = await StaffRequestClearPrefs.load(
      locationId: 'loc1',
      profileKey: 'alex',
    );
    expect(ids, isEmpty);
  });

  test('addIds round-trips', () async {
    await StaffRequestClearPrefs.addIds(
      locationId: 'loc1',
      profileKey: 'alex',
      ids: ['a', 'b'],
    );
    final ids = await StaffRequestClearPrefs.load(
      locationId: 'loc1',
      profileKey: 'alex',
    );
    expect(ids, containsAll(['a', 'b']));
  });
}
