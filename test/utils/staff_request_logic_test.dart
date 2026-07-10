import 'package:flutter_test/flutter_test.dart';
import 'package:wiggywash/models/staff_request.dart';
import 'package:wiggywash/utils/staff_request_logic.dart';

void main() {
  test('profileKey lowercases and trims', () {
    expect(staffRequestProfileKey('  Alex  '), 'alex');
  });

  test('validateRequestText rejects empty and over 120', () {
    expect(validateRequestText(''), isNotNull);
    expect(validateRequestText('x' * 121), isNotNull);
    expect(validateRequestText('Out of soap'), isNull);
  });

  test('canAccept only from pending', () {
    expect(
      canTransition(
        StaffRequestStatus.pending,
        StaffRequestStatus.accepted,
      ),
      isTrue,
    );
    expect(
      canTransition(
        StaffRequestStatus.accepted,
        StaffRequestStatus.completed,
      ),
      isTrue,
    );
    expect(
      canTransition(
        StaffRequestStatus.pending,
        StaffRequestStatus.dismissed,
      ),
      isTrue,
    );
    expect(
      canTransition(
        StaffRequestStatus.completed,
        StaffRequestStatus.accepted,
      ),
      isFalse,
    );
  });

  test('formatStaffRequestTime empty when null', () {
    expect(formatStaffRequestTime(null), '');
  });

  test('formatStaffRequestTime uses h:mm a', () {
    final t = DateTime(2026, 7, 9, 15, 42);
    expect(formatStaffRequestTime(t), '3:42 PM');
  });

  test('employeeRequestCaption status only when no time', () {
    expect(
      employeeRequestCaption(StaffRequestStatus.pending, null),
      'Sent',
    );
  });

  test('employeeRequestCaption status · time', () {
    final t = DateTime(2026, 7, 9, 15, 42);
    expect(
      employeeRequestCaption(StaffRequestStatus.completed, t),
      'Done · 3:42 PM',
    );
  });
}
