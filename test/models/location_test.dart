import 'package:flutter_test/flutter_test.dart';
import 'package:wiggywash/models/location.dart';
import 'package:wiggywash/models/location_access.dart';

void main() {
  test('missing accessStatus defaults to active', () {
    final loc = Location.fromMap('L1', {
      'name': 'Main',
      'city': 'Boise',
      'active': true,
    });
    expect(loc.accessStatus, LocationAccessStatus.active);
    expect(loc.trialEndsAt, isNull);
  });

  test('parses read_only and trialEndsAt', () {
    final loc = Location.fromMap('L1', {
      'name': 'Main',
      'accessStatus': 'read_only',
      'trialEndsAt': null,
    });
    expect(loc.accessStatus, LocationAccessStatus.readOnly);
  });
}
