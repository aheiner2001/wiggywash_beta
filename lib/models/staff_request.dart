import 'package:cloud_firestore/cloud_firestore.dart';

enum StaffRequestStatus {
  pending,
  accepted,
  assigned,
  awaitingReview,
  closed,
  dismissed,
  /// Legacy wire value only — parse maps to [closed]. Prefer [closed] in code.
  completed,
}

enum StaffRequestSource { employeeAsk, managerAssign, employeePersonal }

extension StaffRequestStatusX on StaffRequestStatus {
  String get firestoreValue => switch (this) {
        StaffRequestStatus.completed => 'closed',
        _ => name,
      };

  String get employeeLabel => switch (this) {
        StaffRequestStatus.pending => 'Sent',
        StaffRequestStatus.accepted => 'Accepted',
        StaffRequestStatus.assigned => 'To-do',
        StaffRequestStatus.awaitingReview => 'Waiting review',
        StaffRequestStatus.closed => 'Done',
        StaffRequestStatus.completed => 'Done',
        StaffRequestStatus.dismissed => 'Dismissed',
      };

  static StaffRequestStatus parse(String? raw) {
    if (raw == null || raw.isEmpty) return StaffRequestStatus.pending;
    if (raw == 'completed') return StaffRequestStatus.closed;
    for (final s in StaffRequestStatus.values) {
      if (s == StaffRequestStatus.completed) continue;
      if (s.name == raw) return s;
    }
    return StaffRequestStatus.pending;
  }
}

extension StaffRequestSourceX on StaffRequestSource {
  String get firestoreValue => switch (this) {
        StaffRequestSource.employeeAsk => 'employee_ask',
        StaffRequestSource.managerAssign => 'manager_assign',
        StaffRequestSource.employeePersonal => 'employee_personal',
      };

  bool get isManagerAssigned =>
      this == StaffRequestSource.managerAssign ||
      this == StaffRequestSource.employeeAsk;

  static StaffRequestSource parse(String? raw) {
    return switch (raw) {
      'manager_assign' => StaffRequestSource.managerAssign,
      'employee_personal' => StaffRequestSource.employeePersonal,
      _ => StaffRequestSource.employeeAsk,
    };
  }
}

class StaffRequest {
  const StaffRequest({
    required this.id,
    required this.text,
    required this.employeeName,
    this.employeeProfileKey,
    this.presetId,
    this.source = StaffRequestSource.employeeAsk,
    this.status = StaffRequestStatus.pending,
    this.assigneeName,
    this.assigneeProfileKey,
    this.assignedAt,
    this.assignedByUid,
    this.dueAt,
    this.completionNote,
    this.completionPresetId,
    this.completionPresetLabel,
    this.reviewedAt,
    this.reviewedByUid,
    this.createdAt,
    this.acceptedAt,
    this.acceptedByUid,
    this.completedAt,
    this.completedByUid,
    this.dismissedAt,
  });

  final String id;
  final String text;
  final String employeeName;
  final String? employeeProfileKey;
  final String? presetId;
  final StaffRequestSource source;
  final StaffRequestStatus status;
  final String? assigneeName;
  final String? assigneeProfileKey;
  final DateTime? assignedAt;
  final String? assignedByUid;
  final DateTime? dueAt;
  final String? completionNote;
  final String? completionPresetId;
  final String? completionPresetLabel;
  final DateTime? reviewedAt;
  final String? reviewedByUid;
  final DateTime? createdAt;
  final DateTime? acceptedAt;
  final String? acceptedByUid;
  final DateTime? completedAt;
  final String? completedByUid;
  final DateTime? dismissedAt;

  bool get isPersonal => source == StaffRequestSource.employeePersonal;

  Map<String, dynamic> toMap() => {
        'text': text.trim(),
        'employeeName': employeeName.trim(),
        if (employeeProfileKey != null)
          'employeeProfileKey': employeeProfileKey,
        if (presetId != null) 'presetId': presetId,
        'source': source.firestoreValue,
        'status': status.firestoreValue,
        if (assigneeName != null) 'assigneeName': assigneeName,
        if (assigneeProfileKey != null)
          'assigneeProfileKey': assigneeProfileKey,
        if (assignedAt != null) 'assignedAt': Timestamp.fromDate(assignedAt!),
        if (assignedByUid != null) 'assignedByUid': assignedByUid,
        if (dueAt != null) 'dueAt': Timestamp.fromDate(dueAt!),
        if (completionNote != null) 'completionNote': completionNote,
        if (completionPresetId != null)
          'completionPresetId': completionPresetId,
        if (completionPresetLabel != null)
          'completionPresetLabel': completionPresetLabel,
        if (reviewedAt != null) 'reviewedAt': Timestamp.fromDate(reviewedAt!),
        if (reviewedByUid != null) 'reviewedByUid': reviewedByUid,
        'createdAt': createdAt != null
            ? Timestamp.fromDate(createdAt!)
            : FieldValue.serverTimestamp(),
        if (acceptedAt != null) 'acceptedAt': Timestamp.fromDate(acceptedAt!),
        if (acceptedByUid != null) 'acceptedByUid': acceptedByUid,
        if (completedAt != null)
          'completedAt': Timestamp.fromDate(completedAt!),
        if (completedByUid != null) 'completedByUid': completedByUid,
        if (dismissedAt != null)
          'dismissedAt': Timestamp.fromDate(dismissedAt!),
      };

  factory StaffRequest.fromMap(String id, Map<String, dynamic> data) {
    DateTime? asDate(dynamic v) => v is Timestamp ? v.toDate() : null;
    return StaffRequest(
      id: id,
      text: (data['text'] as String? ?? '').trim(),
      employeeName: (data['employeeName'] as String? ?? '').trim(),
      employeeProfileKey: data['employeeProfileKey'] as String?,
      presetId: data['presetId'] as String?,
      source: StaffRequestSourceX.parse(data['source'] as String?),
      status: StaffRequestStatusX.parse(data['status'] as String?),
      assigneeName: data['assigneeName'] as String?,
      assigneeProfileKey: data['assigneeProfileKey'] as String?,
      assignedAt: asDate(data['assignedAt']),
      assignedByUid: data['assignedByUid'] as String?,
      dueAt: asDate(data['dueAt']),
      completionNote: data['completionNote'] as String?,
      completionPresetId: data['completionPresetId'] as String?,
      completionPresetLabel: data['completionPresetLabel'] as String?,
      reviewedAt: asDate(data['reviewedAt']),
      reviewedByUid: data['reviewedByUid'] as String?,
      createdAt: asDate(data['createdAt']),
      acceptedAt: asDate(data['acceptedAt']),
      acceptedByUid: data['acceptedByUid'] as String?,
      completedAt: asDate(data['completedAt']),
      completedByUid: data['completedByUid'] as String?,
      dismissedAt: asDate(data['dismissedAt']),
    );
  }

  factory StaffRequest.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) =>
      StaffRequest.fromMap(doc.id, doc.data() ?? {});
}
