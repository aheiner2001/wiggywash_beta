import 'package:shared_preferences/shared_preferences.dart';

const _kPrefix = 'ww_staff_req_seen_';

/// Device-local IDs of manager-assigned tasks the employee has already seen.
class StaffRequestSeenPrefs {
  static String _key(String locationId, String profileKey) =>
      '$_kPrefix${locationId}_$profileKey';

  static Future<Set<String>> load({
    required String locationId,
    required String profileKey,
  }) async {
    if (locationId.isEmpty || profileKey.isEmpty) return {};
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList(_key(locationId, profileKey)) ?? const [];
    return list.toSet();
  }

  static Future<void> addIds({
    required String locationId,
    required String profileKey,
    required Iterable<String> ids,
  }) async {
    if (locationId.isEmpty || profileKey.isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    final key = _key(locationId, profileKey);
    final next = {...(prefs.getStringList(key) ?? const []), ...ids};
    await prefs.setStringList(key, next.toList());
  }
}
