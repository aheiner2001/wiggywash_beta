import 'package:flutter_test/flutter_test.dart';
import 'package:wiggywash/models/staff_request.dart';

void main() {
  test('StaffRequest.fromMap parses pending', () {
    final r = StaffRequest.fromMap('r1', {
      'text': 'Out of soap',
      'employeeName': 'Alex',
      'employeeProfileKey': 'alex',
      'status': 'pending',
      'presetId': 'p1',
    });
    expect(r.id, 'r1');
    expect(r.text, 'Out of soap');
    expect(r.employeeName, 'Alex');
    expect(r.status, StaffRequestStatus.pending);
    expect(r.presetId, 'p1');
  });

  test('unknown status falls back to pending', () {
    final r = StaffRequest.fromMap('r1', {
      'text': 'x',
      'employeeName': 'Alex',
      'status': 'weird',
    });
    expect(r.status, StaffRequestStatus.pending);
  });

  test('toMap writes status name', () {
    const r = StaffRequest(
      id: 'r1',
      text: 'Help',
      employeeName: 'Alex',
      status: StaffRequestStatus.accepted,
    );
    expect(r.toMap()['status'], 'accepted');
  });
}
