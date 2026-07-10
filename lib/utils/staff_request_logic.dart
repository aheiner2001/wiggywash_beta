import 'package:intl/intl.dart';

import '../models/staff_request.dart';

const kStaffRequestMaxLen = 120;
const kStaffRequestPresetCap = 20;
const kStaffRequestDebounce = Duration(seconds: 2);

final _staffRequestTime = DateFormat('h:mm a');

String formatStaffRequestTime(DateTime? createdAt) {
  if (createdAt == null) return '';
  return _staffRequestTime.format(createdAt);
}

String employeeRequestCaption(StaffRequestStatus status, DateTime? createdAt) {
  final time = formatStaffRequestTime(createdAt);
  if (time.isEmpty) return status.employeeLabel;
  return '${status.employeeLabel} · $time';
}

String staffRequestProfileKey(String name) => name.trim().toLowerCase();

String? validateRequestText(String raw) {
  final t = raw.trim();
  if (t.isEmpty) return 'Enter a short request.';
  if (t.length > kStaffRequestMaxLen) {
    return 'Keep it under $kStaffRequestMaxLen characters.';
  }
  return null;
}

String? validatePresetLabel(String raw) {
  final t = raw.trim();
  if (t.isEmpty) return 'Enter a preset label.';
  if (t.length > kStaffRequestMaxLen) {
    return 'Keep it under $kStaffRequestMaxLen characters.';
  }
  return null;
}

bool canTransition(StaffRequestStatus from, StaffRequestStatus to) {
  return switch ((from, to)) {
    (StaffRequestStatus.pending, StaffRequestStatus.accepted) => true,
    (StaffRequestStatus.pending, StaffRequestStatus.dismissed) => true,
    (StaffRequestStatus.accepted, StaffRequestStatus.completed) => true,
    _ => false,
  };
}
