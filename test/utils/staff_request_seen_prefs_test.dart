import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wiggywash/utils/staff_request_seen_prefs.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
  });

  test('load empty by default', () async {
    final ids = await StaffRequestSeenPrefs.load(
      locationId: 'loc',
      profileKey: 'alex',
    );
    expect(ids, isEmpty);
  });

  test('addIds round-trips', () async {
    await StaffRequestSeenPrefs.addIds(
      locationId: 'loc',
      profileKey: 'alex',
      ids: ['a', 'b'],
    );
    final ids = await StaffRequestSeenPrefs.load(
      locationId: 'loc',
      profileKey: 'alex',
    );
    expect(ids, {'a', 'b'});
  });
}
