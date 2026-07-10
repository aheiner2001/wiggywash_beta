import 'package:intl/intl.dart';

import '../models/staff_request.dart';

const kStaffRequestMaxLen = 120;
const kStaffRequestPresetCap = 20;
const kCompletionPresetCap = 10;
const kStaffRequestDebounce = Duration(seconds: 2);

final _staffRequestTime = DateFormat('h:mm a');
final _dueDate = DateFormat('MMM d · h:mm a');

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
    (StaffRequestStatus.accepted, StaffRequestStatus.assigned) => true,
    (StaffRequestStatus.accepted, StaffRequestStatus.closed) => true,
    (StaffRequestStatus.accepted, StaffRequestStatus.dismissed) => true,
    (StaffRequestStatus.assigned, StaffRequestStatus.awaitingReview) => true,
    (StaffRequestStatus.assigned, StaffRequestStatus.dismissed) => true,
    (StaffRequestStatus.awaitingReview, StaffRequestStatus.closed) => true,
    (StaffRequestStatus.awaitingReview, StaffRequestStatus.assigned) => true,
    _ => false,
  };
}

String? validateCompletionPayload({
  required String note,
  String? presetLabel,
}) {
  final n = note.trim();
  final p = presetLabel?.trim() ?? '';
  if (n.isEmpty && p.isEmpty) {
    return 'Add a short note or pick a completion preset.';
  }
  if (n.length > kStaffRequestMaxLen) {
    return 'Keep it under $kStaffRequestMaxLen characters.';
  }
  return null;
}

/// Manager-assigned (non-personal) first, then by dueAt ascending (nulls last),
/// then createdAt descending.
List<StaffRequest> sortEmployeeTodos(List<StaffRequest> items) {
  final copy = [...items];
  copy.sort((a, b) {
    final aMgr = !a.isPersonal;
    final bMgr = !b.isPersonal;
    if (aMgr != bMgr) return aMgr ? -1 : 1;
    final ad = a.dueAt;
    final bd = b.dueAt;
    if (ad != null && bd != null) {
      final c = ad.compareTo(bd);
      if (c != 0) return c;
    } else if (ad != null) {
      return -1;
    } else if (bd != null) {
      return 1;
    }
    final at = a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
    final bt = b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
    return bt.compareTo(at);
  });
  return copy;
}

String formatDueCaption(DateTime? dueAt, {DateTime? now}) {
  if (dueAt == null) return '';
  final n = now ?? DateTime.now();
  final sameDay =
      dueAt.year == n.year && dueAt.month == n.month && dueAt.day == n.day;
  if (sameDay) {
    return 'Due · ${formatStaffRequestTime(dueAt)}';
  }
  return 'Due · ${_dueDate.format(dueAt)}';
}

bool isManagerBoardVisible(StaffRequest r) {
  if (r.source == StaffRequestSource.employeePersonal) return false;
  return true;
}
