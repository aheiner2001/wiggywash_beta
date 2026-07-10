import 'package:flutter_test/flutter_test.dart';
import 'package:wiggywash/models/location_access.dart';

void main() {
  test('parse known values', () {
    expect(LocationAccessStatusX.parse('active'), LocationAccessStatus.active);
    expect(LocationAccessStatusX.parse('trial'), LocationAccessStatus.trial);
    expect(LocationAccessStatusX.parse('comp'), LocationAccessStatus.comp);
    expect(
      LocationAccessStatusX.parse('read_only'),
      LocationAccessStatus.readOnly,
    );
  });

  test('null or unknown defaults to active', () {
    expect(LocationAccessStatusX.parse(null), LocationAccessStatus.active);
    expect(LocationAccessStatusX.parse('nope'), LocationAccessStatus.active);
  });

  test('firestoreValue for comp', () {
    expect(LocationAccessStatus.comp.firestoreValue, 'comp');
  });
}
