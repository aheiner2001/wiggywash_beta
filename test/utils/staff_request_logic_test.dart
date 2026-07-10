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
        StaffRequestStatus.closed,
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
        StaffRequestStatus.closed,
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
      employeeRequestCaption(StaffRequestStatus.closed, t),
      'Done · 3:42 PM',
    );
  });

  test('canTransition assign and review paths', () {
    expect(
      canTransition(StaffRequestStatus.accepted, StaffRequestStatus.assigned),
      isTrue,
    );
    expect(
      canTransition(StaffRequestStatus.accepted, StaffRequestStatus.closed),
      isTrue,
    );
    expect(
      canTransition(StaffRequestStatus.accepted, StaffRequestStatus.dismissed),
      isTrue,
    );
    expect(
      canTransition(
        StaffRequestStatus.assigned,
        StaffRequestStatus.awaitingReview,
      ),
      isTrue,
    );
    expect(
      canTransition(
        StaffRequestStatus.awaitingReview,
        StaffRequestStatus.closed,
      ),
      isTrue,
    );
    expect(
      canTransition(
        StaffRequestStatus.awaitingReview,
        StaffRequestStatus.assigned,
      ),
      isTrue,
    );
    expect(
      canTransition(StaffRequestStatus.closed, StaffRequestStatus.assigned),
      isFalse,
    );
  });

  test('legacy completed transition treated as closed target from accepted', () {
    expect(
      canTransition(StaffRequestStatus.accepted, StaffRequestStatus.completed),
      isFalse,
    );
  });

  test('validateCompletionPayload requires note or preset', () {
    expect(validateCompletionPayload(note: '', presetLabel: null), isNotNull);
    expect(validateCompletionPayload(note: '  ', presetLabel: ''), isNotNull);
    expect(validateCompletionPayload(note: 'Done', presetLabel: null), isNull);
    expect(
      validateCompletionPayload(note: '', presetLabel: 'All good'),
      isNull,
    );
  });

  test('sortEmployeeTodos manager-assigned first then due', () {
    final personal = StaffRequest(
      id: 'p',
      text: 'Buy milk',
      employeeName: 'Alex',
      source: StaffRequestSource.employeePersonal,
      status: StaffRequestStatus.assigned,
      assigneeProfileKey: 'alex',
    );
    final mgrLate = StaffRequest(
      id: 'm2',
      text: 'Late',
      employeeName: 'Alex',
      source: StaffRequestSource.managerAssign,
      status: StaffRequestStatus.assigned,
      assigneeProfileKey: 'alex',
      dueAt: DateTime(2026, 7, 10, 18),
    );
    final mgrSoon = StaffRequest(
      id: 'm1',
      text: 'Soon',
      employeeName: 'Alex',
      source: StaffRequestSource.managerAssign,
      status: StaffRequestStatus.assigned,
      assigneeProfileKey: 'alex',
      dueAt: DateTime(2026, 7, 10, 9),
    );
    final sorted = sortEmployeeTodos([personal, mgrLate, mgrSoon]);
    expect(sorted.map((r) => r.id).toList(), ['m1', 'm2', 'p']);
  });

  test('formatDueCaption empty when null', () {
    expect(formatDueCaption(null, now: DateTime(2026, 7, 9, 12)), '');
  });

  test('formatDueCaption today uses time only', () {
    final due = DateTime(2026, 7, 9, 15, 42);
    expect(
      formatDueCaption(due, now: DateTime(2026, 7, 9, 10)),
      'Due · 3:42 PM',
    );
  });
}
