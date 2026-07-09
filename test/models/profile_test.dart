import 'package:flutter_test/flutter_test.dart';
import 'package:wiggywash/models/profile.dart';

void main() {
  test('roleFromString accepts legacy superAdmin', () {
    expect(roleFromString('superAdmin'), UserRole.platformAdmin);
  });

  test('roleFromString accepts legacy manager', () {
    expect(roleFromString('manager'), UserRole.companyManager);
  });

  test('roleFromString accepts new companyManager', () {
    expect(roleFromString('companyManager'), UserRole.companyManager);
  });
}
