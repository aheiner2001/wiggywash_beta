import 'package:flutter_test/flutter_test.dart';
import 'package:wiggywash/models/location_access.dart';
import 'package:wiggywash/utils/location_entitlement.dart';

void main() {
  test('active and trial allow writes', () {
    expect(locationAllowsWrites(LocationAccessStatus.active), isTrue);
    expect(locationAllowsWrites(LocationAccessStatus.trial), isTrue);
  });

  test('readOnly blocks writes', () {
    expect(locationAllowsWrites(LocationAccessStatus.readOnly), isFalse);
  });

  test('effectiveAccess flips expired trial to readOnly', () {
    final past = DateTime.now().subtract(const Duration(days: 1));
    expect(
      effectiveAccess(LocationAccessStatus.trial, trialEndsAt: past),
      LocationAccessStatus.readOnly,
    );
  });

  test('seatUsed counts active and trial only', () {
    expect(
      seatsUsed([
        LocationAccessStatus.active,
        LocationAccessStatus.trial,
        LocationAccessStatus.readOnly,
      ]),
      2,
    );
  });

  test('canActivateAnother is false when at capacity', () {
    expect(canActivateAnother(purchasedSeats: 2, seatsUsed: 2), isFalse);
    expect(canActivateAnother(purchasedSeats: 2, seatsUsed: 1), isTrue);
  });
}
